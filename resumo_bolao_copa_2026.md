# Resumo do projeto — Bolão Copa 2026

---

## Ambiente

- Flutter SDK instalado, projeto rodando no Android Studio
- Projeto localizado em `C:\bolao\`
- Emulador Android configurado e funcionando (Nexus S API 24)
- Run Configuration apontando para `C:\bolao\lib\main.dart`
- Android nativo apenas (sem iOS por enquanto)
- Foco em aprendizado progressivo de Flutter

---

## Estrutura de pastas atual

```
C:\bolao\
  assets/
    avatares/                   ← fotos dos jogadores para seleção de avatar
      messi.jpg, cr7.jpg, mbappe.jpg, vinicius.jpg, neymar.jpg,
      paqueta.jpg, haaland.jpg, bellingham.jpg, salah.jpg,
      yamal.jpg, modric.jpg, ochoa.jpg
    dados/
      jogos.json                ← 104 jogos da Copa 2026 (não declarado no pubspec.yaml;
                                   mantido em disco como referência — dados já populados
                                   no Firestore via WriteBatch. Declarar temporariamente
                                   no pubspec.yaml quando precisar rodar popularJogosNoFirestore)
  lib/
    main.dart                   ← inicialização Firebase + roteamento por auth + perfil Firestore
    firebase_options.dart       ← gerado automaticamente pelo FlutterFire CLI
    models/
      jogo.dart                 ← model com fromJson, fromMap, toMap e getter dataHora
      usuario.dart              ← model com fromMap, toMap e copyWith; campo avatar nullable
      palpite.dart              ← model com fromMap, toMap; criadoEm é DateTime? (nullable)
    screens/
      menu_principal.dart       ← shell com drawer lateral, AppBar, IndexedStack, NavigationBar
      tela_home.dart            ← jogos de hoje (Firestore) + bento grid de navegação
      tela_login.dart           ← login e cadastro; cria conta Firebase antes de abrir setup
      tela_setup_perfil.dart    ← escolha de nome e avatar no primeiro cadastro
      tela_palpites.dart        ← duas abas: Próximos (com palpites) e Resultados
      tela_ranking.dart         ← ranking em tempo real com pódio e lista
      tela_tabela.dart          ← lista os 104 jogos com seções e tabs; nomes em português
      tela_admin.dart           ← tela exclusiva do admin para inserir placares
      tela_perfil.dart          ← perfil do usuário com edição de nome e avatar
      tela_ajuda.dart           ← tela de Ajuda & FAQ com seção de pontuação e perguntas
    services/
      jogo_service.dart         ← popularJogosNoFirestore, buscarTodos, buscarPorData
      usuario_service.dart      ← criarPerfil, buscarPorUid, observarUsuario,
                                   atualizarNome, atualizarAvatar
      palpite_service.dart      ← salvar, buscarPorJogo, buscarTodosPorUsuario,
                                   buscarPorUsuario, buscarTodosPorJogo
    utils/
      cores.dart                ← constantes de cores (Cores.verdePrincipal etc)
      biblioteca.dart           ← funções utilitárias top-level (flagDe, siglaDe,
                                   nomePtDe, formatarData, mostrarMensagem)
      avatares.dart             ← Jogador, kJogadores, WidgetAvatar, CardAvatar
  pubspec.yaml
```

---

## Decisões de arquitetura

- Android nativo apenas (sem iOS por enquanto)
- Backend Firebase (Firestore + Auth) — configurado e funcionando
- Foco em aprendizado progressivo de Flutter
- Padrão Service como camada de abstração entre telas e Firestore (equivalente ao Repository pattern do Android)
- IDs dos documentos Firestore sempre iguais ao identificador da entidade (UID do usuário, id do jogo) — garante idempotência e busca O(1)
- Funções utilitárias compartilhadas são declaradas como funções top-level em `biblioteca.dart`, não como métodos `static` de uma classe wrapper — padrão idiomático em Dart
- Comunicação de filho para pai via callback (`void Function(int)`) — o `MenuPrincipal` passa `onNavegar` para a `TelaHome`
- Cálculo de pontuação feito no cliente (app), não em Cloud Functions — placares inseridos manualmente pelo admin via `tela_admin.dart`
- Palpites precarregados em lote (`buscarTodosPorUsuario`) ao abrir a tela, sem query individual por card
- Widgets de avatar centralizados em `avatares.dart` (`WidgetAvatar`, `CardAvatar`) — reutilizados no drawer, perfil e setup

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

- `Drawer` lateral com avatar do jogador, nome e pontuação via `StreamBuilder<Usuario?>`
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
- Cabeçalho verde com `WidgetAvatar` (foto do jogador ou inicial do nome), nome e pontuação
- Seção "CONTA": Meu Perfil → `TelaPerfil`, Notificações, Configurações
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

## Arquitetura de autenticação e roteamento

O `main.dart` usa dois `StreamBuilder`s aninhados para rotear com base tanto no auth quanto na existência do perfil Firestore:

```dart
StreamBuilder<User?>(               // 1º: estado de autenticação
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, authSnapshot) {
    if (!logado) return TelaLogin();
    return StreamBuilder<Usuario?>(  // 2º: perfil Firestore
      stream: UsuarioService().observarUsuario(uid),
      builder: (context, perfilSnapshot) {
        if (perfil != null) return MenuPrincipal();   // logado + perfil
        return TelaSetupPerfil(user: firebaseUser);   // logado + sem perfil
      },
    );
  },
)
```

### Fluxo de cadastro
1. `TelaLogin`: valida e chama `createUserWithEmailAndPassword` — erros de email duplicado aparecem aqui
2. `authStateChanges` dispara → `main.dart` detecta usuário sem perfil → exibe `TelaSetupPerfil`
3. `TelaSetupPerfil`: usuário escolhe nome e avatar, clica "Confirmar e entrar"
4. `criarPerfil()` salva no Firestore → stream detecta perfil criado → `main.dart` exibe `MenuPrincipal`
5. Botão de voltar no setup faz `signOut()` → stream detecta → retorna para `TelaLogin`

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
uid         : String
email       : String
nome        : String    — definido pelo usuário no setup de perfil
avatar      : String?   — id do jogador escolhido (ex: "messi"); null em contas antigas
pontuacao   : Number    — começa em 0; atualizado via FieldValue.increment()
criadoEm    : Timestamp
isAdmin     : Boolean   — campo opcional; adicionado manualmente no Console
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

Cores dos badges de pontuação:
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
- Cadastro: chama `createUserWithEmailAndPassword` (valida email aqui); roteamento para setup é automático via `main.dart`

### `tela_setup_perfil.dart` — implementada
- Aberta automaticamente pelo `main.dart` quando usuário está logado mas sem perfil Firestore
- Campo de nome (pré-preenchido com prefixo do e-mail)
- Grade 3×4 de avatares com fotos dos jogadores e `errorBuilder` para fallback
- "Confirmar e entrar" salva perfil → stream detecta → `MenuPrincipal` abre
- Botão de voltar faz `signOut()` e retorna para `TelaLogin`

### `tela_home.dart` — implementada
- Carrossel de jogos do dia (Firestore) com chip AO VIVO
- Bento grid de navegação para Palpites, Ranking e Tabela
- Callback `onNavegar` recebido do `MenuPrincipal`

### `tela_tabela.dart` — implementada
- Tabs "Próximos" / "Resultados" com `AnimatedContainer`
- `CustomScrollView` com slivers agrupados por seção
- Chip AO VIVO com ponto pulsante via `AnimationController`
- Nomes dos países em português via `nomePtDe()` de `biblioteca.dart`

### `tela_palpites.dart` — implementada
- Duas abas: **Próximos** e **Resultados**
- `Future.wait` carrega jogos + palpites em paralelo — sem N queries por card
- `Timer.periodic(30s)` reclassifica jogos entre abas automaticamente
- **Aba Próximos:** jogos disponíveis para palpite (mais de 5 min antes do início); "Ver mais" carrega próxima data; trava impede salvar após o cutoff
- **Aba Resultados:** chip "PRESTES A COMEÇAR" (amarelo, <5 min), "AO VIVO" (pulsante), ou horário; cards encerrados coloridos pela pontuação; badge de pontos; "Registrado em DD/MM às HHhMM"
- Palpite precarregado pelo pai — `_CardPalpite` não faz query individual

### `tela_ranking.dart` — implementada
- `StreamBuilder` direto no Firestore → ranking atualiza em tempo real
- Pódio visual para top 3 (1º = amarelo/troféu, 2º = prata, 3º = bronze)
- Lista para 4º em diante; usuário logado destacado com borda verde

### `tela_admin.dart` — implementada (acesso exclusivo via drawer)
- Filtra jogos elegíveis: 105 min após o início (ou IDs de teste configurados em `_jogosTesteIds`)
- Card com pré-preenchimento se já tiver placar (modo correção)
- Ao salvar: `buscarTodosPorJogo` → calcula delta de pontos para cada palpite → `WriteBatch` atômico atualiza placar + pontuações de todos os participantes
- Correção de placar: subtrai pontos antigos antes de adicionar os novos (evita dupla contagem)
- Busca o documento do jogo por `where('id', isEqualTo: jogoId)` em vez de `.doc(id.toString())`

### `tela_perfil.dart` — implementada
- Avatar clicável com ícone de editar — toca para abrir `DraggableScrollableSheet` com grade de jogadores
- Nome editável via diálogo com `TextField`
- E-mail (read-only) e "Membro desde" (mês/ano calculado manualmente sem locale)
- Card verde com pontuação total
- Usa `StreamBuilder<Usuario?>` — atualiza automaticamente ao salvar

### `tela_ajuda.dart` — implementada
- Seção "PONTUAÇÃO" com badges coloridos e exemplos para cada critério
- Seção "PERGUNTAS FREQUENTES" com `ExpansionTile` para cada pergunta

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
`formatarData()` em `biblioteca.dart` formatava sem converter para local. Corrigido adicionando `final local = data.toLocal()` no início da função.

### setState com Future
`onSalvo: () => setState(() => _futureJogos = _carregarElegiveis())` retornava um `Future` para o `setState`. Corrigido com chaves: `setState(() { _futureJogos = _carregarElegiveis(); })`.

### not-found ao atualizar placar
O código usava `.doc(jogo.id.toString())` assumindo que o ID do documento Firestore bate com o campo `id`. Corrigido com `.where('id', isEqualTo: jogoId).limit(1).get()` + `.docs.first.reference`.

### criadoEm null no cache local
`FieldValue.serverTimestamp()` chega como `null` no cache local antes de o servidor responder. Corrigido tornando `criadoEm` nullable (`DateTime?`) no model `Palpite`.

### Flash de MenuPrincipal durante cadastro
`authStateChanges` disparava ao criar a conta Firebase, exibindo `MenuPrincipal` brevemente antes do setup. Corrigido fazendo `main.dart` rotear com base na existência do perfil Firestore (não só no auth).

### Locale pt_BR não inicializado
`DateFormat` com locale `pt_BR` para nomes de meses causava erro em runtime. Corrigido formatando datas manualmente com um array de nomes de meses em português, sem depender de `initializeDateFormatting`.

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
- `StreamBuilder` aninhado — roteamento baseado em múltiplos estados (auth + perfil)
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
- `Navigator.popUntil` para voltar a uma rota específica na pilha

---

## Próximos passos (na ordem recomendada)

1. **Regras de segurança do Firestore** — substituir modo de teste por regras reais antes do lançamento (ex: usuário só lê/escreve seus próprios palpites; só admin escreve em jogos)
2. **Remover IDs de teste** da `tela_admin.dart` (`_jogosTesteIds`) quando a Copa começar
3. **Telas pendentes no drawer:** Notificações, Configurações
