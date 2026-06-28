const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
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

// Pontos Copa de um grupo (espelha calcularPontosCopaGrupo de biblioteca.dart).
// Usada por recalcularCopa e estatisticasRanking.
function calcularPontosCopaGrupo(palpite, real) {
  const classificadosReais = new Set(
    ['primeiro', 'segundo', 'terceiro'].map(p => real[p]).filter(Boolean)
  );
  let pontos = 0;
  let realCount = 0;     // nº de classificados reais (2 ou 3)
  let perfeito = true;   // palpite idêntico ao real em TODAS as posições
  for (const pos of ['primeiro', 'segundo', 'terceiro']) {
    const p = palpite[pos] || null;
    const r = real[pos] || null;
    if (r) realCount++;
    if (p !== r) perfeito = false;

    if (!p) continue; // não palpitou esta posição
    if (r) {
      if (p === r) pontos += 200;
      else if (classificadosReais.has(p)) pontos += 100;
    } else if (classificadosReais.has(p)) {
      // sem resultado nessa posição mas o time classificou em outra
      pontos += 100;
    }
  }
  // Bônus "grupo perfeito": só quando o palpite reproduz exatamente a
  // classificação real — todos os classificados na posição certa e nenhum
  // palpite a mais (ex.: palpitar um 3º num grupo de apenas 2 classificados).
  if (perfeito && realCount >= 2) pontos += 100;
  return pontos;
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
      const palavraPos = abs > 1 ? 'posições' : 'posição';
      const body = delta > 0
        ? `Você subiu ${abs} ${palavraPos} no ranking! Agora está em ${pos}.`
        : `Você caiu ${abs} ${palavraPos} no ranking. Agora está em ${pos}.`;

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
    // Libera novo cálculo do Modo Copa: o app instrui a rodar a Clássica
    // "para resetar" antes de recalcular o Copa (que faz SET em pontuacaoCopa).
    batch.update(db.collection('config').doc('copa2026'), {
      copaGruposCalculado: false,
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
// Calcula pontuação dos 5 palpites especiais. Lê config/copa2026 para obter
// os resultados reais. Só pode ser executada uma vez (flag no config).
//
// Pontuações:
//   Campeão do Mundo      → +500
//   Chuteira de Ouro      → +300
//   Bola de Ouro          → +300
//   Luva de Ouro          → +300
//   Melhor Jogador Jovem  → +200

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
      chuteiradeOuroReal,
      boladeOuroReal,
      luvadeOuroReal,
      melhorJovemReal,
    } = config;

    const temAlgumResultado = campeaoReal || chuteiradeOuroReal || boladeOuroReal
      || luvadeOuroReal || melhorJovemReal;

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

      // Campeão: comparação exata de nome em inglês
      if (campeaoReal && d.palpiteCampeao === campeaoReal) bonus += 500;

      // Premiações FIFA: comparação flexível de texto livre
      if (chuteiradeOuroReal && textoIgual(d.palpiteChuteiradeOuro, chuteiradeOuroReal)) bonus += 300;
      if (boladeOuroReal     && textoIgual(d.palpiteBoladeOuro,     boladeOuroReal))     bonus += 300;
      if (luvadeOuroReal     && textoIgual(d.palpiteLuvadeOuro,     luvadeOuroReal))     bonus += 300;
      if (melhorJovemReal    && textoIgual(d.palpiteMelhorJovem,    melhorJovemReal))    bonus += 200;

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

    // calcularPontosCopaGrupo está no topo do arquivo (helper compartilhado)

    const palpitesCopaSnap = await db.collection('palpites_copa').get();

    // UIDs válidos: ignora palpites_copa órfãos (conta deletada). batch.update
    // em doc inexistente derrubaria todo o batch com NOT_FOUND.
    const usuariosSnap = await db.collection('usuarios').get();
    const uidsValidos = new Set(usuariosSnap.docs.map((d) => d.id));

    const batch = db.batch();
    let atualizados = 0;

    for (const doc of palpitesCopaSnap.docs) {
      const data = doc.data();
      const uid = data.uid;
      const grupos = data.grupos || {};

      if (!uidsValidos.has(uid)) continue; // palpite órfão

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
// foram deletadas. Também tira esses UIDs dos arrays `membros` dos grupos
// (a exclusão de conta não dispara o fluxo "sair do grupo"): grupos que
// ficarem vazios são deletados e, se o dono era órfão, a posse passa para
// o primeiro membro restante.

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

    // palpites_copa (doc ID = UID): mesma limpeza de órfãos que `palpites`
    const palpitesCopaSnap = await db.collection('palpites_copa').get();
    const palpitesCopaOrfaos = palpitesCopaSnap.docs.filter((d) => !uidsValidos.has(d.id));

    for (let i = 0; i < palpitesCopaOrfaos.length; i += 500) {
      const batch = db.batch();
      palpitesCopaOrfaos.slice(i, i + 500).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }

    for (let i = 0; i < usuariosOrfaos.length; i += 500) {
      const batch = db.batch();
      usuariosOrfaos.slice(i, i + 500).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }

    // Grupos: remove UIDs órfãos de `membros`; deleta grupos que ficarem
    // vazios; transfere a posse quando o dono era órfão.
    const gruposSnap = await db.collection('grupos').get();
    let gruposAtualizados = 0;
    let gruposRemovidos = 0;
    const batchGrupos = db.batch();
    gruposSnap.docs.forEach((doc) => {
      const g = doc.data();
      const membros = g.membros || [];
      const membrosValidos = membros.filter((uid) => uidsAuth.has(uid));
      if (membrosValidos.length === membros.length) return;
      if (membrosValidos.length === 0) {
        batchGrupos.delete(doc.ref);
        gruposRemovidos++;
      } else {
        const updates = { membros: membrosValidos };
        if (!uidsAuth.has(g.donoUid)) updates.donoUid = membrosValidos[0];
        batchGrupos.update(doc.ref, updates);
        gruposAtualizados++;
      }
    });
    if (gruposAtualizados + gruposRemovidos > 0) await batchGrupos.commit();

    return {
      usuariosRemovidos: usuariosOrfaos.length,
      palpitesRemovidos: palpitesOrfaos.length,
      palpitesCopaRemovidos: palpitesCopaOrfaos.length,
      gruposAtualizados,
      gruposRemovidos,
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
      const updates = {
        placar1: null,
        placar2: null,
        vencedor: FieldValue.delete(),
        // Campos da football-data.org (apiId é preservado — o de-para vale
        // para o torneio inteiro e sobrevive ao reset de dados de teste)
        statusApi: FieldValue.delete(),
        placarAoVivo1: FieldValue.delete(),
        placarAoVivo2: FieldValue.delete(),
        placarDecisao1: FieldValue.delete(),
        placarDecisao2: FieldValue.delete(),
      };
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
      chuteiradeOuroReal:          FieldValue.delete(),
      boladeOuroReal:              FieldValue.delete(),
      luvadeOuroReal:              FieldValue.delete(),
      melhorJovemReal:             FieldValue.delete(),
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
// Retorna os palpites de um jogo com palpites já travados (a partir de 5 min
// antes do início — quando ninguém mais pode alterar), filtrados pelos
// membros dos grupos do solicitante. Pontos só são calculados depois do
// placar final; antes disso vêm null. Substitui a leitura direta da coleção
// palpites na TelaTabela, permitindo restringir a regra de leitura do
// Firestore ao próprio dono do documento.

exports.buscarPalpitesJogo = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const { jogoId } = request.data;
    if (jogoId == null) throw new HttpsError('invalid-argument', 'jogoId obrigatório.');

    const db = getFirestore();
    const callerUid = request.auth.uid;

    // Valida que o jogo existe e que os palpites já travaram (cutoff de
    // 5 min antes do início — mesma regra da tela de palpites)
    const jogoDoc = await db.collection('jogos').doc(String(jogoId)).get();
    if (!jogoDoc.exists) throw new HttpsError('not-found', 'Jogo não encontrado.');
    const jogo = jogoDoc.data();
    const cutoffMs = jogo.dataHora.toDate().getTime() - 5 * 60 * 1000;
    if (Date.now() < cutoffMs) {
      throw new HttpsError('failed-precondition', 'Palpites ainda não travados.');
    }
    const temPlacar = jogo.placar1 != null && jogo.placar2 != null;

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
          // Pontos só depois do placar final; antes, palpites visíveis sem pontos
          pontos: temPlacar
            ? calcularPontosComFase(
                p.palpite1, p.palpite2,
                jogo.placar1, jogo.placar2,
                jogo.round || 'Fase de Grupos'
              )
            : null,
          // Total Clássico do usuário (= pontuacaoClassicaTotal do app) — base
          // do "Por pontuação" no diálogo enquanto o jogo não tem placar.
          pontuacaoClassicaTotal:
            (u.pontuacaoClassica || 0) +
            (u.pontuacaoEliminatorias || 0) +
            (u.pontuacaoEspeciais || 0),
        };
      })
      .sort((a, b) => temPlacar
        ? b.pontos - a.pontos
        : a.nome.localeCompare(b.nome));

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

// ─── estatisticasRanking ──────────────────────────────────────────────────────
// Estatísticas da última rodada para a TelaRanking: "rodada" = último dia
// (campo `date` do jogo) com pelo menos um jogo encerrado. Para cada membro
// do grupo retorna os pontos ganhos nessa rodada e o movimento de posição
// (ranking antes da rodada vs agora, com os mesmos desempates do app).
// Read-only: não escreve nada — todo o cálculo é feito na hora.

exports.estatisticasRanking = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const { grupoId } = request.data;
    if (!grupoId) throw new HttpsError('invalid-argument', 'grupoId obrigatório.');

    const db = getFirestore();
    const grupoDoc = await db.collection('grupos').doc(grupoId).get();
    if (!grupoDoc.exists) throw new HttpsError('not-found', 'Grupo não encontrado.');

    const membros = grupoDoc.data().membros || [];
    if (!membros.includes(request.auth.uid)) {
      throw new HttpsError('permission-denied', 'Você não é membro deste grupo.');
    }
    const modoCopa = (grupoDoc.data().regra || 'classico') === 'copa';

    const [jogosSnap, configDoc] = await Promise.all([
      db.collection('jogos').get(),
      db.collection('config').doc('copa2026').get(),
    ]);
    const jogos = jogosSnap.docs.map((d) => d.data());
    const encerrados = jogos.filter((j) => j.placar1 != null && j.placar2 != null);
    if (encerrados.length === 0 || membros.length === 0) {
      return { rodada: null, stats: {} };
    }

    const datas = [...new Set(encerrados.map((j) => j.date))].sort();
    const ultimaData = datas[datas.length - 1];
    const jogosRodada = encerrados.filter((j) => j.date === ultimaData);

    // Rótulo da rodada REAL (não confundir com "numero", que é o dia da
    // competição). Fase de grupos: matchday "Rodada N" -> "Nª Rodada".
    // Eliminatórias (sem matchday): nome da fase do jogo mais recente.
    let rodadaLabel = null;
    const comMatchday = jogosRodada.filter((j) => j.matchday);
    if (comMatchday.length > 0) {
      const maxN = Math.max(...comMatchday.map(
        (j) => parseInt(String(j.matchday).replace(/\D/g, ''), 10) || 0
      ));
      rodadaLabel = maxN > 0 ? `${maxN}ª Rodada` : null;
    } else if (jogosRodada.length > 0) {
      rodadaLabel = jogosRodada[0].round || null;
    }

    // Usuários, palpites da rodada (IDs determinísticos {uid}_{jogoId}) e,
    // no modo Copa, os palpites de classificação de grupo
    const usuarioRefs = membros.map((uid) => db.collection('usuarios').doc(uid));
    const palpiteRefs = [];
    for (const uid of membros) {
      for (const j of jogosRodada) {
        palpiteRefs.push(db.collection('palpites').doc(`${uid}_${j.id}`));
      }
    }
    const copaRefs = modoCopa
      ? membros.map((uid) => db.collection('palpites_copa').doc(uid))
      : [];

    const [usuarioDocs, palpiteDocs, copaDocs] = await Promise.all([
      db.getAll(...usuarioRefs),
      db.getAll(...palpiteRefs),
      copaRefs.length > 0 ? db.getAll(...copaRefs) : Promise.resolve([]),
    ]);

    const usuarios = {};
    usuarioDocs.forEach((d) => { if (d.exists) usuarios[d.id] = d.data(); });
    const palpites = {};
    palpiteDocs.forEach((d) => { if (d.exists) palpites[d.id] = d.data(); });
    const palpitesCopa = {};
    copaDocs.forEach((d) => { if (d.exists) palpitesCopa[d.id] = d.data().grupos || {}; });

    // Modo Copa: grupos A–L cuja classificação "fechou" nesta rodada (todos os
    // jogos encerrados e o último deles na última data) — os pontos Copa desses
    // grupos contam como pontos da rodada
    const config = configDoc.exists ? configDoc.data() : {};
    const classificacaoReal = config.classificacao_real || {};
    const gruposFechadosNaRodada = [];
    if (modoCopa) {
      for (const letra of Object.keys(classificacaoReal)) {
        const jogosGrupo = jogos.filter((j) => j.group === `Grupo ${letra}`);
        if (jogosGrupo.length === 0) continue;
        const todosEncerrados = jogosGrupo.every((j) => j.placar1 != null);
        const dataFinal = jogosGrupo.map((j) => j.date).sort().pop();
        if (todosEncerrados && dataFinal === ultimaData) {
          gruposFechadosNaRodada.push(letra);
        }
      }
    }

    // Pontos da rodada por membro. Exatos/perdidos contam em qualquer modo
    // (os contadores placaresExatos/palpitesPerdidos são globais); pontos de
    // jogo da fase de grupos não contam no modo Copa.
    const statsRodada = {};
    for (const uid of membros) {
      const u = usuarios[uid];
      if (!u) continue;
      let pontosRodada = 0, exatos = 0, perdidos = 0;
      for (const j of jogosRodada) {
        const contaPontos = !modoCopa || j.id > 72;
        const p = palpites[`${uid}_${j.id}`];
        if (p) {
          if (contaPontos) {
            pontosRodada += calcularPontosComFase(
              p.palpite1, p.palpite2, j.placar1, j.placar2,
              j.round || 'Fase de Grupos'
            );
          }
          if (p.palpite1 === j.placar1 && p.palpite2 === j.placar2) exatos++;
        } else {
          // Regra −10: sem palpite em jogo posterior à criação da conta
          const criadoEm = u.criadoEm?.toDate?.();
          const dataJogo = j.dataHora?.toDate?.();
          if (criadoEm && dataJogo && criadoEm < dataJogo) {
            if (contaPontos) pontosRodada -= 10;
            perdidos++;
          }
        }
      }
      if (modoCopa) {
        const meusGrupos = palpitesCopa[uid] || {};
        for (const letra of gruposFechadosNaRodada) {
          pontosRodada += calcularPontosCopaGrupo(
            meusGrupos[letra] || {}, classificacaoReal[letra]
          );
        }
      }
      statsRodada[uid] = { pontosRodada, exatos, perdidos };
    }

    // Movimento: posição antes da rodada (totais − pontos da rodada) vs agora.
    // Mesmo critério de ordenarRanking (biblioteca.dart): pontos do modo +
    // 4 desempates (exatos, perdidos, campeão, Chuteira de Ouro).
    const totalDe = (u) => (modoCopa
      ? (u.pontuacaoCopa || 0)
      : (u.pontuacaoClassica || 0))
      + (u.pontuacaoEliminatorias || 0) + (u.pontuacaoEspeciais || 0);
    const campNorm = config.campeaoReal?.toLowerCase().trim() || null;
    const chutNorm = config.chuteiradeOuroReal?.toLowerCase().trim() || null;
    const comparar = (a, b) => {
      if (b.pontos !== a.pontos) return b.pontos - a.pontos;
      if (b.exatos !== a.exatos) return b.exatos - a.exatos;
      if (a.perdidos !== b.perdidos) return a.perdidos - b.perdidos;
      const camp = (x) => (campNorm != null &&
        x.u.palpiteCampeao?.toLowerCase().trim() === campNorm) ? 1 : 0;
      if (camp(b) !== camp(a)) return camp(b) - camp(a);
      const chut = (x) => (chutNorm != null &&
        x.u.palpiteChuteiradeOuro?.toLowerCase().trim() === chutNorm) ? 1 : 0;
      return chut(b) - chut(a);
    };

    const agora = [], antes = [];
    for (const uid of Object.keys(statsRodada)) {
      const u = usuarios[uid];
      const s = statsRodada[uid];
      agora.push({
        uid, u,
        pontos: totalDe(u),
        exatos: u.placaresExatos || 0,
        perdidos: u.palpitesPerdidos || 0,
      });
      antes.push({
        uid, u,
        pontos: totalDe(u) - s.pontosRodada,
        exatos: (u.placaresExatos || 0) - s.exatos,
        perdidos: (u.palpitesPerdidos || 0) - s.perdidos,
      });
    }
    agora.sort(comparar);
    antes.sort(comparar);
    const posAntes = {}, posAgora = {};
    antes.forEach((e, i) => { posAntes[e.uid] = i + 1; });
    agora.forEach((e, i) => { posAgora[e.uid] = i + 1; });

    const stats = {};
    for (const uid of Object.keys(statsRodada)) {
      stats[uid] = {
        pontosRodada: statsRodada[uid].pontosRodada,
        movimento: posAntes[uid] - posAgora[uid],
      };
    }

    return {
      // numero = quantidade de dias distintos com jogo encerrado ("Dia N");
      // label = rodada real (matchday da fase de grupos ou nome da fase)
      rodada: {
        data: ultimaData,
        numero: datas.length,
        jogos: jogosRodada.length,
        label: rodadaLabel,
      },
      stats,
    };
  }
);

// ─── adicionarTodosAoGrupo ────────────────────────────────────────────────────
// Adiciona todos os usuários existentes a um grupo pelo código.
// Ignora quem já é membro. Só pode ser chamada por admin.

exports.adicionarTodosAoGrupo = onCall(
  { region: 'southamerica-east1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const db = getFirestore();
    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    const { codigo, uids } = request.data;
    if (!codigo) throw new HttpsError('invalid-argument', 'codigo obrigatório.');
    if (!Array.isArray(uids) || uids.length === 0) {
      throw new HttpsError('invalid-argument', 'uids deve ser uma lista não vazia.');
    }

    const gruposSnap = await db.collection('grupos')
      .where('codigo', '==', codigo.toUpperCase())
      .limit(1)
      .get();

    if (gruposSnap.empty) {
      throw new HttpsError('not-found', `Grupo com código "${codigo}" não encontrado.`);
    }

    const grupoDoc = gruposSnap.docs[0];
    const membrosAtuais = new Set(grupoDoc.data().membros || []);
    const novosUids = uids.filter((uid) => !membrosAtuais.has(uid));

    if (novosUids.length > 0) {
      await grupoDoc.ref.update({
        membros: FieldValue.arrayUnion(...novosUids),
      });
    }

    return {
      adicionados: novosUids.length,
      grupo: grupoDoc.data().nome,
    };
  }
);

// ─── Integração football-data.org ────────────────────────────────────────────
// O app NUNCA chama a API diretamente (o repositório é público): a chave fica
// no secret FOOTBALL_DATA_KEY (firebase functions:secrets:set FOOTBALL_DATA_KEY)
// e somente as Functions falam com a API. Free tier: 10 requisições/minuto;
// cada execução faz no máximo 3 (matches + standings + scorers).

const FOOTBALL_DATA_KEY = defineSecret('FOOTBALL_DATA_KEY');
const API_BASE = 'https://api.football-data.org/v4';

// Nomes de time que divergem entre a API e o nosso jogos.json.
const ALIAS_API = {
  'Czechia': 'Czech Republic',
  'Bosnia-Herzegovina': 'Bosnia & Herzegovina',
  'United States': 'USA',
  'Cape Verde Islands': 'Cape Verde',
};

// round (nosso) → stage (API)
const STAGE_POR_ROUND = {
  'Fase de Grupos': 'GROUP_STAGE',
  '16 avos de Final': 'LAST_32',
  'Oitavas de Final': 'LAST_16',
  'Quartas de Final': 'QUARTER_FINALS',
  'Semifinal': 'SEMI_FINALS',
  'Disputa de 3º Lugar': 'THIRD_PLACE',
  'Final': 'FINAL',
};

// Converte um nome de time da API para a grafia do nosso jogos.json.
function _nomeNosso(nomeApi) {
  return ALIAS_API[nomeApi] || nomeApi || '';
}

// Comparação tolerante: ignora caixa e tudo que não for letra
// ("Bosnia & Herzegovina" ≅ "Bosnia-Herzegovina").
function _normalizarNome(nome) {
  return (nome || '').toLowerCase().replace(/[^a-z]/g, '');
}

function _mesmoNome(nomeApi, nomeNosso) {
  return _normalizarNome(_nomeNosso(nomeApi)) === _normalizarNome(nomeNosso);
}

// Nome de time da API válido para definir um confronto, já na nossa grafia.
// Retorna null quando o time ainda não foi determinado (a API usa name null
// ou textos tipo "Winner Group A" enquanto o confronto não está definido).
function _nomeRealDeTime(nomeApi) {
  const nome = _nomeNosso(nomeApi);
  if (!nome) return null;
  if (/winner|loser|group|\d/i.test(nome)) return null;
  return nome;
}

async function _buscarApi(caminho) {
  const resp = await fetch(`${API_BASE}${caminho}`, {
    headers: { 'X-Auth-Token': FOOTBALL_DATA_KEY.value() },
  });
  if (!resp.ok) {
    throw new Error(`football-data.org ${caminho} → HTTP ${resp.status}`);
  }
  return resp.json();
}

// Grava um documento de log na coleção `logs`, lida pela tela admin Ver Logs.
// `linhas` vira uma mensagem multi-linha. O campo expiraEm alimenta a política
// de TTL do Firestore (logs somem sozinhos após 7 dias). Nunca propaga erro:
// log é diagnóstico, não pode derrubar a sincronização.
async function _logar(db, origem, linhas) {
  try {
    const agora = Date.now();
    await db.collection('logs').add({
      origem,
      mensagem: linhas.join('\n'),
      criadoEm: Timestamp.fromMillis(agora),
      expiraEm: Timestamp.fromMillis(agora + 7 * 24 * 60 * 60 * 1000),
    });
  } catch (e) {
    console.error('Falha ao gravar log:', e);
  }
}

// Encontra o jogo da API correspondente a um documento nosso.
// Critério primário: mesmo horário UTC + mesma fase (+ mesmo grupo na Fase de
// Grupos). Quando há mais de um candidato (a última rodada de cada grupo tem
// os dois jogos simultâneos), desempata pelos nomes dos times — em qualquer
// ordem, pois a orientação home/away é tratada separadamente.
function _encontrarJogoApi(jogo, matchesApi) {
  const ts = jogo.dataHora?.toDate?.()?.getTime();
  if (!ts) return null;
  const stage = STAGE_POR_ROUND[jogo.round] || 'GROUP_STAGE';
  // Compara só a letra do grupo: o standings do WC 2026 já trocou "GROUP_A"
  // por "Group A", então o matches pode mudar de formato a qualquer momento.
  const letraGrupo = jogo.group ? jogo.group.slice(-1) : null;

  const candidatos = matchesApi.filter((m) =>
    Date.parse(m.utcDate) === ts &&
    m.stage === stage &&
    (letraGrupo == null ||
      (m.group || '').replace(/^GROUP[_ ]/i, '').trim() === letraGrupo)
  );
  if (candidatos.length === 1) return candidatos[0];

  const porNome = candidatos.filter((m) =>
    (_mesmoNome(m.homeTeam?.name, jogo.team1) && _mesmoNome(m.awayTeam?.name, jogo.team2)) ||
    (_mesmoNome(m.homeTeam?.name, jogo.team2) && _mesmoNome(m.awayTeam?.name, jogo.team1))
  );
  return porNome.length === 1 ? porNome[0] : null;
}

// true quando o homeTeam da API corresponde ao nosso team2 (ordem invertida) —
// nesse caso os placares home/away precisam ser trocados antes de gravar.
function _ordemInvertida(jogo, m) {
  return _mesmoNome(m.homeTeam?.name, jogo.team2) &&
    _mesmoNome(m.awayTeam?.name, jogo.team1);
}

// Placar parcial (IN_PLAY/PAUSED) → placarAoVivo1/2. JAMAIS toca
// placar1/placar2 — esses só recebem o placar final, que é o que dispara o
// trigger calcularPontuacao. Retorna apenas o que mudou.
function _verificarPlacaresParciais(jogo, m, invertido) {
  const updates = {};
  const ft = (m.score || {}).fullTime || {};
  const live1 = invertido ? ft.away : ft.home;
  const live2 = invertido ? ft.home : ft.away;
  if (live1 != null && live2 != null &&
      (jogo.placarAoVivo1 !== live1 || jogo.placarAoVivo2 !== live2)) {
    updates.placarAoVivo1 = live1;
    updates.placarAoVivo2 = live2;
  }
  return updates;
}

// Placar final (FINISHED) → placar1/2 pela regra dos 90 minutos
// (score.regularTime; a API só o envia quando houve prorrogação — nos demais
// casos o fullTime já é o placar dos 90). Em empate nos 90, grava `vencedor`
// (score.winner) e o placar da decisão (pênaltis ou placar final da
// prorrogação). Também remove o placar ao vivo. O chamador garante que
// placar1 ainda é null (placar do admin nunca é sobrescrito).
function _aplicarPlacarFinal(jogo, m, invertido) {
  const updates = {};
  let finalizou = false;

  const score = m.score || {};
  const ft = score.fullTime || {};
  // regularTime pode vir como {home: null, away: null} quando não houve
  // prorrogação — só usa se tiver valores de fato.
  const rt = (score.regularTime?.home != null && score.regularTime?.away != null)
    ? score.regularTime : ft;
  const r1 = invertido ? rt.away : rt.home;
  const r2 = invertido ? rt.home : rt.away;

  if (r1 != null && r2 != null) {
    updates.placar1 = r1;
    updates.placar2 = r2;
    if (r1 === r2 && score.winner && score.winner !== 'DRAW') {
      const venceuHome = score.winner === 'HOME_TEAM';
      updates.vencedor = (venceuHome !== invertido) ? jogo.team1 : jogo.team2;
      const dec = score.duration === 'PENALTY_SHOOTOUT' ? score.penalties : ft;
      const d1 = invertido ? dec?.away : dec?.home;
      const d2 = invertido ? dec?.home : dec?.away;
      if (d1 != null && d2 != null) {
        updates.placarDecisao1 = d1;
        updates.placarDecisao2 = d2;
      }
    }
    finalizou = true;
  }

  if (jogo.placarAoVivo1 != null || jogo.placarAoVivo2 != null) {
    updates.placarAoVivo1 = FieldValue.delete();
    updates.placarAoVivo2 = FieldValue.delete();
  }

  return { updates, finalizou };
}

// Busca standings e artilharia na API e grava nos docs api/classificacao e
// api/artilharia (consumidos pela aba CLASSIFICAÇÃO/ARTILHARIA da Tabela e
// pelo card da Home). Nomes de time convertidos para a grafia do jogos.json.
async function _atualizarStandingsEArtilharia(db) {
  const standings = await _buscarApi('/competitions/WC/standings');
  const grupos = {};
  for (const s of standings.standings || []) {
    if (s.type && s.type !== 'TOTAL') continue;
    // Standings do WC 2026 enviam "Group A" (em 2022 era "GROUP_A") —
    // aceita os dois formatos para a chave ficar sempre só com a letra.
    const letra = (s.group || '').replace(/^GROUP[_ ]/i, '').trim();
    if (!letra) continue;
    grupos[letra] = (s.table || []).map((t) => ({
      posicao: t.position ?? 0,
      time: _nomeNosso(t.team?.name),
      jogos: t.playedGames ?? 0,
      vitorias: t.won ?? 0,
      empates: t.draw ?? 0,
      derrotas: t.lost ?? 0,
      pontos: t.points ?? 0,
      golsPro: t.goalsFor ?? 0,
      golsContra: t.goalsAgainst ?? 0,
      saldo: t.goalDifference ?? 0,
    }));
  }

  const scorers = await _buscarApi('/competitions/WC/scorers?limit=100');
  const artilheiros = (scorers.scorers || []).map((s) => ({
    nome: s.player?.name || '',
    selecao: _nomeNosso(s.team?.name),
    gols: s.goals ?? 0,
    assistencias: s.assists ?? 0,
  }));

  await db.collection('api').doc('classificacao').set({
    grupos,
    atualizadoEm: FieldValue.serverTimestamp(),
  });
  await db.collection('api').doc('artilharia').set({
    artilheiros,
    atualizadoEm: FieldValue.serverTimestamp(),
  });
}

// ─── mapearJogosApi ───────────────────────────────────────────────────────────
// De-para permanente: grava o id da API no campo apiId de cada documento de
// `jogos`. Executar uma vez (e novamente após Popular Jogos, que recria os
// docs). Jogos de eliminatória sem horário/fase únicos ficam pendentes e são
// mapeados automaticamente pela sincronizarApi quando os times forem reais.
// Também grava a primeira foto de classificação e artilharia.

exports.mapearJogosApi = onCall(
  { region: 'southamerica-east1', secrets: [FOOTBALL_DATA_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Não autenticado.');

    const db = getFirestore();
    const userDoc = await db.collection('usuarios').doc(request.auth.uid).get();
    if (!userDoc.exists || userDoc.data().isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Acesso restrito ao admin.');
    }

    const resposta = await _buscarApi('/competitions/WC/matches');
    const matches = resposta.matches || [];
    if (matches.length === 0) {
      throw new HttpsError('unavailable', 'A API não retornou jogos.');
    }

    const jogosSnap = await db.collection('jogos').get();
    const docsOrdenados = [...jogosSnap.docs]
      .sort((a, b) => (a.data().id || 0) - (b.data().id || 0));

    const batch = db.batch();
    const usados = new Set();
    let mapeados = 0;
    const pendentes = [];

    for (const doc of docsOrdenados) {
      const jogo = doc.data();
      const m = _encontrarJogoApi(jogo, matches.filter((x) => !usados.has(x.id)));
      if (m) {
        usados.add(m.id);
        batch.update(doc.ref, { apiId: m.id });
        mapeados++;
      } else {
        pendentes.push(jogo.id);
      }
    }
    await batch.commit();

    await _atualizarStandingsEArtilharia(db);

    await _logar(db, 'mapearJogosApi', [
      `${mapeados} jogo(s) mapeado(s)` +
        (pendentes.length > 0 ? `; pendentes: ${pendentes.join(', ')}` : ''),
    ]);

    return { mapeados, pendentes };
  }
);

// ─── sincronizarApi ───────────────────────────────────────────────────────────
// Roda a cada 2 minutos, mas só chama a API quando existe jogo na "janela
// ativa" (começou nas últimas 5h ou começa nos próximos 20 min e ainda sem
// placar final — mesmo com statusApi FINISHED, pois a API pode confirmar o
// placar com atraso) OU jogo de eliminatória nas próximas 72h ainda com time
// placeholder (confronto a definir) — fora desses casos, encerra com uma
// única query barata ao Firestore.
//
// Regras de escrita:
//   - Placar parcial JAMAIS vai em placar1/placar2 (dispararia a pontuação):
//     vai em placarAoVivo1/placarAoVivo2 + statusApi.
//   - Placar final (status FINISHED) segue a regra dos 90 minutos: grava
//     score.regularTime (a API só o envia quando houve prorrogação; nos demais
//     casos o fullTime já é o placar dos 90) e preenche `vencedor` quando os
//     90 min empataram — isso dispara o trigger calcularPontuacao igual à
//     inserção manual do admin.
//   - Só grava o que mudou; e nunca sobrescreve placar1/placar2 já inseridos
//     manualmente (a tela de admin continua valendo como override).

exports.sincronizarApi = onSchedule(
  {
    schedule: '*/2 * * * *',
    region: 'southamerica-east1',
    timeZone: 'America/Sao_Paulo',
    secrets: [FOOTBALL_DATA_KEY],
  },
  async () => {
    const db = getFirestore();
    const agora = Date.now();

    // Uma única query cobre a janela ativa (placares) e as próximas 72h
    // (confrontos de eliminatória ainda não definidos).
    const limiteJanela = agora + 20 * 60 * 1000;
    const jogosSnap = await db.collection('jogos')
      .where('dataHora', '>=', Timestamp.fromMillis(agora - 5 * 60 * 60 * 1000))
      .where('dataHora', '<=', Timestamp.fromMillis(agora + 72 * 60 * 60 * 1000))
      .get();

    // Janela ativa: sincronizar placar ao vivo / final. Não filtra por
    // statusApi: a API pode marcar FINISHED antes de confirmar o placar
    // final (visto no jogo de abertura), então o jogo segue elegível
    // enquanto placar1 for null — a janela de 5h limita as tentativas.
    const pendentes = jogosSnap.docs.filter((d) => {
      const j = d.data();
      return j.dataHora.toMillis() <= limiteJanela &&
        j.placar1 == null &&
        !_ehPlaceholder(j.team1) && !_ehPlaceholder(j.team2);
    });

    // Eliminatórias nas próximas 72h com time placeholder: definir confronto
    // assim que a API publicar os times reais (importante entre o fim da fase
    // de grupos e os 16 avos, quando não há jogo na janela ativa)
    const indefinidos = jogosSnap.docs.filter((d) => {
      const j = d.data();
      return _ehPlaceholder(j.team1) || _ehPlaceholder(j.team2);
    });

    if (pendentes.length === 0 && indefinidos.length === 0) {
      return null; // fora da janela: zero requisições (e zero logs)
    }

    // Tudo que acontece a partir daqui vira UM documento de log por execução
    // (tela admin Ver Logs); execuções fora da janela não geram log.
    const linhas = [];
    try {

    // dateFrom/dateTo cobrindo todos os jogos relevantes, com 1 dia de margem UTC
    const tempos = [...pendentes, ...indefinidos]
      .map((d) => d.data().dataHora.toDate().getTime());
    const fmt = (t) => new Date(t).toISOString().slice(0, 10);
    const dateFrom = fmt(Math.min(...tempos) - 24 * 60 * 60 * 1000);
    const dateTo = fmt(Math.max(...tempos) + 24 * 60 * 60 * 1000);

    const resposta = await _buscarApi(
      `/competitions/WC/matches?dateFrom=${dateFrom}&dateTo=${dateTo}`
    );
    const matches = resposta.matches || [];
    const porId = new Map(matches.map((m) => [m.id, m]));

    linhas.push(
      `${pendentes.length} jogo(s) na janela ativa, ${indefinidos.length} ` +
      `confronto(s) a definir — API retornou ${matches.length} jogo(s) ` +
      `(${dateFrom} a ${dateTo})`
    );

    // Define os confrontos das eliminatórias: preenche team1/team2 apenas
    // onde ainda há placeholder — nunca sobrescreve time já definido (pela
    // propagação da chave, pela tela Admin Copa ou por ajuste manual).
    for (const doc of indefinidos) {
      const j = doc.data();
      const updates = {};

      let m = j.apiId != null ? porId.get(j.apiId) : null;
      if (!m) {
        m = _encontrarJogoApi(j, matches);
        if (m) updates.apiId = m.id;
      }
      if (!m) {
        linhas.push(`Jogo ${j.id}: sem correspondência na API`);
        continue;
      }

      const nome1 = _nomeRealDeTime(m.homeTeam?.name);
      const nome2 = _nomeRealDeTime(m.awayTeam?.name);
      if (_ehPlaceholder(j.team1) && nome1) updates.team1 = nome1;
      if (_ehPlaceholder(j.team2) && nome2) updates.team2 = nome2;

      if (updates.team1 || updates.team2) {
        linhas.push(
          `Jogo ${j.id}: confronto definido — ` +
          `${updates.team1 ?? j.team1} x ${updates.team2 ?? j.team2}`
        );
      } else {
        linhas.push(`Jogo ${j.id}: times ainda não definidos na API`);
      }

      if (Object.keys(updates).length > 0) await doc.ref.update(updates);
    }

    let finalizouAlgum = false;

    for (const doc of pendentes) {
      const j = doc.data();
      const updates = {};

      let m = j.apiId != null ? porId.get(j.apiId) : null;
      if (!m) {
        // De-para ainda não feito para este jogo (ex: eliminatória que ficou
        // pendente no mapearJogosApi) — tenta mapear agora pelos times reais.
        m = _encontrarJogoApi(j, matches);
        if (m) updates.apiId = m.id;
      }
      if (!m) {
        linhas.push(`Jogo ${j.id} ${j.team1} x ${j.team2}: sem correspondência na API`);
        continue;
      }

      if (j.statusApi !== m.status) updates.statusApi = m.status;

      const invertido = _ordemInvertida(j, m);

      if (m.status === 'IN_PLAY' || m.status === 'PAUSED') {
        Object.assign(updates, _verificarPlacaresParciais(j, m, invertido));
      } else if (m.status === 'FINISHED') {
        const { updates: finais, finalizou } = _aplicarPlacarFinal(j, m, invertido);
        Object.assign(updates, finais);
        if (finalizou) finalizouAlgum = true;
      }

      // Placar na orientação home/away da API (pode estar invertido em
      // relação a team1/team2 — a inversão é tratada antes de gravar).
      const ft = (m.score || {}).fullTime || {};
      const mudou = Object.keys(updates).length > 0;
      linhas.push(
        `Jogo ${j.id} ${j.team1} x ${j.team2}: ${m.status}, ` +
        `placar API ${ft.home ?? '-'}x${ft.away ?? '-'}` +
        (mudou ? ` → gravou ${Object.keys(updates).join(', ')}` : ' (sem mudanças)')
      );

      if (mudou) {
        // Um update por documento (sem batch): cada placar final dispara o
        // trigger calcularPontuacao individualmente, como a inserção manual.
        await doc.ref.update(updates);
      }
    }

    // Classificação e artilharia só mudam quando algum jogo termina
    if (finalizouAlgum) {
      await _atualizarStandingsEArtilharia(db);
      linhas.push('Classificação e artilharia atualizadas');
    }

    await _logar(db, 'sincronizarApi', linhas);
    } catch (e) {
      linhas.push(`ERRO: ${e.message}`);
      await _logar(db, 'erro', linhas);
      throw e;
    }

    return null;
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
