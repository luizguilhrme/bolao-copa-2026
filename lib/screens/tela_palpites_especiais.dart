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

// ─── Modelo de dados ──────────────────────────────────────────────────────────

class _JogadorData {
  const _JogadorData({
    required this.nome,
    required this.posicao,
    required this.clube,
    required this.selecaoNome,
    required this.selecaoNomePt,
  });

  final String nome;
  final String posicao;
  final String clube;
  final String selecaoNome;
  final String selecaoNomePt;
}

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
  String? _artilheiroSelecionado;
  String? _goleiroSelecionado;
  String? _melhorJogadorSelecionado;
  String? _maisGoleadoraSelecionada;
  String? _menosVazadaSelecionada;

  List<_JogadorData> _jogadores = [];
  late final List<String> _timesSorted;

  @override
  void initState() {
    super.initState();
    _timesSorted = kTimesCopa2026.toList()
      ..sort((a, b) => nomePtDe(a).compareTo(nomePtDe(b)));
    _inicializar();
  }

  Future<List<_JogadorData>> _carregarJogadores() async {
    final raw =
        await rootBundle.loadString('assets/dados/jogadores.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final result = <_JogadorData>[];
    for (final sel in data['selecoes'] as List) {
      final selNome = sel['nome'] as String;
      final selNomePt = sel['nomePt'] as String;
      for (final j in sel['jogadores'] as List) {
        result.add(_JogadorData(
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
    final jogadores = results[2] as List<_JogadorData>;

    final travados =
        (configSnap.data() as Map<String, dynamic>?)?['palpitesTravados']
            as bool? ??
        false;

    setState(() {
      _campeaoSelecionado = usuario?.palpiteCampeao;
      _artilheiroSelecionado = usuario?.palpiteArtilheiro;
      _goleiroSelecionado = usuario?.palpiteGoleiro;
      _melhorJogadorSelecionado = usuario?.palpiteMelhorJogador;
      _maisGoleadoraSelecionada = usuario?.palpiteMaisGoleadora;
      _menosVazadaSelecionada = usuario?.palpiteMenosVazada;
      _bloqueado = travados;
      _jogadores = jogadores;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    if (_campeaoSelecionado == null) {
      setState(() => _erro = 'Selecione o campeão.');
      return;
    }
    if (_artilheiroSelecionado == null) {
      setState(() => _erro = 'Selecione o artilheiro.');
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
        artilheiro: _artilheiroSelecionado!,
        goleiro: _goleiroSelecionado,
        melhorJogador: _melhorJogadorSelecionado,
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
      builder: (_) => _BottomSheetJogadores(
        titulo: titulo,
        jogadores: _jogadores,
        selecionadoAtual: selecionadoAtual,
        apenasGoleiros: apenasGoleiros,
        onSelecionado: (nome) {
          onSelecionado(nome);
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
        backgroundColor: const Color(0xFFB8860B),
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
              child: CircularProgressIndicator(color: Color(0xFFB8860B)))
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

                      // ── CAMPEÃO ────────────────────────────────────────────
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

                      // ── ARTILHEIRO ─────────────────────────────────────────
                      _buildSecaoLabel('ARTILHEIRO'),
                      const SizedBox(height: 6),
                      _SeletorJogador(
                        label: 'Artilheiro da Copa',
                        jogadorNome: _artilheiroSelecionado,
                        jogadores: _jogadores,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorJogador(
                          titulo: 'Artilheiro',
                          selecionadoAtual: _artilheiroSelecionado,
                          onSelecionado: (n) =>
                              setState(() => _artilheiroSelecionado = n),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── MELHOR GOLEIRO ─────────────────────────────────────
                      _buildSecaoLabel('MELHOR GOLEIRO'),
                      const SizedBox(height: 6),
                      _SeletorJogador(
                        label: 'Melhor goleiro',
                        jogadorNome: _goleiroSelecionado,
                        jogadores: _jogadores,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorJogador(
                          titulo: 'Melhor Goleiro',
                          selecionadoAtual: _goleiroSelecionado,
                          apenasGoleiros: true,
                          onSelecionado: (n) =>
                              setState(() => _goleiroSelecionado = n),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── MELHOR JOGADOR ─────────────────────────────────────
                      _buildSecaoLabel('MELHOR JOGADOR'),
                      const SizedBox(height: 6),
                      _SeletorJogador(
                        label: 'Melhor jogador do torneio',
                        jogadorNome: _melhorJogadorSelecionado,
                        jogadores: _jogadores,
                        bloqueado: _bloqueado,
                        onTap: () => _abrirSeletorJogador(
                          titulo: 'Melhor Jogador',
                          selecionadoAtual: _melhorJogadorSelecionado,
                          onSelecionado: (n) =>
                              setState(() => _melhorJogadorSelecionado = n),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── EQUIPE MAIS GOLEADORA ──────────────────────────────
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

                      // ── EQUIPE MENOS VAZADA ────────────────────────────────
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
            backgroundColor: const Color(0xFFB8860B),
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
  final List<_JogadorData> jogadores;
  final bool bloqueado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    _JogadorData? jogador;
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

// ─── Bottom sheet de seleção de jogador ──────────────────────────────────────

class _BottomSheetJogadores extends StatefulWidget {
  const _BottomSheetJogadores({
    required this.titulo,
    required this.jogadores,
    required this.selecionadoAtual,
    required this.onSelecionado,
    this.apenasGoleiros = false,
  });

  final String titulo;
  final List<_JogadorData> jogadores;
  final String? selecionadoAtual;
  final void Function(String?) onSelecionado;
  final bool apenasGoleiros;

  @override
  State<_BottomSheetJogadores> createState() => _BottomSheetJogadoresState();
}

class _BottomSheetJogadoresState extends State<_BottomSheetJogadores> {
  String _busca = '';
  String? _filtroSelecao;
  final _ctrlBusca = TextEditingController();

  // lista de seleções únicas preservando a ordem do JSON (A→L)
  late final List<(String nome, String nomePt)> _selecoes;

  @override
  void initState() {
    super.initState();
    final base = widget.apenasGoleiros
        ? widget.jogadores.where((j) => j.posicao == 'GOL').toList()
        : widget.jogadores;
    final vistas = <String>{};
    final list = <(String, String)>[];
    for (final j in base) {
      if (vistas.add(j.selecaoNome)) {
        list.add((j.selecaoNome, j.selecaoNomePt));
      }
    }
    _selecoes = list;
  }

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
    // 1. filtro por posição
    final porPosicao = widget.apenasGoleiros
        ? widget.jogadores.where((j) => j.posicao == 'GOL').toList()
        : widget.jogadores;

    // 2. filtro por seleção
    final porSelecao = _filtroSelecao == null
        ? porPosicao
        : porPosicao.where((j) => j.selecaoNome == _filtroSelecao).toList();

    // 3. filtro por nome
    final buscaNorm = _norm(_busca);
    final filtrados = buscaNorm.isEmpty
        ? porSelecao
        : porSelecao
            .where((j) => _norm(j.nome).contains(buscaNorm))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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

            // ── Título ─────────────────────────────────────────────────────
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
                  if (widget.apenasGoleiros) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Cores.azulTerciario.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'GOLEIROS',
                        style: GoogleFonts.anybody(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Cores.azulTerciario,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Busca por nome ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrlBusca,
                autofocus: false,
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome...',
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

            // ── Filtro por seleção ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  _buildChip(nome: null),
                  if (_filtroSelecao != null) ...[
                    const SizedBox(width: 8),
                    _buildChip(nome: _filtroSelecao),
                  ],
                  const Spacer(),
                  _buildBotaoMais(),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtrados.length} jogador${filtrados.length != 1 ? 'es' : ''}',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 12, color: Cores.onSurfaceVariant),
                ),
              ),
            ),
            const Divider(height: 1),

            // ── Lista ──────────────────────────────────────────────────────
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum resultado',
                        style: GoogleFonts.hankenGrotesk(
                            color: Cores.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) {
                        final j = filtrados[i];
                        final selecionado =
                            widget.selecionadoAtual == j.nome;
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Cores.outlineVariant),
                            ),
                            child: Bandeira(j.selecaoNome, tamanho: 36),
                          ),
                          title: Text(
                            j.nome,
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
                          subtitle: Text(
                            j.clube != '-'
                                ? '${j.selecaoNomePt} · ${j.clube}'
                                : j.selecaoNomePt,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12,
                              color: Cores.onSurfaceVariant,
                            ),
                          ),
                          trailing: selecionado
                              ? const Icon(Icons.check_circle,
                                  color: Cores.azulTerciario, size: 22)
                              : null,
                          tileColor: selecionado
                              ? Cores.azulTerciario.withValues(alpha: 0.08)
                              : null,
                          onTap: () => widget.onSelecionado(j.nome),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSeletorEquipe() {
    showDialog<void>(
      context: context,
      builder: (_) => _DialogSelecaoEquipe(
        selecoes: _selecoes,
        selecionadaAtual: _filtroSelecao,
        onSelecionada: (nome) => setState(() => _filtroSelecao = nome),
      ),
    );
  }

  Widget _buildBotaoMais() {
    return GestureDetector(
      onTap: _abrirSeletorEquipe,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Cores.outlineVariant),
        ),
        child: const Icon(
          Icons.tune_rounded,
          size: 18,
          color: Cores.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildChip({required String? nome}) {
    final selecionado = _filtroSelecao == nome;
    return GestureDetector(
      onTap: () => setState(() => _filtroSelecao = nome),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selecionado ? Cores.azulTerciario : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado
                ? Cores.azulTerciario
                : Cores.outlineVariant,
          ),
        ),
        child: nome == null
            ? Text(
                'Ver todos',
                style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selecionado ? Colors.white : Cores.onSurfaceVariant,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    clipBehavior: Clip.antiAlias,
                    decoration:
                        const BoxDecoration(shape: BoxShape.circle),
                    child: Bandeira(nome, tamanho: 18),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    siglaDe(nome),
                    style: GoogleFonts.anybody(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selecionado
                          ? Colors.white
                          : Cores.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Dialog de seleção de equipe ─────────────────────────────────────────────

class _DialogSelecaoEquipe extends StatefulWidget {
  const _DialogSelecaoEquipe({
    required this.selecoes,
    required this.selecionadaAtual,
    required this.onSelecionada,
  });

  final List<(String, String)> selecoes; // (nome em inglês, nomePt)
  final String? selecionadaAtual;
  final void Function(String?) onSelecionada;

  @override
  State<_DialogSelecaoEquipe> createState() => _DialogSelecaoEquipeState();
}

class _DialogSelecaoEquipeState extends State<_DialogSelecaoEquipe> {
  String _busca = '';
  final _ctrl = TextEditingController();

  // null = ordem padrão (grupos A→L)  |  true = A-Z  |  false = Z-A
  bool? _ordemCrescente;

  @override
  void dispose() {
    _ctrl.dispose();
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

  void _toggleAZ() {
    setState(() {
      _ordemCrescente = _ordemCrescente == true ? false : true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final buscaNorm = _norm(_busca);

    var lista = buscaNorm.isEmpty
        ? widget.selecoes.toList()
        : widget.selecoes
            .where((s) => _norm(s.$2).contains(buscaNorm))
            .toList();

    if (_ordemCrescente == true) {
      lista.sort((a, b) => _norm(a.$2).compareTo(_norm(b.$2)));
    } else if (_ordemCrescente == false) {
      lista.sort((a, b) => _norm(b.$2).compareTo(_norm(a.$2)));
    }

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cabeçalho ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    'FILTRAR POR SELEÇÃO',
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

            // ── Busca ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar seleção...',
                  hintStyle: GoogleFonts.hankenGrotesk(
                      color: Cores.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Cores.onSurfaceVariant),
                  filled: true,
                  fillColor: Cores.surfaceContainer,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
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

            // ── Chips de ordenação ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Ordenar:',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildChipOrdem(
                    label: 'Padrão',
                    ativo: _ordemCrescente == null,
                    icone: null,
                    onTap: () => setState(() => _ordemCrescente = null),
                  ),
                  const SizedBox(width: 8),
                  _buildChipOrdem(
                    label: 'A-Z',
                    ativo: _ordemCrescente != null,
                    icone: _ordemCrescente == false
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    onTap: _toggleAZ,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Lista ──────────────────────────────────────────────────────
            Flexible(
              child: lista.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma seleção encontrada',
                        style: GoogleFonts.hankenGrotesk(
                            color: Cores.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final s = lista[i];
                        final selecionada =
                            widget.selecionadaAtual == s.$1;
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Cores.outlineVariant),
                            ),
                            child: Bandeira(s.$1, tamanho: 36),
                          ),
                          title: Text(
                            s.$2,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15,
                              fontWeight: selecionada
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selecionada
                                  ? Cores.azulTerciario
                                  : Cores.onSurface,
                            ),
                          ),
                          trailing: selecionada
                              ? const Icon(Icons.check_circle,
                                  color: Cores.azulTerciario, size: 22)
                              : null,
                          tileColor: selecionada
                              ? Cores.azulTerciario.withValues(alpha: 0.08)
                              : null,
                          onTap: () {
                            widget.onSelecionada(s.$1);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipOrdem({
    required String label,
    required bool ativo,
    required VoidCallback onTap,
    IconData? icone,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color:
              ativo ? Cores.azulTerciario : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ativo ? Cores.azulTerciario : Cores.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.anybody(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ativo ? Colors.white : Cores.onSurfaceVariant,
              ),
            ),
            if (ativo && icone != null) ...[
              const SizedBox(width: 3),
              Icon(
                icone,
                size: 13,
                color: Colors.white,
              ),
            ],
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
                        color: Cores.azulTerciario, width: 2),
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
