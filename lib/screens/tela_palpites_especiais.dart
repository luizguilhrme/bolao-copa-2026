import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../models/usuario.dart';
import '../services/jogo_service.dart';
import '../services/usuario_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaPalpitesEspeciais extends StatefulWidget {
  const TelaPalpitesEspeciais({super.key});

  @override
  State<TelaPalpitesEspeciais> createState() => _TelaPalpitesEspeciaisState();
}

class _TelaPalpitesEspeciaisState extends State<TelaPalpitesEspeciais> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  bool _salvando = false;
  bool _bloqueado = false;

  String? _campeaoSelecionado;
  late final TextEditingController _ctrlArtilheiro;
  late final TextEditingController _ctrlGoleiro;
  late final TextEditingController _ctrlMelhorJogador;
  String? _maisGoleadoraSelecionada;
  String? _menosVazadaSelecionada;
  String? _erro;

  late final List<String> _timesSorted;

  @override
  void initState() {
    super.initState();
    _ctrlArtilheiro = TextEditingController();
    _ctrlGoleiro = TextEditingController();
    _ctrlMelhorJogador = TextEditingController();
    _timesSorted = kTimesCopa2026.toList()
      ..sort((a, b) => nomePtDe(a).compareTo(nomePtDe(b)));
    _inicializar();
  }

  @override
  void dispose() {
    _ctrlArtilheiro.dispose();
    _ctrlGoleiro.dispose();
    _ctrlMelhorJogador.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final results = await Future.wait([
      UsuarioService().buscarPorUid(_uid),
      JogoService().buscarTodos(),
      FirebaseFirestore.instance.collection('config').doc('copa2026').get(),
    ]);
    if (!mounted) return;
    final usuario = results[0] as Usuario?;
    final jogos = results[1] as List<Jogo>;
    final configSnap = results[2] as DocumentSnapshot;

    final travados =
        (configSnap.data() as Map<String, dynamic>?)?['palpitesTravados']
            as bool? ??
        false;

    bool bloqueado = travados;
    if (!bloqueado && jogos.isNotEmpty) {
      final ordenados = jogos.toList()
        ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
      bloqueado = DateTime.now().isAfter(ordenados.first.dataHora);
    }

    setState(() {
      _campeaoSelecionado = usuario?.palpiteCampeao;
      _ctrlArtilheiro.text = usuario?.palpiteArtilheiro ?? '';
      _ctrlGoleiro.text = usuario?.palpiteGoleiro ?? '';
      _ctrlMelhorJogador.text = usuario?.palpiteMelhorJogador ?? '';
      _maisGoleadoraSelecionada = usuario?.palpiteMaisGoleadora;
      _menosVazadaSelecionada = usuario?.palpiteMenosVazada;
      _bloqueado = bloqueado;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    if (_campeaoSelecionado == null) {
      setState(() => _erro = 'Selecione o campeão.');
      return;
    }
    if (_ctrlArtilheiro.text.trim().isEmpty) {
      setState(() => _erro = 'Digite o nome do artilheiro.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await UsuarioService().salvarPalpitesEspeciais(
        uid: _uid,
        campeao: _campeaoSelecionado!,
        artilheiro: _ctrlArtilheiro.text.trim(),
        goleiro: _ctrlGoleiro.text.trim().isEmpty ? null : _ctrlGoleiro.text.trim(),
        melhorJogador: _ctrlMelhorJogador.text.trim().isEmpty ? null : _ctrlMelhorJogador.text.trim(),
        maisGoleadora: _maisGoleadoraSelecionada,
        menosVazada: _menosVazadaSelecionada,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Palpites especiais salvos!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Cores.verdePrincipal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao salvar. Tente novamente.';
          _salvando = false;
        });
      }
    }
  }

  void _abrirSeletorTime({
    required String titulo,
    required String? selecionadoAtual,
    required void Function(String?) onSelecionado,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetTimes(
        titulo: titulo,
        times: _timesSorted,
        selecionadoAtual: selecionadoAtual,
        onSelecionado: (t) {
          onSelecionado(t);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.azulTerciario,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PALPITES ESPECIAIS',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Cores.azulTerciario))
          : Column(
              children: [
                if (_bloqueado)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Cores.azulTerciario.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded,
                            size: 16, color: Cores.azulTerciario),
                        const SizedBox(width: 8),
                        Text(
                          'Bloqueado — a Copa já começou.',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            color: Cores.azulTerciario,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      if (!_bloqueado)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Válidos até o início do primeiro jogo.',
                            style: GoogleFonts.hankenGrotesk(
                                fontSize: 13,
                                color: Cores.onSurfaceVariant),
                          ),
                        ),

                      // ── CAMPEÃO ──────────────────────────────────────────────
                      _buildSecaoLabel('CAMPEÃO'),
                      const SizedBox(height: 6),
                      _SeletorTime(
                        label: 'Campeão da Copa',
                        time: _campeaoSelecionado,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorTime(
                          titulo: 'Campeão',
                          selecionadoAtual: _campeaoSelecionado,
                          onSelecionado: (t) =>
                              setState(() => _campeaoSelecionado = t),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── ARTILHEIRO ───────────────────────────────────────────
                      _buildSecaoLabel('ARTILHEIRO'),
                      const SizedBox(height: 6),
                      _buildCampoTexto(
                          controller: _ctrlArtilheiro,
                          hint: 'Nome do artilheiro'),

                      const SizedBox(height: 20),

                      // ── MELHOR GOLEIRO ───────────────────────────────────────
                      _buildSecaoLabel('MELHOR GOLEIRO'),
                      const SizedBox(height: 6),
                      _buildCampoTexto(
                          controller: _ctrlGoleiro,
                          hint: 'Nome do melhor goleiro'),

                      const SizedBox(height: 20),

                      // ── MELHOR JOGADOR ───────────────────────────────────────
                      _buildSecaoLabel('MELHOR JOGADOR'),
                      const SizedBox(height: 6),
                      _buildCampoTexto(
                          controller: _ctrlMelhorJogador,
                          hint: 'Nome do melhor jogador do torneio'),

                      const SizedBox(height: 20),

                      // ── EQUIPE MAIS GOLEADORA ────────────────────────────────
                      _buildSecaoLabel('EQUIPE MAIS GOLEADORA'),
                      const SizedBox(height: 6),
                      _SeletorTime(
                        label: 'Equipe mais goleadora',
                        time: _maisGoleadoraSelecionada,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorTime(
                          titulo: 'Equipe mais goleadora',
                          selecionadoAtual: _maisGoleadoraSelecionada,
                          onSelecionado: (t) =>
                              setState(() => _maisGoleadoraSelecionada = t),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── EQUIPE MENOS VAZADA ──────────────────────────────────
                      _buildSecaoLabel('EQUIPE MENOS VAZADA'),
                      const SizedBox(height: 6),
                      _SeletorTime(
                        label: 'Equipe menos vazada',
                        time: _menosVazadaSelecionada,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorTime(
                          titulo: 'Equipe menos vazada',
                          selecionadoAtual: _menosVazadaSelecionada,
                          onSelecionado: (t) =>
                              setState(() => _menosVazadaSelecionada = t),
                        ),
                      ),

                      if (_erro != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erro!,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            color: const Color(0xFFE53935),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (!_bloqueado) _buildBotaoSalvar(),
              ],
            ),
    );
  }

  Widget _buildSecaoLabel(String texto) {
    return Text(
      texto,
      style: GoogleFonts.anybody(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Cores.onSurfaceVariant,
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      enabled: !_bloqueado,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.hankenGrotesk(fontSize: 15, color: Cores.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
        filled: true,
        fillColor: Cores.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Cores.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Cores.azulTerciario, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Cores.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildBotaoSalvar() {
    return Container(
      color: Cores.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            _salvando ? 'Salvando...' : 'SALVAR PALPITES',
            style: GoogleFonts.anybody(
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Cores.azulTerciario,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ─── Seletor de time com bandeira ─────────────────────────────────────────────

class _SeletorTime extends StatelessWidget {
  const _SeletorTime({
    required this.label,
    required this.time,
    required this.bloqueado,
    required this.onTap,
  });

  final String label;
  final String? time;
  final bool bloqueado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: bloqueado ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Cores.surfaceContainer,
          border: Border.all(color: Cores.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (time != null) ...[
              Container(
                width: 32,
                height: 32,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Bandeira(time!, tamanho: 32),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nomePtDe(time!),
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurface,
                  ),
                ),
              ),
            ] else ...[
              const Icon(Icons.search_rounded,
                  size: 20, color: Cores.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (!bloqueado)
              const Icon(Icons.chevron_right_rounded,
                  color: Cores.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet de seleção de time ─────────────────────────────────────────

class _BottomSheetTimes extends StatefulWidget {
  const _BottomSheetTimes({
    required this.titulo,
    required this.times,
    required this.selecionadoAtual,
    required this.onSelecionado,
  });

  final String titulo;
  final List<String> times;
  final String? selecionadoAtual;
  final void Function(String?) onSelecionado;

  @override
  State<_BottomSheetTimes> createState() => _BottomSheetTimesState();
}

class _BottomSheetTimesState extends State<_BottomSheetTimes> {
  late String _busca;
  late final TextEditingController _ctrlBusca;

  @override
  void initState() {
    super.initState();
    _busca = '';
    _ctrlBusca = TextEditingController();
  }

  @override
  void dispose() {
    _ctrlBusca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.times
        .where((t) => nomePtDe(t)
            .toLowerCase()
            .contains(_busca.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Cores.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Cores.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Título
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.titulo.toUpperCase(),
                    style: GoogleFonts.anybody(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Cores.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Campo de busca
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrlBusca,
                autofocus: false,
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: GoogleFonts.hankenGrotesk(
                      color: Cores.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Cores.onSurfaceVariant),
                  filled: true,
                  fillColor: Cores.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Cores.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Cores.azulTerciario, width: 2),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Lista
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtrados.length,
                itemBuilder: (_, i) {
                  final time = filtrados[i];
                  final selecionado = widget.selecionadoAtual == time;
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Cores.outlineVariant),
                      ),
                      child: Bandeira(time, tamanho: 36),
                    ),
                    title: Text(
                      nomePtDe(time),
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        fontWeight: selecionado
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: selecionado
                            ? Cores.azulTerciario
                            : Cores.onSurface,
                      ),
                    ),
                    trailing: selecionado
                        ? const Icon(Icons.check_circle,
                            color: Cores.azulTerciario, size: 22)
                        : null,
                    tileColor: selecionado
                        ? Cores.azulTerciario.withValues(alpha: 0.08)
                        : null,
                    onTap: () => widget.onSelecionado(time),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
