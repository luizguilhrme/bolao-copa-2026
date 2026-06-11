# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **REGRA OBRIGATÓRIA — documentação:** `C:\bolao\resumo_bolao_copa_2026.md` é a documentação detalhada do projeto (estrutura de pastas, descrição tela a tela, schema completo do Firestore, Cloud Functions, paleta de cores, histórico de bugs, setup do Firebase/Play Store). Ele DEVE ser atualizado a cada mudança relevante no código. Este CLAUDE.md contém apenas o essencial de toda sessão e só muda quando regras de negócio, convenções ou arquitetura de alto nível mudarem. **Consulte o resumo sempre que precisar de detalhes de uma tela, coleção, função ou decisão passada.**

## Project overview

**Nome do app:** Bolão - Crava aí! (Play Store: "Bolão - Crava aí! | Sem Anúncios")

Flutter app for a World Cup 2026 prediction pool (bolão). Users register predictions for match scores; an admin enters real results, and the app calculates and ranks players by points. Backend is Firebase (Auth + Firestore). Android (nativo) + Web/PWA em https://bolaodasoci2026.web.app (iOS via PWA no Safari). Repositório público no GitHub — nunca commitar chaves (`google-services.json`, `firebase_options.dart`, `key.properties` estão no `.gitignore`).

> **Nota de branding:** O **nome de exibição** do projeto Firebase é `bolaocravaai` e o nome público `Bolão - Crava aí!`. O **ID do projeto** (`bolaodasoci2026`) e a URL de hosting (`bolaodasoci2026.web.app`) são permanentes e não podem ser alterados.

## Common commands

```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter analyze          # static analysis / linting
flutter test             # run all tests
flutter test test/foo_test.dart  # run a single test file
flutter build apk        # build Android APK
```

To populate Firestore with the 104 games, open the drawer → ADMIN → Outras Definições → Popular Jogos. A dialog will ask whether to use production (`jogos.json`) or test data (`jogos_teste.json`). The test dataset has IDs 1–5 with `placar1=1`/`placar2=0` (all Grupo A, dates 2026-05-30/31), IDs 6–72 without scores (original jogos.json dates), and IDs 73–104 identical to jogos.json. `popularJogosNoFirestore` deletes all existing `jogos` documents before inserting, ensuring no orphaned games remain.

## Architecture

**Pattern:** screen → service → Firestore. No state management library — state is handled with `setState` and `StreamBuilder` directly. Cloud Functions (`functions/index.js`, Node 22, região `southamerica-east1`) fazem todo o cálculo de pontuação e a sincronização com a API (lista completa das functions no resumo).

**Six Firestore collections:**
- `usuarios` — document ID = Firebase Auth UID
- `jogos` — document ID = game integer ID (string-cast). Populated once from `assets/dados/jogos.json`. Elimination round games (73–104) have placeholder `team1`/`team2` values (`"1A"`, `"2B"`, `"3°"`, `"Vencedor 73"`, etc.) that are replaced automatically by the admin flow. Also carries the football-data.org sync fields (`apiId`, `statusApi`, `placarAoVivo1/2`) written only by Cloud Functions.
- `palpites` — document ID = `{uid}_{jogoId}`
- `grupos` — document ID = auto-ID. Stores bolão groups with a unique 6-char code.
- `config` — single document `copa2026` with group standings, special results, terceiros allocation.
- `api` — two documents (`classificacao`, `artilharia`) written exclusively by the Cloud Functions from football-data.org data; the app only reads (via `ApiDadosService`).

**Game IDs / fases (48 seleções, 104 jogos):** 1–72 Fase de Grupos | 73–88 16 avos de Final | 89–96 Oitavas | 97–100 Quartas | 101–102 Semifinal | 103 Disputa de 3º Lugar | 104 Final.

**Integração football-data.org:** o app NUNCA chama a API (repositório público). Fluxo: API → Cloud Function agendada `sincronizarApi` (a cada 2 min, mas só faz requisições quando há jogo na janela ativa: início −20 min até +5h sem placar final) → Firestore → app. A chave fica no secret `FOOTBALL_DATA_KEY` (`firebase functions:secrets:set FOOTBALL_DATA_KEY`). O de-para jogo↔API é gravado no campo `apiId` pela callable admin `mapearJogosApi` (rodar novamente após Popular Jogos). Placar parcial vai em `placarAoVivo1/2` + `statusApi` (JAMAIS em `placar1/2`, que disparariam pontuação); o placar final (status FINISHED, `score.regularTime` — regra dos 90 min) é gravado em `placar1/2` e dispara o trigger `calcularPontuacao` como a inserção manual. A função compara antes de escrever e nunca sobrescreve placar já inserido pelo admin (a tela de placares segue como override manual). A partir dos 16 avos, a função também define os confrontos: preenche `team1/team2` dos jogos com placeholder nas próximas 72h assim que a API publica os times reais — sem nunca sobrescrever time já definido.

**Auth routing:** `main.dart` wraps the app in a `StreamBuilder<User?>` on `FirebaseAuth.instance.authStateChanges()`. Logged-in users go to `MenuPrincipal`; logged-out users go to `TelaLogin`.

**Admin access:** Gated by `isAdmin: true` in the user's Firestore document. Checked once at session start in `MenuPrincipal._verificarAdmin()`. The drawer shows 5 admin items: Placares, Classificação Copa, Palpites Especiais, Outras Definições, Teste de API. There is a dedicated test admin account (`teste@teste.com`) with `isAdmin: true` in Firestore, used for Google Play Console review.

**Scoring — four separate Firestore fields on each `usuarios` document:**

| Field | What accumulates | Written by |
|---|---|---|
| `pontuacaoClassica` | Group stage (Clássico) points + −10 penalties | `calcularPontuacao` trigger (games 1–72) / `recalcularTudo` |
| `pontuacaoCopa` | Copa group classification points | `recalcularCopa` (SET, not increment) |
| `pontuacaoEliminatorias` | Elimination game points (games 73–104) + −10 penalties — shared by both modes | `calcularPontuacao` trigger (games 73–104) / `recalcularTudo` |
| `pontuacaoEspeciais` | Special bet points — shared by both modes | `calcularPalpitesEspeciais` |

**Ranking totals:**
- Clássico = `pontuacaoClassicaTotal` getter = `pontuacaoClassica + pontuacaoEliminatorias + pontuacaoEspeciais`
- Copa = `pontuacaoCopaTotal` getter = `pontuacaoCopa + pontuacaoEliminatorias + pontuacaoEspeciais`

Modo Clássico — base points per game, multiplied by phase:
- 100 pts — exact score | 70 — correct winner + correct goal difference
- 60 — correct winner + exact goals of one team | 50 — correct winner only OR correct draw
- 0 — wrong result | −10 — no palpite (only after user's `criadoEm`)

Phase multipliers: Fase de Grupos ×1.0 | 16 avos ×1.2 | Oitavas ×1.4 | Quartas ×1.6 | Semifinal/3º ×1.8 | Final ×2.0

**Regra dos 90 minutos (eliminatórias):** para pontuação vale sempre o placar dos 90 minutos. Vitória na prorrogação ou nos pênaltis é registrada como empate nos 90 + campo `vencedor` (quem avançou). A `sincronizarApi` implementa isso usando `score.regularTime` (nunca `fullTime`, que inclui prorrogação) e preenchendo `vencedor` a partir de `score.winner` quando os 90 min empatam.

Modo Copa — points per team in group classification:
- Exact position: +200 | Qualified, wrong position: +100 | Did not qualify: 0
- Bonus for all palpited positions exact (≥2 valid): +100
- "Qualified but wrong position" applies even when no real result exists for that specific slot (e.g., when a group's 3rd-place slot is null but the team qualified as 1st or 2nd).

Special bets: Campeão do Mundo +500 | Chuteira de Ouro +300 | Bola de Ouro +300 | Luva de Ouro +300 | Melhor Jogador Jovem +200

**Palpite cutoff:** palpites are locked 5 minutes before game start. Games where `team1` or `team2` is still a placeholder (`ehPlaceholder()` in `biblioteca.dart`) are hidden from the palpites screen entirely until both teams are resolved. Palpites Copa e Especiais são bloqueados por `palpitesTravados=true` em `config/copa2026`.

## Code conventions

- All identifiers, comments, and UI strings are in **Brazilian Portuguese**.
- Utility functions in `lib/utils/biblioteca.dart` are top-level (no wrapping class): `flagDe()`, `siglaDe()`, `isoDe()`, `nomePtDe()`, `formatarData()`, `formatarCriadoEm()`, `mostrarMensagem()`, `mostrarRegras()`, `calcularPontos()`, `multiplicadorFase()`, `calcularPontosComFase()`, `corPontuacao()`, `corFundoPontuacao()`, `corBordaPontuacao()`. The `Bandeira` widget is also defined there.
- Shared dialogs and SnackBar helpers live in `lib/utils/dialogos.dart`: `mostrarSnackBarSucesso()`, `mostrarSnackBarErro()`, `mostrarSnackBarInfo()`, `DialogAmbiente`, `JogadorData` (model), `BottomSheetJogadores` (player-picker bottom sheet with `cor:` parameter), and `mostrarSeletorOpcoes()`/`BottomSheetOpcoes` (single-option picker without search, used by the Por rodada/Por grupo filters). Import this file in any screen that needs colored SnackBars, the environment selector dialog, or the pickers.
- Color palette is entirely in `lib/utils/cores.dart` (`Cores` class — never instantiated). Primary green is `Cores.verdePrincipal`. Error red is `Cores.error` — never use `Color(0xFFBA1A1A)` directly. Badge colors: `Cores.pontExato/pontVencedorSaldo/pontVencedorUmTime/pontVencedor/pontZero/pontNegativo`. Pódio: `Cores.ouro`, `Cores.prata`, `Cores.bronze`. Never use `Color(0xFFB8860B)` diretamente — use `Cores.ouro`.
- Two fonts from `google_fonts`: `GoogleFonts.anybody()` for headings/labels, `GoogleFonts.hankenGrotesk()` for body text.
- Visual padrão dos cards de jogo (Tabela, Palpites, Teste de API): fundo branco, sombra suave `Color(0x14000000)` blur 16 offset (0,4), raio 16, sem borda (exceto borda de estado nos cards de palpite: verde=salvo, amarela=pendente), sobre `Cores.background`; bandeiras 36px em círculo com nome centralizado; miolo (placar/inputs) com largura intrínseca e laterais em `Expanded`.
- `Jogo.dataHora` is a computed getter that parses `date`+`time` strings (including UTC offset like `"15:00 UTC-4"`) into a UTC `DateTime`. Always call `.toLocal()` before displaying times to the user.
- `Palpite.docId` is the compound key `{uid}_{jogoId}` used as the Firestore document ID.

## Documentação detalhada

Tudo abaixo está em **`resumo_bolao_copa_2026.md`** — leia a seção relevante antes de mexer no assunto correspondente:

- Estrutura de pastas com descrição de cada arquivo (`lib/`, `assets/`, `functions/`, `web/`)
- O que cada tela contém hoje (comportamento detalhado de todas as telas, incluindo as admin)
- Schema campo a campo das coleções do Firestore + regras de segurança
- Cloud Functions — tabela completa (triggers, callables, agendadas)
- Paleta de cores completa (`cores.dart`), avatares (`avatares.dart`), services e métodos
- Arquitetura de navegação (drawer, IndexedStack, classe `Sinal`) e de autenticação
- Setup do Firebase (SHA-1s, restrição de API keys, regras), status da publicação na Play Store
- Bugs corrigidos e decisões técnicas (R8/Auto Backup, fuso horário, etc.)
