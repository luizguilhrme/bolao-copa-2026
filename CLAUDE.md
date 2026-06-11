# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **REGRA OBRIGATÓRIA:** Este arquivo e `C:\bolao\resumo_bolao_copa_2026.md` são documentação complementar e DEVEM ser atualizados juntos, no mesmo commit, sempre. Se um for atualizado sem o outro, a documentação fica inconsistente.

## Project overview

**Nome do app:** Bolão - Crava aí! (Play Store: "Bolão - Crava aí! | Sem Anúncios")

Flutter app for a World Cup 2026 prediction pool (bolão). Users register predictions for match scores; an admin enters real results, and the app calculates and ranks players by points. Backend is Firebase (Auth + Firestore).

> **Nota de branding:** O **nome de exibição** do projeto Firebase foi atualizado para `bolaocravaai` e o nome público para `Bolão - Crava aí!`. O **ID do projeto** (`bolaodasoci2026`) e a URL de hosting (`bolaodasoci2026.web.app`) são permanentes e não podem ser alterados.

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

**Pattern:** screen → service → Firestore. No state management library — state is handled with `setState` and `StreamBuilder` directly.

**Six Firestore collections:**
- `usuarios` — document ID = Firebase Auth UID
- `jogos` — document ID = game integer ID (string-cast). Populated once from `assets/dados/jogos.json`. Elimination round games (73–104) have placeholder `team1`/`team2` values (`"1A"`, `"2B"`, `"3°"`, `"Vencedor 73"`, etc.) that are replaced automatically by the admin flow. Also carries the football-data.org sync fields (`apiId`, `statusApi`, `placarAoVivo1/2`) written only by Cloud Functions.
- `palpites` — document ID = `{uid}_{jogoId}`
- `grupos` — document ID = auto-ID. Stores bolão groups with a unique 6-char code.
- `config` — single document `copa2026` with group standings, special results, terceiros allocation.
- `api` — two documents (`classificacao`, `artilharia`) written exclusively by the Cloud Functions from football-data.org data; the app only reads (via `ApiDadosService`).

**Integração football-data.org:** o app NUNCA chama a API (repositório público). Fluxo: API → Cloud Function agendada `sincronizarApi` (a cada 2 min, mas só faz requisições quando há jogo na janela ativa: início −20 min até +5h sem placar final) → Firestore → app. A chave fica no secret `FOOTBALL_DATA_KEY` (`firebase functions:secrets:set FOOTBALL_DATA_KEY`). O de-para jogo↔API é gravado no campo `apiId` pela callable admin `mapearJogosApi` (cruzamento por data/hora UTC + fase + grupo; nomes de time como desempate — aliases: "Czechia"→"Czech Republic", "Bosnia-Herzegovina"→"Bosnia & Herzegovina", "United States"→"USA"). Placar parcial vai em `placarAoVivo1/2` + `statusApi` (JAMAIS em `placar1/2`, que disparariam pontuação); o placar final (status FINISHED, `score.regularTime` — regra dos 90 min) é gravado em `placar1/2` e dispara o trigger `calcularPontuacao` como a inserção manual. A função compara antes de escrever e nunca sobrescreve placar já inserido pelo admin (a tela de placares segue como override manual). A partir dos 16 avos, a função também define os confrontos: preenche `team1/team2` dos jogos com placeholder nas próximas 72h assim que a API publica os times reais — sem nunca sobrescrever time já definido (pela propagação da chave, pela tela Admin Copa ou por ajuste manual).

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

**Palpite cutoff:** palpites are locked 5 minutes before game start. Games where `team1` or `team2` is still a placeholder (`ehPlaceholder()` in `biblioteca.dart`) are hidden from the palpites screen entirely until both teams are resolved.

## Code conventions

- All identifiers, comments, and UI strings are in **Brazilian Portuguese**.
- Utility functions in `lib/utils/biblioteca.dart` are top-level (no wrapping class): `flagDe()`, `siglaDe()`, `isoDe()`, `nomePtDe()`, `formatarData()`, `formatarCriadoEm()`, `mostrarMensagem()`, `mostrarRegras()`, `calcularPontos()`, `multiplicadorFase()`, `calcularPontosComFase()`, `corPontuacao()`, `corFundoPontuacao()`, `corBordaPontuacao()`. The `Bandeira` widget is also defined there.
- Shared dialogs and SnackBar helpers live in `lib/utils/dialogos.dart`: `mostrarSnackBarSucesso()`, `mostrarSnackBarErro()`, `mostrarSnackBarInfo()`, `DialogAmbiente`, `JogadorData` (model), `BottomSheetJogadores` (player-picker bottom sheet with `cor:` parameter), and `mostrarSeletorOpcoes()`/`BottomSheetOpcoes` (single-option picker without search, used by the Por rodada/Por grupo filters). Import this file in any screen that needs colored SnackBars, the environment selector dialog, or the pickers.
- Color palette is entirely in `lib/utils/cores.dart` (`Cores` class — never instantiated). Primary green is `Cores.verdePrincipal`. Error red is `Cores.error` — never use `Color(0xFFBA1A1A)` directly. Badge colors: `Cores.pontExato/pontVencedorSaldo/pontVencedorUmTime/pontVencedor/pontZero/pontNegativo`. Pódio: `Cores.ouro`, `Cores.prata`, `Cores.bronze`. Never use `Color(0xFFB8860B)` diretamente — use `Cores.ouro`.
- Two fonts from `google_fonts`: `GoogleFonts.anybody()` for headings/labels, `GoogleFonts.hankenGrotesk()` for body text.
- Visual padrão dos cards de jogo (Tabela, Palpites, Teste de API): fundo branco, sombra suave `Color(0x14000000)` blur 16 offset (0,4), raio 16, sem borda (exceto borda de estado nos cards de palpite: verde=salvo, amarela=pendente), sobre `Cores.background`; bandeiras 36px em círculo com nome centralizado; miolo (placar/inputs) com largura intrínseca e laterais em `Expanded`.
- `Jogo.dataHora` is a computed getter that parses `date`+`time` strings (including UTC offset like `"15:00 UTC-4"`) into a UTC `DateTime`. Always call `.toLocal()` before displaying times to the user.
- `Palpite.docId` is the compound key `{uid}_{jogoId}` used as the Firestore document ID.

---

# Resumo do projeto — Bolão Copa 2026

---

## Ambiente

- Flutter SDK instalado, projeto rodando no Android Studio
- Projeto localizado em `C:\bolao\`
- Emulador Android configurado e funcionando (Nexus S API 24)
- Run Configuration apontando para `C:\bolao\lib\main.dart`
- Android (nativo) + Web/PWA — iOS suportado via PWA no Safari
- Foco em aprendizado progressivo de Flutter

---

## Estrutura de pastas atual

```
C:\bolao\
  assets/
    dados/
      jogos.json              ← 104 jogos com datas reais da Copa 2026
      jogos_teste.json        ← 104 jogos idênticos ao jogos.json (mesmas datas);
                                 únicos campos diferentes: placar1=1 e placar2=0
                                 nos 72 jogos da Fase de Grupos
      jogadores.json          ← elencos das 48 seleções da Copa 2026; estrutura:
                                 {selecoes:[{nome,nomePt,grupo,iso,jogadores:[{nome,
                                 posicao(GOL/DEF/MEI/ATA),clube}]}]}; usado em
                                 tela_palpites_especiais e tela_admin_especiais para
                                 seletores de jogador; "-" no campo clube = informação
                                 não disponível; nomes de jogador são únicos — o nome é a
                                 chave de comparação dos palpites especiais; homônimos
                                 desambiguados: "Montassar Talbi" (Tunísia, vs "Talbi" do
                                 Marrocos) e "Emiliano Martínez (Dibu)" (GOL Argentina,
                                 vs "Emiliano Martínez" MEI do Uruguai)
    avatares/                 ← imagens dos jogadores para seleção de avatar;
                                 inclui as 26 fotos oficiais FIFA da seleção brasileira da
                                 Copa 2026 (25 jogadores + Ancelotti; 512×512, recortadas dos
                                 retratos do ensaio de 04/06/2026); neymar2026/vini2026/
                                 paqueta2026 não colidem com os avatares de "Principais";
                                 Alex Sandro (#6) não tem retrato individual na galeria FIFA
    background-cards/         ← imagens de fundo dos 3 cards de ação da tela Home
                                 (br.png → PALPITES, r9.png → RANKING, 2022.png → PALPITES ESPECIAIS)
                                 cabecalho.webp → animação de fundo do cabeçalho do drawer
                                 (WebP animado q70; convertido do GIF original de 3,2 MB → 655 KB)
  functions/
    index.js                  ← Cloud Functions (Node 22, região southamerica-east1):
                                 calcularPontuacao, lembretesPalpite, recalcularTudo,
                                 membroEntrou, calcularPalpitesEspeciais,
                                 limparUsuariosOrfaos, limparDadosTeste, recalcularCopa,
                                 buscarPalpitesJogo, buscarPalpitesUsuario,
                                 sincronizarApi (agendada */2 min, football-data.org),
                                 mapearJogosApi (de-para apiId; admin); usa o secret
                                 FOOTBALL_DATA_KEY (firebase functions:secrets:set)
  lib/
    main.dart                 ← Firebase init + FCM background handler + StreamBuilder de auth
    firebase_options.dart     ← gerado automaticamente pelo FlutterFire CLI
    models/
      jogo.dart               ← model com fromJson, fromMap, toMap e getter dataHora; campo vencedor (String?, nullable);
                                 campos da API: apiId, statusApi, placarAoVivo1/2,
                                 placarDecisao1/2 (só lidos pelo app; escritos pela
                                 sincronizarApi) + getters aoVivoApi e placarDecisao
      usuario.dart            ← model com fromMap, toMap e copyWith; inclui campos de palpites especiais;
                                 copyWith cobre todos os 6 palpites especiais (campeão, artilheiro,
                                 goleiro, melhorJogador, maisGoleadora, menosVazada)
      palpite.dart            ← model com fromMap, toMap; criadoEm é DateTime? (nullable)
      grupo.dart              ← model com fromMap, toMap; criadoEm é DateTime? (nullable);
                                 campo regra: 'classico' | 'copa' (default 'classico')
      palpite_copa.dart       ← (sem model dedicado; estrutura gerenciada pelo PalpiteCopaService)
    screens/
      menu_principal.dart     ← shell com drawer lateral, AppBar, IndexedStack, NavigationBar;
                                 inicializa FCM; deep linking via notificação (onMessageOpenedApp,
                                 getInitialMessage); SnackBar com botão VER em foreground;
                                 seção ADMIN com 5 itens separados; sinais de ressincronização
                                 (classe Sinal) disparados ao selecionar aba e ao voltar de rotas
                                 do drawer — Home/Palpites/Ranking recarregam dados silenciosamente
                                 (sem perder scroll/rascunhos), corrigindo dados congelados pelo
                                 IndexedStack (ex: grupo Copa criado não exibia aba MODO COPA)
      tela_home.dart          ← hero card verde com ranking/pontuação + carrossel de jogos
                                 do dia no modelo da tela Teste de API com dados reais:
                                 chip de status (AGENDADO azul / AO VIVO vermelho /
                                 INTERVALO amarelo / ENCERRADO cinza), fase • horário,
                                 placar parcial em vermelho (placarAoVivo), placar dos
                                 90 min com decisão "(4 x 2)" embaixo e check verde em
                                 quem avançou (vencedor); fallback por horário acende o
                                 AO VIVO antes do 1º sync da API
                                 + 3 cards de ação em coluna (Palpites, Ranking,
                                 Palpites Especiais) com imagem de fundo personalizada
                                 + card ARTILHARIA (top 5 de api/artilharia; oculto até os
                                 primeiros gols; tocar abre a aba ARTILHARIA da Tabela
                                 via callback onVerArtilharia + Sinal)
      tela_login.dart         ← login e cadastro com design do Stitch; ícone de olho na senha;
                                 botão "Fazer login com o Google" (GIS oficial na web via
                                 renderButton; OutlinedButton estilizado no Android) com
                                 account linking automático
      tela_setup_perfil.dart  ← ordem: Nome → Grupos (criar/entrar opcional) → Avatar;
                                 dialogs de criar/entrar grupo inline;
                                 nome pré-preenchido com displayName do Google quando disponível
      tela_perfil.dart        ← exibe/edita nome e avatar; alterar/definir senha; excluir
                                 conta; usuário Google-only (sem provedor password) define
                                 senha e exclui conta com reautenticação via Google
      tela_notificacoes.dart  ← toggles de preferência de notificação (lembrete / ranking)
      tela_palpites.dart      ← abas MODO CLÁSSICO / MODO COPA (exibidas quando usuário tem grupos
                                 dos dois modos E Fase de Grupos ativa); sub-abas Próximos / Encerrados;
                                 auto-save com debounce de 1s nos cards de palpite (cadeado é
                                 indicador de status, não botão obrigatório); rascunhos não salvos
                                 preservados na troca de abas/modo (Clássico e Copa);
                                 MODO COPA: form de palpite de classificação (12 grupos, FAB SALVAR);
                                 detecção automática de fim da Fase de Grupos (jogos 73+ com times reais);
                                 bloqueio do Modo Copa exclusivamente por palpitesTravados=true;
                                 filtros de jogos no Clássico: chips Por data (sub-abas) /
                                 Por rodada / Por grupo (seletor via BottomSheetOpcoes);
                                 rodada/grupo exibem lista mista (cards editáveis + resultados)
      tela_palpites_especiais.dart ← tela azul com 6 palpites especiais do usuário;
                                 Campeão/MaisGoleadora/MenosVazada: seletor de time;
                                 Artilheiro/MelhorGoleiro/MelhorJogador: seletor de
                                 jogador via BottomSheetJogadores (dialogos.dart) com
                                 busca por nome + PopupMenuButton de filtro por seleção
                                 (exibe nome completo em PT); MelhorGoleiro pré-filtra
                                 posição GOL; bloqueio exclusivamente por palpitesTravados=true
      tela_ranking.dart       ← ranking filtrado por grupo com pódio e lista; chips para alternar grupos;
                                 dialog de palpites com filtro A–L + MATA-MATA, palpites especiais
                                 completos (6 campos) e suporte a Modo Copa com pontuação por posição;
                                 palpites Copa e Especiais ocultos até palpitesTravados=true;
                                 palpites carregados via Cloud Function buscarPalpitesUsuario
                                 (só retorna dados de usuários em grupo comum)
      tela_grupos.dart        ← lista grupos do usuário; criar grupo (código único) com seleção
                                 de modo CLÁSSICO/COPA; entrar com código; sair;
                                 card exibe chip de modo; dialog de detalhes com membros e avatares;
                                 ícone de lápis (só dono) edita o nome do grupo
      tela_tabela.dart        ← 3 abas superiores JOGOS / CLASSIFICAÇÃO / ARTILHARIA (sempre
                                 visíveis); JOGOS: 104 jogos com filtros Por data (sub-abas
                                 Próximos/Encerrados) / Por rodada / Por grupo; cards exibem
                                 placar parcial da API em vermelho quando ao vivo;
                                 CLASSIFICAÇÃO: usa o standings oficial de api/classificacao
                                 quando existe (critérios FIFA completos) com fallback no
                                 cálculo local dos placares; ARTILHARIA: lista completa de
                                 api/artilharia (estado vazio até os primeiros gols);
                                 RefreshIndicator; tocar em jogo
                                 encerrado abre dialog via Cloud Function buscarPalpitesJogo
                                 (exibe palpites da união dos membros de todos os grupos do usuário)
      tela_admin_placares.dart ← inserção de placares com abas Próximos/Encerrados;
                                 sem regra de 105 min; campos vazios no CORRIGIR limpam o placar
                                 (dialog de confirmação) e devolvem o jogo para Próximos;
                                 em eliminatórias com placar empatado, exibe dialog "Quem avançou?"
                                 para selecionar o vencedor (salvo no campo `vencedor` do jogo)
      tela_admin_copa.dart    ← classificação por grupo: 1º e 2º obrigatórios para todos os 12 grupos,
                                 3º limitado a 8 grupos (contador no AppBar); validação antes de salvar;
                                 seção "Terceiros — 16 Avos" com 8 dropdowns para alocar os terceiros
                                 classificados nos slots "3°" dos confrontos; ao salvar, atualiza
                                 automaticamente team1/team2 dos jogos 73–88 no Firestore;
                                 salva em config/copa2026.classificacao_real e .terceiros_classificados
      tela_admin_especiais.dart ← resultados reais: campeão (seletor de time), artilheiro
                                 (seletor de jogador), melhor goleiro (seletor — só GOL),
                                 equipe mais goleadora (seletor de time), equipe menos vazada
                                 (seletor de time), melhor jogador (seletor de jogador);
                                 botão CALCULAR chama calcularPalpitesEspeciais (irreversível)
      tela_admin_definicoes.dart ← ações: popular jogos (Teste/Produção), mapear jogos com a
                                 API (mapearJogosApi; rodar após popular), recalcular Reg.
                                 Clássica, recalcular Reg. Copa, limpar dados de teste,
                                 limpar órfãos; botão Travar/Destravar Palpites
                                 (grava palpitesTravados em config/copa2026)
      tela_admin_teste_api.dart ← simulação visual da integração football-data.org com dados
                                 fictícios no formato JSON real da API (status TIMED/IN_PLAY/
                                 PAUSED/FINISHED, prorrogação e pênaltis com check no
                                 classificado) + seção de artilharia; sem requisição/escrita
      tela_ajuda.dart         ← FAQ: pontuação Modo Clássico, multiplicadores de fase,
                                 pontuação Modo Copa, palpites especiais
    services/
      auth_service.dart       ← login Google (GIS na web / fluxo nativo no Android),
                                 vincularGoogle (account linking com conta e-mail/senha),
                                 reautenticarComGoogle (popup na web / seletor nativo no
                                 Android; usado por excluir conta e definir senha de
                                 usuário Google-only), inicializar, sair
      jogo_service.dart       ← popularJogosNoFirestore({bool teste}), buscarTodos, buscarPorData
      usuario_service.dart    ← criarPerfil, buscarPorUid, observarUsuario,
                                 atualizarNome, atualizarAvatar,
                                 salvarPalpitesEspeciais (todos os 5 palpites especiais)
      palpite_service.dart    ← salvar, buscarPorJogo, buscarTodosPorUsuario,
                                 buscarPorUsuario, buscarTodosPorJogo
      notificacoes_service.dart ← inicializar FCM, salvar token, buscar/atualizar prefs
      grupo_service.dart      ← criarGrupo({regra}), entrarComCodigo, buscarGruposDoUsuario (stream),
                                 buscarGruposDoUsuarioOnce (Future, evita emissão vazia do cache),
                                 sairDoGrupo, editarNome, buscarMembros;
                                 código único gerado com loop anti-colisão
      palpite_copa_service.dart ← buscarPorUid, salvar; coleção palpites_copa/{uid} com
                                 palpites de classificação de grupos do MODO COPA
      api_dados_service.dart  ← buscarArtilharia (api/artilharia → List<Artilheiro>),
                                 buscarClassificacao (api/classificacao → mapa letra do
                                 grupo → List<ClassificacaoApiTime>; null se doc ausente —
                                 chamador usa fallback local)
    utils/
      cores.dart              ← constantes de cores (Cores.verdePrincipal etc)
      biblioteca.dart         ← funções utilitárias top-level (flagDe, siglaDe,
                                 formatarData, mostrarMensagem, ehPlaceholder,
                                 calcularPontos, multiplicadorFase, calcularPontosComFase)
      artilharia.dart         ← model Artilheiro (com fromMap do doc api/artilharia)
                                 + widget LinhaArtilheiro (pódio ouro/prata/bronze);
                                 usado na Home (top 5) e na aba ARTILHARIA da Tabela;
                                 kArtilhariaSimulada foi removida — dados reais via
                                 ApiDadosService.buscarArtilharia()
      avatares.dart           ← listas kJogadores (Principais) e kJogadoresBrasil2026
                                 (26 fotos oficiais FIFA: 25 jogadores + Ancelotti)
                                 + widgets WidgetAvatar, CardAvatar
                                 e GradeAvataresSecionada (abas lado a lado PRINCIPAIS /
                                 BRASIL 2026, abre na aba do avatar selecionado;
                                 usada no setup e no perfil);
                                 CardAvatar é StatefulWidget com animação 3D flip para
                                 "avatares secretos" (long-press abre foto alternativa *2.jpg)
  web/
    index.html              ← meta tags PWA iOS (apple-mobile-web-app-capable etc)
    manifest.json           ← PWA manifest (nome "Bolão Copa 2026", tema #006D32)
    favicon.png             ← ícone personalizado
    icons/                  ← Icon-192.png, Icon-512.png, Icon-maskable-192.png,
                               Icon-maskable-512.png, apple-touch-icon.png
  pubspec.yaml
```

---

## Decisões de arquitetura

- Android (nativo) + Web/PWA — iOS suportado via "Adicionar à Tela de Início" no Safari
- Backend Firebase (Firestore + Auth) — configurado e funcionando
- Foco em aprendizado progressivo de Flutter
- Padrão Service como camada de abstração entre telas e Firestore (equivalente ao Repository pattern do Android)
- IDs dos documentos Firestore sempre iguais ao identificador da entidade (UID do usuário, id do jogo) — garante idempotência e busca O(1)
- Funções utilitárias compartilhadas são declaradas como funções top-level em `biblioteca.dart`, não como métodos `static` de uma classe wrapper — padrão idiomático em Dart
- Comunicação de filho para pai via callback (`void Function(int)`) — o `MenuPrincipal` passa `onNavegar` para a `TelaHome`
- Cálculo de pontuação feito na Cloud Function `calcularPontuacao` (trigger Firestore) — admin insere placar pelo app, função recalcula pontos e envia notificações de ranking
- Palpites precarregados em lote (`buscarTodosPorUsuario`) ao abrir a tela, sem query individual por card
- Notificações via FCM: `lembretesPalpite` (scheduled `*/30min`) + `calcularPontuacao` envia ranking change. Token salvo no campo `fcmToken` do documento do usuário
- Bandeiras exibidas como imagens reais via pacote `country_flags` (não emojis); mapeamento de nome → ISO em `isoDe()`
- Telas admin separadas por responsabilidade (placares, classificação copa, palpites especiais, definições) em vez de uma tela única — cada tela tem foco claro e é navegada via drawer
- Integração football-data.org server-side: `sincronizarApi` agendada a cada 2 min com "janela inteligente" — fora da janela de jogos (início −20 min até +5h sem placar final) encerra com uma única query ao Firestore, sem chamar a API; dentro dela faz no máx. 3 requisições (matches + standings + scorers, estes só quando algum jogo termina). Placar parcial em campos separados (`placarAoVivo1/2`); placar final dispara o trigger de pontuação como a inserção manual; admin segue como override (a função nunca sobrescreve placar já preenchido)
- Ressincronização das telas do IndexedStack via `Sinal` (ChangeNotifier em `biblioteca.dart`): o `MenuPrincipal` dispara o sinal da aba ao selecioná-la no NavigationBar e ao voltar de qualquer rota do drawer (`_abrirRota` com `await`); Home, Palpites e Ranking escutam e recarregam dados silenciosamente — preserva scroll e rascunhos (que uma `Key` nova destruiria)

---

## Paleta de cores (cores.dart)

```dart
// Primária (verde)
Cores.verdePrincipal      = Color(0xFF006D32)
Cores.primaryContainer    = Color(0xFF00D166)
Cores.onPrimary           = Color(0xFFFFFFFF)

// Secundária (amarelo)
Cores.secondaryContainer     = Color(0xFFFCD400)
Cores.onSecondaryContainer   = Color(0xFF6E5C00)

// Terciária (azul)
Cores.azulTerciario       = Color(0xFF004CED)

// Superfície / fundo
Cores.background              = Color(0xFFEFF1F6)  // fundo acinzentado: profundidade p/ cards brancos
Cores.verdeSuave              = Color(0xFFE6F2EA)  // filtros/segmentos não selecionados
Cores.surface                 = Color(0xFFF9F9FF)
Cores.surfaceVariant          = Color(0xFFD3E5DA)  // superfícies em verde claro (antes azuladas)
Cores.surfaceContainer        = Color(0xFFE6F2EA)
Cores.surfaceContainerHigh    = Color(0xFFDCEBE1)

// Texto
Cores.onSurface               = Color(0xFF111C2D)
Cores.onSurfaceVariant        = Color(0xFF3C4A3D)

// Bordas
Cores.outlineVariant          = Color(0xFFBBCBB9)
Cores.outline                 = Color(0xFF6C7B6C)
```

---

## Arquitetura de navegação

`MenuPrincipal` é um **shell** — só gerencia a navegação. Contém:

- `Drawer` lateral com perfil do usuário, menu e seção admin (condicional)
- `AppBar` fundo branco (`Colors.white`), ícone de menu + título dinâmico (verde) + botão de regras
- `IndexedStack` com as 4 telas como filhos (scroll preservado entre abas); `Scaffold` com `backgroundColor: Colors.transparent` sobre `Container(color: Cores.background)`
- `NavigationBar` (Material 3) com fundo `Cores.verdePrincipal`, ícones/labels brancos (70% alpha quando não selecionados), indicador `Cores.secondaryContainer`, ícone selecionado `Cores.verdePrincipal`; estilizado via `NavigationBarTheme`

```dart
// O leading usa Builder para acessar o Scaffold correto
leading: Builder(
  builder: (ctx) => IconButton(
    icon: const Icon(Icons.menu),
    onPressed: () => Scaffold.of(ctx).openDrawer(),
  ),
),
```

### Drawer lateral
- Cabeçalho com animação de fundo (`assets/background-cards/cabecalho.webp`, WebP animado, `BoxFit.cover`) e conteúdo sobreposto via `Stack`: card glassmorphism (`ClipRRect` + `BackdropFilter` blur 10px + fundo `Colors.white` 18% alpha + borda 35% alpha) envolvendo avatar, nome e pontuação Clássico via `StreamBuilder<Usuario?>`
- Seção "CONTA": Meu Perfil → `TelaPerfil`; Notificações → `TelaNotificacoes`
- Seção "GRUPOS": Meus Grupos → `TelaGrupos`
- Seção "ADMIN" (só para `isAdmin == true`), 5 itens:
  - Placares — Reg. Clássica → `TelaAdminPlacares`
  - Classificação — Reg. Copa → `TelaAdminCopa`
  - Palpites Especiais → `TelaAdminEspeciais`
  - Outras Definições → `TelaAdminDefinicoes`
  - Teste de API → `TelaAdminTesteApi`
- Seção "SUPORTE": Ajuda & FAQ → `TelaAjuda`
- Rodapé: botão Sair que chama `FirebaseAuth.instance.signOut()`

### Verificação de admin
```dart
// Lido do Firestore uma única vez no initState
final doc = await FirebaseFirestore.instance.collection('usuarios').doc(_uid).get();
if (doc.data()?['isAdmin'] == true) setState(() => _isAdmin = true);
```

---

## Arquitetura de autenticação

O `main.dart` usa um `StreamBuilder` que ouve o `authStateChanges()` do Firebase Auth:

```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (snapshot.hasData) return const MenuPrincipal(); // logado
    return const TelaLogin();                           // deslogado
  },
)
```

### Fluxo de cadastro
1. `TelaLogin` valida e-mail + chama `createUserWithEmailAndPassword`
2. `authStateChanges` dispara → `main.dart` roteia para `TelaSetupPerfil` automaticamente
3. `TelaSetupPerfil`: usuário define nome, opcionalmente cria/entra em grupo, escolhe avatar, clica "Confirmar"
4. `UsuarioService.criarPerfil` salva no Firestore → stream detecta perfil criado → `MenuPrincipal` abre
5. Botão de voltar no setup faz `signOut()` → retorna para `TelaLogin`

---

## Firebase — configuração completa

### Ferramentas instaladas
- Node.js LTS (v22) instalado via nodejs.org
- Firebase CLI instalado via `npm install -g firebase-tools` (v15.18.0)
- FlutterFire CLI instalado via `dart pub global activate flutterfire_cli`
- PATH do Windows atualizado para incluir `C:\Users\Luiz Guilherme\AppData\Local\Pub\Cache\bin`

### Projeto Firebase
- Nome de exibição: `bolaocravaai` | Nome público: `Bolão - Crava aí!`
- ID do projeto (permanente): `bolaodasoci2026`
- Região do Firestore: `southamerica-east1` (São Paulo)
- App Android registrado com package name: `com.luizdeveloper.bolao.bolao`
- App Web registrado (Firebase Console → Project settings → Apps)
- Firebase Hosting configurado — `firebase.json` aponta para `build/web` com SPA rewrite
- URL de produção: https://bolaodasoci2026.web.app
- Arquivo `firebase_options.dart` gerado automaticamente pelo `flutterfire configure`

### Configurações do Android (`build.gradle.kts`)
```kotlin
android {
    ndkVersion = "27.0.12077973"   // Firebase exige a 27
    defaultConfig {
        minSdk = 23                // firebase_auth exige mínimo 23
    }
}
```

### Pacotes adicionados ao pubspec.yaml
```yaml
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
cloud_functions: ^5.1.0
firebase_messaging: ^15.1.0
google_sign_in: ^6.2.1
country_flags: ^4.1.2
google_fonts: ^6.2.1
intl: ^0.19.0
```

### Serviços ativados no Firebase Console
- **Firestore Database** — regras de produção ativas (ver abaixo)
- **Authentication** — provedores ativos: E-mail/senha e Google Sign-In

### Regras do Firestore
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarios/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
    match /jogos/{jogoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /palpites/{palpiteId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.uid;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.uid;
      allow update: if request.auth != null && request.auth.uid == resource.data.uid;
      allow delete: if false;
    }
    match /palpites_copa/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
    match /grupos/{grupoId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid in resource.data.membros;
      allow delete: if request.auth != null && request.auth.uid == resource.data.donoUid;
    }
    match /api/{docId} {
      allow read: if request.auth != null;
      allow write: if false;  // só as Cloud Functions escrevem (Admin SDK)
    }
  }
}
```

---

## Coleções do Firestore

### `usuarios`
ID do documento = UID do Firebase Auth.

```
uid                  : String
email                : String
nome                 : String    — parte antes do @ no cadastro
pontuacaoClassica      : Number    — fase de grupos Clássico + penalidades; começa em 0
pontuacaoCopa          : Number    — fase de grupos Copa (SET por recalcularCopa); começa em 0
pontuacaoEliminatorias : Number    — mata-mata; compartilhado pelos dois modos; começa em 0
pontuacaoEspeciais     : Number    — palpites especiais; compartilhado pelos dois modos; começa em 0
placaresExatos       : Number    — desempate 1: quantidade de placares exatos acertados; começa em 0
palpitesPerdidos     : Number    — desempate 2: jogos não palpitados (cada um gera −10 pts); começa em 0
criadoEm             : Timestamp
avatar               : String?   — id do jogador selecionado no setup de perfil
isAdmin              : Boolean   — campo opcional; adicionado manualmente no Console
fcmToken             : String?   — token FCM do dispositivo; salvo pelo NotificacoesService
notifLembretes       : Boolean?  — padrão true quando ausente
notifRanking         : Boolean?  — padrão true quando ausente
palpiteCampeao          : String?   — nome em inglês do time campeão (ex: "Brazil")
palpiteChuteiradeOuro   : String?   — nome livre do artilheiro (Chuteira de Ouro)
palpiteBoladeOuro       : String?   — nome livre do melhor jogador (Bola de Ouro)
palpiteLuvadeOuro       : String?   — nome livre do melhor goleiro (Luva de Ouro)
palpiteMelhorJovem      : String?   — nome livre do melhor jogador jovem (sub-21)
```

Todos os palpites especiais são bloqueados quando `palpitesTravados=true` em `config/copa2026`
ou após o início do primeiro jogo (o que ocorrer primeiro).
Salvos via `UsuarioService.salvarPalpitesEspeciais()`.

### `jogos`
104 documentos. ID do documento = id do jogo (string "1" a "104").

```
id          : Number
round       : String   — "Fase de Grupos" | "16 avos de Final" | "Oitavas de Final" |
                         "Quartas de Final" | "Semifinal" | "Disputa de 3º Lugar" | "Final"
matchday    : String?  — "Rodada 1/2/3" (null nas fases eliminatórias)
date        : String   — "2026-06-11"
time        : String   — "13:00 UTC-6"
dataHora    : Timestamp — convertido para UTC; usado para queries e ordenação
team1       : String
team2       : String
group       : String?  — "Grupo A"..."Grupo L" (null nas fases eliminatórias)
ground      : String
placar1     : Number?  — null até o resultado final (admin ou sincronizarApi)
placar2     : Number?  — null até o resultado final (admin ou sincronizarApi)
vencedor    : String?  — preenchido em eliminatórias com empate nos 90 min (pênaltis/prorrogação)
apiId       : Number?  — id do jogo na football-data.org (de-para gravado por mapearJogosApi)
statusApi   : String?  — TIMED | IN_PLAY | PAUSED | FINISHED (escrito pela sincronizarApi)
placarAoVivo1 : Number? — placar parcial durante o jogo (removido quando FINISHED);
placarAoVivo2 : Number?   NUNCA vai em placar1/placar2, que disparariam a pontuação
placarDecisao1 : Number? — decisão quando os 90 min empataram: pênaltis se houve
placarDecisao2 : Number?   disputa, senão o placar final da prorrogação; exibido
                           pequeno sob o placar principal ("(4 x 2)")
```

**Fases eliminatórias da Copa 2026 (48 seleções, 104 jogos):**
- IDs 1–72: Fase de Grupos (6 jogos × 12 grupos = 72 jogos)
- IDs 73–88: 16 avos de Final (16 jogos)
- IDs 89–96: Oitavas de Final (8 jogos)
- IDs 97–100: Quartas de Final (4 jogos)
- IDs 101–102: Semifinal (2 jogos)
- ID 103: Disputa de 3º Lugar
- ID 104: Final

**Conversão de fuso:** `"13:00 UTC-6"` → `DateTime.utc(ano, mes, dia, 13, 0).subtract(Duration(hours: -6))` → `19:00 UTC`.

**Exibição:** `.toLocal()` antes de formatar com `DateFormat` ou manualmente.

### `palpites`
ID do documento = `"{uid}_{jogoId}"` — garante idempotência (salvar duas vezes sobrescreve).

```
uid         : String
jogoId      : Number
palpite1    : Number
palpite2    : Number
criadoEm    : Timestamp  — serverTimestamp(); atualizado a cada save
```

### `grupos`
ID do documento = auto-ID gerado pelo Firestore.

```
nome        : String
codigo      : String    — 6 chars maiúsculos/números; único; gerado com loop anti-colisão
donoUid     : String    — UID de quem criou o grupo
membros     : Array<String>  — lista de UIDs; gerenciado via arrayUnion / arrayRemove
criadoEm    : Timestamp — serverTimestamp(); nullable no cache local → model usa DateTime?
```

### `config`
ID do documento = `copa2026` (documento único).

```
— Resultados reais (admin, via tela_admin_especiais) —
campeaoReal                  : String?   — nome em inglês do campeão real
chuteiradeOuroReal           : String?   — nome do artilheiro real (Chuteira de Ouro)
boladeOuroReal               : String?   — nome do melhor jogador real (Bola de Ouro)
luvadeOuroReal               : String?   — nome do melhor goleiro real (Luva de Ouro)
melhorJovemReal              : String?   — nome do melhor jogador jovem real
palpitesEspeciaisCalculados  : Boolean   — true após executar calcularPalpitesEspeciais

— Classificação real dos grupos (admin, via tela_admin_copa) —
classificacao_real           : Map       — { "A": { "primeiro": "Brazil", "segundo": "Mexico", "terceiro": "..." }, ... }
                                           12 grupos (A–L); terceiro só em 8 grupos
terceiros_classificados      : Map       — alocação dos 8 terceiros nos slots dos jogos 73–88

— Controle de visibilidade —
palpitesTravados             : Boolean   — admin aciona via Outras Definições → Travar/Destravar Palpites;
                                           true: bloqueia edição dos palpites Copa e Especiais nas telas
                                             de palpites + exibe esses palpites no dialog do ranking;
                                           false: permite edição + oculta no dialog do ranking;
                                           Modo Clássico não é afetado; resetado para false por limparDadosTeste
```

### `api`
Dois documentos escritos exclusivamente pelas Cloud Functions (football-data.org);
o app só lê, via `ApiDadosService`.

```
api/classificacao
  grupos       : Map  — { "A": [{posicao, time, jogos, vitorias, empates, derrotas,
                          pontos, golsPro, golsContra, saldo}], ... "L": [...] }
                        ordem das listas = classificação oficial (critérios FIFA
                        completos); nomes de time já na grafia do jogos.json
  atualizadoEm : Timestamp

api/artilharia
  artilheiros  : Array — [{nome, selecao, gols, assistencias}] já ordenado pela API
                         (só jogadores com ≥1 gol; /scorers?limit=100)
  atualizadoEm : Timestamp
```

---

## Regras de pontuação

### Modo Clássico — palpite no resultado do jogo

```dart
int calcularPontos(int p1, int p2, int r1, int r2) {
  if (p1 == r1 && p2 == r2) return 100;          // placar exato
  final sP = p1 - p2, sR = r1 - r2;
  final vP = p1.compareTo(p2), vR = r1.compareTo(r2);
  if (vP != vR) return 0;
  if (vP != 0) {
    if (sP == sR) return 70;                      // vencedor + saldo de gols
    if (p1 == r1 || p2 == r2) return 60;          // vencedor + gols exatos de um time
    return 50;                                     // só o vencedor
  }
  return 50;                                       // empate certo, placar errado
}
```

Punição: −10 pts por jogo não palpitado após o `criadoEm` do usuário. Jogos anteriores ao cadastro não geram penalidade.

### Modo Copa — palpite na classificação de grupos

- Posição exata (1º, 2º ou 3º): +200 por time
- Classificou mas posição errada: +100 por time
- Time não classificou: 0
- Bônus se acertou todas as posições do grupo: +100

### Palpites Especiais (calculados uma vez após o torneio)
- Campeão do Mundo: +500
- Chuteira de Ouro (artilheiro): +300
- Bola de Ouro (melhor jogador, eleito pela FIFA): +300
- Luva de Ouro (melhor goleiro, eleito pela FIFA): +300
- Melhor Jogador Jovem (sub-21, eleito pela FIFA): +200

### Cores dos badges (baseadas em pontosBase, sem multiplicador)
- ≥100 pts → `Color(0xFF006D32)` verde escuro (placar exato)
- ≥70 pts  → `Color(0xFF1B7F3A)` verde médio (vencedor + saldo)
- ≥60 pts  → `Color(0xFF2E7D52)` verde teal (vencedor + um time)
- ≥50 pts  → `Color(0xFF4CAF50)` verde claro (só vencedor / empate)
- 0 pts    → `Color(0xFFBBCBB9)` cinza
- negativo → `Color(0xFFE53935)` vermelho (sem palpite)

---

## O que cada tela contém hoje

### `tela_login.dart` — implementada
- Card centralizado, fontes Anybody + Hanken Grotesk
- Alterna entre login e cadastro com `AnimatedSwitcher`
- Erros do Firebase Auth traduzidos para português
- Ícone de olho no campo de senha para mostrar/ocultar (`_senhaVisivel` bool + `suffixIcon`)
- Navegação por Enter: Enter no e-mail move o foco para a senha; Enter na senha submete o formulário
- Botão "Fazer login com o Google":
  - **Web/PWA:** botão oficial GIS via `renderButton()` de `google_sign_in_web/web_only.dart`
    (standard/outline/large/signinWith/rectangular), num `LayoutBuilder` → `ConstrainedBox(minHeight: 40)`
    passando `minimumWidth`. Plugin inicializado em `initState` via `AuthService().inicializar()`.
  - **Android:** `OutlinedButton` estilizado replicando o GIS (logo via `CustomPainter`).
  - ⚠️ Se o botão sumir no release web, rodar `flutter clean` antes do rebuild (registrant de plugin desatualizado).
- Account linking: se o e-mail Google já existe com senha, exibe `_DialogVincularConta` que faz login com senha e chama `linkWithCredential`

### `tela_setup_perfil.dart` — implementada
- Exibida após cadastro, antes de entrar no app
- Ordem dos campos: Nome → **Grupos (opcional)** → Escolha de avatar
- Seção Grupos: dois botões ("Criar grupo" / "Entrar com código") com dialogs inline (`_DialogCriarGrupoSetup`, `_DialogEntrarGrupoSetup`, `_DialogCodigoSetup`)
- Seleção de avatar obrigatória (grid de jogadores)
- Nome pré-preenchido com `user.displayName` (Google) quando disponível
- Salva perfil no Firestore via `UsuarioService.criarPerfil`

### `tela_home.dart` — implementada
- **Hero card verde** (oculto quando sem grupos ou pontuação zerada): ticker marquee seamless com a posição do usuário em cada grupo ("1º no CLASSICO TESTE | 2º no COPA TESTE"), usando `SingleChildScrollView` horizontal + conteúdo duplicado (jumpTo invisível). Pontuação Clássico (★) à esquerda e Copa (🏆) à direita. Card aparece somente após algum resultado ser registrado (pontuação > 0)
- Título da aba Home: `'CRAVA AÍ!'` (antes `'COPA 2026'`, alterado em `menu_principal.dart`)
- Seção "JOGOS DE HOJE": label compacto + carrossel horizontal com `_CardJogo` (AO VIVO / ENCERRADO). Estado vazio exibido como linha inline (ícone + texto). Sem botão "VER TODOS"
- 3 cards de ação em coluna vertical, mesma largura (full-width menos 32dp): PALPITES, RANKING, PALPITES ESPECIAIS. Cada card usa `_CardAcao` com imagem de fundo (`assets/background-cards/` via `DecorationImage` + `BoxFit.cover`), texto branco em `GoogleFonts.anybody` sem emoji. Navega para índice 1, 2 e `TelaPalpitesEspeciais` respectivamente.
- Card **ARTILHARIA** (top 5 de `kArtilhariaSimulada`, pódio ouro/prata/bronze) abaixo dos cards de ação; tocar navega para a tela Tabela já na aba ARTILHARIA (callback `onVerArtilharia` + `Sinal _sinalAbrirArtilharia` no `MenuPrincipal`)
- Callbacks `onNavegar` e `onVerArtilharia` recebidos do `MenuPrincipal`

### `tela_palpites_especiais.dart` — implementada
- Tela completa com AppBar azul (`Cores.azulTerciario`)
- Banner de bloqueio quando a Copa já começou
- AppBar dourada (`Cores.ouro`)
- 5 palpites com estrutura: **Campeão do Mundo** (seletor de time, fora do card FIFA) + **card dourado "PREMIAÇÕES OFICIAIS FIFA"** (`Cores.ouro` 8% alpha + borda 25% alpha) envolvendo os 4 prêmios: **Chuteira de Ouro**, **Bola de Ouro**, **Luva de Ouro** (pré-filtrada `posicao == 'GOL'`), **Melhor Jogador Jovem**
- Cada prêmio FIFA tem ícone "?" na margem direita que abre um `AlertDialog` explicando o prêmio
- Seletor de time: `_BottomSheetTimes` com `DraggableScrollableSheet` + busca
- Seletores de jogador: `BottomSheetJogadores` (de `dialogos.dart`, `cor: Cores.ouro`) com busca por nome + filtro por seleção
- Jogadores carregados de `assets/dados/jogadores.json` via `rootBundle.loadString()` em `_inicializar()`, em paralelo com Firestore
- Apenas campeão obrigatório; demais opcionais
- Botão "SALVAR PALPITES" dourado fixo no rodapé (`Cores.ouro`)
- Salva via `UsuarioService.salvarPalpitesEspeciais()`

### `tela_tabela.dart` — implementada
- 3 abas superiores **JOGOS / CLASSIFICAÇÃO / ARTILHARIA** (faixa verde com abas brancas, sempre visíveis para todos os usuários; `sinalAbrirArtilharia` permite a Home abrir direto a ARTILHARIA)
- JOGOS: chips de filtro **Por data / Por rodada / Por grupo** — Por data usa sub-abas Próximos/Encerrados (card segmentado verde-suave com seleção branca e contadores); Por rodada/Por grupo usam campo seletor que abre `BottomSheetOpcoes`
- Cards de jogo no estilo novo (brancos, sombra suave, raio 16, sem borda); placar em texto puro ("— x —" antes de encerrar, sem indicador de ao vivo); data·local centralizados no topo do card, sem chips
- CLASSIFICAÇÃO: 12 tabelas de grupo calculadas em tempo real dos placares já inseridos (critérios FIFA: pontos > saldo > gols pró), colunas J/SG/PTS, destaque verde no 1º/2º; seletor "Todos os grupos" / Grupo A–L
- ARTILHARIA: lista completa de `kArtilhariaSimulada` (placeholder do endpoint /scorers da API)
- `CustomScrollView` com slivers agrupados por seção; **RefreshIndicator** (pull-to-refresh)
- Tocar em jogo encerrado abre dialog de palpites via Cloud Function `buscarPalpitesJogo`: valida jogo encerrado, coleta membros de todos os grupos do solicitante (união), retorna palpites filtrados com nome/avatar/pontos; ordenados por pontuação

### `tela_palpites.dart` — implementada
- Abas superiores **MODO CLÁSSICO** / **MODO COPA** em verde (só visíveis quando usuário tem grupos dos dois modos E Fase de Grupos ativa)
- Sub-abas **Próximos** / **Encerrados** dentro de cada modo (card segmentado verde-suave com seleção branca e contadores)
- Filtros de jogos no MODO CLÁSSICO: chips **Por data | Por rodada | Por grupo** — Por data mantém as sub-abas; Por rodada/Por grupo abrem seletor (`BottomSheetOpcoes`) e exibem lista mista (cards de palpite editáveis + cards de resultado) agrupada por data
- MODO CLÁSSICO: exibe jogos da Fase de Grupos (id 1–72) com palpite de placar
- Cards no estilo novo: brancos com sombra suave sobre `Cores.background`; a borda do card sinaliza o estado (verde = salvo, amarela = pendente, sem borda = vazio); as caixas de placar têm visual neutro sempre (não mudam de cor ao salvar)
- Auto-save com debounce: palpite completo é salvo automaticamente 1s após o usuário parar de digitar (ou na hora via Enter/tap no cadeado). Cadeado é indicador de status: fechado verde = salvo, aberto amarelo = digitado mas não salvo, aberto cinza = vazio. Campos sempre editáveis até o cutoff de 5 min; SnackBar verde confirma cada save
- Rascunhos não salvos preservados na troca de sub-aba/modo: `Map<int, ({String p1, String p2})>` no state do pai (Clássico) e referência de `_local` registrada no pai via `onRascunho` (Copa); `dispose()` do card dispara save fire-and-forget se houver palpite completo pendente
- MODO COPA: formulário de palpite de classificação dos 12 grupos (dropdowns 1º/2º/3º por grupo); FAB quadrado "SALVAR" no canto inferior direito; bloqueado após início do 1º jogo
- Detecção automática de fim da Fase de Grupos: quando jogos 73+ têm times reais, abas de modo somem e todos os jogos restantes aparecem em único Próximos/Encerrados
- `Future.wait` carrega jogos + palpites + perfil + grupos em paralelo; palpites Copa carregados separadamente para não bloquear o resto
- `Timer.periodic(30s)` reclassifica jogos automaticamente
- Penalidade −10 pts por ausência de palpite; card vermelho
- Navegação por Enter entre campos
- `buscarGruposDoUsuarioOnce()` (query direta ao servidor) evita bug de emissão vazia do cache do Firestore
- Card de resultado exibe "Avançou: [time em PT]" quando `jogo.vencedor != null` (eliminatórias decididas nos pênaltis/prorrogação)
- Banner verde no topo quando `palpitesTravados == true` informando que Palpites Especiais e Modo Copa estão visíveis para todos

### `tela_ranking.dart` — implementada
- Ranking filtrado por grupo (sem ranking global); sem cabeçalho de título — a tela começa direto no seletor de grupos
- Pódio top 3 + lista 4º em diante; 1º lugar usa `Cores.ouro` (corBorda e corBase), 2º `Cores.prata`, 3º `Cores.bronze`
- Dialog com histórico de palpites do usuário via Cloud Function `buscarPalpitesUsuario`: verifica grupo em comum entre solicitante e alvo, retorna palpites clássicos + Copa; suporte a filtro A–L + MATA-MATA, palpites especiais completos (6 campos) e Modo Copa com pontuação por posição; palpites Copa e Especiais ocultos até palpitesTravados=true
- Usa `calcularPontosComFase` com multiplicador de fase correto
- Desempate 3 (campeão) e desempate 4 (artilheiro) ambos usam comparação case-insensitive + trim()

### `tela_grupos.dart` — implementada
- `StreamBuilder` reativo em grupos do usuário
- Criar grupo com seleção de modo CLÁSSICO/COPA; entrar com código; sair; editar nome (só dono)
- Card exibe chip colorido do modo (verde=CLÁSSICO, azul=COPA)
- Dialog de detalhes com membros e avatares

### `tela_admin_placares.dart` — implementada
- Duas abas: **Próximos** (sem placar) / **Encerrados** (com placar)
- Sem regra de 105 minutos — exibe todos os 104 jogos
- CORRIGIR PLACAR com campos vazios: dialog de confirmação → salva `null` → jogo retorna para Próximos
- Cabeçalho mostra data + horário do jogo

### `tela_admin_copa.dart` — implementada
- 12 cards de grupo com dropdowns de 1º, 2º e 3º colocado
- 3º colocado limitado a 8 grupos (dos 12); quando 8 preenchidos, dropdown dos demais fica desabilitado com hint "Limite de 8 atingido"
- Contador `3º: X/8` no AppBar
- Validação antes de salvar: exige todos os 1ºs, todos os 2ºs e exatamente 8 3ºs
- Salva em `config/copa2026.classificacao_real`

### `tela_admin_especiais.dart` — implementada
- 5 seções: Campeão do Mundo (seletor de time), Chuteira de Ouro (jogador), Bola de Ouro (jogador), Luva de Ouro (jogador — só GOL), Melhor Jogador Jovem (jogador)
- Seletores de jogador usam `BottomSheetJogadores` (de `dialogos.dart`, `cor: Cores.verdePrincipal`); `_DialogSeletorTime` para seleção de time (dialog interno)
- Botão SALVAR grava em `config/copa2026` os campos: `campeaoReal`, `chuteiradeOuroReal`, `boladeOuroReal`, `luvadeOuroReal`, `melhorJovemReal`
- Botão CALCULAR chama `calcularPalpitesEspeciais` (irreversível; desabilitado após execução)

### `tela_admin_definicoes.dart` — implementada
- Popular Jogos: dialog Teste/Produção → `JogoService.popularJogosNoFirestore`
- Recalcular Reg. Clássica: chama Cloud Function `recalcularTudo`
- Recalcular Reg. Copa: chama Cloud Function `recalcularCopa`; executar após inserir todos os placares da fase de grupos
- Limpar Órfãos: chama Cloud Function `limparUsuariosOrfaos`

### `tela_admin_teste_api.dart` — implementada
- Simulação visual da futura integração com a football-data.org — **nenhuma requisição é feita e nada é gravado no Firestore**
- Dados fictícios escritos no formato JSON exato da API v4, consumidos por classes de parse (`_JogoApi.fromJson`) que serão a base da integração real
- Carrossel "JOGOS DE HOJE" com um card por status: TIMED (chip azul AGENDADO `#1A7AE8`), IN_PLAY (chip vermelho AO VIVO, placar vermelho), PAUSED (chip amarelo INTERVALO), FINISHED normal e FINISHED na prorrogação/pênaltis — placar principal = 90 min (`regularTime`), placar pequeno "(4 x 2)" embaixo e check verde na bandeira de quem avançou
- Seção de artilharia com top 5 + dialog da lista completa

### `tela_perfil.dart` — implementada
- Exibe avatar com botão de troca; edição de nome; alterar senha; excluir conta
- Card de pontuação verde exibe Clássico (★ amarelo) à esquerda e Copa (🏆) à direita, seguindo o mesmo padrão visual do hero card da `tela_home.dart`
- Detecção de provedor via `user.providerData` (getter `_temSenha`): usuário Google-only (sem provedor `password`) vê **"Definir senha"** no lugar de "Alterar senha" — dialog explica que não há senha criada e chama `updatePassword` direto (se `requires-recent-login`, reautentica via `AuthService.reautenticarComGoogle()` e tenta de novo); após criar, `user.reload()` e o item vira "Alterar senha"
- Excluir conta para usuário Google-only: dialog sem campo de senha avisa que a exclusão é imediata e que pode ser exigida reautenticação com a conta Google; confirma via `reautenticarComGoogle()` (cancelar o seletor aborta sem excluir; conta Google diferente → erro `user-mismatch` traduzido)

### `tela_notificacoes.dart` — implementada
- Toggles: lembrete de palpite / mudança no ranking

### `tela_ajuda.dart` — implementada
- FAQ com `ExpansionTile` e badges de pontuação: seção MODO CLÁSSICO (tabela de pontos + card de multiplicadores de fase), seção MODO COPA (regras de classificação), seção PALPITES ESPECIAIS

---

## avatares.dart — widgets e dados compartilhados

```dart
const kJogadores = [
  Jogador('messi', 'Messi', 'Argentina'),
  Jogador('cr7', 'Cristiano Ronaldo', 'Portugal'),
  // ... 10 mais
];

// 26 fotos oficiais FIFA da seleção brasileira da Copa 2026 (25 jogadores
// + Ancelotti no final); Neymar/Vini Jr./Paquetá usam ids com sufixo 2026
// (neymar2026, vini2026, paqueta2026) para não colidir com os avatares
// deles em PRINCIPAIS
const kJogadoresBrasil2026 = [
  Jogador('alisson', 'Alisson', 'Brazil'),
  // ... 25 mais
];

WidgetAvatar(avatarId: usuario.avatar, nome: usuario.nome, tamanho: 64)
// interface nova (StatefulWidget com flip):
CardAvatar(jogador: jogador, avatarSelecionadoId: _avatarSelecionado, onTap: (id) { ... })
// Long-press revela foto alternativa (assets/avatares/{id}2.jpg) com animação 3D flip

// Grade com abas lado a lado PRINCIPAIS / BRASIL 2026 (alterna a grade
// exibida; abre na aba do avatar selecionado) — usada em tela_setup_perfil
// e no bottom sheet de troca de avatar da tela_perfil;
// não rola sozinha (colocar dentro de um scroll do chamador)
GradeAvataresSecionada(avatarSelecionadoId: _avatarSelecionado, onTap: (id) { ... })
```

---

## UsuarioService — métodos

```dart
criarPerfil(Usuario)
buscarPorUid(String uid)
observarUsuario(String uid)               // Stream reativo
atualizarNome(String uid, String nome)
atualizarAvatar(String uid, String avatarId)
salvarPalpitesEspeciais({uid, campeao,                    // todos os 5 palpites especiais
  chuteiradeOuro?, boladeOuro?, luvadeOuro?, melhorJovem?})
```

## PalpiteService — métodos

```dart
salvar(Palpite)
buscarPorJogo(String uid, int jogoId)
buscarTodosPorUsuario(String uid)
buscarPorUsuario(String uid)              // requer índice composto no Firestore
buscarTodosPorJogo(int jogoId)
```

---

## Bugs corrigidos e decisões técnicas relevantes

### Bug de fuso horário nos timestamps
O getter `dataHora` no `Jogo` usava `DateTime(...)` (local) antes de subtrair o offset UTC, causando dupla conversão. Corrigido com `DateTime.utc(...)`.

### Bug de exibição de horário
`formatarData()` formatava sem converter para local. Corrigido adicionando `final local = data.toLocal()`.

### setState com Future
`onSalvo: () => setState(() => _futureJogos = _carregarElegiveis())` retornava `Future` para o `setState`. Corrigido com chaves: `setState(() { _futureJogos = ...; })`.

### not-found ao atualizar placar
Corrigido com `.where('id', isEqualTo: jogoId).limit(1).get()` + `.docs.first.reference`.

### criadoEm null no cache local
`FieldValue.serverTimestamp()` chega como `null` antes do servidor responder → `criadoEm` nullable em `Palpite` e `Grupo`.

### Flash de MenuPrincipal durante cadastro
`authStateChanges` disparava antes do perfil Firestore existir. Corrigido verificando existência do perfil no roteamento.

### Nomes de fases da Copa 2026 corrigidos
A Copa 2026 tem 48 seleções e 7 fases eliminatórias. `jogos.json` e `jogos_teste.json` corrigidos:
- IDs 73–88: `"16 avos de Final"` (16 jogos — fase nova introduzida em 2026)
- IDs 89–96: `"Oitavas de Final"`
- IDs 97–100: `"Quartas de Final"`
- IDs 101–102: `"Semifinal"`
- ID 103: `"Disputa de 3º Lugar"`
- ID 104: `"Final"`

### Logout a cada reabertura do app Android (builds da Play Store)
Duas causas encadeadas:
1. **R8 full mode** (padrão desde o AGP 8.0) + `isMinifyEnabled = true` quebrava a persistência da sessão do Firebase Auth (`JSONArray[0] not a string` — [firebase-android-sdk#6375](https://github.com/firebase/firebase-android-sdk/issues/6375)): `authStateChanges()` emitia `null` e o usuário caía na tela de login em toda reabertura. Corrigido com `android.enableR8.fullMode=false` em `android/gradle.properties` (mantém minificação e shrink, só desativa otimizações agressivas de reflexão).
2. **Auto Backup do Android**: o Google fez backup dos dados do app na era do bug; toda instalação via Play Store fazia "restore at install" desse snapshot com estado de auth corrompido, que impedia a gravação de novas sessões **mesmo com o binário corrigido** (instalação via cabo não dispara restore — por isso o APK local funcionava e a versão da loja não). Diagnóstico via `adb logcat` (FirebaseAuth inicializava sem usuário e sem erro) + `dumpsys backup` (eventos "Full restore" a cada install). Corrigido com `android:allowBackup="false"` no AndroidManifest; "Limpar dados" do app saneia aparelhos já afetados.

---

## Conceitos Flutter aprendidos

- `StatelessWidget` vs `StatefulWidget`
- `setState()`, `build()`, `initState()`, `dispose()`
- `Scaffold`, `AppBar`, `Drawer`, `MaterialApp`
- `factory fromJson` / `fromMap` / `toMap` para serialização
- `Material` + `InkWell` para áreas clicáveis com ripple
- `Stack` + `Positioned` para sobreposição
- `NavigationBar` (Material 3) com `selectedIndex`
- `IndexedStack` para preservar estado entre abas
- `AnimatedSwitcher` + `ValueKey` para animação de troca de widget
- `AnimatedContainer` para animar mudanças de propriedades
- `CustomScrollView` + Slivers (`SliverToBoxAdapter`, `SliverPadding`, `SliverList`)
- `AnimationController` + `SingleTickerProviderStateMixin` para animações imperativas
- `AnimatedBuilder` para reconstruir só o trecho animado
- `StreamBuilder` — authStateChanges, ranking em tempo real, dados do usuário no drawer
- `FutureBuilder` — carregamento assíncrono com estados de loading/erro/dado
- `Future.wait` — executa múltiplas Futures em paralelo
- `Timer.periodic` — reclassificação automática de jogos por horário
- `WriteBatch` do Firestore — operações atômicas em lote
- `FieldValue.serverTimestamp()` e `FieldValue.increment()`
- `Timestamp.fromDate()` / `.toDate()` — conversão DateTime ↔ Timestamp
- `DateTime.utc(...)` vs `DateTime(...)` — importância do fuso na construção
- `.toLocal()` antes de exibir horários
- `DateFormat` do pacote `intl` para formatar datas
- `rootBundle.loadString()` para ler assets em tempo de execução
- Callback `void Function(int)` como padrão de comunicação filho → pai
- `widget.X` dentro de um `State` para acessar propriedades do `StatefulWidget`
- Funções top-level em Dart como alternativa idiomática a métodos `static`
- Arrow function `=>` vs bloco `{}` — diferença de tipo de retorno
- `Builder` widget para acessar o `Scaffold` correto dentro do `AppBar`
- `addPostFrameCallback` para executar código após o frame atual terminar
- `.clamp(min, max)` para limitar valores numéricos
- `showModalBottomSheet` + `DraggableScrollableSheet` para sheets scrolláveis com busca
- `GridView.builder` com `SliverGridDelegateWithFixedCrossAxisCount`
- `Image.asset` com `errorBuilder` para fallback quando imagem não existe
- `ExpansionTile` para listas expansíveis (FAQ)
- `RefreshIndicator` — pull-to-refresh envolvendo `CustomScrollView` ou `ListView`; estado vazio também precisa ser envolvido com `ListView` filho para o gesto funcionar
- `TabController` + `TabBar` + `TabBarView` — abas com `SingleTickerProviderStateMixin`; `TabBar` no `bottom` do `AppBar`
- `obscureText` controlado por `bool` de estado + `suffixIcon` com `IconButton` — padrão para campo de senha com olho
- `@pragma('vm:entry-point')` — necessário para funções top-level chamadas pelo runtime nativo
- `FirebaseMessaging.onBackgroundMessage` — handler de mensagens com app fechado; deve ser top-level
- `FirebaseMessaging.onMessage` — stream de mensagens em foreground
- `EmailAuthProvider.credential` + `reauthenticateWithCredential` — reautenticação para operações sensíveis
- `showDialog<T>` retornando valor via `Navigator.of(ctx).pop(valor)`
- `FocusNode` + `FocusScope.of(context).requestFocus()` — navegação programática entre campos
- `TextInputAction.next` / `.done` + `onSubmitted`
- `CountryFlag` via `country_flags 4.x` — `ImageTheme(width, height)`; suporta `GB-ENG`, `GB-SCT`, `GB-WLS`
- `Color.withValues(alpha: x)` — substituto de `withOpacity` a partir do Flutter 3.27
- `FieldValue.arrayUnion` / `arrayRemove` — atômico e idempotente
- `Exception('ja_membro')` + `e.toString().contains('ja_membro')` — distinguir casos de erro sem classes customizadas
- `kIsWeb` — guard para código não suportado na web

---

## Cloud Functions — visão geral

Deployadas na região `southamerica-east1`. Arquivo: `functions/index.js` (Node 22).

| Função | Tipo | O que faz |
|---|---|---|
| `calcularPontuacao` | Firestore trigger (`jogos/{jogoId}`) | Jogos 1–72 → incrementa `pontuacaoClassica`; jogos 73–104 → incrementa `pontuacaoEliminatorias`; aplica −10 para ausências; envia FCM de ranking; propaga vencedor/perdedor para o próximo jogo |
| `lembretesPalpite` | Schedule (`*/30 * * * *`) | Notifica usuários sem palpite em jogos que começam em ~30 min |
| `recalcularTudo` | HTTPS Callable (admin only) | Recalcula `pontuacaoClassica` (jogos 1–72) e `pontuacaoEliminatorias` (jogos 73–104) do zero. Não toca em `pontuacaoEspeciais` nem `pontuacaoCopa`. |
| `membroEntrou` | Firestore trigger (`grupos/{grupoId}`) | Detecta novo membro e envia FCM para o dono do grupo |
| `calcularPalpitesEspeciais` | HTTPS Callable (admin only) | Aplica pontos dos 6 especiais em `pontuacaoEspeciais`; marca `palpitesEspeciaisCalculados: true`. Botão CALCULAR sempre salva resultados antes de chamar a função. |
| `limparUsuariosOrfaos` | HTTPS Callable (admin only) | Remove docs `usuarios` sem conta Auth + palpites órfãos; tira UIDs órfãos dos arrays `membros` dos grupos (deleta grupos que ficarem vazios; transfere a posse se o dono era órfão) |
| `limparDadosTeste` | HTTPS Callable (admin only) | Reseta placares, times de eliminatórias, classificação, resultados especiais, `pontuacaoClassica`, `pontuacaoCopa`, `pontuacaoEliminatorias`, `pontuacaoEspeciais`, flags e os campos da API (`statusApi`, `placarAoVivo1/2`, `placarDecisao1/2` — `apiId` é preservado). Palpites preservados. |
| `recalcularCopa` | HTTPS Callable (admin only) | Calcula pontos da fase de grupos Copa (SET em `pontuacaoCopa`); marca `copaGruposCalculado: true`. Executar após inserir todos os placares da fase de grupos. |
| `buscarPalpitesJogo` | HTTPS Callable | Retorna palpites de um jogo encerrado filtrados pelos membros dos grupos do solicitante (união de todos os grupos). Usado pelo dialog da `tela_tabela`. |
| `buscarPalpitesUsuario` | HTTPS Callable | Retorna palpites clássicos + Copa de um usuário, validando que o solicitante compartilha pelo menos um grupo com o alvo. Usado pelo dialog do `tela_ranking`. |
| `sincronizarApi` | Schedule (`*/2 * * * *`, secret FOOTBALL_DATA_KEY) | Janela inteligente: só chama a football-data.org quando há jogo ativo (início −20 min a +5h, sem placar final) ou eliminatória com placeholder nas próximas 72h. Grava `statusApi` + `placarAoVivo1/2` durante o jogo; no FINISHED grava `placar1/2` (`score.regularTime` — regra dos 90 min) + `vencedor` (`score.winner` em empate nos 90) + `placarDecisao1/2` (pênaltis ou placar final da prorrogação), disparando o trigger `calcularPontuacao`. Define os confrontos das eliminatórias preenchendo `team1/team2` onde ainda há placeholder (nunca sobrescreve time definido). Compara antes de escrever; não sobrescreve placar inserido pelo admin. Quando algum jogo termina, atualiza `api/classificacao` e `api/artilharia`. Mapeia `apiId` pendentes quando os times ficam definidos. |
| `mapearJogosApi` | HTTPS Callable (admin only, secret FOOTBALL_DATA_KEY) | De-para permanente jogo↔API: grava `apiId` em cada doc de `jogos` cruzando data/hora UTC + fase + grupo (nomes de time como desempate, com aliases para grafias divergentes). Retorna `{mapeados, pendentes}`. Também grava a primeira foto de `api/classificacao` e `api/artilharia`. Rodar uma vez — e novamente após Popular Jogos. |

**Deep linking via notificação:** `data: { tela: 'palpites' }`, `data: { tela: 'ranking' }`, `data: { tela: 'grupos' }`.

---

## Segurança das API Keys (Google Cloud Console)

O repositório é **público** no GitHub. Os arquivos `google-services.json` e `firebase_options.dart` foram removidos do tracking git e adicionados ao `.gitignore`. As API keys são restritas no Google Cloud Console → APIs & Services → Credentials:

- **Android key:** restrita por package name `com.luizdeveloper.bolao.bolao` + três SHA-1 cadastrados:
  - `85:A9:45:98:52:84:56:96:87:11:DD:A2:30:1F:55:35:5B:77:4F:68` — upload keystore (release local / AAB)
  - `0E:B5:82:48:A9:AE:FE:4B:BA:05:C1:95:9F:91:AE:11:27:DD:EC:68` — debug keystore (emulador/IDE)
  - `2B:81:F1:6C:60:F5:CD:6B:19:E7:2A:3B:63:F5:18:2B:CB:CD:3A:D9` — Google Play App Signing (APK distribuído pela loja)
- **Browser key:** restrita por HTTP referrer `bolaodasoci2026.web.app/*` e `bolaodasoci2026.firebaseapp.com/*`
- **Keystore e senhas** (`key.properties`, `upload-keystore.jks`) nunca foram commitados; protegidos pelo `.gitignore`

> **Atenção Google Play App Signing:** o Google re-assina o APK com a chave dele antes de distribuir. O SHA-1 do APK instalado via Play Store é diferente do upload keystore. Os três SHA-1 acima devem estar cadastrados **no Firebase Console** (Configurações do projeto → Android app → Impressões digitais do certificado SHA) — o Firebase cria automaticamente o OAuth client no Google Cloud. Sem o SHA-1 do Play App Signing no Firebase, o Google Sign-In falha em builds da Play Store mesmo funcionando no emulador. Após adicionar um novo SHA-1, baixar o `google-services.json` atualizado do Firebase e substituir em `android/app/`.

Para novo ambiente de desenvolvimento: rodar `flutterfire configure` para regenerar `firebase_options.dart` e baixar `google-services.json` do Firebase Console.

---

## Segurança do Firestore

**`usuarios`**
- `read`: qualquer autenticado
- `create`: só o próprio usuário; campos restritos; `isAdmin`/`pontuacao` protegidos
- `update`: só campos de perfil e palpites especiais; `pontuacao`/`isAdmin` protegidos
- `delete`: só o próprio usuário

**`jogos`** — `read`: autenticado; `write`: autenticado (admin na prática)

**`palpites`** — `read`: só o próprio dono (`request.auth.uid == resource.data.uid`); leitura de palpites alheios feita exclusivamente via Cloud Functions (`buscarPalpitesJogo`, `buscarPalpitesUsuario`) que rodam com Admin SDK; `create`/`update`: dono + jogo não iniciado (cutoff no backend); `delete`: bloqueado

**`config`** — `read`: autenticado; `write`: só admin

**`palpites_copa`** — `read`: só o próprio usuário; leitura por terceiros via Cloud Function `buscarPalpitesUsuario`; `write`: só o próprio usuário (`uid == auth.uid`)

**`grupos`** — `read/create`: autenticado; `update`: membro; `delete`: dono

**`api`** — `read`: autenticado; `write`: bloqueado (só Cloud Functions via Admin SDK)

---

## Google Play — status de publicação

- **Internal Testing** — ✓ v1.0.0+2 publicada
- **Closed Testing (Alpha)** — ✓ v1.0.0+10 em build (2026-06-03); corrige Google Sign-In Android e PERMISSION_DENIED no cadastro
- **Política de privacidade** — ✓ `https://bolaodasoci2026.web.app/privacy`
- **Exclusão de conta** — ✓ `https://bolaodasoci2026.web.app/delete`
- **Segurança dos dados, classificação, público-alvo, anúncios** — ✓ todos enviados
- **Usuário de revisão** — `teste@teste.com` (isAdmin: true no Firestore)

## Integração football-data.org — implementada

- **Fluxo:** API → `sincronizarApi` (agendada `*/2 min`, southamerica-east1) → Firestore → app (streams/futures existentes). O app nunca chama a API (repositório público).
- **Chave:** secret das Functions — `firebase functions:secrets:set FOOTBALL_DATA_KEY` (obrigatório antes do deploy; o deploy falha se o secret não existir).
- **Setup (uma vez):** 1) criar o secret; 2) `firebase deploy --only functions,firestore:rules`; 3) no app, ADMIN → Outras Definições → **Mapear Jogos com a API** (grava `apiId` nos 104 jogos e a primeira foto de classificação/artilharia). Repetir o passo 3 sempre que rodar Popular Jogos (que recria os docs e perde o `apiId`).
- **Janela inteligente:** fora da janela de jogos a função encerra com 1 query ao Firestore e zero requisições; dentro dela, no máximo 3 por execução (limite do free tier: 10/min).
- **Confrontos das eliminatórias:** definidos automaticamente pela API — jogos com placeholder nas próximas 72h têm `team1/team2` preenchidos assim que a API publica os times (cobre o intervalo entre o fim da fase de grupos e os 16 avos, sem jogo na janela ativa). A tela Admin Copa segue necessária para a classificação real do Modo Copa (`recalcularCopa`) e vale como ajuste manual (a API nunca sobrescreve time já definido).
- **Endpoints usados:** `/competitions/WC/matches?dateFrom&dateTo`, `/competitions/WC/standings`, `/competitions/WC/scorers?limit=100`.
- **Free tier:** placares com delay de alguns minutos — irrelevante para o fluxo (aviso exibido na Home).
- A tela ADMIN → Teste de API continua como simulação visual (formato JSON real da API), sem requisições.

## Próximos passos

1. Publicar nova versão na Play Store quando o conjunto de features estiver estável.
