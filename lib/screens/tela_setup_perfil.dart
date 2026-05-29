import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grupo.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../services/usuario_service.dart';
import '../utils/avatares.dart';
import '../utils/cores.dart';

class TelaSetupPerfil extends StatefulWidget {
  const TelaSetupPerfil({super.key, required this.user});

  final User user;

  @override
  State<TelaSetupPerfil> createState() => _TelaSetupPerfilState();
}

class _TelaSetupPerfilState extends State<TelaSetupPerfil> {
  late final TextEditingController _nomeController;
  String _avatarSelecionado = kJogadores.first.id;
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final email = widget.user.email ?? '';
    _nomeController = TextEditingController(text: email.split('@').first);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _voltar() async {
    // Cancela o cadastro: desloga e main.dart volta para TelaLogin automaticamente
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _confirmar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Digite seu nome.');
      return;
    }
    setState(() { _carregando = true; _erro = null; });
    try {
      await UsuarioService().criarPerfil(Usuario(
        uid: widget.user.uid,
        email: widget.user.email!,
        nome: nome,
        avatar: _avatarSelecionado,
        criadoEm: DateTime.now(),
      ));
      // Perfil criado → stream em main.dart detecta e abre MenuPrincipal automaticamente
    } catch (_) {
      setState(() => _erro = 'Erro ao salvar perfil. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Cores.verdePrincipal),
          onPressed: _carregando ? null : _voltar,
        ),
        title: const Text(
          'CONFIGURAR PERFIL',
          style: TextStyle(
            color: Cores.verdePrincipal,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              children: [
                Text(
                  'NOME NO BOLÃO',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.hankenGrotesk(fontSize: 16, color: Cores.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Como você quer aparecer no ranking',
                    hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Cores.onSurfaceVariant),
                    filled: true,
                    fillColor: Cores.surfaceContainer,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Cores.outlineVariant, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Cores.azulTerciario, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'GRUPOS',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opcional — você pode criar ou entrar em um grupo agora ou depois.',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: Cores.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Criar grupo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Cores.verdePrincipal,
                          side: const BorderSide(color: Cores.verdePrincipal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _DialogCriarGrupoSetup(
                              uid: widget.user.uid),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Entrar com código'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Cores.verdePrincipal,
                          side: const BorderSide(color: Cores.verdePrincipal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _DialogEntrarGrupoSetup(
                              uid: widget.user.uid),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                Text(
                  'ESCOLHA SEU AVATAR',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: kJogadores.length,
                  itemBuilder: (context, index) {
                    final jogador = kJogadores[index];
                    return CardAvatar(
                      jogador: jogador,
                      selecionado: _avatarSelecionado == jogador.id,
                      onTap: () => setState(() => _avatarSelecionado = jogador.id),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: const BoxDecoration(
              color: Cores.surface,
              border: Border(top: BorderSide(color: Cores.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hankenGrotesk(fontSize: 14, color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _carregando ? null : _confirmar,
                    style: FilledButton.styleFrom(
                      backgroundColor: Cores.verdePrincipal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _carregando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(
                      'Confirmar e entrar',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog: criar grupo (setup) ─────────────────────────────────────────────

class _DialogCriarGrupoSetup extends StatefulWidget {
  const _DialogCriarGrupoSetup({required this.uid});
  final String uid;

  @override
  State<_DialogCriarGrupoSetup> createState() => _DialogCriarGrupoSetupState();
}

class _DialogCriarGrupoSetupState extends State<_DialogCriarGrupoSetup> {
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
        builder: (_) => _DialogCodigoSetup(grupo: grupo),
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Criar grupo',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nome do grupo',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
          style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
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

// ─── Dialog: código gerado (setup) ───────────────────────────────────────────

class _DialogCodigoSetup extends StatelessWidget {
  const _DialogCodigoSetup({required this.grupo});
  final Grupo grupo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Grupo criado!',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Compartilhe o código com seus amigos:',
              style: GoogleFonts.hankenGrotesk(fontSize: 14)),
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
                      Text('toque para copiar',
                          style: GoogleFonts.hankenGrotesk(
                              fontSize: 11, color: Cores.onSurfaceVariant)),
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
          style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
          child: Text('OK',
              style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Dialog: entrar com código (setup) ───────────────────────────────────────

class _DialogEntrarGrupoSetup extends StatefulWidget {
  const _DialogEntrarGrupoSetup({required this.uid});
  final String uid;

  @override
  State<_DialogEntrarGrupoSetup> createState() =>
      _DialogEntrarGrupoSetupState();
}

class _DialogEntrarGrupoSetupState extends State<_DialogEntrarGrupoSetup> {
  final _controller = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final codigo = _controller.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    setState(() => _carregando = true);
    try {
      final grupo = await GrupoService().entrarComCodigo(codigo, widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      final msg = grupo == null ? 'Código não encontrado.' : 'Você entrou no grupo "${grupo.nome}"!';
      final cor = grupo == null ? const Color(0xFFBA1A1A) : Cores.verdePrincipal;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.hankenGrotesk()),
          backgroundColor: cor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      final jaMembro = e.toString().contains('ja_membro');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            jaMembro ? 'Você já é membro deste grupo.' : 'Erro ao entrar: $e',
            style: GoogleFonts.hankenGrotesk(),
          ),
          backgroundColor: jaMembro ? Cores.azulTerciario : const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Entrar com código',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        decoration: InputDecoration(
          labelText: 'Código do grupo',
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Cores.verdePrincipal, width: 2),
          ),
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
          style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
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
