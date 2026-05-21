import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../services/usuario_service.dart';
import '../utils/avatares.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaPerfil extends StatelessWidget {
  const TelaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.surface,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Cores.verdePrincipal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MEU PERFIL',
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
      body: StreamBuilder<Usuario?>(
        stream: UsuarioService().observarUsuario(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Cores.verdePrincipal));
          }
          final usuario = snapshot.data;
          if (usuario == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }
          return _PerfilConteudo(usuario: usuario);
        },
      ),
    );
  }
}

class _PerfilConteudo extends StatefulWidget {
  const _PerfilConteudo({required this.usuario});

  final Usuario usuario;

  @override
  State<_PerfilConteudo> createState() => _PerfilConteudoState();
}

class _PerfilConteudoState extends State<_PerfilConteudo> {
  Usuario get usuario => widget.usuario;

  Future<void> _editarNome(BuildContext context) async {
    final controller = TextEditingController(text: usuario.nome);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar nome',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w800, color: Cores.onSurface),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.hankenGrotesk(color: Cores.onSurface),
          decoration: InputDecoration(
            hintText: 'Seu nome no bolão',
            hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Cores.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Cores.verdePrincipal, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
            onPressed: () {
              final valor = controller.text.trim();
              if (valor.isNotEmpty) Navigator.of(ctx).pop(valor);
            },
            child: Text('Salvar', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (novoNome != null && novoNome != usuario.nome) {
      await UsuarioService().atualizarNome(usuario.uid, novoNome);
    }
  }

  void _editarAvatar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Cores.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeletorAvatarSheet(
        avatarAtual: usuario.avatar,
        onSelecionado: (id) async {
          Navigator.of(context).pop();
          await UsuarioService().atualizarAvatar(usuario.uid, id);
        },
      ),
    );
  }

  Future<void> _alterarSenha(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => _DialogAlterarSenha(email: usuario.email),
    );
  }

  Future<void> _excluirConta(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogExcluirConta(email: usuario.email),
    );
    if (confirmado == true && context.mounted) {
      Navigator.of(context).pop(); // fecha TelaPerfil — authStateChanges redireciona para login
    }
  }

  @override
  Widget build(BuildContext context) {
    const meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
        'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
    final data = usuario.criadoEm.toLocal();
    final membroDesde = '${meses[data.month - 1]} de ${data.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      children: [
        // Avatar com botão de editar
        Center(
          child: GestureDetector(
            onTap: () => _editarAvatar(context),
            child: Stack(
              children: [
                WidgetAvatar(
                  avatarId: usuario.avatar,
                  nome: usuario.nome,
                  tamanho: 90,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Cores.verdePrincipal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Cores.background, width: 2),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Card de dados
        Container(
          decoration: BoxDecoration(
            color: Cores.surface,
            border: Border.all(color: Cores.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _CampoInfo(
                icone: Icons.person_outline_rounded,
                label: 'Nome',
                valor: usuario.nome,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Cores.verdePrincipal),
                  onPressed: () => _editarNome(context),
                  tooltip: 'Editar nome',
                ),
              ),
              const Divider(height: 1, color: Cores.outlineVariant, indent: 16, endIndent: 16),
              _CampoInfo(
                icone: Icons.email_outlined,
                label: 'E-mail',
                valor: usuario.email,
              ),
              const Divider(height: 1, color: Cores.outlineVariant, indent: 16, endIndent: 16),
              _CampoInfo(
                icone: Icons.calendar_today_outlined,
                label: 'Membro desde',
                valor: membroDesde,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card de pontuação
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Cores.verdePrincipal,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pontuação total',
                    style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Colors.white70),
                  ),
                  Text(
                    '${usuario.pontuacao} pts',
                    style: GoogleFonts.anybody(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Seção de ações de conta
        Container(
          decoration: BoxDecoration(
            color: Cores.surface,
            border: Border.all(color: Cores.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _ItemAcao(
                icone: Icons.lock_outline_rounded,
                label: 'Alterar senha',
                onTap: () => _alterarSenha(context),
                primeiro: true,
              ),
              const Divider(height: 1, color: Cores.outlineVariant, indent: 16, endIndent: 16),
              _ItemAcao(
                icone: Icons.delete_outline_rounded,
                label: 'Excluir conta',
                cor: const Color(0xFFBA1A1A),
                onTap: () => _excluirConta(context),
                ultimo: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom sheet de seleção de avatar ───────────────────────────────────────

class _SeletorAvatarSheet extends StatefulWidget {
  const _SeletorAvatarSheet({required this.avatarAtual, required this.onSelecionado});

  final String? avatarAtual;
  final void Function(String) onSelecionado;

  @override
  State<_SeletorAvatarSheet> createState() => _SeletorAvatarSheetState();
}

class _SeletorAvatarSheetState extends State<_SeletorAvatarSheet> {
  late String? _selecionado;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.avatarAtual;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Cores.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'ESCOLHA SEU AVATAR',
            style: GoogleFonts.anybody(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Cores.verdePrincipal,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                  selecionado: _selecionado == jogador.id,
                  onTap: () {
                    setState(() => _selecionado = jogador.id);
                    widget.onSelecionado(jogador.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item de ação (alterar senha / excluir conta) ────────────────────────────

class _ItemAcao extends StatelessWidget {
  const _ItemAcao({
    required this.icone,
    required this.label,
    required this.onTap,
    this.cor,
    this.primeiro = false,
    this.ultimo = false,
  });

  final IconData icone;
  final String label;
  final VoidCallback onTap;
  final Color? cor;
  final bool primeiro;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final color = cor ?? Cores.verdePrincipal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: primeiro ? const Radius.circular(16) : Radius.zero,
        bottom: ultimo ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icone, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog de alterar senha ──────────────────────────────────────────────────

class _DialogAlterarSenha extends StatefulWidget {
  const _DialogAlterarSenha({required this.email});
  final String email;

  @override
  State<_DialogAlterarSenha> createState() => _DialogAlterarSenhaState();
}

class _DialogAlterarSenhaState extends State<_DialogAlterarSenha> {
  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _verSenhaAtual = false;
  bool _verNovaSenha = false;
  bool _salvando = false;

  @override
  void dispose() {
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final senhaAtual = _senhaAtualCtrl.text.trim();
    final novaSenha = _novaSenhaCtrl.text.trim();
    final confirmar = _confirmarCtrl.text.trim();

    if (senhaAtual.isEmpty || novaSenha.isEmpty || confirmar.isEmpty) {
      mostrarMensagem(context, 'Preencha todos os campos.');
      return;
    }
    if (novaSenha.length < 6) {
      mostrarMensagem(context, 'A nova senha deve ter ao menos 6 caracteres.');
      return;
    }
    if (novaSenha != confirmar) {
      mostrarMensagem(context, 'As senhas não coincidem.');
      return;
    }

    setState(() => _salvando = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: widget.email,
        password: senhaAtual,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(novaSenha);
      if (mounted) {
        Navigator.of(context).pop();
        mostrarMensagem(context, 'Senha alterada com sucesso!');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        mostrarMensagem(context, _traduzirErro(e.code));
        setState(() => _salvando = false);
      }
    }
  }

  String _traduzirErro(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Senha atual incorreta.';
      case 'weak-password':
        return 'A nova senha é muito fraca.';
      default:
        return 'Erro ao alterar senha. Tente novamente.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Alterar senha',
        style: GoogleFonts.anybody(fontWeight: FontWeight.w800, color: Cores.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CampoSenha(
            controller: _senhaAtualCtrl,
            label: 'Senha atual',
            mostrar: _verSenhaAtual,
            onToggle: () => setState(() => _verSenhaAtual = !_verSenhaAtual),
          ),
          const SizedBox(height: 12),
          _CampoSenha(
            controller: _novaSenhaCtrl,
            label: 'Nova senha',
            mostrar: _verNovaSenha,
            onToggle: () => setState(() => _verNovaSenha = !_verNovaSenha),
          ),
          const SizedBox(height: 12),
          _CampoSenha(
            controller: _confirmarCtrl,
            label: 'Confirmar nova senha',
            mostrar: _verNovaSenha,
            onToggle: () => setState(() => _verNovaSenha = !_verNovaSenha),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: Text('Cancelar',
              style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Alterar',
                  style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _CampoSenha extends StatelessWidget {
  const _CampoSenha({
    required this.controller,
    required this.label,
    required this.mostrar,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool mostrar;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !mostrar,
      style: GoogleFonts.hankenGrotesk(color: Cores.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant, fontSize: 13),
        suffixIcon: IconButton(
          icon: Icon(mostrar ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20, color: Cores.onSurfaceVariant),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Cores.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Cores.verdePrincipal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── Dialog de excluir conta ──────────────────────────────────────────────────

class _DialogExcluirConta extends StatefulWidget {
  const _DialogExcluirConta({required this.email});
  final String email;

  @override
  State<_DialogExcluirConta> createState() => _DialogExcluirContaState();
}

class _DialogExcluirContaState extends State<_DialogExcluirConta> {
  final _senhaCtrl = TextEditingController();
  bool _verSenha = false;
  bool _excluindo = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    final senha = _senhaCtrl.text.trim();
    if (senha.isEmpty) {
      mostrarMensagem(context, 'Digite sua senha para confirmar.');
      return;
    }

    setState(() => _excluindo = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: widget.email,
        password: senha,
      );
      await user.reauthenticateWithCredential(credential);
      // Remove o documento do Firestore antes de deletar a conta Auth
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).delete();
      await user.delete();
      // authStateChanges emite null → StreamBuilder navega para TelaLogin
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Senha incorreta.'
            : 'Erro ao excluir conta. Tente novamente.';
        mostrarMensagem(context, msg);
        setState(() => _excluindo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFBA1A1A), size: 22),
          const SizedBox(width: 8),
          Text(
            'Excluir conta',
            style: GoogleFonts.anybody(
                fontWeight: FontWeight.w800, color: const Color(0xFFBA1A1A)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta ação é permanente e não pode ser desfeita. Seus palpites serão mantidos no histórico.',
            style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Cores.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _CampoSenha(
            controller: _senhaCtrl,
            label: 'Digite sua senha para confirmar',
            mostrar: _verSenha,
            onToggle: () => setState(() => _verSenha = !_verSenha),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _excluindo ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancelar',
              style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A)),
          onPressed: _excluindo ? null : _excluir,
          child: _excluindo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Excluir',
                  style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Campo de informação ──────────────────────────────────────────────────────

class _CampoInfo extends StatelessWidget {
  const _CampoInfo({
    required this.icone,
    required this.label,
    required this.valor,
    this.trailing,
  });

  final IconData icone;
  final String label;
  final String valor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icone, size: 20, color: Cores.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
