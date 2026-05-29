# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **REGRA OBRIGATÓRIA:** Este arquivo e `C:\bolao\resumo_bolao_copa_2026.md` são documentação complementar e DEVEM ser atualizados juntos, no mesmo commit, sempre. Se um for atualizado sem o outro, a documentação fica inconsistente.

## Project overview

Flutter app for a World Cup 2026 prediction pool (bolão). Users register predictions for match scores; an admin enters real results, and the app calculates and ranks players by points. Backend is Firebase (Auth + Firestore).

## Common commands

```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter analyze          # static analysis / linting
flutter test             # run all tests
flutter test test/foo_test.dart  # run a single test file
flutter build apk        # build Android APK
```

To populate Firestore with the 104 games, open the drawer → ADMIN → Outras Definições → Popular Jogos. A dialog will ask whether to use production (`jogos.json`) or test data (`jogos_teste.json`). The test dataset has dates shifted −25 days and results pre-filled for past games.

## Architecture

**Pattern:** screen → service → Firestore. No state management library — state is handled with `setState` and `StreamBuilder` directly.

**Five Firestore collections:**
- `usuarios` — document ID = Firebase Auth UID
- `jogos` — document ID = game integer ID (string-cast). Populated once from `assets/dados/jogos.json`. Elimination round games (73–104) have placeholder `team1`/`team2` values (`"1A"`, `"2B"`, `"3°"`, `"Vencedor 73"`, etc.) that are replaced automatically by the admin flow.
- `palpites` — document ID = `{uid}_{jogoId}`
- `grupos` — document ID = auto-ID. Stores bolão groups with a unique 6-char code.
- `config` — single document `copa2026` with group standings, special results, terceiros allocation.

**Auth routing:** `main.dart` wraps the app in a `StreamBuilder<User?>` on `FirebaseAuth.instance.authStateChanges()`. Logged-in users go to `MenuPrincipal`; logged-out users go to `TelaLogin`.

**Admin access:** Gated by `isAdmin: true` in the user's Firestore document. Checked once at session start in `MenuPrincipal._verificarAdmin()`. The drawer shows 4 admin items: Placares, Classificação Copa, Palpites Especiais, Outras Definições. There is a dedicated test admin account (`teste@teste.com`) with `isAdmin: true` in Firestore, used for Google Play Console review.

**Scoring (implemented in `tela_palpites.dart` and Cloud Function `calcularPontuacao`/`recalcularTudo`):**
- 10 pts — exact score
- 7 pts — correct winner + correct goal difference
- 5 pts — correct winner only
- 4 pts — correct draw (wrong score)
- 0 pts — none of the above
- −1 pt — forgot to palpite (only applies to games after the user's `criadoEm`)

**Palpite cutoff:** palpites are locked 5 minutes before game start. Games where `team1` or `team2` is still a placeholder (`ehPlaceholder()` in `biblioteca.dart`) are hidden from the palpites screen entirely until both teams are resolved.

## Code conventions

- All identifiers, comments, and UI strings are in **Brazilian Portuguese**.
- Utility functions in `lib/utils/biblioteca.dart` are top-level (no wrapping class): `flagDe()`, `siglaDe()`, `isoDe()`, `nomePtDe()`, `formatarData()`, `mostrarMensagem()`. The `Bandeira` widget is also defined there — it renders a real flag image via `country_flags` package using `isoDe()` to map team names to ISO 3166-1 alpha-2 codes. For circular containers, the parent must set `clipBehavior: Clip.antiAlias`.
- Color palette is entirely in `lib/utils/cores.dart` (`Cores` class — never instantiated). Primary green is `Cores.verdePrincipal`.
- Two fonts from `google_fonts`: `GoogleFonts.anybody()` for headings/labels, `GoogleFonts.hankenGrotesk()` for body text.
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
      jogos_teste.json        ← 104 jogos com datas deslocadas -25 dias;
                                 jogos antes de 21/05/2026 já têm resultados
    avatares/                 ← imagens dos jogadores para seleção de avatar
  functions/
    index.js                  ← Cloud Functions (Node 22, região southamerica-east1):
                                 calcularPontuacao, lembretesPalpite, recalcularTudo,
                                 membroEntrou, calcularPalpitesEspeciais,
                                 limparUsuariosOrfaos
  lib/
    main.dart                 ← Firebase init + FCM background handler + StreamBuilder de auth
    firebase_options.dart     ← gerado automaticamente pelo FlutterFire CLI
    models/
      jogo.dart               ← model com fromJson, fromMap, toMap e getter dataHora; campo vencedor (String?, nullable)
      usuario.dart            ← model com fromMap, toMap e copyWith; inclui campos de palpites especiais
      palpite.dart            ← model com fromMap, toMap; criadoEm é DateTime? (nullable)
      grupo.dart              ← model com fromMap, toMap; criadoEm é DateTime? (nullable)
    screens/
      menu_principal.dart     ← shell com drawer lateral, AppBar, IndexedStack, NavigationBar;
                                 inicializa FCM; deep linking via notificação (onMessageOpenedApp,
                                 getInitialMessage); SnackBar com botão VER em foreground;
                                 seção ADMIN com 4 itens separados
      tela_home.dart          ← jogos de hoje (Firestore) + bento grid de navegação;
                                 card "PALPITES ESPECIAIS" navega para TelaPalpitesEspeciais
      tela_login.dart         ← login e cadastro com design do Stitch; ícone de olho na senha;
                                 botão "Continuar com Google" com account linking automático
      tela_setup_perfil.dart  ← ordem: Nome → Grupos (criar/entrar opcional) → Avatar;
                                 dialogs de criar/entrar grupo inline;
                                 nome pré-preenchido com displayName do Google quando disponível
      tela_perfil.dart        ← exibe/edita nome e avatar; alterar senha; excluir conta
      tela_notificacoes.dart  ← toggles de preferência de notificação (lembrete / ranking)
      tela_palpites.dart      ← duas abas: Próximos (com palpites) e Resultados
      tela_palpites_especiais.dart ← tela azul com 6 palpites especiais do usuário:
                                 campeão, artilheiro, melhor goleiro, melhor jogador,
                                 equipe mais goleadora, equipe menos vazada;
                                 bottom sheet com busca para seleção de times;
                                 bloqueado após início do primeiro jogo
      tela_ranking.dart       ← ranking filtrado por grupo com pódio e lista; chips para alternar grupos
      tela_grupos.dart        ← lista grupos do usuário; criar grupo (código único); entrar com código; sair;
                                 tocar no card abre dialog de detalhes com membros e avatares;
                                 ícone de lápis (só dono) edita o nome do grupo
      tela_tabela.dart        ← lista os 104 jogos com seções e tabs; RefreshIndicator (pull-to-refresh)
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
      tela_admin_especiais.dart ← resultados reais: campeão, artilheiro, melhor goleiro,
                                 equipe mais goleadora, equipe menos vazada, melhor jogador;
                                 botão CALCULAR chama calcularPalpitesEspeciais (irreversível)
      tela_admin_definicoes.dart ← ações: popular jogos (Teste/Produção), recalcular Reg. Clássica,
                                 recalcular Reg. Copa (placeholder), limpar dados de teste, limpar órfãos
      tela_ajuda.dart         ← FAQ estático
    services/
      jogo_service.dart       ← popularJogosNoFirestore({bool teste}), buscarTodos, buscarPorData
      usuario_service.dart    ← criarPerfil, buscarPorUid, observarUsuario,
                                 atualizarNome, atualizarAvatar,
                                 salvarPalpiteEspecial (campeão + artilheiro),
                                 salvarPalpitesEspeciais (todos os 6 campos)
      palpite_service.dart    ← salvar, buscarPorJogo, buscarTodosPorUsuario,
                                 buscarPorUsuario, buscarTodosPorJogo
      notificacoes_service.dart ← inicializar FCM, salvar token, buscar/atualizar prefs
      grupo_service.dart      ← criarGrupo, entrarComCodigo, buscarGruposDoUsuario,
                                 sairDoGrupo, editarNome, buscarMembros;
                                 código único gerado com loop anti-colisão
    utils/
      cores.dart              ← constantes de cores (Cores.verdePrincipal etc)
      biblioteca.dart         ← funções utilitárias top-level (flagDe, siglaDe,
                                 formatarData, mostrarMensagem, ehPlaceholder)
      avatares.dart           ← lista kJogadores + widgets WidgetAvatar e CardAvatar
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
Cores.background              = Color(0xFFF9F9FF)
Cores.surface                 = Color(0xFFF9F9FF)
Cores.surfaceVariant          = Color(0xFFD8E3FB)
Cores.surfaceContainer        = Color(0xFFE7EEFF)
Cores.surfaceContainerHigh    = Color(0xFFDEE8FF)

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
- `AppBar` com ícone da bola (abre drawer) + título dinâmico + botão de regras
- `IndexedStack` com as 4 telas como filhos (scroll preservado entre abas)
- `NavigationBar` (Material 3) com 4 destinos

```dart
// O leading usa Builder para acessar o Scaffold correto
leading: Builder(
  builder: (ctx) => IconButton(
    icon: const Icon(Icons.sports_soccer),
    onPressed: () => Scaffold.of(ctx).openDrawer(),
  ),
),
```

### Drawer lateral
- Cabeçalho verde com avatar do jogador selecionado, nome e pontuação via `StreamBuilder<Usuario?>`
- Seção "CONTA": Meu Perfil → `TelaPerfil`; Notificações → `TelaNotificacoes`
- Seção "GRUPOS": Meus Grupos → `TelaGrupos`
- Seção "ADMIN" (só para `isAdmin == true`), 4 itens:
  - Placares — Reg. Clássica → `TelaAdminPlacares`
  - Classificação — Reg. Copa → `TelaAdminCopa`
  - Palpites Especiais → `TelaAdminEspeciais`
  - Outras Definições → `TelaAdminDefinicoes`
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
- Nome: `bolaodasoci2026`
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
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /grupos/{grupoId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid in resource.data.membros;
      allow delete: if request.auth != null && request.auth.uid == resource.data.donoUid;
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
pontuacao            : Number    — começa em 0; atualizado via FieldValue.increment()
criadoEm             : Timestamp
avatar               : String?   — id do jogador selecionado no setup de perfil
isAdmin              : Boolean   — campo opcional; adicionado manualmente no Console
fcmToken             : String?   — token FCM do dispositivo; salvo pelo NotificacoesService
notifLembretes       : Boolean?  — padrão true quando ausente
notifRanking         : Boolean?  — padrão true quando ausente
palpiteCampeao       : String?   — nome em inglês do time campeão (ex: "Brazil")
palpiteArtilheiro    : String?   — nome livre do artilheiro
palpiteGoleiro       : String?   — nome livre do melhor goleiro
palpiteMelhorJogador : String?   — nome livre do melhor jogador do torneio
palpiteMaisGoleadora : String?   — nome em inglês da equipe mais goleadora
palpiteMenosVazada   : String?   — nome em inglês da equipe menos vazada
```

Todos os palpites especiais são bloqueados após o início do primeiro jogo da Copa.
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
placar1     : Number?  — null até o admin inserir o resultado
placar2     : Number?  — null até o admin inserir o resultado
vencedor    : String?  — preenchido em eliminatórias com empate nos 90 min (pênaltis/prorrogação)
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
artilheiroReal               : String?   — nome do artilheiro real
melhorGoleiroReal            : String?   — nome do melhor goleiro real
maisGoleadoraReal            : String?   — nome em inglês da equipe mais goleadora
maisVazadaReal               : String?   — nome em inglês da equipe menos vazada (campo legado)
melhorJogadorFinalReal       : String?   — nome do melhor jogador real (campo legado)
palpitesEspeciaisCalculados  : Boolean   — true após executar calcularPalpitesEspeciais

— Classificação real dos grupos (admin, via tela_admin_copa) —
classificacao_real           : Map       — { "A": { "primeiro": "Brazil", "segundo": "Mexico", "terceiro": "..." }, ... }
                                           12 grupos (A–L); terceiro só em 8 grupos
```

---

## Regras de pontuação

```dart
int calcularPontos(int p1, int p2, int r1, int r2) {
  if (p1 == r1 && p2 == r2) return 10;           // placar exato
  final sP = p1 - p2, sR = r1 - r2;
  final vP = p1.compareTo(p2), vR = r1.compareTo(r2);
  if (sP == sR && vP == vR) return 7;            // vencedor + saldo
  if (vP == vR && vR != 0) return 5;             // só o vencedor
  if (vP == 0 && vR == 0) return 4;              // empate (sem exato)
  return 0;                                       // errou tudo
}
```

Regra extra: −1 pt para quem esqueceu de palpitar em jogo disputado após o `criadoEm` do usuário. Jogos anteriores ao cadastro não geram penalidade.

Cores dos badges de pontuação:
- 10 pts → `Color(0xFF006D32)` verde escuro
- 7 pts → `Color(0xFF1B7F3A)` verde médio
- 5 pts → `Color(0xFF4CAF50)` verde claro
- 4 pts → `Color(0xFFFCD400)` amarelo (texto: `Cores.onSecondaryContainer`)
- 0 pts → `Color(0xFFBBCBB9)` cinza
- −1 pt → `Color(0xFFE53935)` vermelho

---

## O que cada tela contém hoje

### `tela_login.dart` — implementada
- Card centralizado, fontes Anybody + Hanken Grotesk
- Alterna entre login e cadastro com `AnimatedSwitcher`
- Erros do Firebase Auth traduzidos para português
- Ícone de olho no campo de senha para mostrar/ocultar (`_senhaVisivel` bool + `suffixIcon`)
- Navegação por Enter: Enter no e-mail move o foco para a senha; Enter na senha submete o formulário
- Botão "Continuar com Google" com logo desenhado via `CustomPainter` (sem asset externo)
- Account linking: se o e-mail Google já existe com senha, exibe `_DialogVincularConta` que faz login com senha e chama `linkWithCredential`

### `tela_setup_perfil.dart` — implementada
- Exibida após cadastro, antes de entrar no app
- Ordem dos campos: Nome → **Grupos (opcional)** → Escolha de avatar
- Seção Grupos: dois botões ("Criar grupo" / "Entrar com código") com dialogs inline (`_DialogCriarGrupoSetup`, `_DialogEntrarGrupoSetup`, `_DialogCodigoSetup`)
- Seleção de avatar obrigatória (grid de jogadores)
- Nome pré-preenchido com `user.displayName` (Google) quando disponível
- Salva perfil no Firestore via `UsuarioService.criarPerfil`

### `tela_home.dart` — implementada
- Carrossel de jogos do dia (Firestore) com chip AO VIVO / ENCERRADO
- Bento grid: MEUS PALPITES, CLASSIFICAÇÃO, **PALPITES ESPECIAIS** (azul, navega para `TelaPalpitesEspeciais`), TODOS OS JOGOS
- Callback `onNavegar` recebido do `MenuPrincipal`

### `tela_palpites_especiais.dart` — implementada
- Tela completa com AppBar azul (`Cores.azulTerciario`)
- Banner de bloqueio quando a Copa já começou
- 6 palpites: Campeão (seletor de time), Artilheiro (texto), Melhor Goleiro (texto), Melhor Jogador (texto), Equipe Mais Goleadora (seletor), Equipe Menos Vazada (seletor)
- Seletores de time abrem `_BottomSheetTimes` com `DraggableScrollableSheet` + campo de busca
- Botão "SALVAR PALPITES" azul fixo no rodapé
- Salva via `UsuarioService.salvarPalpitesEspeciais()`

### `tela_tabela.dart` — implementada
- Tabs "Próximos" / "Resultados" com `AnimatedContainer`
- Chips horizontais roláveis: **Todos** + **A** a **L**; eliminatórias só em "Todos"
- `CustomScrollView` com slivers agrupados por seção
- **RefreshIndicator** (pull-to-refresh) — rebusca todos os jogos via `JogoService().buscarTodos()`
- Tocar em jogo encerrado abre dialog com todos os palpites registrados

### `tela_palpites.dart` — implementada
- Duas abas: **Próximos** e **Resultados**
- `Future.wait` carrega jogos + palpites + perfil em paralelo
- `Timer.periodic(30s)` reclassifica jogos automaticamente
- Regra −1 pt para ausência de palpite; card vermelho
- Navegação por Enter entre campos

### `tela_ranking.dart` — implementada
- Ranking filtrado por grupo (sem ranking global)
- Pódio top 3 + lista 4º em diante
- Dialog com histórico de palpites do usuário

### `tela_grupos.dart` — implementada
- `StreamBuilder` reativo em grupos do usuário
- Criar, entrar com código, sair, editar nome (só dono)
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
- Resultados reais: Campeão (seletor com bandeiras), Artilheiro (texto), Melhor Goleiro (texto), Equipe Mais Goleadora (seletor), Equipe Menos Vazada (seletor), Melhor Jogador (texto)
- Botão SALVAR grava em `config/copa2026`
- Botão CALCULAR chama `calcularPalpitesEspeciais` (irreversível; desabilitado após execução)

### `tela_admin_definicoes.dart` — implementada
- Popular Jogos: dialog Teste/Produção → `JogoService.popularJogosNoFirestore`
- Recalcular Reg. Clássica: chama Cloud Function `recalcularTudo`
- Recalcular Reg. Copa: placeholder (a implementar)
- Limpar Órfãos: chama Cloud Function `limparUsuariosOrfaos`

### `tela_perfil.dart` — implementada
- Exibe avatar com botão de troca; edição de nome; alterar senha; excluir conta

### `tela_notificacoes.dart` — implementada
- Toggles: lembrete de palpite / mudança no ranking

### `tela_ajuda.dart` — implementada
- FAQ estático com `ExpansionTile` e badges de pontuação

---

## avatares.dart — widgets e dados compartilhados

```dart
const kJogadores = [
  Jogador('messi', 'Messi', 'Argentina'),
  Jogador('cr7', 'Cristiano Ronaldo', 'Portugal'),
  // ... 10 mais
];

WidgetAvatar(avatarId: usuario.avatar, nome: usuario.nome, tamanho: 64)
CardAvatar(jogador: jogador, selecionado: true, onTap: () { ... })
```

---

## UsuarioService — métodos

```dart
criarPerfil(Usuario)
buscarPorUid(String uid)
observarUsuario(String uid)               // Stream reativo
atualizarNome(String uid, String nome)
atualizarAvatar(String uid, String avatarId)
salvarPalpiteEspecial({uid, campeao, artilheiro})         // legado — só 2 campos
salvarPalpitesEspeciais({uid, campeao, artilheiro,        // todos os 6 palpites especiais
  goleiro?, melhorJogador?, maisGoleadora?, menosVazada?})
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
| `calcularPontuacao` | Firestore trigger (`jogos/{jogoId}`) | Calcula pontuação para cada palpite; aplica −1 para ausências; envia FCM de ranking; propaga vencedor/perdedor para o próximo jogo da chave (eliminatórias) |
| `lembretesPalpite` | Schedule (`*/30 * * * *`) | Notifica usuários sem palpite em jogos que começam em ~30 min |
| `recalcularTudo` | HTTPS Callable (admin only) | Recalcula pontuação de todos os usuários do zero |
| `membroEntrou` | Firestore trigger (`grupos/{grupoId}`) | Detecta novo membro e envia FCM para o dono do grupo |
| `calcularPalpitesEspeciais` | HTTPS Callable (admin only) | Aplica pontos por campeão/artilheiro acertados; marca `palpitesEspeciaisCalculados: true` |
| `limparUsuariosOrfaos` | HTTPS Callable (admin only) | Remove docs `usuarios` sem conta Auth + palpites órfãos |
| `limparDadosTeste` | HTTPS Callable (admin only) | Reseta placares, times de eliminatórias (volta placeholders), classificação, resultados especiais e pontuações. Palpites são preservados. Acessível em Outras Definições. |

**Deep linking via notificação:** `data: { tela: 'palpites' }`, `data: { tela: 'ranking' }`, `data: { tela: 'grupos' }`.

---

## Segurança do Firestore

**`usuarios`**
- `read`: qualquer autenticado
- `create`: só o próprio usuário; campos restritos; `isAdmin`/`pontuacao` protegidos
- `update`: só campos de perfil e palpites especiais; `pontuacao`/`isAdmin` protegidos
- `delete`: só o próprio usuário

**`jogos`** — `read`: autenticado; `write`: autenticado (admin na prática)

**`palpites`** — `read/write`: autenticado (cutoff verificado no frontend)

**`config`** — `read`: autenticado; `write`: só admin

**`grupos`** — `read/create`: autenticado; `update`: membro; `delete`: dono

---

## Google Play — status de publicação

- **Internal Testing** — ✓ v1.0.0+2 publicada
- **Closed Testing (Alpha)** — ✓ v1.0.0+3 publicada
- **Política de privacidade** — ✓ `https://bolaodasoci2026.web.app/privacy`
- **Exclusão de conta** — ✓ `https://bolaodasoci2026.web.app/delete`
- **Segurança dos dados, classificação, público-alvo, anúncios** — ✓ todos enviados
- **Usuário de revisão** — `teste@teste.com` (isAdmin: true no Firestore)

## Próximos passos

1. Aguardar aprovação da revisão do Google.
2. Após aprovação: retomar a faixa no Play Console para liberar aos testadores.
3. Implementar `regra` no model de grupo (Reg. Clássica vs Reg. Copa) e pontuação por grupo.
4. Implementar tela de palpites Regra Copa para o usuário (classificação de grupos).
5. Atualizar tela de ranking para ler pontuação por grupo quando regra copa estiver ativa.
