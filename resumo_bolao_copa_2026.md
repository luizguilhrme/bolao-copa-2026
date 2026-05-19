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
    dados/
      jogos.json              ← 104 jogos da Copa 2026 (não declarado no pubspec.yaml;
                                 mantido em disco como referência, pois os dados já
                                 foram populados no Firestore via WriteBatch)
  lib/
    main.dart                 ← configuração + inicialização Firebase + StreamBuilder de auth
    firebase_options.dart     ← gerado automaticamente pelo FlutterFire CLI
    models/
      jogo.dart               ← model com fromJson, fromMap, toMap e getter dataHora
      usuario.dart            ← model com fromMap, toMap e copyWith
    screens/
      menu_principal.dart     ← shell: AppBar + IndexedStack + NavigationBar
      tela_home.dart          ← jogos de hoje (Firestore) + bento grid de navegação
      tela_login.dart         ← login e cadastro com design do Stitch
      tela_palpites.dart      ← placeholder
      tela_ranking.dart       ← placeholder
      tela_tabela.dart        ← implementada: lista os 104 jogos com seções e tabs
    services/
      jogo_service.dart       ← popularJogosNoFirestore, buscarTodos, buscarPorData
      usuario_service.dart    ← criarPerfil, buscarPorUid, observarUsuario
    utils/
      cores.dart              ← constantes de cores (Cores.verdePrincipal etc)
      biblioteca.dart         ← funções utilitárias top-level (sem classe wrapper)
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
- Comunicação de filho para pai via callback (`void Function(int)`) — o `MenuPrincipal` passa `onNavegar` para a `TelaHome`, que o chama nos cards do bento grid

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

## Arquitetura de navegação implementada

`MenuPrincipal` é um **shell** — só gerencia a navegação. Contém:

- `AppBar` com título dinâmico (`AnimatedSwitcher` faz crossfade ao trocar de aba)
- `IndexedStack` com as 4 telas como filhos
- `NavigationBar` (Material 3) com 4 destinos

```dart
// A lista de telas é construída dentro do build(), não como campo da classe.
// Isso é necessário porque o callback onNavegar referencia setState,
// que só está disponível dentro de métodos — não em campos de instância.

@override
Widget build(BuildContext context) {
  final telas = [
    TelaHome(
      onNavegar: (indice) => setState(() => _indiceNav = indice),
    ),
    TelaPalpites(),
    TelaRanking(),
    TelaTabela(),
  ];

  return Scaffold(
    body: IndexedStack(
      index: _indiceNav,   // só esta tela fica visível
      children: telas,     // todas ficam vivas na memória (scroll preservado)
    ),
    ...
  );
}
```

### Navegação via callback (filho → pai)

A `TelaHome` recebe um parâmetro `onNavegar` do tipo `void Function(int)`. Quando o usuário toca em um card do bento grid, o filho chama esse callback com o índice desejado — o pai (`MenuPrincipal`) executa o `setState` e troca a aba. O filho não precisa saber nada sobre o pai, só que tem uma função para chamar.

```dart
// Em TelaHome:
class TelaHome extends StatefulWidget {
  const TelaHome({super.key, required this.onNavegar});
  final void Function(int) onNavegar;
  ...
}

// Nos cards do bento grid (dentro de _TelaHomeState):
onTap: () => widget.onNavegar(1), // Palpites
onTap: () => widget.onNavegar(2), // Ranking
onTap: () => widget.onNavegar(3), // Tabela

// widget.X é como o State acessa propriedades do StatefulWidget que o criou.
```

---

## Arquitetura de autenticação

O `main.dart` usa um `StreamBuilder` que ouve o `authStateChanges()` do Firebase Auth. Esse Stream emite um novo evento toda vez que o estado de login muda — usuário logou, deslogou, ou a sessão foi restaurada ao abrir o app. Com base no valor emitido, o app decide qual tela mostrar:

```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (snapshot.hasData) return const MenuPrincipal(); // logado
    return const TelaLogin();                           // deslogado
  },
)
```

Isso elimina qualquer lógica manual de redirecionamento — o Stream cuida de tudo reativamente.

---

## Firebase — configuração completa

### Ferramentas instaladas
- Node.js LTS (v22) instalado via nodejs.org
- Firebase CLI instalado via `npm install -g firebase-tools` (v15.18.0)
- FlutterFire CLI instalado via `dart pub global activate flutterfire_cli`
- PATH do Windows atualizado para incluir `C:\Users\Luiz Guilherme\AppData\Local\Pub\Cache\bin`

### Projeto Firebase
- Nome: `bolaodasoci2026`
- Região do Firestore: `southamerica-east1` (São Paulo) — melhor latência para usuários brasileiros
- App Android registrado com package name: `com.luizdeveloper.bolao.bolao`
- Arquivo `firebase_options.dart` gerado automaticamente pelo `flutterfire configure`

### Configurações do Android
No arquivo `C:\bolao\android\app\build.gradle.kts` foram feitas duas alterações em relação ao padrão:

```kotlin
android {
    ndkVersion = "27.0.12077973"   // era flutter.ndkVersion — Firebase exige a 27
    defaultConfig {
        minSdk = 23                // era flutter.minSdkVersion — firebase_auth exige mínimo 23
    }
}
```

### Pacotes adicionados ao pubspec.yaml
```yaml
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
google_fonts: ^6.2.1
intl: ^0.19.0
```

### Serviços ativados no Firebase Console
- **Firestore Database** — modo de teste (expira em 30 dias; regras de produção a definir antes do lançamento)
- **Authentication** — provedor E-mail/senha ativado

---

## Coleções do Firestore

### `usuarios`
Cada documento tem o UID do Firebase Auth como ID. Campos:

```
uid         : String   — mesmo UID do Auth, repetido dentro do documento para facilitar queries
email       : String
nome        : String   — inicialmente extraído do e-mail (parte antes do @)
pontuacao   : Number   — começa em 0
criadoEm    : Timestamp — gerado pelo servidor (FieldValue.serverTimestamp())
```

O perfil é criado automaticamente no Firestore logo após o `createUserWithEmailAndPassword` ter sucesso na tela de login.

### `jogos`
104 documentos, cada um com o id do jogo (1 a 104) como ID do documento. Campos:

```
id          : Number
round       : String   — "Fase de Grupos", "Oitavas de Final", etc.
matchday    : String?  — "Rodada 1", "Rodada 2", "Rodada 3" (null nas fases eliminatórias)
date        : String   — "2026-06-11" (string original preservada)
time        : String   — "13:00 UTC-6" (string original preservada)
dataHora    : Timestamp — date + time convertidos para UTC; usado para queries e ordenação
team1       : String
team2       : String
group       : String?  — "Grupo A" ... "Grupo L" (null nas fases eliminatórias)
ground      : String   — cidade/estádio
placar1     : Number?  — null enquanto o jogo não aconteceu
placar2     : Number?  — null enquanto o jogo não aconteceu
```

Os jogos foram populados via `WriteBatch` — uma operação que agrupa todas as 104 escritas em uma única chamada de rede, atômica e idempotente. O `jogos.json` que serviu como fonte permanece em disco em `assets/dados/` mas não está declarado no `pubspec.yaml` e não é compilado no APK.

A conversão de fuso funciona assim: `"13:00 UTC-6"` → extrai offset `-6` → `DateTime.subtract(Duration(hours: -6))` → resultado em UTC (`19:00 UTC`) → salvo como Timestamp. O Firebase Console exibe no fuso do navegador (UTC-3 = 16:00, que é o horário correto de Brasília).

**Pendência futura:** traduzir os nomes dos países para português no Firestore.

---

## O que cada tela contém hoje

### `tela_login.dart` — implementada
- Design fiel ao mockup do Stitch (card centralizado, fontes Anybody + Hanken Grotesk via `google_fonts`)
- Campos de e-mail e senha com ícones e borda que muda para azul no foco
- Alterna entre modo login e modo cadastro com `AnimatedSwitcher`
- Erros do Firebase Auth traduzidos para português
- No cadastro: cria conta no Auth e em seguida cria o perfil no Firestore via `UsuarioService`
- Após login bem-sucedido, o `StreamBuilder` do `main.dart` redireciona automaticamente

### `tela_home.dart` — implementada
- `StatefulWidget` com `initState` que dispara `JogoService().buscarPorData(DateTime.now())`
- `FutureBuilder` gerencia os estados: carregando → sem jogos → com jogos → erro
- Carrossel horizontal de cards com bandeira emoji, sigla, horário local e chip "AO VIVO"
- Detecção de jogo ao vivo: `placar1 == null && dataHora.toLocal().isBefore(DateTime.now())`
- Horário exibido convertido de UTC para o fuso local via `DateFormat('HH:mm').format(dataHora.toLocal())`
- Bento grid com cards de navegação para Palpites (índice 1), Classificação (índice 2) e Todos os Jogos (índice 3)
- Aceita callback `onNavegar` do `MenuPrincipal` e o chama via `widget.onNavegar(indice)` nos cards
- Botão "VER TODOS" no cabeçalho da seção também chama `widget.onNavegar(3)`

### `tela_tabela.dart` — implementada
- Tabs "Próximos" / "Resultados" com `AnimatedContainer` para transição suave
- Filtragem: Próximos = `placar1 == null`; Resultados = `placar1 != null`
- Jogos ordenados por `dataHora` e agrupados por seção usando `Map` com ordem de inserção preservada
- Seções: "Fase de Grupos — Rodada 1", "Oitavas de Final", etc.
- `CustomScrollView` com slivers intercalando cabeçalhos de seção e listas de cards
- Cards mostram: chip de grupo/fase, horário local ou "AO VIVO", bandeiras, placar (ou `—`)
- Chip "AO VIVO" com ponto pulsante animado via `AnimationController`

### `tela_palpites.dart` — placeholder
### `tela_ranking.dart` — placeholder

---

## biblioteca.dart — funções utilitárias

Todas as funções são **top-level** (sem classe wrapper) — padrão idiomático em Dart, onde funções top-level são cidadãs de primeira classe, como `runApp()` e `showDialog()` do próprio Flutter. Usar `static` numa classe seria um hábito de Java/C# desnecessário em Dart.

```dart
// Uso em qualquer arquivo após import '../utils/biblioteca.dart':
flagDe('Brazil')         // → '🇧🇷'
siglaDe('Germany')       // → 'GER'
formatarData(agora)      // → '12/06/2026 às 20h00'
mostrarMensagem(ctx, msg) // exibe SnackBar padronizado
```

Os mapas internos de `flagDe` e `siglaDe` são `const` — compilados como literais em tempo de compilação, alocados uma única vez na memória independente de quantas vezes as funções forem chamadas.

---

## Conceitos Flutter já vistos

- `StatelessWidget` vs `StatefulWidget`
- `setState()` como equivalente ao `notifyDataSetChanged()`
- `build()` como equivalente ao `onCreateView()`
- `initState()` como equivalente ao `onCreate()`
- Hot reload com `r` no terminal
- `Scaffold`, `AppBar`, `MaterialApp`
- `factory fromJson` como alternativa ao Gson
- `factory fromMap` / `toMap` para serialização com o Firestore
- `Material` + `InkWell` para áreas clicáveis com ripple
- `Stack` + `Positioned` para sobreposição (equivalente a `position: absolute`)
- `NavigationBar` (Material 3) com `selectedIndex`
- `IndexedStack` para preservar estado entre abas
- `AnimatedSwitcher` + `ValueKey` para animação de troca de widget
- `AnimatedContainer` para animar mudanças de propriedades (cor, sombra, tamanho)
- `const` em widgets para otimização de recriação
- `ListView` com `scrollDirection: Axis.horizontal` para carrossel
- `IntrinsicHeight` para forçar altura igual em widgets irmãos numa `Row`
- `StreamBuilder` para reagir a Streams em tempo real (usado com `authStateChanges()`)
- `FutureBuilder` para reagir a operações assíncronas (usado para carregar jogos do Firestore)
- Getter computado em Dart (`DateTime get dataHora`) como alternativa a campo calculado
- `WriteBatch` do Firestore para operações em lote atômicas e idempotentes
- `FieldValue.serverTimestamp()` para timestamps gerados pelo servidor
- `Timestamp.fromDate()` e `.toDate()` para converter entre `DateTime` do Dart e `Timestamp` do Firestore
- `DateFormat` do pacote `intl` para formatar datas
- `rootBundle.loadString()` para ler arquivos de assets em tempo de execução
- `CustomScrollView` + Slivers (`SliverToBoxAdapter`, `SliverPadding`, `SliverList`) para listas com cabeçalhos intercalados de forma eficiente
- `AnimationController` + `SingleTickerProviderStateMixin` para animações imperativas (ponto pulsante do chip AO VIVO)
- `AnimatedBuilder` para reconstruir apenas o trecho animado da árvore a cada frame, sem chamar `setState`
- Callback `void Function(int)` como padrão de comunicação filho → pai (substituindo EventBus ou similar do Android)
- `widget.X` dentro de um `State` para acessar propriedades do `StatefulWidget` que o criou
- Funções top-level em Dart como alternativa idiomática a métodos `static` em classes utilitárias
- `const` em mapas literais dentro de funções para alocação única em tempo de compilação
- `Map` em Dart preserva ordem de inserção — útil para agrupar e exibir dados em sequência cronológica sem ordenação extra

---

## Próximos passos (na ordem recomendada)

1. **Tela de palpites** — o usuário escolhe um jogo e registra o placar previsto; o palpite é salvo no Firestore na coleção `palpites` associado ao UID do usuário
2. **Coleção `palpites`** no Firestore — estrutura a definir
3. **Cálculo de pontuação** — comparar palpite com placar real e atualizar `pontuacao` no documento do usuário
4. **Tela de ranking** — listar usuários ordenados por pontuação
5. **Regras de segurança do Firestore** — substituir o modo de teste por regras reais antes do lançamento
6. **Logout** — botão no perfil ou no menu
7. **Tradução dos nomes dos países** para português no Firestore (pendência de baixa prioridade)
