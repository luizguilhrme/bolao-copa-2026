# Resumo do projeto — Bolão - Crava aí!

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
      jogos_teste.json        ← 99 jogos para testes: IDs 1–5 com placar1=1/placar2=0
                                 (todos Grupo A, datas 2026-05-30/31); IDs 6–72 sem placar
                                 (datas originais do jogos.json); IDs 73–104 idênticos ao
                                 jogos.json. popularJogosNoFirestore apaga todos os docs
                                 existentes antes de inserir os novos.
      jogadores.json          ← elencos das 48 seleções da Copa 2026; cada seleção tem
                                 {nome, nomePt, grupo, iso, jogadores}; cada jogador tem
                                 {nome, posicao (GOL/DEF/MEI/ATA), clube}; "-" no clube =
                                 informação não disponível; usado pelos seletores de jogador
                                 em tela_palpites_especiais e tela_admin_especiais;
                                 nomes de jogador são únicos — o nome é a chave de comparação
                                 dos palpites especiais; homônimos desambiguados:
                                 "Montassar Talbi" (Tunísia, vs "Talbi" do Marrocos) e
                                 "Emiliano Martínez (Dibu)" (GOL Argentina, vs "Emiliano
                                 Martínez" MEI do Uruguai)
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
      jogo.dart               ← model com fromJson, fromMap, toMap e getter dataHora;
                                 campos da API: apiId, statusApi, placarAoVivo1/2,
                                 placarDecisao1/2 (só lidos pelo app; escritos pela
                                 sincronizarApi) + getters aoVivoApi e placarDecisao
      usuario.dart            ← model com fromMap, toMap e copyWith; copyWith cobre todos
                                 os 6 campos de palpites especiais
      palpite.dart            ← model com fromMap, toMap; criadoEm é DateTime? (nullable)
      grupo.dart              ← model com fromMap, toMap; criadoEm é DateTime? (nullable);
                                 campo regra: 'classico' | 'copa' (default 'classico')
    screens/
      menu_principal.dart     ← shell com drawer lateral, AppBar, IndexedStack, NavigationBar;
                                 inicializa FCM; deep linking via notificação (onMessageOpenedApp,
                                 getInitialMessage); SnackBar com botão VER em foreground;
                                 sinais de ressincronização (classe Sinal) disparados ao selecionar
                                 aba e ao voltar de rotas do drawer — Home/Palpites/Ranking
                                 recarregam dados silenciosamente (sem perder scroll/rascunhos),
                                 corrigindo dados congelados pelo IndexedStack (ex: grupo Copa
                                 criado não exibia aba MODO COPA até reabrir o app);
                                 seção ADMIN com 5 itens; Sinal _sinalAbrirArtilharia conecta
                                 o card de artilharia da Home à aba ARTILHARIA da Tabela
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
                                 via callback onVerArtilharia)
      tela_login.dart         ← login e cadastro com design do Stitch; Google Sign-In com account linking
      tela_setup_perfil.dart  ← seleção de avatar no primeiro acesso (pós-cadastro);
                                 nome pré-preenchido com displayName do Google
      tela_perfil.dart        ← exibe/edita nome e avatar; alterar/definir senha; excluir
                                 conta; usuário Google-only (sem provedor password) define
                                 senha e exclui conta com reautenticação via Google
      tela_notificacoes.dart  ← toggles de preferência de notificação (lembrete / ranking)
      tela_palpites.dart      ← abas MODO CLÁSSICO/MODO COPA (condicionais) + sub-abas Próximos/Encerrados;
                                 auto-save com debounce de 1s nos cards de palpite (cadeado é
                                 indicador de status, não botão obrigatório); rascunhos não salvos
                                 preservados na troca de abas/modo (Clássico e Copa);
                                 MODO COPA: form de palpite de classificação dos 12 grupos;
                                 bloqueio do Modo Copa exclusivamente por palpitesTravados=true;
                                 card de resultado exibe "Avançou: [time]" quando jogo.vencedor != null;
                                 banner verde no topo quando palpitesTravados=true;
                                 filtros de jogos no Clássico: chips Por data (sub-abas) /
                                 Por rodada / Por grupo (seletor via BottomSheetOpcoes);
                                 rodada/grupo exibem lista mista (cards editáveis + resultados)
      tela_palpites_especiais.dart ← 5 palpites especiais com AppBar dourada (Cores.ouro);
                                 Campeão do Mundo: seletor de time (fora do card FIFA);
                                 card dourado "PREMIAÇÕES OFICIAIS FIFA" (Cores.ouro 8% alpha)
                                 engloba Chuteira de Ouro/Bola de Ouro/Luva de Ouro/Melhor
                                 Jogador Jovem; seletor de jogador via BottomSheetJogadores
                                 (cor: Cores.ouro); Luva de Ouro pré-filtra GOL; cada prêmio
                                 tem botão "?" que abre AlertDialog explicativo;
                                 bloqueio por palpitesTravados=true
      tela_ranking.dart       ← ranking filtrado por grupo com pódio e lista; chips para alternar grupos;
                                 dialog de palpites via CF buscarPalpitesUsuario (valida grupo em comum);
                                 filtro A–L + MATA-MATA, palpites especiais completos (5 campos)
                                 e suporte a Modo Copa; palpites Copa e Especiais ocultos até palpitesTravados=true;
                                 desempate 3 (campeão) e 4 (artilheiro) usam comparação case-insensitive
      tela_grupos.dart        ← lista grupos do usuário; criar grupo com seleção de modo CLÁSSICO/COPA;
                                 card exibe chip de modo; entrar com código; sair;
                                 tocar no card abre dialog de detalhes com membros e avatares;
                                 ícone de lápis (só dono) edita o nome do grupo
      tela_tabela.dart        ← 3 abas superiores JOGOS / CLASSIFICAÇÃO / ARTILHARIA (sempre
                                 visíveis); JOGOS: 104 jogos com filtros Por data (sub-abas
                                 Próximos/Encerrados) / Por rodada / Por grupo; cards exibem
                                 placar parcial da API em vermelho quando ao vivo;
                                 CLASSIFICAÇÃO: usa o standings oficial de api/classificacao
                                 quando existe, com fallback no cálculo local dos placares;
                                 ARTILHARIA: lista completa de api/artilharia (estado vazio
                                 até os primeiros gols);
                                 tocar em jogo encerrado abre dialog via CF buscarPalpitesJogo
                                 (palpites da união dos membros de todos os grupos do usuário)
      tela_admin_placares.dart ← inserção de placares com abas Próximos/Encerrados;
                                 em eliminatórias com empate abre dialog "Quem avançou?" para salvar
                                 o campo vencedor (pênaltis/prorrogação)
      tela_admin_copa.dart    ← classificação por grupo (1º/2º obrigatórios, 3º para 8 grupos);
                                 seção "Terceiros — 16 Avos" para alocar os 8 terceiros nos slots;
                                 ao salvar, atualiza automaticamente team1/team2 dos jogos 73–88
      tela_admin_especiais.dart ← resultados reais na mesma ordem da tela do usuário: Campeão,
                                 Artilheiro, Melhor Goleiro, Melhor Jogador, Mais Goleadora,
                                 Menos Vazada; seletor de jogador via BottomSheetJogadores
                                 (dialogos.dart, cor: verdePrincipal); seletor de time via
                                 _DialogSeletorTime (interno); botão SALVAR + botão CALCULAR
      tela_admin_definicoes.dart ← popular jogos, mapear jogos com a API (mapearJogosApi;
                                 rodar após popular), recalcular regras, limpar dados de
                                 teste, limpar órfãos; botão Travar/Destravar Palpites
                                 (grava palpitesTravados em config/copa2026)
      tela_admin_teste_api.dart ← simulação visual da integração football-data.org com dados
                                 fictícios no formato JSON real da API (status TIMED/IN_PLAY/
                                 PAUSED/FINISHED, prorrogação e pênaltis com check no
                                 classificado) + seção de artilharia; sem requisição/escrita
      tela_ajuda.dart         ← FAQ: pontuação Modo Clássico + multiplicadores de fase,
                                 pontuação Modo Copa, palpites especiais
    services/
      auth_service.dart       ← login Google (GIS na web / fluxo nativo no Android),
                                 vincularGoogle (account linking com conta e-mail/senha),
                                 reautenticarComGoogle (popup na web / seletor nativo no
                                 Android; usado por excluir conta e definir senha de
                                 usuário Google-only), inicializar, sair
      jogo_service.dart       ← popularJogosNoFirestore({bool teste}), buscarTodos, buscarPorData
      usuario_service.dart    ← criarPerfil, buscarPorUid, observarUsuario,
                                 atualizarNome, atualizarAvatar
      palpite_service.dart    ← salvar, buscarPorJogo, buscarTodosPorUsuario,
                                 buscarPorUsuario, buscarTodosPorJogo
      notificacoes_service.dart ← inicializar FCM, salvar token, buscar/atualizar prefs
      grupo_service.dart      ← criarGrupo({regra}), entrarComCodigo,
                                 buscarGruposDoUsuario (stream), buscarGruposDoUsuarioOnce (Future),
                                 sairDoGrupo, editarNome, buscarMembros;
                                 código único gerado com loop anti-colisão
      palpite_copa_service.dart ← buscarPorUid, salvar; armazena palpites de classificação
                                 de grupos em palpites_copa/{uid}
      api_dados_service.dart  ← buscarArtilharia (api/artilharia → List<Artilheiro>),
                                 buscarClassificacao (api/classificacao → mapa letra do
                                 grupo → List<ClassificacaoApiTime>; null se doc ausente —
                                 chamador usa fallback local)
    utils/
      cores.dart              ← constantes de cores; inclui Cores.error (vermelho),
                                 Cores.pont* (badges de pontuação), Cores.ouro/prata/bronze (pódio);
                                 nunca usar Color(0xFFB8860B) diretamente — usar Cores.ouro
      biblioteca.dart         ← funções utilitárias top-level: flagDe, siglaDe, isoDe,
                                 nomePtDe, formatarData, formatarCriadoEm, mostrarMensagem,
                                 mostrarRegras, ehPlaceholder, calcularPontos, multiplicadorFase,
                                 calcularPontosComFase, corPontuacao, corFundoPontuacao,
                                 corBordaPontuacao; widget Bandeira
      dialogos.dart           ← helpers de SnackBar (mostrarSnackBarSucesso/Erro/Info),
                                 DialogAmbiente (seleção Produção/Teste), JogadorData (model),
                                 BottomSheetJogadores (seletor de jogador com cor:) e
                                 mostrarSeletorOpcoes/BottomSheetOpcoes (seletor de opção
                                 única sem busca — filtros Por rodada/Por grupo)
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
                                 CardAvatar é StatefulWidget com flip 3D para avatares secretos
                                 (long-press revela foto *2.jpg)
  web/
    index.html              ← meta tags PWA iOS (apple-mobile-web-app-capable etc)
    manifest.json           ← PWA manifest (nome "Bolão - Crava aí!", tema #006D32)
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
- Funções utilitárias compartilhadas são declaradas como funções top-level em `biblioteca.dart` — padrão idiomático em Dart. Helpers de SnackBar e widgets de diálogo reutilizados ficam em `dialogos.dart`. Cores centralizadas em `cores.dart` — nunca hardcodar valores de cor nas telas.
- Comunicação de filho para pai via callback (`void Function(int)`) — o `MenuPrincipal` passa `onNavegar` para a `TelaHome`
- Cálculo de pontuação feito na Cloud Function `calcularPontuacao` (trigger Firestore) — admin insere placar pelo app, função recalcula pontos e envia notificações de ranking
- Palpites precarregados em lote (`buscarTodosPorUsuario`) ao abrir a tela, sem query individual por card
- Notificações via FCM: `lembretesPalpite` (scheduled `*/30min`) + `calcularPontuacao` envia ranking change. Token salvo no campo `fcmToken` do documento do usuário
- Bandeiras exibidas como imagens reais via pacote `country_flags` (não emojis); mapeamento de nome → ISO em `isoDe()`
- Integração football-data.org server-side: o app NUNCA chama a API (repositório público) — fluxo API → Cloud Function `sincronizarApi` (agendada a cada 2 min com "janela inteligente": fora da janela de jogos encerra com 1 query ao Firestore, sem requisição; dentro dela no máx. 3 requisições) → Firestore → app. Chave no secret `FOOTBALL_DATA_KEY`. De-para jogo↔API no campo `apiId` (callable admin `mapearJogosApi`, cruzamento por data/hora UTC + fase + grupo com nomes como desempate; aliases: "Czechia"→"Czech Republic", "Bosnia-Herzegovina"→"Bosnia & Herzegovina", "United States"→"USA"). Placar parcial em `placarAoVivo1/2` + `statusApi` (JAMAIS em `placar1/2`); placar final (FINISHED, `score.regularTime` — regra dos 90 min) dispara o trigger `calcularPontuacao` como a inserção manual; a função compara antes de escrever e nunca sobrescreve placar do admin (tela de placares segue como override). A partir dos 16 avos, define os confrontos: preenche `team1/team2` dos jogos com placeholder nas próximas 72h assim que a API publica os times reais (nunca sobrescreve time já definido pela propagação da chave, Admin Copa ou ajuste manual)
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
- `AppBar` fundo branco, ícone de menu + título dinâmico (verde) + botão de regras
- `IndexedStack` com as 4 telas como filhos (scroll preservado entre abas); `Scaffold` transparente sobre `Container(color: Cores.background)`
- `NavigationBar` verde (`Cores.verdePrincipal`), ícones/labels brancos, indicador amarelo (`Cores.secondaryContainer`), estilizado via `NavigationBarTheme`

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
- Cabeçalho com animação de fundo (`assets/background-cards/cabecalho.webp`, WebP animado, `BoxFit.cover`) e conteúdo sobreposto via `Stack`: card glassmorphism (`ClipRRect` + `BackdropFilter` blur 10px + branco 18% alpha + borda branca 35% alpha) envolvendo avatar, nome e pontuação Clássico
- Seção "CONTA": Meu Perfil → `TelaPerfil`; Notificações → `TelaNotificacoes`
- Seção "GRUPOS": Meus Grupos → `TelaGrupos`
- Seção "ADMIN" (só para `isAdmin == true`), 5 itens: Placares — Reg. Clássica → `TelaAdminPlacares`; Classificação — Reg. Copa → `TelaAdminCopa`; Palpites Especiais → `TelaAdminEspeciais`; Outras Definições → `TelaAdminDefinicoes`; Teste de API → `TelaAdminTesteApi`
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
uid             : String
email           : String
nome                   : String
pontuacaoClassica      : Number    — fase de grupos Clássico + penalidades; começa em 0
pontuacaoCopa          : Number    — fase de grupos Copa (SET por recalcularCopa); começa em 0
pontuacaoEliminatorias : Number    — mata-mata; compartilhado pelos dois modos; começa em 0
pontuacaoEspeciais     : Number    — palpites especiais; compartilhado pelos dois modos; começa em 0
placaresExatos         : Number    — desempate 1: quantidade de placares exatos acertados; começa em 0
palpitesPerdidos       : Number    — desempate 2: jogos não palpitados (cada um gera −10 pts); começa em 0
criadoEm               : Timestamp
avatar          : String?   — id do jogador selecionado no setup de perfil
isAdmin         : Boolean   — campo opcional; adicionado manualmente no Console
fcmToken        : String?   — token FCM do dispositivo; salvo pelo NotificacoesService
notifLembretes     : Boolean?  — padrão true quando ausente
notifRanking       : Boolean?  — padrão true quando ausente
palpiteCampeao         : String?   — nome em inglês do time (ex: "Brazil")
palpiteChuteiradeOuro  : String?   — nome livre do artilheiro (Chuteira de Ouro)
palpiteBoladeOuro      : String?   — nome livre do melhor jogador (Bola de Ouro)
palpiteLuvadeOuro      : String?   — nome livre do melhor goleiro (Luva de Ouro)
palpiteMelhorJovem     : String?   — nome livre do melhor jogador jovem (sub-21)
— todos bloqueados quando palpitesTravados=true; salvos via UsuarioService.salvarPalpitesEspeciais
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

### `grupos`
ID do documento = auto-ID gerado pelo Firestore.

```
nome        : String
codigo      : String    — 6 chars maiúsculos/números; único; gerado com loop anti-colisão
donoUid     : String    — UID de quem criou o grupo
membros     : Array<String>  — lista de UIDs; gerenciado via arrayUnion / arrayRemove
criadoEm    : Timestamp — serverTimestamp(); nullable no cache local → model usa DateTime?
```

**Busca de grupos do usuário:** `where('membros', arrayContains: uid)` — sem índice composto necessário (sem orderBy). Ordenação feita client-side por `criadoEm`.

### `config`
ID do documento = `copa2026` (documento único).

```
campeaoReal                  : String?   — nome em inglês do campeão real (ex: "Brazil")
chuteiradeOuroReal           : String?   — artilheiro real (comparação case-insensitive)
boladeOuroReal               : String?   — melhor jogador real (Bola de Ouro FIFA)
luvadeOuroReal               : String?   — melhor goleiro real (Luva de Ouro FIFA)
melhorJovemReal              : String?   — melhor jogador jovem real (sub-21, FIFA)
palpitesEspeciaisCalculados  : Boolean   — true após executar calcularPalpitesEspeciais; impede execução dupla
classificacao_real           : Map       — { "A": { "primeiro": "Brazil", "segundo": "Mexico", "terceiro": "..." }, ... }
terceiros_classificados      : Map       — alocação dos 8 terceiros nos slots dos 16 avos
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

Pontos base (Fase de Grupos), multiplicados pelo fator de fase:

```dart
int _calcularPontos(int p1, int p2, int r1, int r2) {
  if (p1 == r1 && p2 == r2) return 100; // placar exato
  final sP = p1 - p2, sR = r1 - r2;
  final vP = p1.compareTo(p2), vR = r1.compareTo(r2);
  if (vP != vR) return 0;
  if (vP != 0) {
    if (sP == sR) return 70;              // vencedor + saldo de gols
    if (p1 == r1 || p2 == r2) return 60; // vencedor + gols exatos de um time
    return 50;                            // só o vencedor
  }
  return 50; // empate certo, placar errado
}
```

Multiplicadores por fase:
- Fase de Grupos: ×1.0
- 16 avos de Final: ×1.2
- Oitavas de Final: ×1.4
- Quartas de Final: ×1.6
- Semifinal + Disputa de 3º Lugar: ×1.8
- Final: ×2.0

Punição: −10 pts por jogo não palpitado após o `criadoEm` do usuário. Jogos anteriores ao cadastro não geram penalidade.

**Regra dos 90 minutos (eliminatórias):** para pontuação vale sempre o placar dos 90 minutos. Vitória na prorrogação ou nos pênaltis é registrada como empate nos 90 + campo `vencedor` (quem avançou). A `sincronizarApi` implementa isso usando `score.regularTime` (nunca `fullTime`, que inclui prorrogação) e preenchendo `vencedor` a partir de `score.winner` quando os 90 min empatam.

### Palpites Especiais (calculados uma vez após o torneio)
- Campeão do Mundo: +500
- Chuteira de Ouro (artilheiro): +300
- Bola de Ouro (melhor jogador, eleito pela FIFA): +300
- Luva de Ouro (melhor goleiro, eleito pela FIFA): +300
- Melhor Jogador Jovem (sub-21, eleito pela FIFA): +200

Times comparados por nome exato em inglês. Pessoas (artilheiro, melhor jogador, goleiro) comparadas com flexibilidade (case-insensitive, trim).

### Modo Copa — palpite na classificação de grupos
- Posição exata (1º, 2º ou 3º): +200 por time
- Classificou mas posição errada: +100 por time
- Time não classificou: 0
- Bônus se acertou todas as posições do grupo: +100

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
- Cadastro: cria conta no Auth + perfil no Firestore via `UsuarioService`
- Navegação por Enter: Enter no e-mail move o foco para a senha; Enter na senha submete o formulário
- Botão "Fazer login com o Google":
  - **Web/PWA:** botão oficial GIS via `renderButton()` de `google_sign_in_web/web_only.dart`
    (type: standard, theme: outline, size: large, text: signinWith, shape: rectangular).
    Renderizado num `LayoutBuilder` → `ConstrainedBox(minHeight: 40)` → `Stack`, passando a
    largura disponível como `minimumWidth`. O plugin é inicializado em `initState` via
    `AuthService().inicializar()` (chama `signInSilently`) — sem isso a Future `initialized`
    dentro de `renderButton()` nunca completa e o botão não aparece.
  - **Android/Mobile:** `OutlinedButton` estilizado replicando as specs do GIS (borda `#747775`,
    `borderRadius: 4`, logo via `CustomPainter`, texto "Fazer login com o Google") → chama
    `AuthService().entrarComGoogle()` (fluxo nativo).
- Account linking: se o e-mail Google já existe com senha, exibe `_DialogVincularConta` que faz login com senha e chama `linkWithCredential`

### `tela_setup_perfil.dart` — implementada
- Exibida após cadastro, antes de entrar no app
- Seleção de avatar obrigatória (grid de jogadores)
- Salva `avatar` no Firestore via `UsuarioService.atualizarAvatar`
- Nome pré-preenchido com `user.displayName` (Google) quando disponível

### `tela_home.dart` — implementada
- **Hero card verde** (oculto quando sem grupos ou pontuação zerada): ticker marquee seamless com a posição do usuário em cada grupo ("1º no CLASSICO TESTE | 2º no COPA TESTE"), usando `SingleChildScrollView` horizontal + conteúdo duplicado (jumpTo invisível). Pontuação Clássico (★) à esquerda e Copa (🏆) à direita. Card aparece somente após algum resultado ser registrado (pontuação > 0)
- Título da aba Home: `'CRAVA AÍ!'` (antes `'COPA 2026'`, alterado em `menu_principal.dart`)
- Seção "JOGOS DE HOJE": label compacto + carrossel horizontal com `_CardJogo` (AO VIVO / ENCERRADO). Estado vazio exibido como linha inline (ícone + texto). Sem botão "VER TODOS"
- 3 cards de ação em coluna vertical, mesma largura (full-width menos 32dp): PALPITES, RANKING, PALPITES ESPECIAIS. Cada card usa `_CardAcao` com imagem de fundo (`assets/background-cards/` via `DecorationImage` + `BoxFit.cover`), texto branco em `GoogleFonts.anybody` sem emoji. Navega para índice 1, 2 e `TelaPalpitesEspeciais` respectivamente.
- Card **ARTILHARIA** (top 5 de `kArtilhariaSimulada`, pódio ouro/prata/bronze) abaixo dos cards de ação; tocar navega para a tela Tabela já na aba ARTILHARIA (callback `onVerArtilharia` + `Sinal _sinalAbrirArtilharia` no `MenuPrincipal`)
- Callbacks `onNavegar` e `onVerArtilharia` recebidos do `MenuPrincipal`

### `tela_tabela.dart` — implementada
- 3 abas superiores **JOGOS / CLASSIFICAÇÃO / ARTILHARIA** (faixa verde com abas brancas, sempre visíveis para todos os usuários; `sinalAbrirArtilharia` permite a Home abrir direto a ARTILHARIA)
- JOGOS: chips de filtro **Por data / Por rodada / Por grupo** — Por data usa sub-abas Próximos/Encerrados (card segmentado verde-suave com seleção branca e contadores); Por rodada/Por grupo usam campo seletor que abre `BottomSheetOpcoes`
- Cards de jogo no estilo novo (brancos, sombra suave, raio 16, sem borda); placar em texto puro ("— x —" antes de encerrar, sem indicador de ao vivo); data·local centralizados no topo; bandeiras 36px em círculo e nomes em português (`nomePtDe`)
- CLASSIFICAÇÃO: 12 tabelas de grupo calculadas em tempo real dos placares inseridos (critérios FIFA: pontos > saldo > gols pró), colunas J/SG/PTS, destaque verde no 1º/2º; seletor "Todos os grupos" / Grupo A–L
- ARTILHARIA: lista completa de `kArtilhariaSimulada` (placeholder do endpoint /scorers da API)
- `CustomScrollView` com slivers agrupados por seção; RefreshIndicator (pull-to-refresh)
- Tocar em um jogo encerrado abre dialog com todos os palpites registrados, ordenados por pontuação; cada linha mostra posição, avatar, nome, palpite e badge de pontos

### `tela_palpites.dart` — implementada
- **Abas superiores MODO CLÁSSICO / MODO COPA** (verde, só visíveis quando usuário tem grupos dos dois modos E Fase de Grupos ativa); sub-abas **Próximos** / **Encerrados** dentro de cada modo (card segmentado verde-suave com seleção branca e contadores)
- **Filtros de jogos no MODO CLÁSSICO:** chips **Por data | Por rodada | Por grupo** — Por data mantém as sub-abas; Por rodada/Por grupo abrem seletor (`BottomSheetOpcoes`) e exibem lista mista (cards de palpite editáveis + cards de resultado) agrupada por data
- **Cards no estilo novo:** brancos com sombra suave sobre `Cores.background`; a borda do card sinaliza o estado (verde = salvo, amarela = pendente, sem borda = vazio); as caixas de placar têm visual neutro sempre (não mudam de cor ao salvar)
- **MODO CLÁSSICO:** palpite de placar nos jogos da Fase de Grupos (id 1–72)
- **Auto-save com debounce:** quando os dois placares estão preenchidos, o palpite é salvo automaticamente 1s após o usuário parar de digitar (ou imediatamente ao pressionar Enter / tocar no cadeado). O cadeado é indicador de status — fechado verde = salvo, aberto amarelo (`Cores.secondaryContainer` na borda) = digitado mas não salvo, aberto cinza = vazio. Campos sempre editáveis até o cutoff de 5 min. SnackBar verde confirma cada save ("Palpite salvo: Brasil 2 × 1 México")
- **Rascunhos preservados:** valores digitados e ainda não salvos vivem em `Map<int, ({String p1, String p2})>` no state do pai (`_TelaPalpitesState._rascunhos`) — sobrevivem à troca de sub-aba e de modo. O form do Modo Copa registra a referência de `_local` no pai (`_copaRascunho`) com o mesmo efeito. Como rede final, o `dispose()` do card dispara um save fire-and-forget se houver palpite completo não salvo
- **MODO COPA:** formulário de palpite de classificação dos 12 grupos A–L com dropdowns 1º/2º/3º; FAB quadrado "SALVAR" no canto inferior direito; bloqueado quando `palpitesTravados=true`
- **Detecção automática de fim da Fase de Grupos:** quando jogos 73+ têm times reais (sem placeholder), abas de modo somem e todos os jogos restantes aparecem em único Próximos/Encerrados
- `Future.wait` carrega jogos + palpites + perfil + grupos em paralelo; palpites Copa em bloco separado com try-catch próprio para não bloquear o resto em caso de erro de permissão
- `buscarGruposDoUsuarioOnce()` usa `.get()` direto (evita bug de emissão vazia do cache do Firestore)
- `Timer.periodic(30s)` reclassifica jogos automaticamente
- **Penalidade −10 pts:** jogo encerrado sem palpite cujo `dataHora > criadoEm` → card vermelho + badge "−10 pts"
- **Navegação por Enter** entre campos de gol; `_AbaProximos` gerencia `FocusNode` por card
- Pontos exibidos com multiplicador de fase (×1.0 a ×2.0); cores dos badges baseadas em `pontosBase`

### `tela_ranking.dart` — implementada
- Ranking filtrado por grupo — não existe ranking global; sem cabeçalho de título — a tela começa direto no seletor de grupos
- `StatefulWidget` com dois `StreamBuilder` aninhados: grupos do usuário (outer) + todos os usuários ordenados por pontuação (inner); filtragem client-side por `grupo.membros`
- Usuário sem grupos → mensagem orientando a criar/entrar via Meus Grupos
- Usuário com 1 grupo → ranking desse grupo, sem seletor
- Usuário com 2+ grupos → chips no topo para alternar; seleção explícita em `_grupoSelecionado`; se grupo selecionado sair da lista, volta automaticamente para o primeiro
- Pódio visual para top 3: avatar real (foto do jogador via `WidgetAvatar`); fundo do degrau `Cores.ouro` (1º) / `Cores.prata` (2º) / `Cores.bronze` (3º)
- Lista para 4º em diante com avatar real; usuário logado destacado com borda verde
- Tocar em qualquer card (pódio ou lista) abre `_DialogPalpitesUsuario`:
  - Cabeçalho verde (Clássico) ou azul (Copa) com avatar + nome
  - Bloco de Palpites Especiais (6 campos: campeão, artilheiro, goleiro, melhor jogador, mais goleadora, menos vazada) — visível somente após `palpitesTravados=true`
  - Filtro de chips A–L + chip MATA-MATA (aparece quando admin registra pelo menos um jogo 73+)
  - **Modo Clássico + grupo A–L:** lista os 6 jogos daquele grupo com placar real, palpite e badge de pontos (só jogos com placar registrado)
  - **Modo Copa + grupo A–L:** 3 posições palpitadas; se classificação real salva, mostra seta/check por posição, badge de pontos e linha de bônus (+100 se grupo perfeito) — visível somente após `palpitesTravados=true`
  - **MATA-MATA (ambos os modos):** palpites de placar exato dos jogos 73–104 com resultado registrado

### `tela_grupos.dart` — implementada (acesso via drawer → GRUPOS → Meus Grupos)
- `StreamBuilder` em `GrupoService().buscarGruposDoUsuario(uid)` → lista reativa de grupos
- Cada card: nome, chip de modo (verde=CLÁSSICO, azul=COPA), código de 6 chars, badge "ADMIN" se for o dono
- **Tocar no card** abre `_DialogDetalhesGrupo`: cabeçalho verde com nome e código copiável; lista de membros com `WidgetAvatar` + nome; `FutureBuilder` em `GrupoService().buscarMembros(uids)`
- **Ícone de lápis** no card (só visível para o dono) abre `_DialogEditarNome`
- **Criar grupo**: dialog com campo nome + seleção de modo CLÁSSICO/COPA (chips iguais em altura via `IntrinsicHeight`) → `GrupoService.criarGrupo({regra})` → dialog exibe código gerado
- **Entrar com código**: dialog com campo de 6 chars → `GrupoService.entrarComCodigo`
- **Sair do grupo**: dialog de confirmação; grupo deletado automaticamente se ficar sem membros

### `tela_admin.dart` — **REMOVIDA** (substituída pelas 4 telas admin especializadas)
- Ao salvar: atualiza `placar1`/`placar2` no Firestore → Cloud Function `calcularPontuacao` dispara automaticamente
- Botão de popular jogos abre dialog pedindo **Teste** (`jogos_teste.json`) ou **Produção** (`jogos.json`)
- Botão de recalcular chama a Cloud Function `recalcularTudo` (admin only)
- Botão de vassoura (`delete_sweep`) chama `limparUsuariosOrfaos`: remove docs `usuarios` sem conta Auth + palpites cujo uid não existe em `usuarios`; exibe contagem de usuários e palpites removidos
- **Seção Palpites Especiais** no topo: seletor de campeão real com bandeiras e nomes em PT (filtra placeholders com dígitos, ordena ignorando acentos); campo de artilheiro (texto livre); botão SALVAR grava em `config/copa2026`; botão CALCULAR chama `calcularPalpitesEspeciais` (irreversível, desabilitado após execução); `resizeToAvoidBottomInset: false` evita overflow ao abrir teclado

### `tela_perfil.dart` — implementada
- Exibe avatar do jogador com botão de troca (bottom sheet grid)
- Card de pontuação verde exibe ★ Clássico (esquerda) e 🏆 Copa (direita), mesmo padrão visual do hero card da home
- Edição de nome inline via dialog
- Alterar senha: dialog com senha atual + nova senha + confirmação + reautenticação
- Excluir conta: dialog com senha para confirmação; remove doc Firestore + conta Auth
- Detecção de provedor via `user.providerData` (getter `_temSenha`): usuário Google-only (sem provedor `password`) vê **"Definir senha"** no lugar de "Alterar senha" — dialog explica que não há senha criada e chama `updatePassword` direto (se `requires-recent-login`, reautentica via `AuthService.reautenticarComGoogle()` e tenta de novo); após criar, `user.reload()` e o item vira "Alterar senha"
- Excluir conta para usuário Google-only: dialog sem campo de senha avisa que a exclusão é imediata e que pode ser exigida reautenticação com a conta Google; confirma via `reautenticarComGoogle()` (cancelar o seletor aborta sem excluir; conta Google diferente → erro `user-mismatch` traduzido)

### `tela_notificacoes.dart` — implementada
- Toggle **Lembrete de palpite**: notificação 30 min antes de jogos sem palpite
- Toggle **Mudança no ranking**: notificação quando posição no ranking muda
- Prefs salvas nos campos `notifLembretes` / `notifRanking` do documento do usuário
- Auto-save a cada toggle

### `tela_ajuda.dart` — implementada
- FAQ com `ExpansionTile` e badges de pontuação
- Seção PONTUAÇÃO — MODO CLÁSSICO: tabela de pontos + card de multiplicadores de fase
- Seção PONTUAÇÃO — MODO COPA: regras de classificação de grupos
- Seção PALPITES ESPECIAIS: lista de premiações

---

## avatares.dart — widgets e dados compartilhados

```dart
// Lista dos 12 jogadores da seção PRINCIPAIS
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

// Exibe foto do jogador em círculo; fallback: inicial do nome
WidgetAvatar(avatarId: usuario.avatar, nome: usuario.nome, tamanho: 64)

// Card de seleção com borda verde, check quando selecionado e flip 3D em long-press
// Interface nova (StatefulWidget):
CardAvatar(jogador: jogador, avatarSelecionadoId: _avatarSelecionado, onTap: (id) { ... })
// Long-press revela assets/avatares/{id}2.jpg se existir

// Grade com abas lado a lado PRINCIPAIS / BRASIL 2026 (alterna a grade
// exibida; abre na aba do avatar selecionado) — usada em tela_setup_perfil
// e no bottom sheet de troca de avatar da tela_perfil;
// não rola sozinha (colocar dentro de um scroll do chamador)
GradeAvataresSecionada(avatarSelecionadoId: _avatarSelecionado, onTap: (id) { ... })
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

**Nota sobre índices:** `buscarPorUsuario` usa `where + orderBy` em campos diferentes → Firestore exige índice composto. O índice está versionado em `firestore.indexes.json` e é deployado com `firebase deploy --only firestore`.

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
`FieldValue.serverTimestamp()` chega como `null` no cache local antes de o servidor responder. Corrigido tornando `criadoEm` nullable (`DateTime?`) no model `Palpite`. O mesmo padrão foi aplicado em `Grupo.fromMap` com fallback para `DateTime.now()`.

### Flash de MenuPrincipal durante cadastro
`authStateChanges` disparava ao criar a conta Firebase, exibindo `MenuPrincipal` brevemente antes do setup. Corrigido fazendo o roteamento levar em conta a existência do perfil Firestore, não só o auth.

### Botão GIS do Google sumindo em produção (web release)
O botão oficial "Fazer login com o Google" aparecia em debug (`flutter run -d chrome`) mas **não** no build release publicado (`flutter build web` → Hosting). No console de produção: `TypeError: ... type 'X' is not a subtype of type 'Y'`. Causa: o **registrant de plugin web ficou desatualizado**, deixando `GoogleSignInPlatform.instance` como a instância default em vez de `GoogleSignInPlugin` — então o cast dentro de `renderButton()` estourava e o botão não renderizava (em debug o registrant é regenerado por outro caminho, mascarando o problema). **Corrigido com `flutter clean` + `flutter pub get` + rebuild**, que regenera o registrant. Lição: ao mexer em plugins que dependem de registro de plataforma na web, sempre `flutter clean` antes de validar o release. Também migrado para a API oficial `renderButton` de `google_sign_in_web/web_only.dart` e adicionada a inicialização do plugin em `initState`.

### Logout a cada reabertura do app Android (builds da Play Store)
Usuários relatavam que precisavam logar novamente toda vez que abriam o app instalado pela Play Store. O diagnóstico revelou **duas causas encadeadas**:

1. **R8 full mode** (padrão desde o AGP 8.0; o projeto usa 8.7.0): com `isMinifyEnabled = true`, o full mode remove/renomeia código acessado por reflexão — o caminho que o Firebase Auth usa para serializar/desserializar o JSON da sessão salva no aparelho. A leitura falhava (`JSONArray[0] not a string` — [firebase-android-sdk#6375](https://github.com/firebase/firebase-android-sdk/issues/6375)), o SDK concluía que não havia usuário e `authStateChanges()` emitia `null` → tela de login. Corrigido com **`android.enableR8.fullMode=false` em `android/gradle.properties`** — o R8 continua ligado (minificação + ofuscação + shrink), apenas no modo compatível.

2. **Auto Backup do Android** (`allowBackup`, padrão `true`): o Google fez backup em nuvem dos dados do app na era do bug. Toda instalação **via Play Store** dispara "restore at install", restaurando o snapshot com estado de auth corrompido — que impedia a gravação de novas sessões **mesmo com o binário já corrigido** (login OK em memória, mas nada persistido: na reabertura o FirebaseAuth inicializava em silêncio, sem usuário e sem erro). Instalação via cabo/adb **não** dispara restore — por isso o APK local de teste funcionava enquanto a mesma versão da loja falhava, o que quase derrubou o diagnóstico. Evidências: `adb logcat` (segundo start sem nenhuma linha do FirebaseAuth) e `adb shell dumpsys backup` (evento "Full restore" do pacote em cada install via Play). Corrigido com **`android:allowBackup="false"` no AndroidManifest** — nada local vale backup, todos os dados vivem no Firestore. Aparelhos já afetados saneiam com "Limpar dados" do app (ou desinstalar/reinstalar a versão com a correção).

Lições: (a) testar correção de release **pelo mesmo canal de distribuição** dos usuários — APK via cabo não passa pelo restore da loja; (b) `dumpsys backup` mostra o histórico de restores; (c) instalar APK local por cima da versão da loja exige desinstalar antes (assinaturas diferentes — upload keystore × Play App Signing).

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
- `WidgetsBinding.instance.addPostFrameCallback` para evitar conflito de setState
- `@pragma('vm:entry-point')` — necessário para funções top-level chamadas pelo runtime nativo (ex: handler de background do FCM)
- `FirebaseMessaging.onBackgroundMessage` — registra handler para mensagens com app fechado; deve ser top-level
- `FirebaseMessaging.onMessage` — stream de mensagens com app em foreground (não exibe notificação automaticamente)
- `EmailAuthProvider.credential` + `reauthenticateWithCredential` — reautenticação necessária para operações sensíveis (updatePassword, delete)
- Converter `StatelessWidget` em `StatefulWidget` — padrão quando um widget filho precisa de estado próprio (ex: `_PerfilConteudo`)
- `showDialog<T>` retornando valor via `Navigator.of(ctx).pop(valor)` — comunicação do dialog de volta ao chamador
- `FocusNode` + `FocusScope.of(context).requestFocus()` — navegação programática entre campos de texto
- `TextInputAction.next` / `.done` + `onSubmitted` — ação do botão Enter no teclado virtual
- `FocusNode` compartilhado entre pai e filho — pai cria o nó, filho usa como `focusNode` no `TextField`; permite que o pai solicite foco externamente
- Gerenciar lista de `FocusNode` em `StatefulWidget` com `didUpdateWidget` para recriar nós quando o número de itens muda
- `CountryFlag.fromCountryCode(iso, height: h, width: w)` do pacote `country_flags` — renderiza bandeiras como imagens SVG por código ISO 3166-1 alpha-2; suporta subdivisões como `GB-ENG`, `GB-WLS`, `GB-SCT`
- `Container.clipBehavior: Clip.antiAlias` com `BoxDecoration(shape: BoxShape.circle)` — recorta o filho (ex: imagem de bandeira) em formato circular
- `country_flags 4.x`: API mudou — tamanho agora vai dentro de `ImageTheme(width, height)` em vez de parâmetros diretos; suporta nativamente subdivisões do Reino Unido (`GB-ENG`, `GB-SCT`, `GB-WLS`); não precisa mais de `FittedBox` com zoom
- `FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge)` com `CountryFlag(width: tamanho * 2.2)` — força bandeira a preencher o círculo sem letterboxing (largura 2.2× garante que flags até 2:1 preencham a altura)
- `FirebaseMessaging.onMessageOpenedApp` — stream disparado quando usuário toca na notificação com app em background; `getInitialMessage()` — recupera notificação que abriu o app quando estava fechado; usados juntos para deep linking FCM
- `Flexible` dentro de `Row` — permite que o filho encolha e use `TextOverflow.ellipsis` sem estourar o layout; essencial em cabeçalhos de dialog com nomes longos ao lado de widgets de tamanho fixo (bandeiras, placar)
- `kIsWeb` de `package:flutter/foundation.dart` — guard para código não suportado na web (ex: `FirebaseMessaging.onBackgroundMessage`, FCM token registration)
- Flutter web: `flutter create --platforms web .` cria a pasta `web/` com boilerplate; `manifest.json` configura nome/ícone/tema; meta tags iOS habilitam "Adicionar à Tela de Início" no Safari
- `firebase deploy --only hosting --project <id>` — deploya `build/web` no Firebase Hosting
- `calcularPontos()` em `biblioteca.dart` — função pública compartilhada; os dialogs de palpites a usam para calcular badges de pontuação
- `FieldValue.arrayUnion([value])` / `arrayRemove([value])` — adiciona/remove elemento de array no Firestore de forma atômica, sem sobrescrever o array inteiro; idempotente (arrayUnion não duplica)
- `Color.withValues(alpha: x)` — substituto de `withOpacity(x)` a partir do Flutter 3.27; opera em precisão de ponto flutuante completa em vez de converter para 8 bits
- Catch genérico `catch (_)` engole exceções silenciosamente — usar `catch (e)` e exibir `$e` no SnackBar durante desenvolvimento para ver o erro real
- `Exception('ja_membro')` + `e.toString().contains('ja_membro')` — padrão simples para distinguir casos de erro sem criar classes de exceção customizadas

---

## Cloud Functions — visão geral

Deployadas na região `southamerica-east1`. Arquivo: `functions/index.js` (Node 22).

| Função | Tipo | O que faz |
|---|---|---|
| `calcularPontuacao` | Firestore trigger (`jogos/{jogoId}`) | Jogos 1–72 → incrementa `pontuacaoClassica`; jogos 73–104 → incrementa `pontuacaoEliminatorias`; aplica −10 para ausências; mantém `placaresExatos` e `palpitesPerdidos`; envia FCM de ranking; propaga vencedor/perdedor |
| `lembretesPalpite` | Schedule (`*/30 * * * *`) | Notifica usuários sem palpite em jogos que começam em ~30 min |
| `recalcularTudo` | HTTPS Callable (admin only) | Recalcula `pontuacaoClassica`, `pontuacaoEliminatorias`, `placaresExatos` e `palpitesPerdidos` do zero. Não toca em `pontuacaoEspeciais` nem `pontuacaoCopa`. |
| `membroEntrou` | Firestore trigger (`grupos/{grupoId}`) | Detecta novo membro no array `membros` e envia FCM para o dono do grupo |
| `calcularPalpitesEspeciais` | HTTPS Callable (admin only) | Grava resultados reais e aplica pontos em `pontuacaoEspeciais`; marca `palpitesEspeciaisCalculados: true`. Botão CALCULAR sempre salva antes de chamar. |
| `recalcularCopa` | HTTPS Callable (admin only) | Calcula pontos Copa fase de grupos (SET em `pontuacaoCopa`); marca `copaGruposCalculado: true` |
| `limparUsuariosOrfaos` | HTTPS Callable (admin only) | Remove docs `usuarios` sem conta Auth + palpites órfãos; tira UIDs órfãos dos arrays `membros` dos grupos (deleta grupos que ficarem vazios; transfere a posse se o dono era órfão) |
| `limparDadosTeste` | HTTPS Callable (admin only) | Reseta placares, times eliminatórias, classificação, `pontuacaoClassica`, `pontuacaoCopa`, `pontuacaoEliminatorias`, `pontuacaoEspeciais`, `placaresExatos`, `palpitesPerdidos`, flags e os campos da API (`statusApi`, `placarAoVivo1/2`, `placarDecisao1/2` — `apiId` é preservado); palpites preservados |
| `buscarPalpitesJogo` | HTTPS Callable | Retorna palpites de um jogo encerrado filtrados pelos membros dos grupos do solicitante (união). Usado pelo dialog da `tela_tabela`. |
| `buscarPalpitesUsuario` | HTTPS Callable | Retorna palpites clássicos + Copa de um usuário, validando grupo em comum com o solicitante. Usado pelo dialog do `tela_ranking`. |
| `sincronizarApi` | Schedule (`*/2 * * * *`, secret FOOTBALL_DATA_KEY) | Janela inteligente: só chama a football-data.org quando há jogo ativo (início −20 min a +5h, sem placar final) ou eliminatória com placeholder nas próximas 72h. Grava `statusApi` + `placarAoVivo1/2` durante o jogo; no FINISHED grava `placar1/2` (`score.regularTime` — regra dos 90 min) + `vencedor` (`score.winner` em empate nos 90) + `placarDecisao1/2` (pênaltis ou placar final da prorrogação), disparando o trigger `calcularPontuacao`. Define os confrontos das eliminatórias preenchendo `team1/team2` onde ainda há placeholder (nunca sobrescreve time definido). Compara antes de escrever; não sobrescreve placar inserido pelo admin. Quando algum jogo termina, atualiza `api/classificacao` e `api/artilharia`. Mapeia `apiId` pendentes quando os times ficam definidos. |
| `mapearJogosApi` | HTTPS Callable (admin only, secret FOOTBALL_DATA_KEY) | De-para permanente jogo↔API: grava `apiId` em cada doc de `jogos` cruzando data/hora UTC + fase + grupo (nomes de time como desempate, com aliases para grafias divergentes). Retorna `{mapeados, pendentes}`. Também grava a primeira foto de `api/classificacao` e `api/artilharia`. Rodar uma vez — e novamente após Popular Jogos. |

**FCM token management:** token salvo em `usuarios/{uid}.fcmToken`. Tokens inválidos são removidos automaticamente (`messaging/registration-token-not-registered`).

**Deep linking via notificação:** payload FCM inclui `data: { tela: 'palpites' }` (lembrete), `data: { tela: 'ranking' }` (ranking) ou `data: { tela: 'grupos' }` (novo membro). `MenuPrincipal` lê esse campo em `onMessageOpenedApp`, `getInitialMessage` e no `onMessage` (SnackBar com botão VER) para navegar para a aba correta.

---

## Segurança do Firestore

Regras em `firestore.rules`, índice composto em `firestore.indexes.json`. Deploy: `firebase deploy --only firestore --project bolaodasoci2026`.

**`usuarios`**
- `read`: qualquer autenticado (ranking, drawer, dialogs)
- `create`: só o próprio usuário; payload restrito a `['uid', 'email', 'nome', 'pontuacao', 'criadoEm', 'avatar']`; `isAdmin` e `pontuacao` devem ser `false`/`0` — impede escalada de privilégio
- `update`: só campos de perfil, FCM, preferências e palpites especiais (`palpiteCampeao`, `palpiteChuteiradeOuro`, `palpiteBoladeOuro`, `palpiteLuvadeOuro`, `palpiteMelhorJovem`); `pontuacao`, `isAdmin`, `criadoEm`, `email`, `uid` protegidos (alterados apenas pelo Admin SDK da Cloud Function)
- `delete`: só o próprio usuário (exclusão de conta)

**`jogos`**
- `read`: qualquer autenticado
- `write`: só admin (verificado via `get()` no documento do usuário)

**`palpites`**
- `read`: só o próprio dono (`request.auth.uid == resource.data.uid`); leitura de palpites alheios feita exclusivamente via Cloud Functions (`buscarPalpitesJogo`, `buscarPalpitesUsuario`) que rodam com Admin SDK e aplicam filtro de grupo em comum
- `create`: dono do palpite + `request.time < jogo.dataHora` (cutoff no backend, não só no frontend)
- `update`: dono + `uid`/`jogoId` imutáveis + jogo não iniciado
- `delete`: bloqueado

**`config`**
- `read`: qualquer autenticado
- `write`: só admin — usado para gravar `campeaoReal`, `chuteiradeOuroReal`, `boladeOuroReal`, `luvadeOuroReal`, `melhorJovemReal` e `palpitesEspeciaisCalculados` em `config/copa2026`

**`palpites_copa`**
- `read`: só o próprio usuário; leitura por terceiros via Cloud Function `buscarPalpitesUsuario` (Admin SDK)
- `write`: só o próprio usuário (`request.auth.uid == uid` — ID do documento é o UID)

**`grupos`**
- `read`: qualquer autenticado
- `create`: qualquer autenticado (cria seu próprio grupo)
- `update`: membro do grupo (sair/editar) OU usuário adicionando apenas a si mesmo ao array `membros` (entrar com código)
- `delete`: só o dono (`request.auth.uid == resource.data.donoUid`)

**`api`**
- `read`: qualquer autenticado
- `write`: bloqueado (`if false`) — só as Cloud Functions escrevem, via Admin SDK

**Decisões conscientes:**
- Email visível a todos os autenticados: aceitável para bolão de amigos; mudar exigiria refatoração de arquitetura
- Palpites de jogos futuros legíveis: restringir exigiria `dataHoraJogo` em cada palpite + migração de dados; não vale para grupo de amigos

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

## Google Play — status de publicação

- **Internal Testing** — ✓ v1.0.0+2 publicada; testadores adicionados por e-mail e podem instalar via Play Store
- **Closed Testing (Alpha)** — ✓ v1.0.0+10 em build (AAB gerado em 2026-06-03); corrige Google Sign-In Android e PERMISSION_DENIED no cadastro
- **Política de privacidade** — ✓ publicada em `https://bolaodasoci2026.web.app/privacy`
- **Exclusão de conta** — ✓ publicada em `https://bolaodasoci2026.web.app/delete`
- **Segurança dos dados** — ✓ questionário completo enviado no Play Console
- **Classificação de conteúdo** — ✓ questionário enviado
- **Público-alvo** — ✓ 13 anos ou mais
- **Declaração de anúncios** — ✓ sem anúncios
- **Página da loja** — ✓ ícone, elemento gráfico, descrição breve e completa configurados (pt-BR)
- **Categoria** — ✓ App de Esportes
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

## Próximos passos (na ordem recomendada)

1. Publicar nova versão na Play Store quando o conjunto de features estiver estável.
