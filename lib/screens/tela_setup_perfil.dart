import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
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
    // Cancela o cadastro: desfaz a conta criada e volta para o login
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).pop();
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
      // Volta para a root — que nesse momento já é o MenuPrincipal
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
