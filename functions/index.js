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

    // Propagar vencedor/perdedor para o próximo jogo da chave
    // (deve acontecer antes do early return por ausência de palpites)
    const progressao = {
      73: [{dest: 90, campo: 'team1', tipo: 'v'}],
      74: [{dest: 89, campo: 'team1', tipo: 'v'}],
      75: [{dest: 90, campo: 'team2', tipo: 'v'}],
      76: [{dest: 91, campo: 'team1', tipo: 'v'}],
      77: [{dest: 89, campo: 'team2', tipo: 'v'}],
      78: [{dest: 91, campo: 'team2', tipo: 'v'}],
      79: [{dest: 92, campo: 'team1', tipo: 'v'}],
      80: [{dest: 92, campo: 'team2', tipo: 'v'}],
      81: [{dest: 94, campo: 'team1', tipo: 'v'}],
      82: [{dest: 94, campo: 'team2', tipo: 'v'}],
      83: [{dest: 93, campo: 'team1', tipo: 'v'}],
      84: [{dest: 93, campo: 'team2', tipo: 'v'}],
      85: [{dest: 96, campo: 'team1', tipo: 'v'}],
      86: [{dest: 95, campo: 'team1', tipo: 'v'}],
      87: [{dest: 96, campo: 'team2', tipo: 'v'}],
      88: [{dest: 95, campo: 'team2', tipo: 'v'}],
      89: [{dest: 97, campo: 'team1', tipo: 'v'}],
      90: [{dest: 97, campo: 'team2', tipo: 'v'}],
      91: [{dest: 99, campo: 'team1', tipo: 'v'}],
      92: [{dest: 99, campo: 'team2', tipo: 'v'}],
      93: [{dest: 98, campo: 'team1', tipo: 'v'}],
      94: [{dest: 98, campo: 'team2', tipo: 'v'}],
      95: [{dest: 100, campo: 'team1', tipo: 'v'}],
      96: [{dest: 100, campo: 'team2', tipo: 'v'}],
      97: [{dest: 101, campo: 'team1', tipo: 'v'}],
      98: [{dest: 101, campo: 'team2', tipo: 'v'}],
      99: [{dest: 102, campo: 'team1', tipo: 'v'}],
      100: [{dest: 102, campo: 'team2', tipo: 'v'}],
      101: [
        {dest: 104, campo: 'team1', tipo: 'v'},
        {dest: 103, campo: 'team1', tipo: 'p'},
      ],
      102: [
        {dest: 104, campo: 'team2', tipo: 'v'},
        {dest: 103, campo: 'team2', tipo: 'p'},
      ],
    };

    const slots = progressao[jogoId];
    if (slots) {
      const p1 = depois.placar1, p2 = depois.placar2;
      let vencedor, perdedor;

      if (p1 > p2) {
        vencedor = depois.team1;
        perdedor = depois.team2;
      } else if (p2 > p1) {
        vencedor = depois.team2;
        perdedor = depois.team1;
      } else if (depois.vencedor) {
        vencedor = depois.vencedor;
        perdedor = depois.vencedor === depois.team1 ? depois.team2 : depois.team1;
      }

      if (vencedor) {
        const propagBatch = db.batch();
        for (const slot of slots) {
          const time = slot.tipo === 'v' ? vencedor : perdedor;
          propagBatch.update(
            db.collection('jogos').doc(String(slot.dest)),
            { [slot.campo]: time }
          );
        }
        await propagBatch.commit();
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

// Reseta todos os dados de teste: placares, times eliminatórias, config e pontuações.
// Só pode ser chamada por admin. Usada para limpar um ciclo de testes completo.
exports.limparDadosTeste = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');
    const db = getFirestore();
    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    // Placeholders originais para restaurar times das eliminatórias
    const placeholders = {
      73:  { team1: '2A',          team2: '2B'           },
      74:  { team1: '1E',          team2: '3°'           },
      75:  { team1: '1F',          team2: '2C'           },
      76:  { team1: '1C',          team2: '2F'           },
      77:  { team1: '1I',          team2: '3°'           },
      78:  { team1: '2E',          team2: '2I'           },
      79:  { team1: '1A',          team2: '3°'           },
      80:  { team1: '1L',          team2: '3°'           },
      81:  { team1: '1D',          team2: '3°'           },
      82:  { team1: '1G',          team2: '3°'           },
      83:  { team1: '2K',          team2: '2L'           },
      84:  { team1: '1H',          team2: '2J'           },
      85:  { team1: '1B',          team2: '3°'           },
      86:  { team1: '1J',          team2: '2H'           },
      87:  { team1: '1K',          team2: '3°'           },
      88:  { team1: '2D',          team2: '2G'           },
      89:  { team1: 'Vencedor 74', team2: 'Vencedor 77'  },
      90:  { team1: 'Vencedor 73', team2: 'Vencedor 75'  },
      91:  { team1: 'Vencedor 76', team2: 'Vencedor 78'  },
      92:  { team1: 'Vencedor 79', team2: 'Vencedor 80'  },
      93:  { team1: 'Vencedor 83', team2: 'Vencedor 84'  },
      94:  { team1: 'Vencedor 81', team2: 'Vencedor 82'  },
      95:  { team1: 'Vencedor 86', team2: 'Vencedor 88'  },
      96:  { team1: 'Vencedor 85', team2: 'Vencedor 87'  },
      97:  { team1: 'Vencedor 89', team2: 'Vencedor 90'  },
      98:  { team1: 'Vencedor 93', team2: 'Vencedor 94'  },
      99:  { team1: 'Vencedor 91', team2: 'Vencedor 92'  },
      100: { team1: 'Vencedor 95', team2: 'Vencedor 96'  },
      101: { team1: 'Vencedor 97', team2: 'Vencedor 98'  },
      102: { team1: 'Vencedor 99', team2: 'Vencedor 100' },
      103: { team1: 'Perdedor 101',team2: 'Perdedor 102' },
      104: { team1: 'Vencedor 101',team2: 'Vencedor 102' },
    };

    const LOTE = 400;
    async function commitEmLotes(ops) {
      for (let i = 0; i < ops.length; i += LOTE) {
        const b = db.batch();
        ops.slice(i, i + LOTE).forEach(fn => fn(b));
        await b.commit();
      }
    }

    // 1. Resetar todos os jogos
    const jogosSnap = await db.collection('jogos').get();
    const opsJogos = jogosSnap.docs.map(doc => b => {
      const id = doc.data().id;
      const updates = { placar1: null, placar2: null, vencedor: FieldValue.delete() };
      if (placeholders[id]) {
        updates.team1 = placeholders[id].team1;
        updates.team2 = placeholders[id].team2;
      }
      b.update(doc.ref, updates);
    });
    await commitEmLotes(opsJogos);

    // 2. Limpar config/copa2026
    await db.collection('config').doc('copa2026').set({
      classificacao_real:          FieldValue.delete(),
      terceiros_classificados:     FieldValue.delete(),
      campeaoReal:                 FieldValue.delete(),
      artilheiroReal:              FieldValue.delete(),
      melhorGoleiroReal:           FieldValue.delete(),
      maisGoleadoraReal:           FieldValue.delete(),
      maisVazadaReal:              FieldValue.delete(),
      melhorJogadorFinalReal:      FieldValue.delete(),
      palpitesEspeciaisCalculados: FieldValue.delete(),
    }, { merge: true });

    // 3. Zerar pontuação de todos os usuários
    const usuariosSnap = await db.collection('usuarios').get();
    const opsUsuarios = usuariosSnap.docs.map(doc => b =>
      b.update(doc.ref, { pontuacao: 0 })
    );
    await commitEmLotes(opsUsuarios);

    return {
      jogosResetados: opsJogos.length,
      usuariosZerados: opsUsuarios.length,
    };
  }
);

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
