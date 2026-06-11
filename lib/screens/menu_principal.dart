import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/notificacoes_service.dart';
import '../services/usuario_service.dart';
import '../utils/avatares.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import 'tela_admin_copa.dart';
import 'tela_admin_definicoes.dart';
import 'tela_admin_especiais.dart';
import 'tela_admin_placares.dart';
import 'tela_admin_teste_api.dart';
import 'tela_ajuda.dart';
import 'tela_grupos.dart';
import 'tela_home.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_palpites.dart';
import 'tela_ranking.dart';
import 'tela_tabela.dart';

const _titulos = ['CRAVA AÍ!', 'PALPITES', 'RANKING', 'TABELA'];

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  int _indiceNav = 0;
  bool _isAdmin = false;

  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final Stream<Usuario?> _streamUsuario;

  // Sinais de ressincronização das telas do IndexedStack (que só rodam
  // initState uma vez). Disparados ao selecionar a aba e ao voltar de rotas
  // do drawer, para a tela recarregar dados sem perder scroll/rascunhos.
  final _sinalHome = Sinal();
  final _sinalPalpites = Sinal();
  final _sinalRanking = Sinal();
  // Pede à TelaTabela para abrir a aba superior ARTILHARIA (atalho da Home)
  final _sinalAbrirArtilharia = Sinal();

  @override
  void initState() {
    super.initState();
    _streamUsuario = UsuarioService().observarUsuario(_uid);
    _verificarAdmin();
    _inicializarFcm();
  }

  @override
  void dispose() {
    _sinalHome.dispose();
    _sinalPalpites.dispose();
    _sinalRanking.dispose();
    _sinalAbrirArtilharia.dispose();
    super.dispose();
  }

  void _sinalizarAba(int indice) {
    switch (indice) {
      case 0:
        _sinalHome.disparar();
      case 1:
        _sinalPalpites.disparar();
      case 2:
        _sinalRanking.disparar();
      // Tabela (3) tem pull-to-refresh próprio
    }
  }

  void _navegarPorNotificacao(Map<String, dynamic> data) {
    final tela = data['tela'] as String?;
    if (tela == 'palpites') {
      setState(() => _indiceNav = 1);
    } else if (tela == 'ranking') {
      setState(() => _indiceNav = 2);
    }
  }

  Future<void> _inicializarFcm() async {
    await NotificacoesService().inicializar(_uid);

    // App estava fechado quando a notificação foi tocada.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _navegarPorNotificacao(initialMessage.data),
      );
    }

    // App estava em background quando a notificação foi tocada.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (mounted) _navegarPorNotificacao(message.data);
    });

    // App em foreground — exibe SnackBar com botão "Ver".
    // Notificações de ranking não mostram SnackBar; o sistema de notificações do celular já cuida.
    FirebaseMessaging.onMessage.listen((message) {
      final titulo = message.notification?.title ?? '';
      final corpo = message.notification?.body ?? '';
      if (!mounted || corpo.isEmpty) return;
      final tela = message.data['tela'] as String?;
      if (tela == 'ranking') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Cores.verdePrincipal,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titulo.isNotEmpty)
                Text(
                  titulo,
                  style: GoogleFonts.anybody(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              Text(
                corpo,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          action:
              tela != null
                  ? SnackBarAction(
                    label: 'VER',
                    textColor: Cores.secondaryContainer,
                    onPressed: () => _navegarPorNotificacao(message.data),
                  )
                  : null,
        ),
      );
    });
  }

  // Lê isAdmin diretamente do Firestore — campo ausente equivale a false.
  // Executado uma única vez: isAdmin não muda durante a sessão.
  Future<void> _verificarAdmin() async {
    final doc =
        await FirebaseFirestore.instance.collection('usuarios').doc(_uid).get();
    if (!mounted) return;
    if (doc.exists && doc.data()?['isAdmin'] == true) {
      setState(() => _isAdmin = true);
    }
  }

  void _abrirRegras() => mostrarRegras(context);

  // Fecha o drawer, abre a rota e, ao voltar, ressincroniza a aba visível —
  // mudanças feitas na rota (entrar em grupo, placar inserido etc.) aparecem
  // sem precisar fechar e reabrir o app.
  Future<void> _abrirRota(Widget tela) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
    _sinalizarAba(_indiceNav);
  }

  void _abrirPerfil() => _abrirRota(const TelaPerfil());

  void _abrirNotificacoes() => _abrirRota(const TelaNotificacoes());

  void _abrirGrupos() => _abrirRota(const TelaGrupos());

  void _abrirAjuda() => _abrirRota(const TelaAjuda());

  void _abrirAdminPlacares() => _abrirRota(const TelaAdminPlacares());

  void _abrirAdminCopa() => _abrirRota(const TelaAdminCopa());

  void _abrirAdminEspeciais() => _abrirRota(const TelaAdminEspeciais());

  void _abrirAdminDefinicoes() => _abrirRota(const TelaAdminDefinicoes());

  void _abrirAdminTesteApi() => _abrirRota(const TelaAdminTesteApi());

  Future<void> _logout() async {
    Navigator.of(context).pop(); // fecha o drawer
    await AuthService().sair();
    // StreamBuilder do main.dart detecta signOut e exibe TelaLogin
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      TelaHome(
        onNavegar: (i) => setState(() => _indiceNav = i),
        sinalAtualizar: _sinalHome,
        onVerArtilharia: () {
          setState(() => _indiceNav = 3);
          _sinalAbrirArtilharia.disparar();
        },
      ),
      TelaPalpites(sinalAtualizar: _sinalPalpites),
      TelaRanking(sinalAtualizar: _sinalRanking),
      TelaTabela(sinalAbrirArtilharia: _sinalAbrirArtilharia),
    ];

    return Container(
      color: Cores.background,
      child: StreamBuilder<Usuario?>(
        stream: _streamUsuario,
        builder: (context, snapshot) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(),
            drawer: _DrawerNav(
              usuario: snapshot.data,
              isAdmin: _isAdmin,
              onPerfil: _abrirPerfil,
              onNotificacoes: _abrirNotificacoes,
              onGrupos: _abrirGrupos,
              onAjuda: _abrirAjuda,
              onAdminPlacares: _abrirAdminPlacares,
              onAdminCopa: _abrirAdminCopa,
              onAdminEspeciais: _abrirAdminEspeciais,
              onAdminDefinicoes: _abrirAdminDefinicoes,
              onAdminTesteApi: _abrirAdminTesteApi,
              onLogout: _logout,
            ),
            body: IndexedStack(index: _indiceNav, children: telas),
            bottomNavigationBar: _buildBottomNav(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      // Builder necessário: o leading precisa de um BuildContext que
      // contenha o Scaffold para chamar openDrawer().
      leading: Builder(
        builder:
            (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Cores.verdePrincipal),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          _titulos[_indiceNav],
          key: ValueKey(_indiceNav),
          style: const TextStyle(
            color: Cores.verdePrincipal,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _abrirRegras,
          icon: const Icon(Icons.info_outline_rounded),
          color: Cores.verdePrincipal,
          tooltip: 'Regras de pontuação',
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Cores.verdePrincipal);
          }
          return const IconThemeData(color: Colors.white70);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 12);
        }),
      ),
      child: NavigationBar(
        backgroundColor: Cores.verdePrincipal,
        indicatorColor: Cores.secondaryContainer,
        selectedIndex: _indiceNav,
        onDestinationSelected: (i) {
          setState(() => _indiceNav = i);
          _sinalizarAba(i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit_square),
            label: 'Palpites',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Tabela',
          ),
        ],
      ),
    );
  }
}

// ─── Drawer lateral ───────────────────────────────────────────────────────────

class _DrawerNav extends StatelessWidget {
  const _DrawerNav({
    required this.usuario,
    required this.isAdmin,
    required this.onPerfil,
    required this.onNotificacoes,
    required this.onGrupos,
    required this.onAjuda,
    required this.onAdminPlacares,
    required this.onAdminCopa,
    required this.onAdminEspeciais,
    required this.onAdminDefinicoes,
    required this.onAdminTesteApi,
    required this.onLogout,
  });

  final Usuario? usuario;
  final bool isAdmin;
  final VoidCallback onPerfil;
  final VoidCallback onNotificacoes;
  final VoidCallback onGrupos;
  final VoidCallback onAjuda;
  final VoidCallback onAdminPlacares;
  final VoidCallback onAdminCopa;
  final VoidCallback onAdminEspeciais;
  final VoidCallback onAdminDefinicoes;
  final VoidCallback onAdminTesteApi;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Cores.surface,
      child: Column(
        children: [
          _CabecalhoDrawer(usuario: usuario),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _LabelSecao('CONTA'),
                _ItemDrawer(
                  icone: Icons.person_outline_rounded,
                  label: 'Meu Perfil',
                  onTap: onPerfil,
                ),
                _ItemDrawer(
                  icone: Icons.notifications_outlined,
                  label: 'Notificações',
                  onTap: onNotificacoes,
                ),

                const Divider(
                  indent: 16,
                  endIndent: 16,
                  color: Cores.outlineVariant,
                  height: 24,
                ),
                _LabelSecao('GRUPOS'),
                _ItemDrawer(
                  icone: Icons.group_outlined,
                  label: 'Meus Grupos',
                  onTap: onGrupos,
                ),

                // Seção admin — só visível para o administrador
                if (isAdmin) ...[
                  const Divider(
                    indent: 16,
                    endIndent: 16,
                    color: Cores.outlineVariant,
                    height: 24,
                  ),
                  _LabelSecao('ADMIN'),
                  _ItemDrawer(
                    icone: Icons.sports_score_rounded,
                    label: 'Placares — Reg. Clássica',
                    cor: Cores.verdePrincipal,
                    onTap: onAdminPlacares,
                  ),
                  _ItemDrawer(
                    icone: Icons.emoji_events_rounded,
                    label: 'Classificação — Reg. Copa',
                    cor: Cores.verdePrincipal,
                    onTap: onAdminCopa,
                  ),
                  _ItemDrawer(
                    icone: Icons.star_rounded,
                    label: 'Palpites Especiais',
                    cor: Cores.verdePrincipal,
                    onTap: onAdminEspeciais,
                  ),
                  _ItemDrawer(
                    icone: Icons.settings_rounded,
                    label: 'Outras Definições',
                    cor: Cores.verdePrincipal,
                    onTap: onAdminDefinicoes,
                  ),
                  _ItemDrawer(
                    icone: Icons.sensors_rounded,
                    label: 'Teste de API',
                    cor: Cores.verdePrincipal,
                    onTap: onAdminTesteApi,
                  ),
                ],

                const Divider(
                  indent: 16,
                  endIndent: 16,
                  color: Cores.outlineVariant,
                  height: 24,
                ),
                _LabelSecao('SUPORTE'),
                _ItemDrawer(
                  icone: Icons.help_outline_rounded,
                  label: 'Ajuda & FAQ',
                  onTap: onAjuda,
                ),
              ],
            ),
          ),

          // Rodapé com logout
          const Divider(color: Cores.outlineVariant, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Cores.error),
              title: Text(
                'Sair',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Cores.error,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: onLogout,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Cabeçalho verde do drawer ────────────────────────────────────────────────

class _CabecalhoDrawer extends StatelessWidget {
  const _CabecalhoDrawer({required this.usuario});

  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/background-cards/cabecalho.webp',
            fit: BoxFit.cover,
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WidgetAvatar(
                      avatarId: usuario?.avatar,
                      nome: usuario?.nome ?? '',
                      tamanho: 64,
                      corFundo: Cores.primaryContainer,
                      corTexto: Cores.verdePrincipal,
                      borderColor: Colors.white54,
                      borderWidth: 2,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      usuario?.nome ?? '...',
                      style: GoogleFonts.anybody(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 6),
                          Shadow(color: Colors.black38, blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFFCD400),
                          size: 18,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${usuario?.pontuacaoClassicaTotal ?? 0} pts',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _LabelSecao extends StatelessWidget {
  const _LabelSecao(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        texto,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Cores.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ItemDrawer extends StatelessWidget {
  const _ItemDrawer({
    required this.icone,
    required this.label,
    required this.onTap,
    this.cor,
  });

  final IconData icone;
  final String label;
  final VoidCallback onTap;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final color = cor ?? Cores.verdePrincipal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Icon(icone, color: color, size: 22),
        title: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Cores.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}
