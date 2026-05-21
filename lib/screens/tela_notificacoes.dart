import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notificacoes_service.dart';
import '../utils/cores.dart';

class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  bool _carregando = true;
  bool _lembretes = true;
  bool _ranking = true;

  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _service = NotificacoesService();

  @override
  void initState() {
    super.initState();
    _carregarPrefs();
  }

  Future<void> _carregarPrefs() async {
    final prefs = await _service.buscarPrefs(_uid);
    if (!mounted) return;
    setState(() {
      _lembretes = prefs['lembretes']!;
      _ranking = prefs['ranking']!;
      _carregando = false;
    });
  }

  Future<void> _alternarLembretes(bool valor) async {
    setState(() => _lembretes = valor);
    await _service.atualizarPrefs(_uid, lembretes: valor);
  }

  Future<void> _alternarRanking(bool valor) async {
    setState(() => _ranking = valor);
    await _service.atualizarPrefs(_uid, ranking: valor);
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
          'NOTIFICAÇÕES',
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
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Cores.verdePrincipal))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
              children: [
                Text(
                  'Gerencie quais notificações você deseja receber.',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Cores.surface,
                    border: Border.all(color: Cores.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _TileNotificacao(
                        icone: Icons.sports_soccer_rounded,
                        titulo: 'Lembrete de palpite',
                        descricao:
                            'Aviso 30 minutos antes de um jogo começar caso você ainda não tenha palpitado.',
                        valor: _lembretes,
                        onChanged: _alternarLembretes,
                        primeiro: true,
                      ),
                      const Divider(
                        height: 1,
                        color: Cores.outlineVariant,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _TileNotificacao(
                        icone: Icons.leaderboard_rounded,
                        titulo: 'Mudança no ranking',
                        descricao:
                            'Aviso quando você subir ou descer posições no ranking após um resultado ser registrado.',
                        valor: _ranking,
                        onChanged: _alternarRanking,
                        ultimo: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TileNotificacao extends StatelessWidget {
  const _TileNotificacao({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.onChanged,
    this.primeiro = false,
    this.ultimo = false,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final bool valor;
  final ValueChanged<bool> onChanged;
  final bool primeiro;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!valor),
      borderRadius: BorderRadius.vertical(
        top: primeiro ? const Radius.circular(16) : Radius.zero,
        bottom: ultimo ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: valor
                    ? Cores.verdePrincipal.withOpacity(0.1)
                    : Cores.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icone,
                size: 20,
                color: valor ? Cores.verdePrincipal : Cores.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Cores.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    descricao,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: Cores.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: valor,
              onChanged: onChanged,
              activeColor: Cores.verdePrincipal,
              activeTrackColor: Cores.verdePrincipal.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
