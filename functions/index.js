const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
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
