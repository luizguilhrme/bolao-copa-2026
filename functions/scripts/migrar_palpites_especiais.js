/**
 * Script de migração dos palpites especiais para os novos nomes de campo.
 *
 * O que faz:
 *  - Para cada usuário, copia o valor dos campos antigos para os novos,
 *    apenas se o campo antigo existe E o novo ainda está vazio.
 *    Não sobrescreve palpites já feitos na nova estrutura.
 *
 * Mapeamento:
 *  palpiteArtilheiro   → palpiteChuteiradeOuro
 *  palpiteGoleiro      → palpiteLuvadeOuro
 *  palpiteMelhorJogador → palpiteBoladeOuro
 *
 * Campos sem equivalente (palpiteMaisGoleadora, palpiteMenosVazada):
 *  Mantidos como órfãos no Firestore — o app ignora, não causam problema.
 *
 * Como rodar (na raiz do projeto):
 *   node functions/scripts/migrar_palpites_especiais.js
 *
 * Requer autenticação prévia com: firebase login
 */

const admin = require('firebase-admin');
const path  = require('path');

// Usa chave de serviço local (baixar em Firebase Console → Project settings → Service accounts)
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
  ?? path.join(__dirname, 'serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(keyPath),
  projectId: 'bolaodasoci2026',
});

const db = admin.firestore();

const MAPEAMENTO = [
  { antigo: 'palpiteArtilheiro',    novo: 'palpiteChuteiradeOuro' },
  { antigo: 'palpiteGoleiro',       novo: 'palpiteLuvadeOuro'     },
  { antigo: 'palpiteMelhorJogador', novo: 'palpiteBoladeOuro'     },
];

async function commitBatch(ops) {
  const LIMITE = 400;
  for (let i = 0; i < ops.length; i += LIMITE) {
    const batch = db.batch();
    ops.slice(i, i + LIMITE).forEach(fn => fn(batch));
    await batch.commit();
  }
}

async function main() {
  console.log('Iniciando migração dos palpites especiais...\n');

  const snap = await db.collection('usuarios').get();
  console.log(`${snap.size} usuários encontrados.\n`);

  const ops = [];
  let migrados = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const updates = {};

    for (const { antigo, novo } of MAPEAMENTO) {
      const valorAntigo = data[antigo];
      const valorNovo   = data[novo];

      if (valorAntigo != null && valorNovo == null) {
        updates[novo] = valorAntigo;
      }
    }

    if (Object.keys(updates).length > 0) {
      const nome = data.nome ?? data.email ?? doc.id;
      console.log(`  → ${nome}: ${JSON.stringify(updates)}`);
      ops.push(batch => batch.update(doc.ref, updates));
      migrados++;
    }
  }

  if (ops.length === 0) {
    console.log('Nenhum usuário precisou de migração.');
  } else {
    await commitBatch(ops);
    console.log(`\n✓ ${migrados} usuário(s) migrado(s).`);
  }

  console.log('\nMigração concluída!');
}

main().catch(err => {
  console.error('Erro durante a migração:', err);
  process.exit(1);
}).finally(() => process.exit(0));
