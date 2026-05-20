import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../services/usuario_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class _Jogador {
  final String id;
  final String nome;
  final String pais;
  const _Jogador(this.id, this.nome, this.pais);
}

const _jogadores = [
  _Jogador('messi', 'Messi', 'Argentina'),
  _Jogador('cr7', 'Cristiano Ronaldo', 'Portugal'),
  _Jogador('mbappe', 'Mbappé', 'France'),
  _Jogador('vinicius', 'Vinicius Jr.', 'Brazil'),
  _Jogador('haaland', 'Haaland', 'Norway'),
  _Jogador('bellingham', 'Bellingham', 'England'),
  _Jogador('salah', 'Salah', 'Egypt'),
  _Jogador('kane', 'Kane', 'England'),
  _Jogador('yamal', 'Yamal', 'Spain'),
  _Jogador('pedri', 'Pedri', 'Spain'),
  _Jogador('de_bruyne', 'De Bruyne', 'Belgium'),
  _Jogador('rodri', 'Rodri', 'Spain'),
];

class TelaSetupPerfil extends StatefulWidget {
  const TelaSetupPerfil({super.key, required this.email, required this.senha});

  final String email;
  final String senha;

  @override
  State<TelaSetupPerfil> createState() => _TelaSetupPerfilState();
}

class _TelaSetupPerfilState extends State<TelaSetupPerfil> {
  late final TextEditingController _nomeController;
  String _avatarSelecionado = _jogadores.first.id;
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.email.split('@').first);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Digite seu nome.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultado = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.senha,
      );
      await UsuarioService().criarPerfil(Usuario(
        uid: resultado.user!.uid,
        email: widget.email,
        nome: nome,
        avatar: _avatarSelecionado,
        criadoEm: DateTime.now(),
      ));
      // authStateChanges dispara e o main.dart troca para MenuPrincipal automaticamente
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _traduzirErro(e.code));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _traduzirErro(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':
        return 'Esse e-mail já está cadastrado. Volte e faça login.';
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
      appBar: AppBar(
        backgroundColor: Cores.surface,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Cores.verdePrincipal),
          onPressed: () => Navigator.of(context).pop(),
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
                // Campo de nome
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

                // Grade de avatares
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
                  itemCount: _jogadores.length,
                  itemBuilder: (context, index) {
                    final jogador = _jogadores[index];
                    return _CardAvatar(
                      jogador: jogador,
                      selecionado: _avatarSelecionado == jogador.id,
                      onTap: () => setState(() => _avatarSelecionado = jogador.id),
                    );
                  },
                ),
              ],
            ),
          ),

          // Barra inferior com botão
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

class _CardAvatar extends StatelessWidget {
  const _CardAvatar({
    required this.jogador,
    required this.selecionado,
    required this.onTap,
  });

  final _Jogador jogador;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFE8F5E9) : Cores.surface,
          border: Border.all(
            color: selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
            width: selecionado ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/avatares/${jogador.id}.jpg',
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 62,
                      height: 62,
                      color: Cores.surfaceContainerHigh,
                      child: const Icon(Icons.person_rounded, size: 38, color: Cores.onSurfaceVariant),
                    ),
                  ),
                ),
                if (selecionado)
                  Container(
                    decoration: const BoxDecoration(
                      color: Cores.verdePrincipal,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                jogador.nome,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurface,
                ),
              ),
            ),
            Text(
              flagDe(jogador.pais),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
