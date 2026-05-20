const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();

// Dispara quando o admin insere ou corrige um placar em /jogos/{jogoId}.
// Recalcula e aplica o delta de pontuação para cada participante que fez
// palpite nesse jogo — sem depender do cliente para o cálculo.
exports.calcularPontuacao = onDocumentUpdated(
  { document: 'jogos/{jogoId}', region: 'southamerica-east1' },
  async (event) => {
    const antes = event.data.before.data();
    const depois = event.data.after.data();

    // Ignora atualizações que não alteraram o placar
    if (antes.placar1 === depois.placar1 && antes.placar2 === depois.placar2) {
      return null;
    }

    // Só processa quando o novo placar estiver completo
    if (depois.placar1 == null || depois.placar2 == null) return null;

    const db = getFirestore();
    const jogoId = depois.id; // campo numérico no documento

    const palpitesSnap = await db
      .collection('palpites')
      .where('jogoId', '==', jogoId)
      .get();

    if (palpitesSnap.empty) return null;

    const batch = db.batch();

    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      let delta = 0;

      // Subtrai pontos do placar anterior (correção de placar)
      if (antes.placar1 != null && antes.placar2 != null) {
        delta -= calcularPontos(p.palpite1, p.palpite2, antes.placar1, antes.placar2);
      }

      delta += calcularPontos(p.palpite1, p.palpite2, depois.placar1, depois.placar2);

      if (delta !== 0) {
        const userRef = db.collection('usuarios').doc(p.uid);
        batch.update(userRef, { pontuacao: FieldValue.increment(delta) });
      }
    });

    return batch.commit();
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

    // Indexa jogos com placar por id numérico
    const jogosSnap = await db.collection('jogos').get();
    const jogosPorId = {};
    jogosSnap.forEach((doc) => {
      const d = doc.data();
      if (d.placar1 != null && d.placar2 != null) jogosPorId[d.id] = d;
    });

    // Soma pontos por uid
    const pontuacaoPorUid = {};
    const palpitesSnap = await db.collection('palpites').get();
    palpitesSnap.forEach((doc) => {
      const p = doc.data();
      const jogo = jogosPorId[p.jogoId];
      if (!jogo) return;
      const pts = calcularPontos(p.palpite1, p.palpite2, jogo.placar1, jogo.placar2);
      pontuacaoPorUid[p.uid] = (pontuacaoPorUid[p.uid] || 0) + pts;
    });

    // Sobrescreve pontuacao de todos os usuários com o valor correto (ou 0)
    const usuariosSnap = await db.collection('usuarios').get();
    const batch = db.batch();
    usuariosSnap.forEach((doc) => {
      batch.update(doc.ref, { pontuacao: pontuacaoPorUid[doc.id] || 0 });
    });
    await batch.commit();

    return { atualizados: usuariosSnap.size };
  }
);

// Mesma lógica de pontuação do app Flutter (tela_palpites.dart).
// p = palpite, r = resultado real
function calcularPontos(p1, p2, r1, r2) {
  if (p1 === r1 && p2 === r2) return 10;
  const sP = p1 - p2;
  const sR = r1 - r2;
  const vP = Math.sign(p1 - p2); // -1 | 0 | 1  (equivalente ao compareTo do Dart)
  const vR = Math.sign(r1 - r2);
  if (sP === sR && vP === vR) return 7;
  if (vP === vR && vR !== 0) return 5;
  if (vP === 0 && vR === 0) return 4;
  return 0;
}
