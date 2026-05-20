import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/cores.dart';
import 'tela_setup_perfil.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _modoLogin = true;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_modoLogin) {
      setState(() { _carregando = true; _erro = null; });
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _erro = _traduzirErro(e.code));
      } finally {
        setState(() => _carregando = false);
      }
    } else {
      // Valida localmente antes de abrir o setup
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();
      if (email.isEmpty || senha.isEmpty) {
        setState(() => _erro = 'Preencha todos os campos.');
        return;
      }
      if (senha.length < 6) {
        setState(() => _erro = 'A senha precisa ter pelo menos 6 caracteres.');
        return;
      }
      setState(() => _erro = null);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TelaSetupPerfil(email: email, senha: senha),
        ),
      );
    }
  }
  String _traduzirErro(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'Nenhuma conta encontrada com esse e-mail.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Esse e-mail já está cadastrado.';
      case 'weak-password':
        return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'E-mail inválido.';
      default:
        return 'Ocorreu um erro. Tente novamente.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 448), // max-w-md
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Cores.surfaceContainerHigh),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCabecalho(),
                const SizedBox(height: 24),
                _buildFormulario(),
                const SizedBox(height: 16),
                _buildRodape(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Seção do topo: ícone, título COPA 2026 e subtítulo
  Widget _buildCabecalho() {
    return Column(
      children: [
        // Ícone de bola preenchido em verde
        Icon(
          Icons.sports_soccer,
          color: Cores.verdePrincipal,
          size: 48,
        ),
        const SizedBox(height: 8),

        // "COPA 2026" com a fonte Anybody, italic, bold, maiúsculo
        Text(
          'COPA 2026',
          style: GoogleFonts.anybody(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: Cores.verdePrincipal,
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        // Título "Bem-vindo de volta!" ou "Crie sua conta"
        // AnimatedSwitcher anima a troca de texto quando o modo muda
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _modoLogin ? 'Bem-vindo de volta!' : 'Crie sua conta',
            key: ValueKey(_modoLogin),
            style: GoogleFonts.anybody(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Cores.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),

        Text(
          _modoLogin
              ? 'Faça login para continuar suas previsões.'
              : 'Cadastre-se para participar do bolão.',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: Cores.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Formulário com os dois campos e o botão
  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label "EMAIL" em caps
        _buildLabel('Email'),
        const SizedBox(height: 4),
        _buildCampoTexto(
          controller: _emailController,
          hint: 'seu@email.com',
          icone: Icons.mail_outlined,
          tipo: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Label "SENHA" com link "Esqueceu?" à direita (só no modo login)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Senha'),
            if (_modoLogin)
              TextButton(
                onPressed: () {}, // implementar depois
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Esqueceu?',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    color: Cores.azulTerciario,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        _buildCampoTexto(
          controller: _senhaController,
          hint: '••••••••',
          icone: Icons.lock_outlined,
          obscureText: true,
        ),

        // Mensagem de erro (aparece só quando há erro)
        if (_erro != null) ...[
          const SizedBox(height: 8),
          Text(
            _erro!,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              color: Colors.red,
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Botão principal verde com ícone de seta
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _carregando ? null : _entrar,
            style: FilledButton.styleFrom(
              backgroundColor: Cores.verdePrincipal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _carregando
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.arrow_forward, color: Colors.white),
            label: Text(
              _modoLogin ? 'Entrar' : 'Criar conta',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Link "Não tem conta? Cadastre-se" / "Já tem conta? Entre"
  Widget _buildRodape() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _modoLogin ? 'Não tem uma conta? ' : 'Já tem conta? ',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: Cores.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _modoLogin = !_modoLogin;
            _erro = null;
          }),
          child: Text(
            _modoLogin ? 'Cadastre-se' : 'Entre',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Cores.azulTerciario,
            ),
          ),
        ),
      ],
    );
  }

  // Label reutilizável no estilo "CAPS SMALL"
  Widget _buildLabel(String texto) {
    return Text(
      texto.toUpperCase(),
      style: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Cores.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  // Campo de texto reutilizável com ícone e borda estilizada
  // O focus muda a cor da borda para azul (tertiary), exatamente como o CSS
  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String hint,
    required IconData icone,
    TextInputType tipo = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: tipo,
      obscureText: obscureText,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 16,
        color: Cores.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
        prefixIcon: Icon(icone, color: Cores.onSurfaceVariant),
        filled: true,
        fillColor: Cores.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Cores.outlineVariant, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Cores.outlineVariant, width: 2),
        ),
        // Borda azul no foco, igual ao focus:border-tertiary do CSS
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Cores.azulTerciario, width: 2),
        ),
      ),
    );
  }
}