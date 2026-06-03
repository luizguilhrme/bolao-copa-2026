import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/cores.dart';
import '../utils/signin_web.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaFocus = FocusNode();
  bool _modoLogin = true;
  bool _carregando = false;
  bool _carregandoGoogle = false;
  bool _senhaVisivel = false;
  String? _erro;
  StreamSubscription<void>? _googleAuthSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      registrarBotaoGoogle();
      _googleAuthSub = AuthService().onGoogleUserChanged.listen((_) {
        _onBotaoGisCompleto();
      });
      // Dispara initWithParams() no plugin web. Sem isso, a Future `initialized`
      // dentro de renderButton() nunca completa e o botão GIS não aparece.
      AuthService().inicializar();
    }
  }

  @override
  void dispose() {
    _googleAuthSub?.cancel();
    _emailController.dispose();
    _senhaController.dispose();
    _senhaFocus.dispose();
    super.dispose();
  }

  /// Chamado quando o botão GIS conclui a autenticação na web.
  Future<void> _onBotaoGisCompleto() async {
    if (!mounted) return;
    setState(() { _carregandoGoogle = true; _erro = null; });
    try {
      await AuthService().processarUltimaContaGoogle();
      // authStateChanges dispara → main.dart roteia automaticamente
    } on ContaJaExisteException catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogVincularConta(
          email: e.email,
          credencialGoogle: e.credencial,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _erro = _traduzirErro(e.code));
    } catch (_) {
      if (mounted) setState(() => _erro = 'Erro no login com Google. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregandoGoogle = false);
    }
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
        if (mounted) setState(() => _carregando = false);
      }
    } else {
      setState(() { _carregando = true; _erro = null; });
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
        // authStateChanges dispara → main.dart roteia para TelaSetupPerfil automaticamente
      } on FirebaseAuthException catch (e) {
        setState(() => _erro = _traduzirErro(e.code));
      } finally {
        if (mounted) setState(() => _carregando = false);
      }
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() { _carregandoGoogle = true; _erro = null; });
    try {
      await AuthService().entrarComGoogle();
      // null = usuário fechou o seletor; authStateChanges dispara se logou
    } on ContaJaExisteException catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogVincularConta(
          email: e.email,
          credencialGoogle: e.credencial,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _erro = _traduzirErro(e.code));
    } catch (_) {
      // PlatformException (ex: popup bloqueado, origem não autorizada no
      // Google Cloud Console) — não mostra erro para não confundir com
      // o caso em que o usuário apenas fechou o seletor.
      // Se o botão não abrir nada, verifique as Authorized JavaScript
      // origins do OAuth client no Google Cloud Console.
    } finally {
      if (mounted) setState(() => _carregandoGoogle = false);
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
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
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
            constraints: const BoxConstraints(maxWidth: 448),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Cores.surfaceContainerHigh),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                _buildBotaoGoogle(),
                const SizedBox(height: 20),
                _buildDivisor(),
                const SizedBox(height: 20),
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

  Widget _buildCabecalho() {
    return Column(
      children: [
        Icon(Icons.sports_soccer, color: Cores.verdePrincipal, size: 48),
        const SizedBox(height: 8),
        Text(
          'CRAVA AÍ!',
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

  // Botão "Continuar com Google":
  // • Web: botão oficial GIS (renderButton) — usa FedCM, sem popup.
  // • Mobile: botão Flutter customizado → chama entrarComGoogle() nativo.
  Widget _buildBotaoGoogle() {
    if (kIsWeb) {
      // FlexHtmlElementView (usado pelo renderButton) auto-dimensiona via
      // ResizeObserver. Passamos a largura disponível como minimumWidth para
      // que o botão GIS preencha o card. O ConstrainedBox reserva altura
      // mínima enquanto o GIS ainda não renderizou.
      return LayoutBuilder(
        builder: (context, constraints) {
          final double largura = constraints.maxWidth.clamp(200.0, 400.0);
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Stack(
              alignment: Alignment.center,
              children: [
                buildBotaoGoogleWeb(largura: largura),
                if (_carregandoGoogle)
                  Container(
                    height: 44,
                    color: Colors.white.withValues(alpha: 0.85),
                    child: const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    // Android/Mobile: botão estilizado conforme especificações do botão GIS
    // (outline theme, rectangular shape, large size — mesmo visual do web).
    return OutlinedButton(
      onPressed: (_carregando || _carregandoGoogle) ? null : _entrarComGoogle,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF747775)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: _carregandoGoogle
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoGoogle(tamanho: 18),
                const SizedBox(width: 10),
                Text(
                  'Fazer login com o Google',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F1F1F),
                    letterSpacing: 0.25,
                  ),
                ),
              ],
            ),
    );
  }

  // Divisor "ou" entre o botão Google e o formulário de e-mail
  Widget _buildDivisor() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFDADCE0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFDADCE0))),
      ],
    );
  }

  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Email'),
        const SizedBox(height: 4),
        _buildCampoTexto(
          controller: _emailController,
          hint: 'seu@email.com',
          icone: Icons.mail_outlined,
          tipo: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).requestFocus(_senhaFocus),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Senha'),
            if (_modoLogin)
              TextButton(
                onPressed: () {},
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
          obscureText: !_senhaVisivel,
          focusNode: _senhaFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _entrar(),
          suffixIcon: IconButton(
            icon: Icon(
              _senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Cores.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 8),
          Text(
            _erro!,
            style: GoogleFonts.hankenGrotesk(fontSize: 14, color: Colors.red),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_carregando || _carregandoGoogle) ? null : _entrar,
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

  Widget _buildRodape() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _modoLogin ? 'Não tem uma conta? ' : 'Já tem conta? ',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: Cores.onSurfaceVariant),
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

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String hint,
    required IconData icone,
    TextInputType tipo = TextInputType.text,
    bool obscureText = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: tipo,
      obscureText: obscureText,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: GoogleFonts.hankenGrotesk(fontSize: 16, color: Cores.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
        prefixIcon: Icon(icone, color: Cores.onSurfaceVariant),
        suffixIcon: suffixIcon,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Cores.azulTerciario, width: 2),
        ),
      ),
    );
  }
}

// ─── Logo do Google renderizado com CustomPainter ────────────────────────────
// Desenha o "G" colorido do Google sem precisar de arquivo de imagem externo.

class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle({required this.tamanho});
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(tamanho, tamanho),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * 0.12;

    // Arco azul (225° → 90°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.88),
        _rad(225), _rad(225), false, paint);

    // Arco vermelho (315° → 45°) — deixamos o azul cobrir o início
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.88),
        _rad(315), _rad(90), false, paint);

    // Arco amarelo (45° → 45°)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.88),
        _rad(45), _rad(45), false, paint);

    // Arco verde (90° → 135°)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.88),
        _rad(90), _rad(135), false, paint);

    // Barra horizontal azul (o traço do "G")
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.07, r * 0.88, size.height * 0.14),
      paint,
    );
  }

  double _rad(double graus) => graus * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Dialog de account linking ────────────────────────────────────────────────
// Exibido quando o e-mail do Google já tem uma conta com senha no Firebase.
// Pede a senha para fazer login com ela e então vincula o Google à mesma conta.

class _DialogVincularConta extends StatefulWidget {
  const _DialogVincularConta({
    required this.email,
    required this.credencialGoogle,
  });
  final String email;
  final Object credencialGoogle; // AuthCredential

  @override
  State<_DialogVincularConta> createState() => _DialogVincularContaState();
}

class _DialogVincularContaState extends State<_DialogVincularConta> {
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _vincular() async {
    final senha = _senhaController.text.trim();
    if (senha.isEmpty) {
      setState(() => _erro = 'Digite sua senha.');
      return;
    }
    setState(() { _carregando = true; _erro = null; });
    try {
      await AuthService().vincularGoogle(
        email: widget.email,
        senha: senha,
        credencialGoogle: widget.credencialGoogle as dynamic,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      // authStateChanges dispara → main.dart roteia automaticamente
    } on FirebaseAuthException catch (e) {
      setState(() {
        _erro = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Senha incorreta.'
            : 'Erro ao conectar as contas. Tente novamente.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Conectar conta Google',
        style: GoogleFonts.anybody(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O e-mail ${widget.email} já tem uma conta com senha neste app.',
            style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite sua senha para conectar o Google à sua conta existente. Depois disso você poderá entrar das duas formas.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              color: Cores.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _senhaController,
            obscureText: !_senhaVisivel,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _vincular(),
            style: GoogleFonts.hankenGrotesk(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Senha',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Cores.azulTerciario, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Cores.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              ),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(
              _erro!,
              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _carregando ? null : () => Navigator.of(context).pop(),
          child: Text('CANCELAR',
              style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
        ),
        FilledButton(
          onPressed: _carregando ? null : _vincular,
          style: FilledButton.styleFrom(backgroundColor: Cores.azulTerciario),
          child: _carregando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('CONECTAR',
                  style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
