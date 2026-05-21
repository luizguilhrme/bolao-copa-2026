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
                                 calcularPontuacao, lembretesPalpite, recalcularTudo
  lib/
    main.dart                 ← Firebase init + FCM background handler + StreamBuilder de auth
    firebase_options.dart     ← gerado automaticamente pelo FlutterFire CLI
    models/
      jogo.dart               ← model com fromJson, fromMap, toMap e getter dataHora
      usuario.dart            ← model com fromMap, toMap e copyWith
      palpite.dart            ← model com fromMap, toMap; criadoEm é DateTime? (nullable)
    screens/
      menu_principal.dart     ← shell com drawer lateral, AppBar, IndexedStack, NavigationBar;
                                 inicializa FCM; deep linking via notificação (onMessageOpenedApp,
                                 getInitialMessage); SnackBar com botão VER em foreground
      tela_home.dart          ← jogos de hoje (Firestore) + bento grid de navegação
      tela_login.dart         ← login e cadastro; navegação por Enter entre campos
      tela_setup_perfil.dart  ← seleção de avatar no primeiro acesso (pós-cadastro)
      tela_perfil.dart        ← exibe/edita nome e avatar; alterar senha; excluir conta
      tela_notificacoes.dart  ← toggles de preferência de notificação (lembrete / ranking)
      tela_palpites.dart      ← duas abas: Próximos (com palpites) e Resultados
      tela_ranking.dart       ← ranking em tempo real com pódio e lista
      tela_tabela.dart        ← lista os 104 jogos com seções e tabs
      tela_admin.dart         ← inserção de placares; dialog Teste/Produção no popular jogos
      tela_ajuda.dart         ← FAQ estático
    services/
      jogo_service.dart       ← popularJogosNoFirestore({bool teste}), buscarTodos, buscarPorData
      usuario_service.dart    ← criarPerfil, buscarPorUid, observarUsuario,
                                 atualizarNome, atualizarAvatar
      palpite_service.dart    ← salvar, buscarPorJogo, buscarTodosPorUsuario,
                                 buscarPorUsuario, buscarTodosPorJogo
      notificacoes_service.dart ← inicializar FCM, salvar token, buscar/atualizar prefs
    utils/
      cores.dart              ← constantes de cores (Cores.verdePrincipal etc)
      biblioteca.dart         ← funções utilitárias top-level: flagDe, siglaDe, isoDe,
                                 nomePtDe, formatarData, mostrarMensagem + widget Bandeira
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
- Seção "ADMIN" (só para `isAdmin == true`): Atualizar Placares → navega para `TelaAdmin`
- Seção "SUPORTE": Ajuda & FAQ → `TelaAjuda`
- Rodapé: botão Sair que chama `FirebaseAuth.instance.signOut()`

### Verificação de admin
```dart
// Lido do Firestore uma única vez no initState
// Campo isAdmin adicionado manualmente no Console para o usuário admin
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
3. `TelaSetupPerfil`: usuário escolhe avatar, clica "Confirmar"
4. `UsuarioService.atualizarAvatar` salva no Firestore → stream detecta perfil criado → `MenuPrincipal` abre
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
country_flags: ^4.1.2
google_fonts: ^6.2.1
intl: ^0.19.0
```

### Serviços ativados no Firebase Console
- **Firestore Database** — modo de teste (substituir por regras reais antes do lançamento)
- **Authentication** — provedor E-mail/senha ativado

---

## Coleções do Firestore

### `usuarios`
ID do documento = UID do Firebase Auth.

```
uid             : String
email           : String
nome            : String    — parte antes do @ no cadastro
pontuacao       : Number    — começa em 0; atualizado via FieldValue.increment()
criadoEm        : Timestamp
avatar          : String?   — id do jogador selecionado no setup de perfil
isAdmin         : Boolean   — campo opcional; adicionado manualmente no Console
fcmToken        : String?   — token FCM do dispositivo; salvo pelo NotificacoesService
notifLembretes  : Boolean?  — padrão true quando ausente
notifRanking    : Boolean?  — padrão true quando ausente
```

### `jogos`
104 documentos. ID do documento = id do jogo (string "1" a "104").

```
id          : Number
round       : String   — "Fase de Grupos", "Oitavas de Final", etc.
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
```

**Conversão de fuso:** `"13:00 UTC-6"` → `DateTime.utc(ano, mes, dia, 13, 0).subtract(Duration(hours: -6))` → `19:00 UTC`. O bug original usava `DateTime(...)` local em vez de `DateTime.utc(...)`, causando dupla conversão de fuso.

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

`criadoEm` chega como `null` no cache local antes de o servidor responder → model usa `DateTime?`.

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

Cores dos badges de pontuação (usadas no diálogo de regras e nos cards de resultado):
- 10 pts → `Color(0xFF006D32)` verde escuro
- 7 pts → `Color(0xFF1B7F3A)` verde médio
- 5 pts → `Color(0xFF4CAF50)` verde claro
- 4 pts → `Color(0xFFFCD400)` amarelo (texto: `Cores.onSecondaryContainer`)
- 0 pts → `Color(0xFFBBCBB9)` cinza

---

## O que cada tela contém hoje

### `tela_login.dart` — implementada
- Card centralizado, fontes Anybody + Hanken Grotesk
- Alterna entre login e cadastro com `AnimatedSwitcher`
- Erros do Firebase Auth traduzidos para português
- Cadastro: cria conta no Auth + perfil no Firestore via `UsuarioService`
- Navegação por Enter: Enter no e-mail move foco para senha; Enter na senha submete o formulário

### `tela_setup_perfil.dart` — implementada
- Exibida após cadastro, antes de entrar no app
- Seleção de avatar obrigatória (grid de jogadores)
- Salva `avatar` no Firestore via `UsuarioService.atualizarAvatar`

### `tela_home.dart` — implementada
- Carrossel de jogos do dia (Firestore) com chip AO VIVO
- Jogos com placar já inserido vão para o final do carrossel; chip "ENCERRADO" (bolinha cinza) e placar real exibido
- AO VIVO exibe "0 – 0" (nunca exibe null); aviso "O placar é atualizado somente ao final da partida." abaixo do carrossel
- Bento grid de navegação para Palpites, Ranking e Tabela
- Callback `onNavegar` recebido do `MenuPrincipal`
- Cards exibem bandeiras reais (`Bandeira`) e nome completo em português (`nomePtDe`)

### `tela_tabela.dart` — implementada
- Tabs "Próximos" / "Resultados" com `AnimatedContainer`
- `CustomScrollView` com slivers agrupados por seção
- Chip AO VIVO com ponto pulsante via `AnimationController`
- Exibe bandeiras reais (`Bandeira`) em círculo e nomes em português (`nomePtDe`)
- Tocar em um jogo encerrado na aba Resultados abre dialog com todos os palpites registrados, ordenados por pontuação; cada linha mostra posição, avatar, nome, palpite e badge de pontos

### `tela_palpites.dart` — implementada
- Duas abas: **Próximos** e **Resultados**
- `Future.wait` carrega jogos + palpites em paralelo — sem N queries por card
- `Timer.periodic(30s)` reclassifica jogos entre abas automaticamente
- **Aba Próximos:** jogos disponíveis para palpite (mais de 5 min antes do início); "Ver mais" carrega próxima data; trava impede salvar após o cutoff
- **Aba Resultados:** chip "PRESTES A COMEÇAR" (amarelo, <5 min), "AO VIVO" (pulsante), ou horário; cards encerrados coloridos pela pontuação; badge de pontos; "Registrado em DD/MM às HHhMM"
- Palpite precarregado pelo pai — `_CardPalpite` não faz query individual
- Bandeiras reais (`Bandeira`) e nome completo em português nos cards de ambas as abas
- **Navegação por Enter:** Enter no gol 1 → foco para gol 2; Enter no gol 2 → salva e move foco para o gol 1 do próximo card; sem próximo card → fecha teclado
- `_AbaProximos` é `StatefulWidget` gerenciando lista de `FocusNode` (um por card visível); reconstruída ao mudar o número de cards (ex: "Ver mais")

### `tela_ranking.dart` — implementada
- `StreamBuilder` direto no Firestore → ranking atualiza em tempo real
- Pódio visual para top 3: avatar real (foto do jogador via `WidgetAvatar`); fundo do degrau dourado/prata (`Color(0xFFC0C0C0)`)/bronze (`Color(0xFFCD7F32)`); texto em `Cores.onSurface`
- Lista para 4º em diante com avatar real; usuário logado destacado com borda verde
- Tocar em qualquer card (pódio ou lista) abre dialog com palpites do usuário nos jogos encerrados, ordenados do mais recente para o mais antigo; cada linha mostra bandeiras + siglas + resultado, palpite e badge de pontos

### `tela_admin.dart` — implementada (acesso exclusivo via drawer)
- Filtra jogos elegíveis: 105 min após o início (IDs 1 e 2 sempre desbloqueados para teste)
- Card com pré-preenchimento se já tiver placar (modo correção); exibe bandeiras reais e nomes em português
- Ao salvar: atualiza `placar1`/`placar2` no Firestore → Cloud Function `calcularPontuacao` dispara automaticamente
- Botão de popular jogos abre dialog pedindo **Teste** (`jogos_teste.json`) ou **Produção** (`jogos.json`)
- Botão de recalcular chama a Cloud Function `recalcularTudo` (admin only)

### `tela_perfil.dart` — implementada
- Exibe avatar do jogador com botão de troca (bottom sheet grid)
- Edição de nome inline via dialog
- Alterar senha: dialog com senha atual + nova senha + confirmação + reautenticação
- Excluir conta: dialog com senha para confirmação; remove doc Firestore + conta Auth

### `tela_notificacoes.dart` — implementada
- Toggle **Lembrete de palpite**: notificação 30 min antes de jogos sem palpite
- Toggle **Mudança no ranking**: notificação quando posição no ranking muda
- Prefs salvas nos campos `notifLembretes` / `notifRanking` do documento do usuário
- Auto-save a cada toggle

### `tela_ajuda.dart` — implementada
- FAQ estático com perguntas e respostas expansíveis
- Seção de pontuação com badges coloridos e exemplos

---

## Cloud Functions — visão geral

Deployadas na região `southamerica-east1`. Arquivo: `functions/index.js` (Node 22).

| Função | Tipo | O que faz |
|---|---|---|
| `calcularPontuacao` | Firestore trigger (`jogos/{jogoId}`) | Calcula delta de pontuação para cada palpite; envia FCM de ranking para quem mudou de posição |
| `lembretesPalpite` | Schedule (`*/30 * * * *`) | Notifica usuários sem palpite em jogos que começam em ~30 min |
| `recalcularTudo` | HTTPS Callable (admin only) | Recalcula pontuação de todos os usuários do zero |

**FCM token management:** token salvo em `usuarios/{uid}.fcmToken`. Tokens inválidos são removidos automaticamente (`messaging/registration-token-not-registered`).

**Deep linking via notificação:** payload FCM inclui `data: { tela: 'palpites' }` (lembrete) ou `data: { tela: 'ranking' }` (ranking). `MenuPrincipal` lê esse campo em `onMessageOpenedApp`, `getInitialMessage` e no `onMessage` (SnackBar com botão VER) para navegar para a aba correta.

---

## avatares.dart — widgets e dados compartilhados

```dart
// Lista dos 12 jogadores disponíveis como avatar
const kJogadores = [
  Jogador('messi', 'Messi', 'Argentina'),
  Jogador('cr7', 'Cristiano Ronaldo', 'Portugal'),
  // ... 10 mais
];

// Exibe foto do jogador em círculo; fallback: inicial do nome
WidgetAvatar(avatarId: usuario.avatar, nome: usuario.nome, tamanho: 64)

// Card de seleção com borda verde e check quando selecionado
CardAvatar(jogador: jogador, selecionado: true, onTap: () { ... })
```

`WidgetAvatar` aceita `corFundo`, `corTexto`, `borderColor` e `borderWidth` para se adaptar ao drawer (fundo verde-claro) e ao perfil (fundo verde-escuro).

---

## PalpiteService — métodos

```dart
salvar(Palpite)                          // set() com docId fixo — idempotente
buscarPorJogo(String uid, int jogoId)    // get() por docId — O(1)
buscarTodosPorUsuario(String uid)        // where(uid) sem orderBy — sem índice composto
buscarPorUsuario(String uid)             // where(uid) + orderBy(jogoId) — requer índice composto
buscarTodosPorJogo(int jogoId)           // where(jogoId) — usado pelo admin
```

**Nota sobre índices:** `buscarPorUsuario` usa `where + orderBy` em campos diferentes → Firestore exige índice composto. Na primeira execução, o log mostra um link para criar o índice automaticamente.

---

## Bugs corrigidos e decisões técnicas relevantes

### Bug de fuso horário nos timestamps
O getter `dataHora` no `Jogo` usava `DateTime(...)` (local) antes de subtrair o offset UTC, causando dupla conversão. Corrigido com `DateTime.utc(...)`.

### Bug de exibição de horário
`formatarData()` em `biblioteca.dart` formatava sem converter para local. Corrigido adicionando `final local = data.toLocal()` no início da função — todos os pontos de uso se beneficiam automaticamente.

### setState com Future
`onSalvo: () => setState(() => _futureJogos = _carregarElegiveis())` retornava um `Future` para o `setState`. Corrigido com chaves: `setState(() { _futureJogos = _carregarElegiveis(); })`.

### not-found ao atualizar placar
O código usava `.doc(jogo.id.toString())` assumindo que o ID do documento Firestore bate com o campo `id`. Corrigido com `.where('id', isEqualTo: jogoId).limit(1).get()` + `.docs.first.reference`.

### criadoEm null no cache local
`FieldValue.serverTimestamp()` chega como `null` no cache local antes de o servidor responder. Corrigido tornando `criadoEm` nullable (`DateTime?`) no model `Palpite`.

### Flash de MenuPrincipal durante cadastro
`authStateChanges` disparava ao criar a conta Firebase, exibindo `MenuPrincipal` brevemente antes do setup. Corrigido fazendo o roteamento levar em conta a existência do perfil Firestore, não só o auth.

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
- `const` em mapas literais para alocação única em tempo de compilação
- `Map` em Dart preserva ordem de inserção
- Arrow function `=>` vs bloco `{}` — diferença de tipo de retorno (causou o bug do setState)
- `Builder` widget para acessar o `Scaffold` correto dentro do `AppBar`
- `addPostFrameCallback` para executar código após o frame atual terminar
- `.clamp(min, max)` para limitar valores numéricos
- `showModalBottomSheet` + `DraggableScrollableSheet` para sheets scrolláveis
- `GridView.builder` com `SliverGridDelegateWithFixedCrossAxisCount`
- `Image.asset` com `errorBuilder` para fallback quando imagem não existe
- `ExpansionTile` para listas expansíveis (FAQ)
- `showDialog<T>` retornando valor via `Navigator.of(ctx).pop(valor)` — comunicação do dialog de volta ao chamador
- `@pragma('vm:entry-point')` — necessário para funções top-level chamadas pelo runtime nativo (ex: handler de background do FCM)
- `FirebaseMessaging.onBackgroundMessage` — registra handler para mensagens com app fechado; deve ser top-level
- `FirebaseMessaging.onMessage` — stream de mensagens com app em foreground (não exibe notificação automaticamente)
- `EmailAuthProvider.credential` + `reauthenticateWithCredential` — reautenticação necessária para operações sensíveis (updatePassword, delete)
- Converter `StatelessWidget` em `StatefulWidget` — padrão quando um widget filho precisa de estado próprio
- `FocusNode` + `FocusScope.of(context).requestFocus()` — navegação programática entre campos de texto
- `TextInputAction.next` / `.done` + `onSubmitted` — ação do botão Enter no teclado virtual
- `FocusNode` compartilhado entre pai e filho — pai cria o nó, filho usa como `focusNode` no `TextField`
- Gerenciar lista de `FocusNode` em `StatefulWidget` com `didUpdateWidget` para recriar nós quando o número de itens muda
- `country_flags 4.x`: API mudou — tamanho agora vai dentro de `ImageTheme(width, height)` em vez de parâmetros diretos; suporta nativamente subdivisões do Reino Unido (`GB-ENG`, `GB-SCT`, `GB-WLS`); não precisa mais de `FittedBox` com zoom
- `Container.clipBehavior: Clip.antiAlias` com `BoxDecoration(shape: BoxShape.circle)` — recorta o filho em formato circular
- `FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge)` com `CountryFlag(width: tamanho * 2.2)` — força bandeira a preencher o círculo sem letterboxing (largura 2.2× garante que flags até 2:1 preencham a altura)
- `FirebaseMessaging.onMessageOpenedApp` — stream disparado quando usuário toca na notificação com app em background; `getInitialMessage()` — recupera notificação que abriu o app quando estava fechado; usados juntos para deep linking FCM
- `Flexible` dentro de `Row` — permite que o filho encolha e use `TextOverflow.ellipsis` sem estourar o layout; essencial em cabeçalhos de dialog com nomes longos ao lado de widgets de tamanho fixo (bandeiras, placar)
- `calcularPontos()` em `biblioteca.dart` — função pública compartilhada; os dialogs de palpites a usam para calcular badges de pontuação
- `kIsWeb` de `package:flutter/foundation.dart` — guard para código não suportado na web (ex: `FirebaseMessaging.onBackgroundMessage`, FCM token registration)
- Flutter web: `flutter create --platforms web .` cria a pasta `web/` com boilerplate; `manifest.json` configura nome/ícone/tema; meta tags iOS habilitam "Adicionar à Tela de Início" no Safari
- `firebase deploy --only hosting --project <id>` — deploya `build/web` no Firebase Hosting

---

## Próximos passos (na ordem recomendada)

1. **Regras de segurança do Firestore** — substituir modo de teste por regras reais antes do lançamento (ex: usuário só lê/escreve seus próprios palpites; só admin escreve em jogos)
2. **Google Play Internal Testing** — conta Play Console aguardando verificação de identidade; quando aprovada: criar keystore, configurar signing no `build.gradle.kts`, build AAB, upload no Play Console
3. **Popular com dados de produção** — clicar em Popular → Produção quando a Copa começar (11/jun)
