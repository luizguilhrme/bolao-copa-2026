import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grupo.dart';
import '../services/grupo_service.dart';
import '../utils/cores.dart';

class TelaGrupos extends StatefulWidget {
  const TelaGrupos({super.key});

  @override
  State<TelaGrupos> createState() => _TelaGruposState();
}

class _TelaGruposState extends State<TelaGrupos> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _service = GrupoService();

  void _abrirCriarGrupo() {
    showDialog(context: context, builder: (_) => _DialogCriarGrupo(uid: _uid));
  }

  void _abrirEntrarComCodigo() {
    showDialog(
        context: context, builder: (_) => _DialogEntrarGrupo(uid: _uid));
  }

  Future<void> _confirmarSaida(Grupo grupo) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sair do grupo?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Você será removido de "${grupo.nome}" e não verá mais o ranking deste grupo.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('SAIR',
                style: GoogleFonts.anybody(
                    color: const Color(0xFFBA1A1A),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (sair == true && mounted) {
      await _service.sairDoGrupo(grupo.id, _uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.surface,
        elevation: 1,
        shadowColor: Colors.black12,
        title: Text(
          'MEUS GRUPOS',
          style: const TextStyle(
            color: Cores.verdePrincipal,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Cores.verdePrincipal),
      ),
      body: StreamBuilder<List<Grupo>>(
        stream: _service.buscarGruposDoUsuario(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Cores.verdePrincipal));
          }
          final grupos = snapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _BotaoAcao(
                          icone: Icons.add_rounded,
                          label: 'Criar grupo',
                          onTap: _abrirCriarGrupo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BotaoAcao(
                          icone: Icons.login_rounded,
                          label: 'Entrar com código',
                          onTap: _abrirEntrarComCodigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (grupos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_outlined,
                            size: 64, color: Cores.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum grupo ainda.',
                          style: GoogleFonts.anybody(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Cores.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crie um grupo ou entre com um código.',
                          style: GoogleFonts.hankenGrotesk(
                              fontSize: 14, color: Cores.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CardGrupo(
                          grupo: grupos[i],
                          isDono: grupos[i].donoUid == _uid,
                          onSair: () => _confirmarSaida(grupos[i]),
                        ),
                      ),
                      childCount: grupos.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Card de grupo ────────────────────────────────────────────────────────────

class _CardGrupo extends StatelessWidget {
  const _CardGrupo({
    required this.grupo,
    required this.isDono,
    required this.onSair,
  });

  final Grupo grupo;
  final bool isDono;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cores.surface,
        border: Border.all(color: Cores.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  grupo.nome,
                  style: GoogleFonts.anybody(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDono)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Cores.verdePrincipal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ADMIN',
                    style: GoogleFonts.anybody(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Código copiável
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: grupo.codigo));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Código copiado!',
                            style: GoogleFonts.hankenGrotesk()),
                        backgroundColor: Cores.verdePrincipal,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Cores.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.content_copy_rounded,
                            size: 14, color: Cores.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          grupo.codigo,
                          style: GoogleFonts.anybody(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: Cores.verdePrincipal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nº de membros
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      size: 16, color: Cores.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${grupo.membros.length} ${grupo.membros.length == 1 ? 'membro' : 'membros'}',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onSair,
              icon: const Icon(Icons.logout_rounded,
                  size: 16, color: Color(0xFFBA1A1A)),
              label: Text(
                'Sair do grupo',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  color: const Color(0xFFBA1A1A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Botão de ação (criar / entrar) ──────────────────────────────────────────

class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.icone,
    required this.label,
    required this.onTap,
  });

  final IconData icone;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.verdePrincipal,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dialog: criar grupo ──────────────────────────────────────────────────────

class _DialogCriarGrupo extends StatefulWidget {
  const _DialogCriarGrupo({required this.uid});
  final String uid;

  @override
  State<_DialogCriarGrupo> createState() => _DialogCriarGrupoState();
}

class _DialogCriarGrupoState extends State<_DialogCriarGrupo> {
  final _controller = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final nome = _controller.text.trim();
    if (nome.isEmpty) return;
    setState(() => _carregando = true);
    try {
      final grupo = await GrupoService().criarGrupo(nome, widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (_) => _DialogCodigoGerado(grupo: grupo),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar grupo: $e',
              style: GoogleFonts.hankenGrotesk()),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Criar grupo',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nome do grupo',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Cores.verdePrincipal, width: 2),
          ),
        ),
        onSubmitted: (_) => _criar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCELAR',
              style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
        ),
        FilledButton(
          onPressed: _carregando ? null : _criar,
          style: FilledButton.styleFrom(
              backgroundColor: Cores.verdePrincipal),
          child: _carregando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('CRIAR',
                  style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Dialog: código gerado ────────────────────────────────────────────────────

class _DialogCodigoGerado extends StatelessWidget {
  const _DialogCodigoGerado({required this.grupo});
  final Grupo grupo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Grupo criado!',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Compartilhe o código abaixo com seus amigos:',
            style: GoogleFonts.hankenGrotesk(fontSize: 14),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: grupo.codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Código copiado!',
                      style: GoogleFonts.hankenGrotesk()),
                  backgroundColor: Cores.verdePrincipal,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Cores.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Cores.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    grupo.codigo,
                    style: GoogleFonts.anybody(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Cores.verdePrincipal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.content_copy_rounded,
                          size: 12, color: Cores.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'toque para copiar',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11,
                          color: Cores.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
              backgroundColor: Cores.verdePrincipal),
          child: Text('OK',
              style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Dialog: entrar com código ────────────────────────────────────────────────

class _DialogEntrarGrupo extends StatefulWidget {
  const _DialogEntrarGrupo({required this.uid});
  final String uid;

  @override
  State<_DialogEntrarGrupo> createState() => _DialogEntrarGrupoState();
}

class _DialogEntrarGrupoState extends State<_DialogEntrarGrupo> {
  final _controller = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final codigo = _controller.text.trim();
    if (codigo.isEmpty) return;
    setState(() => _carregando = true);
    try {
      final grupo =
          await GrupoService().entrarComCodigo(codigo, widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (grupo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código não encontrado.',
                style: GoogleFonts.hankenGrotesk()),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você entrou em "${grupo.nome}"!',
                style: GoogleFonts.hankenGrotesk()),
            backgroundColor: Cores.verdePrincipal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('ja_membro')) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você já faz parte deste grupo.',
                style: GoogleFonts.hankenGrotesk()),
            backgroundColor: Cores.azulTerciario,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao entrar no grupo: $e',
                style: GoogleFonts.hankenGrotesk()),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Entrar com código',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        decoration: InputDecoration(
          labelText: 'Código do grupo',
          hintText: 'Ex: ABC123',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Cores.verdePrincipal, width: 2),
          ),
        ),
        style: GoogleFonts.anybody(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          color: Cores.verdePrincipal,
        ),
        onSubmitted: (_) => _entrar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCELAR',
              style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
        ),
        FilledButton(
          onPressed: _carregando ? null : _entrar,
          style: FilledButton.styleFrom(
              backgroundColor: Cores.verdePrincipal),
          child: _carregando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('ENTRAR',
                  style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
