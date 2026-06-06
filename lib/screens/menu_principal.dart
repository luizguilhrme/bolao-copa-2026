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

  @override
  void initState() {
    super.initState();
    _streamUsuario = UsuarioService().observarUsuario(_uid);
    _verificarAdmin();
    _inicializarFcm();
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
                style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
          action: tela != null
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
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_uid)
        .get();
    if (!mounted) return;
    if (doc.exists && doc.data()?['isAdmin'] == true) {
      setState(() => _isAdmin = true);
    }
  }

  void _abrirRegras() => mostrarRegras(context);

  void _abrirAdminPlacares() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TelaAdminPlacares()),
    );
  }

  void _abrirAdminCopa() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TelaAdminCopa()),
    );
  }

  void _abrirAdminEspeciais() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TelaAdminEspeciais()),
    );
  }

  void _abrirAdminDefinicoes() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TelaAdminDefinicoes()),
    );
  }

  Future<void> _logout() async {
    Navigator.of(context).pop(); // fecha o drawer
    await AuthService().sair();
    // StreamBuilder do main.dart detecta signOut e exibe TelaLogin
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      TelaHome(onNavegar: (i) => setState(() => _indiceNav = i)),
      const TelaPalpites(),
      const TelaRanking(),
      const TelaTabela(),
    ];

    return StreamBuilder<Usuario?>(
      stream: _streamUsuario,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: Cores.background,
          appBar: _buildAppBar(),
          drawer: _DrawerNav(
            usuario: snapshot.data,
            isAdmin: _isAdmin,
            onAdminPlacares: _abrirAdminPlacares,
            onAdminCopa: _abrirAdminCopa,
            onAdminEspeciais: _abrirAdminEspeciais,
            onAdminDefinicoes: _abrirAdminDefinicoes,
            onLogout: _logout,
          ),
          body: IndexedStack(index: _indiceNav, children: telas),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Cores.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      // Builder necessário: o leading precisa de um BuildContext que
      // contenha o Scaffold para chamar openDrawer().
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.sports_soccer, color: Cores.verdePrincipal),
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
    return NavigationBar(
      backgroundColor: Cores.surfaceContainer,
      indicatorColor: Cores.secondaryContainer,
      selectedIndex: _indiceNav,
      onDestinationSelected: (i) => setState(() => _indiceNav = i),
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
    );
  }
}

// ─── Drawer lateral ───────────────────────────────────────────────────────────

class _DrawerNav extends StatelessWidget {
  const _DrawerNav({
    required this.usuario,
    required this.isAdmin,
    required this.onAdminPlacares,
    required this.onAdminCopa,
    required this.onAdminEspeciais,
    required this.onAdminDefinicoes,
    required this.onLogout,
  });

  final Usuario? usuario;
  final bool isAdmin;
  final VoidCallback onAdminPlacares;
  final VoidCallback onAdminCopa;
  final VoidCallback onAdminEspeciais;
  final VoidCallback onAdminDefinicoes;
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
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TelaPerfil()),
                    );
                  },
                ),
                _ItemDrawer(
                  icone: Icons.notifications_outlined,
                  label: 'Notificações',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TelaNotificacoes()),
                    );
                  },
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
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TelaGrupos()),
                    );
                  },
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
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TelaAjuda()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Rodapé com logout
          const Divider(color: Cores.outlineVariant, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: Cores.error),
              title: Text(
                'Sair',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Cores.error,
                ),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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

    return Container(
      width: double.infinity,
      color: Cores.verdePrincipal,
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 20, 20, 24),
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
            ),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.stars_rounded,
                  color: Color(0xFFFCD400), size: 18),
              const SizedBox(width: 4),
              Text(
                '${usuario?.pontuacaoClassicaTotal ?? 0} pts',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}

