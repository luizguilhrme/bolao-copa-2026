const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

// Dispara quando o admin insere ou corrige um placar em /jogos/{jogoId}.
// Recalcula e aplica o delta de pontuação para cada participante que fez
// palpite nesse jogo. Após o commit, envia notificações de mudança de ranking.
exports.calcularPontuacao = onDocumentUpdated(
  { document: 'jogos/{jogoId}', region: 'southamerica-east1' },
  async (event) => {
    const antes = event.data.before.data();
    const depois = event.data.after.data();

    if (antes.placar1 === depois.placar1 && antes.placar2 === depois.placar2) return null;
    if (depois.placar1 == null || depois.placar2 == null) return null;

    const db = getFirestore();
    const jogoId = depois.id;

    const palpitesSnap = await db
      .collection('palpites')
      .where('jogoId', '==', jogoId)
      .get();

    // Lê ranking atual (antes do batch) para calcular mudanças de posição
    const usuariosSnap = await db.collection('usuarios').orderBy('pontuacao', 'desc').get();
    const rankingAntes = {};
    const pontuacaoAtual = {};
    usuariosSnap.docs.forEach((doc, idx) => {
      rankingAntes[doc.id] = idx + 1;
      pontuacaoAtual[doc.id] = doc.data().pontuacao || 0;
    });

    // Calcula deltas e acumula por uid (um usuário pode ter feito palpites em
    // múltiplos jogos afetados pela mesma correção de placar, embora raro)
    const deltasPorUid = {};
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      let delta = 0;
      if (antes.placar1 != null && antes.placar2 != null) {
        delta -= calcularPontos(p.palpite1, p.palpite2, antes.placar1, antes.placar2);
      }
      delta += calcularPontos(p.palpite1, p.palpite2, depois.placar1, depois.placar2);
      if (delta !== 0) deltasPorUid[p.uid] = (deltasPorUid[p.uid] || 0) + delta;
    });

    // Regra −1: na primeira vez que o resultado é inserido, penaliza usuários
    // sem palpite que criaram conta antes do início do jogo.
    const primeiraVez = antes.placar1 == null || antes.placar2 == null;
    if (primeiraVez) {
      const comPalpite = new Set(palpitesSnap.docs.map((d) => d.data().uid));
      const gameDataHora = depois.dataHora?.toDate?.();
      if (gameDataHora) {
        usuariosSnap.docs.forEach((doc) => {
          if (comPalpite.has(doc.id)) return;
          const criadoEm = doc.data().criadoEm?.toDate?.();
          if (!criadoEm || criadoEm >= gameDataHora) return;
          deltasPorUid[doc.id] = (deltasPorUid[doc.id] || 0) - 1;
        });
      }
    }

    if (Object.keys(deltasPorUid).length === 0) return null;

    const batch = db.batch();
    for (const [uid, delta] of Object.entries(deltasPorUid)) {
      batch.update(db.collection('usuarios').doc(uid), {
        pontuacao: FieldValue.increment(delta),
      });
    }
    await batch.commit();

    // Projeta novo ranking em memória (evita segunda leitura do Firestore)
    const novaPontuacao = { ...pontuacaoAtual };
    for (const [uid, delta] of Object.entries(deltasPorUid)) {
      novaPontuacao[uid] = (novaPontuacao[uid] || 0) + delta;
    }
    const rankingDepois = Object.keys(novaPontuacao)
      .sort((a, b) => novaPontuacao[b] - novaPontuacao[a])
      .reduce((acc, uid, idx) => { acc[uid] = idx + 1; return acc; }, {});

    // Envia notificações para quem mudou de posição e tem notifRanking ativo
    const messaging = getMessaging();
    const usuariosData = {};
    usuariosSnap.docs.forEach((doc) => { usuariosData[doc.id] = doc.data(); });

    for (const uid of Object.keys(rankingDepois)) {
      const posAntes = rankingAntes[uid];
      const posDepois = rankingDepois[uid];
      if (posAntes === posDepois) continue;

      const userData = usuariosData[uid];
      if (!userData?.fcmToken) continue;
      if (userData.notifRanking === false) continue;

      const delta = posAntes - posDepois; // positivo = subiu, negativo = desceu
      const abs = Math.abs(delta);
      const pos = `${posDepois}º lugar`;
      const body = delta > 0
        ? `Você subiu ${abs} posição${abs > 1 ? 'ões' : ''} no ranking! Agora está em ${pos}.`
        : `Você caiu ${abs} posição${abs > 1 ? 'ões' : ''} no ranking. Agora está em ${pos}.`;

      await _enviarNotificacao(messaging, db, uid, userData.fcmToken, {
        title: '📊 Ranking atualizado',
        body,
        data: { tela: 'ranking' },
      });
    }

    return null;
  }
);

// Roda a cada 30 minutos e notifica usuários que ainda não palpitaram em jogos
// que começam em ~30 minutos.
exports.lembretesPalpite = onSchedule(
  { schedule: '*/30 * * * *', region: 'southamerica-east1', timeZone: 'America/Sao_Paulo' },
  async () => {
    const db = getFirestore();
    const messaging = getMessaging();
    const agora = new Date();

    // Janela: jogos que começam entre 25 e 35 minutos a partir de agora
    const inicio = new Date(agora.getTime() + 25 * 60 * 1000);
    const fim = new Date(agora.getTime() + 35 * 60 * 1000);

    const jogosSnap = await db.collection('jogos')
      .where('dataHora', '>=', Timestamp.fromDate(inicio))
      .where('dataHora', '<=', Timestamp.fromDate(fim))
      .get();

    if (jogosSnap.empty) return null;

    const jogoIds = jogosSnap.docs.map((d) => d.data().id);

    // Palpites já registrados nesses jogos
    const palpitesSnap = await db.collection('palpites')
      .where('jogoId', 'in', jogoIds)
      .get();

    const palpitadosPorJogo = {};
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      if (!palpitadosPorJogo[p.jogoId]) palpitadosPorJogo[p.jogoId] = new Set();
      palpitadosPorJogo[p.jogoId].add(p.uid);
    });

    // Todos os usuários — trata ausência de notifLembretes como true (padrão)
    const usuariosSnap = await db.collection('usuarios').get();

    for (const userDoc of usuariosSnap.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data();
      if (!userData.fcmToken) continue;
      if (userData.notifLembretes === false) continue;

      const jogosSemPalpite = jogosSnap.docs.filter((jDoc) => {
        const jId = jDoc.data().id;
        return !palpitadosPorJogo[jId]?.has(uid);
      });

      if (jogosSemPalpite.length === 0) continue;

      let title, body;
      if (jogosSemPalpite.length === 1) {
        const j = jogosSemPalpite[0].data();
        title = '⚽ Lembrete de palpite';
        body = `${j.team1} × ${j.team2} começa em 30 minutos! Não esqueça de registrar seu palpite!`;
      } else {
        title = '⚽ Lembretes de palpite';
        body = `${jogosSemPalpite.length} jogos começam em 30 minutos! Não esqueça de registrar seus palpites!`;
      }

      await _enviarNotificacao(messaging, db, uid, userData.fcmToken, { title, body, data: { tela: 'palpites' } });
    }

    return null;
  }
);

// Recalcula pontuação de TODOS os usuários do zero, a partir dos placares
// e palpites atuais. Útil para corrigir inconsistências geradas em testes.
// Só pode ser chamada por um usuário com isAdmin == true no Firestore.
exports.recalcularTudo = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Não autenticado.');
    }

    const db = getFirestore();

    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    const jogosSnap = await db.collection('jogos').get();
    const jogosPorId = {};
    jogosSnap.forEach((doc) => {
      const d = doc.data();
      if (d.placar1 != null && d.placar2 != null) jogosPorId[d.id] = d;
    });

    const pontuacaoPorUid = {};
    const palpitesSnap = await db.collection('palpites').get();

    // Indexa palpites por jogo para detectar ausências
    const palpitesPorJogo = {};
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      const jogo = jogosPorId[p.jogoId];
      if (!jogo) return;
      const pts = calcularPontos(p.palpite1, p.palpite2, jogo.placar1, jogo.placar2);
      pontuacaoPorUid[p.uid] = (pontuacaoPorUid[p.uid] || 0) + pts;
      if (!palpitesPorJogo[p.jogoId]) palpitesPorJogo[p.jogoId] = new Set();
      palpitesPorJogo[p.jogoId].add(p.uid);
    });

    const usuariosSnap = await db.collection('usuarios').get();

    // Regra −1: penaliza ausência de palpite em jogos após o cadastro do usuário
    usuariosSnap.forEach((doc) => {
      const criadoEm = doc.data().criadoEm?.toDate?.();
      if (!criadoEm) return;
      for (const [jogoId, jogo] of Object.entries(jogosPorId)) {
        if (palpitesPorJogo[jogoId]?.has(doc.id)) continue;
        const gameDataHora = jogo.dataHora?.toDate?.();
        if (!gameDataHora || criadoEm >= gameDataHora) continue;
        pontuacaoPorUid[doc.id] = (pontuacaoPorUid[doc.id] || 0) - 1;
      }
    });

    const batch = db.batch();
    usuariosSnap.forEach((doc) => {
      batch.update(doc.ref, { pontuacao: pontuacaoPorUid[doc.id] || 0 });
    });
    await batch.commit();

    return { atualizados: usuariosSnap.size };
  }
);

// Dispara quando alguém entra em um grupo. Notifica o dono do grupo.
exports.membroEntrou = onDocumentUpdated(
  { document: 'grupos/{grupoId}', region: 'southamerica-east1' },
  async (event) => {
    const antes = event.data.before.data();
    const depois = event.data.after.data();

    const membrosAntes = antes.membros || [];
    const membrosDepois = depois.membros || [];
    const novosMembros = membrosDepois.filter(uid => !membrosAntes.includes(uid));
    if (novosMembros.length === 0) return null;

    const novoUid = novosMembros[0];
    if (novoUid === depois.donoUid) return null; // o dono criou o grupo, não notifica

    const db = getFirestore();
    const messaging = getMessaging();

    const [donoDoc, membroDoc] = await Promise.all([
      db.collection('usuarios').doc(depois.donoUid).get(),
      db.collection('usuarios').doc(novoUid).get(),
    ]);

    if (!donoDoc.exists) return null;
    const donoData = donoDoc.data();
    if (!donoData.fcmToken) return null;

    const membroNome = membroDoc.exists ? membroDoc.data().nome : 'Alguém';

    await _enviarNotificacao(messaging, db, depois.donoUid, donoData.fcmToken, {
      title: '👥 Novo membro!',
      body: `${membroNome} entrou no grupo "${depois.nome}".`,
      data: { tela: 'grupos' },
    });

    return null;
  }
);

// Calcula pontuação dos palpites especiais (campeão e artilheiro).
// Lê config/copa2026 para obter os resultados reais e aplica +50 / +25
// para cada usuário que acertou. Só pode ser executada uma vez (flag no config).
exports.calcularPalpitesEspeciais = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Não autenticado.');
    }

    const db = getFirestore();
    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    const configDoc = await db.collection('config').doc('copa2026').get();
    if (!configDoc.exists) {
      throw new HttpsError('not-found', 'Configuração não encontrada.');
    }

    const { campeaoReal, artilheiroReal, palpitesEspeciaisCalculados } = configDoc.data();

    if (palpitesEspeciaisCalculados) {
      throw new HttpsError('already-exists', 'Pontuação especial já foi calculada.');
    }
    if (!campeaoReal && !artilheiroReal) {
      throw new HttpsError('failed-precondition', 'Defina o campeão e/ou artilheiro antes de calcular.');
    }

    const usuariosSnap = await db.collection('usuarios').get();
    const batch = db.batch();
    let atualizados = 0;

    usuariosSnap.forEach((doc) => {
      const data = doc.data();
      let bonus = 0;
      if (campeaoReal && data.palpiteCampeao === campeaoReal) bonus += 50;
      if (artilheiroReal && data.palpiteArtilheiro &&
          data.palpiteArtilheiro.toLowerCase().trim() === artilheiroReal.toLowerCase().trim()) {
        bonus += 25;
      }
      if (bonus > 0) {
        batch.update(doc.ref, { pontuacao: FieldValue.increment(bonus) });
        atualizados++;
      }
    });

    batch.update(configDoc.ref, { palpitesEspeciaisCalculados: true });
    await batch.commit();

    return { atualizados };
  }
);

// Remove documentos de `usuarios` e `palpites` cujas contas Firebase Auth
// foram deletadas. Também remove palpites órfãos cujo uid não existe mais
// em `usuarios` (cobre casos onde o doc de usuário já foi deletado antes).
exports.limparUsuariosOrfaos = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Não autenticado.');
    }

    const db = getFirestore();
    const auth = getAuth();

    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    // Coleta todos os UIDs existentes no Firebase Auth (paginado)
    const uidsAuth = new Set();
    let pageToken;
    do {
      const result = await auth.listUsers(1000, pageToken);
      result.users.forEach((u) => uidsAuth.add(u.uid));
      pageToken = result.pageToken;
    } while (pageToken);

    // UIDs com documento em `usuarios`
    const usuariosSnap = await db.collection('usuarios').get();
    const uidsFirestore = new Set(usuariosSnap.docs.map((d) => d.id));

    // Docs de `usuarios` sem conta Auth correspondente
    const usuariosOrfaos = usuariosSnap.docs.filter((d) => !uidsAuth.has(d.id));
    const uidsSemAuth = new Set(usuariosOrfaos.map((d) => d.id));

    // UIDs válidos = têm conta Auth E documento em usuarios
    const uidsValidos = new Set([...uidsFirestore].filter((uid) => uidsAuth.has(uid)));

    // Coleta UIDs únicos presentes nos palpites
    const palpitesSnap = await db.collection('palpites').get();
    const uidsPalpites = new Set(palpitesSnap.docs.map((d) => d.data().uid));

    // Palpites cujo uid não está entre os válidos
    const palpitesOrfaos = palpitesSnap.docs.filter((d) => !uidsValidos.has(d.data().uid));

    // Deleta palpites órfãos em lotes de 500
    for (let i = 0; i < palpitesOrfaos.length; i += 500) {
      const batch = db.batch();
      palpitesOrfaos.slice(i, i + 500).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }

    // Deleta docs de usuarios sem Auth
    for (let i = 0; i < usuariosOrfaos.length; i += 500) {
      const batch = db.batch();
      usuariosOrfaos.slice(i, i + 500).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }

    return {
      usuariosRemovidos: usuariosOrfaos.length,
      palpitesRemovidos: palpitesOrfaos.length,
    };
  }
);

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Envia notificação FCM e remove o token inválido do Firestore se necessário.
async function _enviarNotificacao(messaging, db, uid, token, { title, body, data = {} }) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      android: {
        notification: {
          channelId: 'bolao_alertas',
          priority: 'high',
        },
      },
    });
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered') {
      await db.collection('usuarios').doc(uid).update({ fcmToken: FieldValue.delete() });
    }
  }
}

// Mesma lógica de pontuação do app Flutter (tela_palpites.dart).
function calcularPontos(p1, p2, r1, r2) {
  if (p1 === r1 && p2 === r2) return 10;
  const sP = p1 - p2;
  const sR = r1 - r2;
  const vP = Math.sign(p1 - p2);
  const vR = Math.sign(r1 - r2);
  if (sP === sR && vP === vR) return 7;
  if (vP === vR && vR !== 0) return 5;
  if (vP === 0 && vR === 0) return 4;
  return 0;
}
