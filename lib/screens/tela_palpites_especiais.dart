import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../services/usuario_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import '../utils/dialogos.dart';


// ─── Tela ─────────────────────────────────────────────────────────────────────

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
  String? _erro;

  String? _campeaoSelecionado;
  String? _chuteiradeOuroSelecionado;
  String? _boladeOuroSelecionado;
  String? _luvadeOuroSelecionado;
  String? _melhorJovemSelecionado;

  List<JogadorData> _jogadores = [];
  late final List<String> _timesSorted;

  @override
  void initState() {
    super.initState();
    _timesSorted = kTimesCopa2026.toList()
      ..sort((a, b) => nomePtDe(a).compareTo(nomePtDe(b)));
    _inicializar();
  }

  Future<List<JogadorData>> _carregarJogadores() async {
    final raw =
        await rootBundle.loadString('assets/dados/jogadores.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final result = <JogadorData>[];
    for (final sel in data['selecoes'] as List) {
      final selNome = sel['nome'] as String;
      final selNomePt = sel['nomePt'] as String;
      for (final j in sel['jogadores'] as List) {
        result.add(JogadorData(
          nome: j['nome'] as String,
          posicao: j['posicao'] as String,
          clube: j['clube'] as String,
          selecaoNome: selNome,
          selecaoNomePt: selNomePt,
        ));
      }
    }
    return result;
  }

  Future<void> _inicializar() async {
    final results = await Future.wait<Object?>([
      UsuarioService().buscarPorUid(_uid),
      FirebaseFirestore.instance.collection('config').doc('copa2026').get(),
      _carregarJogadores(),
    ]);
    if (!mounted) return;

    final usuario = results[0] as Usuario?;
    final configSnap = results[1] as DocumentSnapshot;
    final jogadores = results[2] as List<JogadorData>;

    final travados =
        (configSnap.data() as Map<String, dynamic>?)?['palpitesTravados']
            as bool? ??
        false;

    setState(() {
      _campeaoSelecionado = usuario?.palpiteCampeao;
      _chuteiradeOuroSelecionado = usuario?.palpiteChuteiradeOuro;
      _boladeOuroSelecionado = usuario?.palpiteBoladeOuro;
      _luvadeOuroSelecionado = usuario?.palpiteLuvadeOuro;
      _melhorJovemSelecionado = usuario?.palpiteMelhorJovem;
      _bloqueado = travados;
      _jogadores = jogadores;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    if (_campeaoSelecionado == null) {
      setState(() => _erro = 'Selecione o Campeão do Mundo.');
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
        chuteiradeOuro: _chuteiradeOuroSelecionado,
        boladeOuro: _boladeOuroSelecionado,
        luvadeOuro: _luvadeOuroSelecionado,
        melhorJovem: _melhorJovemSelecionado,
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

  void _abrirSeletorJogador({
    required String titulo,
    required String? selecionadoAtual,
    required void Function(String?) onSelecionado,
    bool apenasGoleiros = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetJogadores(
        titulo: titulo,
        jogadores: _jogadores,
        selecionadoAtual: selecionadoAtual,
        apenasGoleiros: apenasGoleiros,
        cor: Cores.ouro,
        onSelecionado: (nome) {
          onSelecionado(nome);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _mostrarDica(String titulo, String descricao) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Cores.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titulo,
          style: GoogleFonts.anybody(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Cores.onSurface,
          ),
        ),
        content: Text(
          descricao,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: Cores.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.anybody(
                fontWeight: FontWeight.w700,
                color: Cores.ouro,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.ouro,
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
              child: CircularProgressIndicator(color: Cores.ouro))
          : Column(
              children: [
                if (_bloqueado)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Cores.ouro.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded,
                            size: 16, color: Cores.ouro),
                        const SizedBox(width: 8),
                        Text(
                          'Bloqueado — a Copa já começou.',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            color: Cores.ouro,
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

                      // ── CAMPEÃO ────────────────────────────────────────────
                      _buildSecaoLabel('CAMPEÃO DO MUNDO'),
                      const SizedBox(height: 6),
                      _SeletorTime(
                        label: 'Campeão do Mundo',
                        time: _campeaoSelecionado,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorTime(
                          titulo: 'Campeão do Mundo',
                          selecionadoAtual: _campeaoSelecionado,
                          onSelecionado: (t) =>
                              setState(() => _campeaoSelecionado = t),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── PREMIAÇÕES OFICIAIS FIFA (card) ───────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Cores.ouro.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Cores.ouro.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    size: 15, color: Cores.ouro),
                                const SizedBox(width: 8),
                                Text(
                                  'PREMIAÇÕES OFICIAIS FIFA',
                                  style: GoogleFonts.anybody(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Cores.ouro,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ── CHUTEIRA DE OURO ───────────────────────────
                            _buildSecaoLabel(
                              'CHUTEIRA DE OURO',
                              dica: 'Troféu entregue ao artilheiro (maior goleador) da Copa do Mundo.',
                              onDica: () => _mostrarDica(
                                'Chuteira de Ouro',
                                'Troféu entregue ao artilheiro (maior goleador) da Copa do Mundo.',
                              ),
                            ),
                            const SizedBox(height: 6),
                            _SeletorJogador(
                              label: 'Artilheiro da Copa',
                              jogadorNome: _chuteiradeOuroSelecionado,
                              jogadores: _jogadores,
                              bloqueado: _bloqueado,
                              onTap: () => _abrirSeletorJogador(
                                titulo: 'Chuteira de Ouro',
                                selecionadoAtual: _chuteiradeOuroSelecionado,
                                onSelecionado: (n) =>
                                    setState(() => _chuteiradeOuroSelecionado = n),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── BOLA DE OURO ───────────────────────────────
                            _buildSecaoLabel(
                              'BOLA DE OURO',
                              dica: 'Prêmio concedido ao melhor jogador do torneio, eleito pela FIFA.',
                              onDica: () => _mostrarDica(
                                'Bola de Ouro',
                                'Prêmio concedido ao melhor jogador do torneio, eleito pela FIFA.',
                              ),
                            ),
                            const SizedBox(height: 6),
                            _SeletorJogador(
                              label: 'Melhor jogador do torneio',
                              jogadorNome: _boladeOuroSelecionado,
                              jogadores: _jogadores,
                              bloqueado: _bloqueado,
                              onTap: () => _abrirSeletorJogador(
                                titulo: 'Bola de Ouro',
                                selecionadoAtual: _boladeOuroSelecionado,
                                onSelecionado: (n) =>
                                    setState(() => _boladeOuroSelecionado = n),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── LUVA DE OURO ───────────────────────────────
                            _buildSecaoLabel(
                              'LUVA DE OURO',
                              dica: 'Prêmio ao melhor goleiro da Copa do Mundo, eleito pela FIFA.',
                              onDica: () => _mostrarDica(
                                'Luva de Ouro',
                                'Prêmio ao melhor goleiro da Copa do Mundo, eleito pela FIFA.',
                              ),
                            ),
                            const SizedBox(height: 6),
                            _SeletorJogador(
                              label: 'Melhor goleiro',
                              jogadorNome: _luvadeOuroSelecionado,
                              jogadores: _jogadores,
                              bloqueado: _bloqueado,
                              onTap: () => _abrirSeletorJogador(
                                titulo: 'Luva de Ouro',
                                selecionadoAtual: _luvadeOuroSelecionado,
                                apenasGoleiros: true,
                                onSelecionado: (n) =>
                                    setState(() => _luvadeOuroSelecionado = n),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── MELHOR JOGADOR JOVEM ───────────────────────
                            _buildSecaoLabel(
                              'MELHOR JOGADOR JOVEM',
                              dica: 'Prêmio ao melhor jogador jovem (sub-21) da Copa do Mundo, eleito pela FIFA.',
                              onDica: () => _mostrarDica(
                                'Melhor Jogador Jovem',
                                'Prêmio ao melhor jogador jovem (sub-21) da Copa do Mundo, eleito pela FIFA.',
                              ),
                            ),
                            const SizedBox(height: 6),
                            _SeletorJogador(
                              label: 'Melhor jogador jovem',
                              jogadorNome: _melhorJovemSelecionado,
                              jogadores: _jogadores,
                              bloqueado: _bloqueado,
                              onTap: () => _abrirSeletorJogador(
                                titulo: 'Melhor Jogador Jovem',
                                selecionadoAtual: _melhorJovemSelecionado,
                                onSelecionado: (n) =>
                                    setState(() => _melhorJovemSelecionado = n),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_erro != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _erro!,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            color: Cores.error,
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

  Widget _buildSecaoLabel(String texto, {String? dica, VoidCallback? onDica}) {
    return Row(
      children: [
        Text(
          texto,
          style: GoogleFonts.anybody(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Cores.onSurfaceVariant,
          ),
        ),
        if (onDica != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onDica,
            child: const Icon(
              Icons.help_outline_rounded,
              size: 16,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ],
      ],
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
            backgroundColor: Cores.ouro,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ─── Seletor de jogador ───────────────────────────────────────────────────────

class _SeletorJogador extends StatelessWidget {
  const _SeletorJogador({
    required this.label,
    required this.jogadorNome,
    required this.jogadores,
    required this.bloqueado,
    required this.onTap,
  });

  final String label;
  final String? jogadorNome;
  final List<JogadorData> jogadores;
  final bool bloqueado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    JogadorData? jogador;
    if (jogadorNome != null && jogadores.isNotEmpty) {
      try {
        jogador = jogadores.firstWhere((j) => j.nome == jogadorNome);
      } catch (_) {}
    }

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
            if (jogador != null) ...[
              Container(
                width: 36,
                height: 36,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Bandeira(jogador.selecaoNome, tamanho: 36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      jogador.nome,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Cores.onSurface,
                      ),
                    ),
                    Text(
                      jogador.clube != '-'
                          ? '${jogador.selecaoNomePt} · ${jogador.clube}'
                          : jogador.selecaoNomePt,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: Cores.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (jogadorNome != null) ...[
              const Icon(Icons.person_rounded,
                  size: 20, color: Cores.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  jogadorNome!,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    color: Cores.onSurfaceVariant,
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
  String _busca = '';
  final _ctrlBusca = TextEditingController();

  @override
  void dispose() {
    _ctrlBusca.dispose();
    super.dispose();
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');

  @override
  Widget build(BuildContext context) {
    final buscaNorm = _norm(_busca);
    final filtrados = widget.times
        .where((t) => _norm(nomePtDe(t)).contains(buscaNorm))
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
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Cores.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                        color: Cores.ouro, width: 2),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
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
                            ? Cores.ouro
                            : Cores.onSurface,
                      ),
                    ),
                    trailing: selecionado
                        ? const Icon(Icons.check_circle,
                            color: Cores.ouro, size: 22)
                        : null,
                    tileColor: selecionado
                        ? Cores.ouro.withValues(alpha: 0.08)
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
