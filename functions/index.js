const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

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

    if (palpitesSnap.empty) return null;

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
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      const jogo = jogosPorId[p.jogoId];
      if (!jogo) return;
      const pts = calcularPontos(p.palpite1, p.palpite2, jogo.placar1, jogo.placar2);
      pontuacaoPorUid[p.uid] = (pontuacaoPorUid[p.uid] || 0) + pts;
    });

    const usuariosSnap = await db.collection('usuarios').get();
    const batch = db.batch();
    usuariosSnap.forEach((doc) => {
      batch.update(doc.ref, { pontuacao: pontuacaoPorUid[doc.id] || 0 });
    });
    await batch.commit();

    return { atualizados: usuariosSnap.size };
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
