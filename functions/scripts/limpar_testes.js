/**
 * Script de limpeza de dados de teste do Firestore.
 *
 * O que faz:
 *  - Reseta placar1, placar2 e vencedor de todos os 104 jogos para null
 *  - Restaura team1/team2 dos jogos 73-104 (eliminatórias) para os placeholders originais
 *  - Limpa todos os resultados reais em config/copa2026
 *  - Zera a pontuação de todos os usuários
 *
 * O que NÃO toca:
 *  - Palpites dos usuários (ficam intactos para o próximo ciclo de testes)
 *  - Dados de perfil, grupos e preferências de notificação
 *
 * Como rodar (na raiz do projeto):
 *   node functions/scripts/limpar_testes.js
 *
 * Requer autenticação prévia com: firebase login
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Usa o token gerado pelo Firebase CLI: firebase login:ci
// Se FIREBASE_TOKEN não estiver setado, tenta applicationDefault
const credential = process.env.FIREBASE_TOKEN
  ? admin.credential.refreshToken(process.env.FIREBASE_TOKEN)
  : admin.credential.applicationDefault();

admin.initializeApp({ credential, projectId: 'bolaodasoci2026' });

const db = admin.firestore();

// Placeholders originais dos jogos eliminatórios (73-104), extraídos do jogos.json
// Usados para restaurar team1/team2 após testes
const PLACEHOLDERS_ORIGINAIS = {
  73:  { team1: '2A',          team2: '2B'          },
  74:  { team1: '1E',          team2: '3°'          },
  75:  { team1: '1F',          team2: '2C'          },
  76:  { team1: '1C',          team2: '2F'          },
  77:  { team1: '1I',          team2: '3°'          },
  78:  { team1: '2E',          team2: '2I'          },
  79:  { team1: '1A',          team2: '3°'          },
  80:  { team1: '1L',          team2: '3°'          },
  81:  { team1: '1D',          team2: '3°'          },
  82:  { team1: '1G',          team2: '3°'          },
  83:  { team1: '2K',          team2: '2L'          },
  84:  { team1: '1H',          team2: '2J'          },
  85:  { team1: '1B',          team2: '3°'          },
  86:  { team1: '1J',          team2: '2H'          },
  87:  { team1: '1K',          team2: '3°'          },
  88:  { team1: '2D',          team2: '2G'          },
  89:  { team1: 'Vencedor 74', team2: 'Vencedor 77' },
  90:  { team1: 'Vencedor 73', team2: 'Vencedor 75' },
  91:  { team1: 'Vencedor 76', team2: 'Vencedor 78' },
  92:  { team1: 'Vencedor 79', team2: 'Vencedor 80' },
  93:  { team1: 'Vencedor 83', team2: 'Vencedor 84' },
  94:  { team1: 'Vencedor 81', team2: 'Vencedor 82' },
  95:  { team1: 'Vencedor 86', team2: 'Vencedor 88' },
  96:  { team1: 'Vencedor 85', team2: 'Vencedor 87' },
  97:  { team1: 'Vencedor 89', team2: 'Vencedor 90' },
  98:  { team1: 'Vencedor 93', team2: 'Vencedor 94' },
  99:  { team1: 'Vencedor 91', team2: 'Vencedor 92' },
  100: { team1: 'Vencedor 95', team2: 'Vencedor 96' },
  101: { team1: 'Vencedor 97', team2: 'Vencedor 98' },
  102: { team1: 'Vencedor 99', team2: 'Vencedor 100'},
  103: { team1: 'Perdedor 101',team2: 'Perdedor 102'},
  104: { team1: 'Vencedor 101',team2: 'Vencedor 102'},
};

async function commitBatch(ops) {
  const LIMITE = 400;
  for (let i = 0; i < ops.length; i += LIMITE) {
    const batch = db.batch();
    ops.slice(i, i + LIMITE).forEach(fn => fn(batch));
    await batch.commit();
  }
}

async function main() {
  console.log('Iniciando limpeza de dados de teste...\n');

  // ─── 1. Resetar todos os jogos ──────────────────────────────────────────────
  const jogosSnap = await db.collection('jogos').get();
  const opsJogos = jogosSnap.docs.map(doc => batch => {
    const id = doc.data().id;
    const updates = {
      placar1: null,
      placar2: null,
      vencedor: admin.firestore.FieldValue.delete(),
    };
    if (PLACEHOLDERS_ORIGINAIS[id]) {
      updates.team1 = PLACEHOLDERS_ORIGINAIS[id].team1;
      updates.team2 = PLACEHOLDERS_ORIGINAIS[id].team2;
    }
    batch.update(doc.ref, updates);
  });
  await commitBatch(opsJogos);
  console.log(`✓ ${opsJogos.length} jogos resetados (placares, vencedor, times eliminatórias).`);

  // ─── 2. Limpar resultados reais do config ───────────────────────────────────
  const FVD = admin.firestore.FieldValue.delete;
  await db.collection('config').doc('copa2026').set({
    classificacao_real:          FVD(),
    terceiros_classificados:     FVD(),
    campeaoReal:                 FVD(),
    chuteiradeOuroReal:          FVD(),
    boladeOuroReal:              FVD(),
    luvadeOuroReal:              FVD(),
    melhorJovemReal:             FVD(),
    palpitesEspeciaisCalculados: FVD(),
  }, { merge: true });
  console.log('✓ config/copa2026 limpo (classificação, resultados especiais).');

  // ─── 3. Zerar pontuação de todos os usuários ────────────────────────────────
  const usuariosSnap = await db.collection('usuarios').get();
  const opsUsuarios = usuariosSnap.docs.map(doc => batch =>
    batch.update(doc.ref, { pontuacao: 0 })
  );
  await commitBatch(opsUsuarios);
  console.log(`✓ ${opsUsuarios.length} usuários zerados (pontuacao → 0).`);

  console.log('\nLimpeza concluída!');
}

main().catch(err => {
  console.error('Erro durante a limpeza:', err);
  process.exit(1);
}).finally(() => process.exit(0));
