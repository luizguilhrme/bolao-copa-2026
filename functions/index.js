const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

// ─── Helpers de pontuação ─────────────────────────────────────────────────────

// Retorna pontos BASE (sem multiplicador de fase).
// Espelha exatamente a lógica do Flutter (_calcularPontos em tela_palpites.dart).
function calcularPontos(p1, p2, r1, r2) {
  if (p1 === r1 && p2 === r2) return 100; // placar exato
  const sP = p1 - p2, sR = r1 - r2;
  const vP = Math.sign(p1 - p2), vR = Math.sign(r1 - r2);
  if (vP !== vR) return 0; // errou o vencedor
  if (vP !== 0) {
    if (sP === sR) return 70;              // vencedor + saldo de gols
    if (p1 === r1 || p2 === r2) return 60; // vencedor + gols exatos de um time
    return 50;                             // só o vencedor
  }
  return 50; // empate certo, placar errado
}

// Multiplicador por fase — idêntico ao Flutter (_multiplicador em tela_palpites.dart).
function multiplicador(round) {
  switch (round) {
    case '16 avos de Final':    return 1.2;
    case 'Oitavas de Final':    return 1.4;
    case 'Quartas de Final':    return 1.6;
    case 'Semifinal':
    case 'Disputa de 3º Lugar': return 1.8;
    case 'Final':               return 2.0;
    default:                    return 1.0; // Fase de Grupos
  }
}

// Pontos reais considerando a fase do jogo.
function calcularPontosComFase(p1, p2, r1, r2, round) {
  const base = calcularPontos(p1, p2, r1, r2);
  if (base === 0) return 0;
  return Math.round(base * multiplicador(round));
}

// ─── calcularPontuacao ────────────────────────────────────────────────────────
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
    const round = depois.round || 'Fase de Grupos';

    const palpitesSnap = await db
      .collection('palpites')
      .where('jogoId', '==', jogoId)
      .get();

    // Lê ranking atual (antes do batch) para calcular mudanças de posição
    const usuariosSnap = await db.collection('usuarios').get();
    const rankingAntes = {};
    const pontuacaoAtual = {};
    const usuariosOrdenados = [...usuariosSnap.docs].sort((a, b) => {
      const d = (u) => (u.pontuacaoClassica || 0) + (u.pontuacaoEliminatorias || 0) + (u.pontuacaoEspeciais || 0);
      return d(b.data()) - d(a.data());
    });
    usuariosOrdenados.forEach((doc, idx) => {
      const d = doc.data();
      rankingAntes[doc.id] = idx + 1;
      pontuacaoAtual[doc.id] = (d.pontuacaoClassica || 0) + (d.pontuacaoEliminatorias || 0) + (d.pontuacaoEspeciais || 0);
    });

    // Calcula deltas: subtrai pontuação anterior e adiciona a nova
    const deltasPorUid = {};
    const exatosDeltaPorUid = {};
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      let delta = 0;
      if (antes.placar1 != null && antes.placar2 != null) {
        delta -= calcularPontosComFase(p.palpite1, p.palpite2, antes.placar1, antes.placar2, round);
      }
      delta += calcularPontosComFase(p.palpite1, p.palpite2, depois.placar1, depois.placar2, round);
      if (delta !== 0) deltasPorUid[p.uid] = (deltasPorUid[p.uid] || 0) + delta;

      // Rastreia mudança no contador de placares exatos
      const eraExato = antes.placar1 != null && antes.placar2 != null &&
          p.palpite1 === antes.placar1 && p.palpite2 === antes.placar2;
      const eExato = p.palpite1 === depois.placar1 && p.palpite2 === depois.placar2;
      if (!eraExato && eExato) {
        exatosDeltaPorUid[p.uid] = (exatosDeltaPorUid[p.uid] || 0) + 1;
      } else if (eraExato && !eExato) {
        exatosDeltaPorUid[p.uid] = (exatosDeltaPorUid[p.uid] || 0) - 1;
      }
    });

    // Regra −10: na primeira inserção de placar, penaliza usuários sem palpite
    // que criaram conta antes do início do jogo.
    const primeiraVez = antes.placar1 == null || antes.placar2 == null;
    const perdidosDeltaPorUid = {};
    if (primeiraVez) {
      const comPalpite = new Set(palpitesSnap.docs.map((d) => d.data().uid));
      const gameDataHora = depois.dataHora?.toDate?.();
      if (gameDataHora) {
        usuariosSnap.docs.forEach((doc) => {
          if (comPalpite.has(doc.id)) return;
          const criadoEm = doc.data().criadoEm?.toDate?.();
          if (!criadoEm || criadoEm >= gameDataHora) return;
          deltasPorUid[doc.id] = (deltasPorUid[doc.id] || 0) - 10;
          perdidosDeltaPorUid[doc.id] = (perdidosDeltaPorUid[doc.id] || 0) + 1;
        });
      }
    }

    // Propagar vencedor/perdedor para o próximo jogo da chave eliminatória
    const progressao = {
      73:  [{dest: 90, campo: 'team1', tipo: 'v'}],
      74:  [{dest: 89, campo: 'team1', tipo: 'v'}],
      75:  [{dest: 90, campo: 'team2', tipo: 'v'}],
      76:  [{dest: 91, campo: 'team1', tipo: 'v'}],
      77:  [{dest: 89, campo: 'team2', tipo: 'v'}],
      78:  [{dest: 91, campo: 'team2', tipo: 'v'}],
      79:  [{dest: 92, campo: 'team1', tipo: 'v'}],
      80:  [{dest: 92, campo: 'team2', tipo: 'v'}],
      81:  [{dest: 94, campo: 'team1', tipo: 'v'}],
      82:  [{dest: 94, campo: 'team2', tipo: 'v'}],
      83:  [{dest: 93, campo: 'team1', tipo: 'v'}],
      84:  [{dest: 93, campo: 'team2', tipo: 'v'}],
      85:  [{dest: 96, campo: 'team1', tipo: 'v'}],
      86:  [{dest: 95, campo: 'team1', tipo: 'v'}],
      87:  [{dest: 96, campo: 'team2', tipo: 'v'}],
      88:  [{dest: 95, campo: 'team2', tipo: 'v'}],
      89:  [{dest: 97, campo: 'team1', tipo: 'v'}],
      90:  [{dest: 97, campo: 'team2', tipo: 'v'}],
      91:  [{dest: 99, campo: 'team1', tipo: 'v'}],
      92:  [{dest: 99, campo: 'team2', tipo: 'v'}],
      93:  [{dest: 98, campo: 'team1', tipo: 'v'}],
      94:  [{dest: 98, campo: 'team2', tipo: 'v'}],
      95:  [{dest: 100, campo: 'team1', tipo: 'v'}],
      96:  [{dest: 100, campo: 'team2', tipo: 'v'}],
      97:  [{dest: 101, campo: 'team1', tipo: 'v'}],
      98:  [{dest: 101, campo: 'team2', tipo: 'v'}],
      99:  [{dest: 102, campo: 'team1', tipo: 'v'}],
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
        vencedor = depois.team1; perdedor = depois.team2;
      } else if (p2 > p1) {
        vencedor = depois.team2; perdedor = depois.team1;
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

    const temUpdates = Object.keys(deltasPorUid).length > 0
        || Object.keys(exatosDeltaPorUid).length > 0
        || Object.keys(perdidosDeltaPorUid).length > 0;
    if (!temUpdates) return null;

    // Consolida todas as atualizações por UID num único batch.update por documento
    const isElim = jogoId > 72;
    const updatesPorUid = {};
    for (const [uid, delta] of Object.entries(deltasPorUid)) {
      if (!updatesPorUid[uid]) updatesPorUid[uid] = {};
      const campo = isElim ? 'pontuacaoEliminatorias' : 'pontuacaoClassica';
      updatesPorUid[uid][campo] = FieldValue.increment(delta);
    }
    for (const [uid, delta] of Object.entries(exatosDeltaPorUid)) {
      if (!updatesPorUid[uid]) updatesPorUid[uid] = {};
      updatesPorUid[uid].placaresExatos = FieldValue.increment(delta);
    }
    for (const [uid, delta] of Object.entries(perdidosDeltaPorUid)) {
      if (!updatesPorUid[uid]) updatesPorUid[uid] = {};
      updatesPorUid[uid].palpitesPerdidos = FieldValue.increment(delta);
    }
    const batch = db.batch();
    for (const [uid, updates] of Object.entries(updatesPorUid)) {
      batch.update(db.collection('usuarios').doc(uid), updates);
    }
    await batch.commit();

    // Projeta novo ranking em memória para envio de notificações
    const novaPontuacao = { ...pontuacaoAtual };
    for (const [uid, delta] of Object.entries(deltasPorUid)) {
      novaPontuacao[uid] = (novaPontuacao[uid] || 0) + delta;
    }
    const rankingDepois = Object.keys(novaPontuacao)
      .sort((a, b) => novaPontuacao[b] - novaPontuacao[a])
      .reduce((acc, uid, idx) => { acc[uid] = idx + 1; return acc; }, {});

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

      const delta = posAntes - posDepois;
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

// ─── lembretesPalpite ─────────────────────────────────────────────────────────
// Roda a cada 30 minutos e notifica usuários que ainda não palpitaram em jogos
// que começam em ~30 minutos. Ignora jogos com times placeholder.

exports.lembretesPalpite = onSchedule(
  { schedule: '*/30 * * * *', region: 'southamerica-east1', timeZone: 'America/Sao_Paulo' },
  async () => {
    const db = getFirestore();
    const messaging = getMessaging();
    const agora = new Date();

    const inicio = new Date(agora.getTime() + 25 * 60 * 1000);
    const fim = new Date(agora.getTime() + 35 * 60 * 1000);

    const jogosSnap = await db.collection('jogos')
      .where('dataHora', '>=', Timestamp.fromDate(inicio))
      .where('dataHora', '<=', Timestamp.fromDate(fim))
      .get();

    if (jogosSnap.empty) return null;

    // Filtra jogos com times ainda não definidos (placeholders de eliminatórias)
    const jogosValidos = jogosSnap.docs.filter((d) => {
      const { team1, team2 } = d.data();
      return !_ehPlaceholder(team1) && !_ehPlaceholder(team2);
    });

    if (jogosValidos.length === 0) return null;

    const jogoIds = jogosValidos.map((d) => d.data().id);

    const palpitesSnap = await db.collection('palpites')
      .where('jogoId', 'in', jogoIds)
      .get();

    const palpitadosPorJogo = {};
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      if (!palpitadosPorJogo[p.jogoId]) palpitadosPorJogo[p.jogoId] = new Set();
      palpitadosPorJogo[p.jogoId].add(p.uid);
    });

    const usuariosSnap = await db.collection('usuarios').get();

    for (const userDoc of usuariosSnap.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data();
      if (!userData.fcmToken) continue;
      if (userData.notifLembretes === false) continue;

      const jogosSemPalpite = jogosValidos.filter((jDoc) => {
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

// ─── recalcularTudo ───────────────────────────────────────────────────────────
// Recalcula pontuação de TODOS os usuários do zero, a partir dos placares
// e palpites atuais. Aplica multiplicadores de fase e penalidade −10.
// Só pode ser chamada por admin. NÃO reaplica pontos de palpites especiais.

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

    const classicaPorUid = {};
    const elimPorUid = {};
    const exatosPorUid = {};
    const palpitesSnap = await db.collection('palpites').get();

    // Indexa palpites por jogo para detectar ausências
    const palpitesPorJogo = {};
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      const jogo = jogosPorId[p.jogoId];
      if (!jogo) return;
      const pts = calcularPontosComFase(p.palpite1, p.palpite2, jogo.placar1, jogo.placar2, jogo.round || 'Fase de Grupos');
      if (jogo.id > 72) elimPorUid[p.uid] = (elimPorUid[p.uid] || 0) + pts;
      else classicaPorUid[p.uid] = (classicaPorUid[p.uid] || 0) + pts;
      if (!palpitesPorJogo[p.jogoId]) palpitesPorJogo[p.jogoId] = new Set();
      palpitesPorJogo[p.jogoId].add(p.uid);
      // Conta placares exatos
      if (p.palpite1 === jogo.placar1 && p.palpite2 === jogo.placar2) {
        exatosPorUid[p.uid] = (exatosPorUid[p.uid] || 0) + 1;
      }
    });

    const usuariosSnap = await db.collection('usuarios').get();

    // Regra −10: penaliza ausência de palpite em jogos após o cadastro
    const perdidosPorUid = {};
    usuariosSnap.forEach((doc) => {
      const criadoEm = doc.data().criadoEm?.toDate?.();
      if (!criadoEm) return;
      for (const [jogoId, jogo] of Object.entries(jogosPorId)) {
        if (palpitesPorJogo[jogoId]?.has(doc.id)) continue;
        const gameDataHora = jogo.dataHora?.toDate?.();
        if (!gameDataHora || criadoEm >= gameDataHora) continue;
        if (jogo.id > 72) elimPorUid[doc.id] = (elimPorUid[doc.id] || 0) - 10;
        else classicaPorUid[doc.id] = (classicaPorUid[doc.id] || 0) - 10;
        perdidosPorUid[doc.id] = (perdidosPorUid[doc.id] || 0) + 1;
      }
    });

    const batch = db.batch();
    usuariosSnap.forEach((doc) => {
      batch.update(doc.ref, {
        pontuacaoClassica: classicaPorUid[doc.id] || 0,
        pontuacaoEliminatorias: elimPorUid[doc.id] || 0,
        placaresExatos: exatosPorUid[doc.id] || 0,
        palpitesPerdidos: perdidosPorUid[doc.id] || 0,
      });
    });
    await batch.commit();

    return { atualizados: usuariosSnap.size };
  }
);

// ─── membroEntrou ─────────────────────────────────────────────────────────────
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
    if (novoUid === depois.donoUid) return null;

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

// ─── calcularPalpitesEspeciais ────────────────────────────────────────────────
// Calcula pontuação dos 6 palpites especiais. Lê config/copa2026 para obter
// os resultados reais. Só pode ser executada uma vez (flag no config).
//
// Pontuações:
//   Campeão           → +500
//   Artilheiro        → +300
//   Melhor Jogador    → +300
//   Melhor Goleiro    → +300
//   Mais Goleadora    → +200
//   Menos Vazada      → +200

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

    const config = configDoc.data();

    if (config.palpitesEspeciaisCalculados) {
      throw new HttpsError('already-exists', 'Pontuação especial já foi calculada.');
    }

    const {
      campeaoReal,
      artilheiroReal,
      melhorJogadorFinalReal,
      melhorGoleiroReal,
      maisGoleadoraReal,
      maisVazadaReal,
    } = config;

    const temAlgumResultado = campeaoReal || artilheiroReal || melhorJogadorFinalReal
      || melhorGoleiroReal || maisGoleadoraReal || maisVazadaReal;

    if (!temAlgumResultado) {
      throw new HttpsError('failed-precondition', 'Defina ao menos um resultado real antes de calcular.');
    }

    // Comparação de texto livre: case-insensitive + trim
    const textoIgual = (a, b) =>
      a && b && a.toLowerCase().trim() === b.toLowerCase().trim();

    const usuariosSnap = await db.collection('usuarios').get();
    const batch = db.batch();
    let atualizados = 0;

    usuariosSnap.forEach((doc) => {
      const d = doc.data();
      let bonus = 0;

      // Times (comparação exata de nome em inglês)
      if (campeaoReal        && d.palpiteCampeao      === campeaoReal)     bonus += 500;
      if (maisGoleadoraReal  && d.palpiteMaisGoleadora === maisGoleadoraReal) bonus += 200;
      if (maisVazadaReal     && d.palpiteMenosVazada   === maisVazadaReal)  bonus += 200;

      // Pessoas (comparação flexível de texto livre)
      if (artilheiroReal         && textoIgual(d.palpiteArtilheiro,    artilheiroReal))         bonus += 300;
      if (melhorJogadorFinalReal && textoIgual(d.palpiteMelhorJogador, melhorJogadorFinalReal)) bonus += 300;
      if (melhorGoleiroReal      && textoIgual(d.palpiteGoleiro,       melhorGoleiroReal))      bonus += 300;

      if (bonus > 0) {
        batch.update(doc.ref, {
          pontuacaoEspeciais: FieldValue.increment(bonus),
        });
        atualizados++;
      }
    });

    batch.update(configDoc.ref, { palpitesEspeciaisCalculados: true });
    await batch.commit();

    return { atualizados };
  }
);

// ─── recalcularCopa ───────────────────────────────────────────────────────────
// Calcula pontuação da fase de grupos do Modo Copa para todos os usuários.
// Lê classificacao_real do config/copa2026 e palpites_copa de cada usuário.
// Aplica FieldValue.increment() em pontuacao — deve ser rodado APÓS recalcularTudo.
// Usa flag copaGruposCalculado para evitar dupla execução.

exports.recalcularCopa = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const db = getFirestore();
    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    const configDoc = await db.collection('config').doc('copa2026').get();
    if (!configDoc.exists) throw new HttpsError('not-found', 'Configuração não encontrada.');

    const config = configDoc.data();
    if (config.copaGruposCalculado) {
      throw new HttpsError(
        'already-exists',
        'Pontuação Copa já foi calculada. Rode "Recalcular Reg. Clássica" primeiro para resetar, depois rode Copa novamente.'
      );
    }

    const classificacaoReal = config.classificacao_real;
    if (!classificacaoReal || Object.keys(classificacaoReal).length === 0) {
      throw new HttpsError(
        'failed-precondition',
        'Classificação real não encontrada. Salve a classificação na tela Admin Copa primeiro.'
      );
    }

    // Espelha calcularPontosCopaGrupo() de biblioteca.dart
    function calcularPontosCopaGrupo(palpite, real) {
      const classificadosReais = new Set(
        ['primeiro', 'segundo', 'terceiro'].map(p => real[p]).filter(Boolean)
      );
      let pontos = 0, exatos = 0, validos = 0;
      for (const pos of ['primeiro', 'segundo', 'terceiro']) {
        const p = palpite[pos];
        if (!p) continue; // não palpitou esta posição
        const r = real[pos];
        if (r) {
          // há resultado real para esta posição: conta para o bônus
          validos++;
          if (p === r) { pontos += 200; exatos++; }
          else if (classificadosReais.has(p)) pontos += 100;
        } else if (classificadosReais.has(p)) {
          // sem resultado nessa posição mas o time classificou em outra
          pontos += 100;
        }
      }
      if (validos >= 2 && exatos === validos) pontos += 100;
      return pontos;
    }

    const palpitesCopaSnap = await db.collection('palpites_copa').get();

    const batch = db.batch();
    let atualizados = 0;

    for (const doc of palpitesCopaSnap.docs) {
      const data = doc.data();
      const uid = data.uid;
      const grupos = data.grupos || {};

      let totalPontos = 0;
      for (const [letra, real] of Object.entries(classificacaoReal)) {
        const palpite = grupos[letra] || {};
        totalPontos += calcularPontosCopaGrupo(palpite, real);
      }

      if (totalPontos > 0) {
        batch.update(db.collection('usuarios').doc(uid), {
          pontuacaoCopa: totalPontos,
        });
        atualizados++;
      }
    }

    batch.update(configDoc.ref, { copaGruposCalculado: true });
    await batch.commit();

    return { atualizados };
  }
);

// ─── limparUsuariosOrfaos ─────────────────────────────────────────────────────
// Remove documentos de `usuarios` e `palpites` cujas contas Firebase Auth
// foram deletadas.

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

    const uidsAuth = new Set();
    let pageToken;
    do {
      const result = await auth.listUsers(1000, pageToken);
      result.users.forEach((u) => uidsAuth.add(u.uid));
      pageToken = result.pageToken;
    } while (pageToken);

    const usuariosSnap = await db.collection('usuarios').get();
    const uidsFirestore = new Set(usuariosSnap.docs.map((d) => d.id));

    const usuariosOrfaos = usuariosSnap.docs.filter((d) => !uidsAuth.has(d.id));
    const uidsValidos = new Set([...uidsFirestore].filter((uid) => uidsAuth.has(uid)));

    const palpitesSnap = await db.collection('palpites').get();
    const palpitesOrfaos = palpitesSnap.docs.filter((d) => !uidsValidos.has(d.data().uid));

    for (let i = 0; i < palpitesOrfaos.length; i += 500) {
      const batch = db.batch();
      palpitesOrfaos.slice(i, i + 500).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }

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

// ─── limparDadosTeste ─────────────────────────────────────────────────────────
// Reseta todos os dados de teste: placares, times eliminatórias, config e pontuações.

exports.limparDadosTeste = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');
    const db = getFirestore();
    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

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
      copaGruposCalculado:         FieldValue.delete(),
      palpitesTravados:            false,
    }, { merge: true });

    const usuariosSnap = await db.collection('usuarios').get();
    const opsUsuarios = usuariosSnap.docs.map(doc => b =>
      b.update(doc.ref, {
        pontuacaoClassica: 0, pontuacaoCopa: 0,
        pontuacaoEliminatorias: 0, pontuacaoEspeciais: 0,
        placaresExatos: 0, palpitesPerdidos: 0,
      })
    );
    await commitEmLotes(opsUsuarios);

    return {
      jogosResetados: opsJogos.length,
      usuariosZerados: opsUsuarios.length,
    };
  }
);

// ─── buscarPalpitesJogo ───────────────────────────────────────────────────────
// Retorna os palpites de um jogo já encerrado, filtrados pelos membros dos
// grupos do solicitante. Substitui a leitura direta da coleção palpites na
// TelaTabela, permitindo restringir a regra de leitura do Firestore ao
// próprio dono do documento.

exports.buscarPalpitesJogo = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const { jogoId } = request.data;
    if (jogoId == null) throw new HttpsError('invalid-argument', 'jogoId obrigatório.');

    const db = getFirestore();
    const callerUid = request.auth.uid;

    // Valida que o jogo existe e está encerrado
    const jogoDoc = await db.collection('jogos').doc(String(jogoId)).get();
    if (!jogoDoc.exists) throw new HttpsError('not-found', 'Jogo não encontrado.');
    const jogo = jogoDoc.data();
    if (jogo.placar1 == null || jogo.placar2 == null) {
      throw new HttpsError('failed-precondition', 'Jogo ainda não encerrado.');
    }

    // Coleta UIDs de todos os membros dos grupos do solicitante (inclui ele mesmo)
    const gruposSnap = await db.collection('grupos')
      .where('membros', 'array-contains', callerUid)
      .get();

    const membrosUids = new Set([callerUid]);
    gruposSnap.forEach((doc) => {
      (doc.data().membros || []).forEach((uid) => membrosUids.add(uid));
    });

    // Busca palpites do jogo e filtra pelos membros
    const palpitesSnap = await db.collection('palpites')
      .where('jogoId', '==', jogoId)
      .get();

    const palpitesFiltrados = palpitesSnap.docs
      .map((d) => d.data())
      .filter((p) => membrosUids.has(p.uid));

    if (palpitesFiltrados.length === 0) return { itens: [] };

    // Busca dados dos usuários em paralelo
    const uids = [...new Set(palpitesFiltrados.map((p) => p.uid))];
    const usuariosDocs = await Promise.all(
      uids.map((uid) => db.collection('usuarios').doc(uid).get())
    );
    const usuariosMap = {};
    usuariosDocs.forEach((doc) => {
      if (doc.exists) usuariosMap[doc.id] = doc.data();
    });

    const itens = palpitesFiltrados
      .filter((p) => usuariosMap[p.uid])
      .map((p) => {
        const u = usuariosMap[p.uid];
        return {
          uid: p.uid,
          nome: u.nome,
          avatar: u.avatar || null,
          palpite1: p.palpite1,
          palpite2: p.palpite2,
          pontos: calcularPontosComFase(
            p.palpite1, p.palpite2,
            jogo.placar1, jogo.placar2,
            jogo.round || 'Fase de Grupos'
          ),
        };
      })
      .sort((a, b) => b.pontos - a.pontos);

    return { itens };
  }
);

// ─── buscarPalpitesUsuario ────────────────────────────────────────────────────
// Retorna palpites clássicos e Copa de um usuário, desde que o solicitante
// compartilhe pelo menos um grupo com ele (ou seja o próprio usuário).
// Substitui as leituras diretas de palpites/palpites_copa na TelaRanking.

exports.buscarPalpitesUsuario = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const { targetUid } = request.data;
    if (!targetUid) throw new HttpsError('invalid-argument', 'targetUid obrigatório.');

    const db = getFirestore();
    const callerUid = request.auth.uid;

    // O próprio usuário sempre pode ver seus palpites; para outros, exige grupo em comum
    if (targetUid !== callerUid) {
      const gruposSnap = await db.collection('grupos')
        .where('membros', 'array-contains', callerUid)
        .get();

      const membrosUids = new Set();
      gruposSnap.forEach((doc) => {
        (doc.data().membros || []).forEach((uid) => membrosUids.add(uid));
      });

      if (!membrosUids.has(targetUid)) {
        throw new HttpsError('permission-denied', 'Usuário não está em nenhum grupo em comum.');
      }
    }

    // Busca palpites clássicos e Copa em paralelo
    const [palpitesSnap, copaDoc] = await Promise.all([
      db.collection('palpites').where('uid', '==', targetUid).get(),
      db.collection('palpites_copa').doc(targetUid).get(),
    ]);

    const palpites = palpitesSnap.docs.map((doc) => {
      const d = doc.data();
      return { jogoId: d.jogoId, palpite1: d.palpite1, palpite2: d.palpite2 };
    });

    const palpitesCopa = copaDoc.exists ? (copaDoc.data().grupos || {}) : {};

    return { palpites, palpitesCopa };
  }
);

// ─── Helpers internos ─────────────────────────────────────────────────────────

// Envia notificação FCM e remove token inválido do Firestore se necessário.
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

// Detecta se um time ainda é placeholder (eliminatórias não resolvidas).
// Espelha ehPlaceholder() de biblioteca.dart no Flutter.
function _ehPlaceholder(nome) {
  if (!nome) return true;
  return /^\d[A-L]$/.test(nome)        // ex: "1A", "2B"
    || nome.startsWith('Vencedor ')
    || nome.startsWith('Perdedor ')
    || nome === '3°';
}
