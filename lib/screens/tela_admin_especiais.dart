import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/jogo_service.dart';
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

class TelaAdminEspeciais extends StatefulWidget {
  const TelaAdminEspeciais({super.key});

  @override
  State<TelaAdminEspeciais> createState() => _TelaAdminEspeciaisState();
}

class _TelaAdminEspeciaisState extends State<TelaAdminEspeciais> {
  // ── Estado dos campos ────────────────────────────────────────────────────────
  String? _campeaoReal;
  String? _maisGoleadoraReal;
  String? _maisVazadaReal;
  String? _artilheiroReal;
  String? _goleiroReal;
  String? _melhorJogadorFinalReal;

  List<_JogadorData> _jogadores = [];

  bool _palpitesCalculados = false;
  bool _carregandoConfig   = true;
  bool _salvandoConfig     = false;
  bool _calculando         = false;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  // ── Firestore + jogadores ─────────────────────────────────────────────────────

  Future<List<_JogadorData>> _carregarJogadores() async {
    final raw = await rootBundle.loadString('assets/dados/jogadores.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final result = <_JogadorData>[];
    for (final sel in data['selecoes'] as List) {
      final selNome   = sel['nome']   as String;
      final selNomePt = sel['nomePt'] as String;
      for (final j in sel['jogadores'] as List) {
        result.add(_JogadorData(
          nome:         j['nome']    as String,
          posicao:      j['posicao'] as String,
          clube:        j['clube']   as String,
          selecaoNome:  selNome,
          selecaoNomePt: selNomePt,
        ));
      }
    }
    return result;
  }

  Future<void> _carregarConfig() async {
    try {
      final results = await Future.wait<Object?>([
        FirebaseFirestore.instance.collection('config').doc('copa2026').get(),
        _carregarJogadores(),
      ]);

      final doc      = results[0] as DocumentSnapshot;
      final jogadores = results[1] as List<_JogadorData>;

      if (doc.exists && mounted) {
        final d = doc.data()! as Map<String, dynamic>;
        setState(() {
          _campeaoReal        = d['campeaoReal']            as String?;
          _maisGoleadoraReal  = d['maisGoleadoraReal']      as String?;
          _maisVazadaReal     = d['maisVazadaReal']         as String?;
          _artilheiroReal     = d['artilheiroReal']         as String?;
          _goleiroReal        = d['melhorGoleiroReal']      as String?;
          _melhorJogadorFinalReal = d['melhorJogadorFinalReal'] as String?;
          _palpitesCalculados = d['palpitesEspeciaisCalculados'] == true;
          _jogadores          = jogadores;
        });
      } else if (mounted) {
        setState(() => _jogadores = jogadores);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _carregandoConfig = false);
    }
  }

  Future<void> _salvarConfig() async {
    setState(() => _salvandoConfig = true);
    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('copa2026')
          .set({
        'campeaoReal':            _campeaoReal,
        'maisGoleadoraReal':      _maisGoleadoraReal,
        'maisVazadaReal':         _maisVazadaReal,
        'artilheiroReal':         _artilheiroReal,
        'melhorGoleiroReal':      _goleiroReal,
        'melhorJogadorFinalReal': _melhorJogadorFinalReal,
        'palpitesEspeciaisCalculados': _palpitesCalculados,
      }, SetOptions(merge: true));
      if (mounted) mostrarMensagem(context, 'Configuração salva!');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvandoConfig = false);
    }
  }

  // ── Seletor de time genérico ──────────────────────────────────────────────────

  Future<void> _abrirSeletorTime({
    required String titulo,
    required String? selecionadoAtual,
    required void Function(String?) onSelecionado,
  }) async {
    String semAcento(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');

    final jogos = await JogoService().buscarTodos();
    final times = jogos
        .expand((j) => [j.team1, j.team2])
        .toSet()
        .where((t) => !t.contains(RegExp(r'\d')))
        .toList()
      ..sort((a, b) => semAcento(nomePtDe(a)).compareTo(semAcento(nomePtDe(b))));
    if (!mounted) return;
    final selecionado = await showDialog<String>(
      context: context,
      builder: (_) => _DialogSeletorTime(
        titulo: titulo,
        times: times,
        selecionado: selecionadoAtual,
      ),
    );
    if (!mounted) return;
    if (selecionado == '') {
      onSelecionado(null);
    } else if (selecionado != null) {
      onSelecionado(selecionado);
    }
  }

  // ── Seletor de jogador ────────────────────────────────────────────────────────

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

  // ── Calcular palpites especiais ───────────────────────────────────────────────

  Future<void> _calcularPalpitesEspeciais() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Calcular pontuação especial?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Os resultados serão salvos e as pontuações dos palpites especiais serão aplicadas a todos os usuários.\n\nEsta ação não pode ser desfeita.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
            child: Text('CALCULAR',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _calculando = true);
    try {
      await _salvarConfig();
      if (!mounted) return;

      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('calcularPalpitesEspeciais').call();
      final atualizados = result.data['atualizados'];
      if (mounted) {
        setState(() => _palpitesCalculados = true);
        mostrarMensagem(context,
            'Pontuação especial calculada! $atualizados usuário(s) acertaram.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.code == 'already-exists') {
        mostrarMensagem(context,
            'Pontuação especial já foi calculada. Para recalcular, use Limpar Dados de Teste primeiro.');
      } else {
        mostrarMensagem(context, 'Erro ao calcular: ${e.message}');
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.verdePrincipal,
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
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: _carregandoConfig
          ? const Center(child: CircularProgressIndicator(color: Cores.verdePrincipal))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_palpitesCalculados)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Cores.verdePrincipal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Cores.verdePrincipal.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Cores.verdePrincipal, size: 18),
                      const SizedBox(width: 8),
                      Text('Pontuação especial já calculada e aplicada.',
                          style: GoogleFonts.hankenGrotesk(
                              fontSize: 13,
                              color: Cores.verdePrincipal,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),

                // ── CAMPEÃO ──────────────────────────────────────────────────
                _Secao(titulo: 'CAMPEÃO DO TORNEIO', children: [
                  _SeletorTime(
                    label: 'Campeão',
                    time: _campeaoReal,
                    bloqueado: _palpitesCalculados,
                    onTap: () => _abrirSeletorTime(
                      titulo: 'Selecionar campeão',
                      selecionadoAtual: _campeaoReal,
                      onSelecionado: (t) => setState(() => _campeaoReal = t),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── ARTILHEIRO ───────────────────────────────────────────────
                _Secao(titulo: 'ARTILHEIRO', children: [
                  _SeletorJogador(
                    label: 'Artilheiro da Copa',
                    jogadorNome: _artilheiroReal,
                    jogadores: _jogadores,
                    bloqueado: _palpitesCalculados,
                    onTap: () => _abrirSeletorJogador(
                      titulo: 'Artilheiro',
                      selecionadoAtual: _artilheiroReal,
                      onSelecionado: (n) => setState(() => _artilheiroReal = n),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── MELHOR GOLEIRO ───────────────────────────────────────────
                _Secao(titulo: 'MELHOR GOLEIRO', children: [
                  _SeletorJogador(
                    label: 'Melhor goleiro',
                    jogadorNome: _goleiroReal,
                    jogadores: _jogadores,
                    bloqueado: _palpitesCalculados,
                    onTap: () => _abrirSeletorJogador(
                      titulo: 'Melhor Goleiro',
                      selecionadoAtual: _goleiroReal,
                      apenasGoleiros: true,
                      onSelecionado: (n) => setState(() => _goleiroReal = n),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── MELHOR JOGADOR ────────────────────────────────────────────
                _Secao(titulo: 'MELHOR JOGADOR', children: [
                  _SeletorJogador(
                    label: 'Melhor jogador do torneio',
                    jogadorNome: _melhorJogadorFinalReal,
                    jogadores: _jogadores,
                    bloqueado: _palpitesCalculados,
                    onTap: () => _abrirSeletorJogador(
                      titulo: 'Melhor Jogador',
                      selecionadoAtual: _melhorJogadorFinalReal,
                      onSelecionado: (n) =>
                          setState(() => _melhorJogadorFinalReal = n),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── EQUIPE MAIS GOLEADORA ─────────────────────────────────────
                _Secao(titulo: 'EQUIPE MAIS GOLEADORA', children: [
                  _SeletorTime(
                    label: 'Equipe mais goleadora',
                    time: _maisGoleadoraReal,
                    bloqueado: _palpitesCalculados,
                    onTap: () => _abrirSeletorTime(
                      titulo: 'Equipe mais goleadora',
                      selecionadoAtual: _maisGoleadoraReal,
                      onSelecionado: (t) => setState(() => _maisGoleadoraReal = t),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── EQUIPE MENOS VAZADA ───────────────────────────────────────
                _Secao(titulo: 'EQUIPE MENOS VAZADA', children: [
                  _SeletorTime(
                    label: 'Equipe menos vazada',
                    time: _maisVazadaReal,
                    bloqueado: _palpitesCalculados,
                    onTap: () => _abrirSeletorTime(
                      titulo: 'Equipe menos vazada',
                      selecionadoAtual: _maisVazadaReal,
                      onSelecionado: (t) => setState(() => _maisVazadaReal = t),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Botões ────────────────────────────────────────────────────
                if (!_palpitesCalculados)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _salvandoConfig ? null : _salvarConfig,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Cores.verdePrincipal),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _salvandoConfig
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Cores.verdePrincipal))
                            : Text('SALVAR',
                                style: GoogleFonts.anybody(
                                    fontWeight: FontWeight.w700,
                                    color: Cores.verdePrincipal)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _calculando ? null : _calcularPalpitesEspeciais,
                        style: FilledButton.styleFrom(
                          backgroundColor: Cores.verdePrincipal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _calculando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('CALCULAR',
                                style: GoogleFonts.anybody(
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
              ],
            ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.children});
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cores.surface,
        border: Border.all(color: Cores.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Text(titulo,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// Seletor de equipe com bandeira (campeão, mais goleadora, menos vazada)
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
    return InkWell(
      onTap: bloqueado ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: bloqueado
                ? Cores.outlineVariant
                : Cores.verdePrincipal.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          if (time != null) ...[
            Container(
              width: 28,
              height: 28,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Bandeira(time!, tamanho: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(nomePtDe(time!),
                  style: GoogleFonts.anybody(
                      fontWeight: FontWeight.w700, color: Cores.onSurface)),
            ),
          ] else
            Expanded(
              child: Text('Toque para selecionar',
                  style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant)),
            ),
          if (!bloqueado)
            const Icon(Icons.arrow_drop_down_rounded, color: Cores.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// Seletor de jogador (artilheiro, goleiro, melhor jogador)
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

    return InkWell(
      onTap: bloqueado ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: bloqueado
                ? Cores.outlineVariant
                : Cores.verdePrincipal.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (jogador != null) ...[
              Container(
                width: 28,
                height: 28,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Bandeira(jogador.selecaoNome, tamanho: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      jogador.nome,
                      style: GoogleFonts.anybody(
                          fontWeight: FontWeight.w700, color: Cores.onSurface),
                    ),
                    Text(
                      jogador.clube != '-'
                          ? '${jogador.selecaoNomePt} · ${jogador.clube}'
                          : jogador.selecaoNomePt,
                      style: GoogleFonts.hankenGrotesk(
                          fontSize: 12, color: Cores.onSurfaceVariant),
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
                      fontSize: 15, color: Cores.onSurfaceVariant),
                ),
              ),
            ] else ...[
              const Icon(Icons.search_rounded,
                  size: 20, color: Cores.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Toque para selecionar',
                  style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
                ),
              ),
            ],
            if (!bloqueado)
              const Icon(Icons.arrow_drop_down_rounded,
                  color: Cores.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog seletor de time genérico ─────────────────────────────────────────

class _DialogSeletorTime extends StatefulWidget {
  const _DialogSeletorTime({
    required this.titulo,
    required this.times,
    this.selecionado,
  });
  final String titulo;
  final List<String> times;
  final String? selecionado;

  @override
  State<_DialogSeletorTime> createState() => _DialogSeletorTimeState();
}

class _DialogSeletorTimeState extends State<_DialogSeletorTime> {
  final _ctrlBusca = TextEditingController();
  String _busca = '';

  String _semAcento(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');

  @override
  void dispose() {
    _ctrlBusca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buscaNorm = _semAcento(_busca);
    final filtrados = widget.times
        .where((t) => _semAcento(nomePtDe(t)).contains(buscaNorm))
        .toList();

    return Dialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(widget.titulo,
                style: GoogleFonts.anybody(
                    fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ctrlBusca,
              autofocus: false,
              onChanged: (v) => setState(() => _busca = v),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle:
                    GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Cores.onSurfaceVariant),
                filled: true,
                fillColor: Cores.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Cores.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Cores.verdePrincipal, width: 2),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 340,
            child: filtrados.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum resultado.',
                      style: GoogleFonts.hankenGrotesk(
                          color: Cores.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) {
                      final time = filtrados[i];
                      final sel = time == widget.selecionado;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Cores.outlineVariant)),
                          child: Bandeira(time, tamanho: 36),
                        ),
                        title: Text(nomePtDe(time),
                            style: GoogleFonts.anybody(
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w400,
                                color: sel
                                    ? Cores.verdePrincipal
                                    : Cores.onSurface)),
                        trailing: sel
                            ? const Icon(Icons.check_circle_rounded,
                                color: Cores.verdePrincipal)
                            : null,
                        onTap: () => Navigator.of(context).pop(time),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('CANCELAR',
                  style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
            ),
          ),
        ],
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
    final porPosicao = widget.apenasGoleiros
        ? widget.jogadores.where((j) => j.posicao == 'GOL').toList()
        : widget.jogadores;

    final porSelecao = _filtroSelecao == null
        ? porPosicao
        : porPosicao.where((j) => j.selecaoNome == _filtroSelecao).toList();

    final buscaNorm = _norm(_busca);
    final filtrados = buscaNorm.isEmpty
        ? porSelecao
        : porSelecao.where((j) => _norm(j.nome).contains(buscaNorm)).toList();

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        color: Cores.verdePrincipal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'GOLEIROS',
                        style: GoogleFonts.anybody(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Cores.verdePrincipal,
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
                    borderSide: const BorderSide(color: Cores.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Cores.verdePrincipal, width: 2),
                  ),
                ),
              ),
            ),

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
                        final selecionado = widget.selecionadoAtual == j.nome;
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Cores.outlineVariant),
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
                                  ? Cores.verdePrincipal
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
                                  color: Cores.verdePrincipal, size: 22)
                              : null,
                          tileColor: selecionado
                              ? Cores.verdePrincipal.withValues(alpha: 0.08)
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
          color: selecionado ? Cores.verdePrincipal : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
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
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Bandeira(nome, tamanho: 18),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    siglaDe(nome),
                    style: GoogleFonts.anybody(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selecionado ? Colors.white : Cores.onSurfaceVariant,
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

  final List<(String, String)> selecoes;
  final String? selecionadaAtual;
  final void Function(String?) onSelecionada;

  @override
  State<_DialogSelecaoEquipe> createState() => _DialogSelecaoEquipeState();
}

class _DialogSelecaoEquipeState extends State<_DialogSelecaoEquipe> {
  String _busca = '';
  final _ctrl = TextEditingController();

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Cores.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Cores.verdePrincipal, width: 2),
                  ),
                ),
              ),
            ),

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
                        final selecionada = widget.selecionadaAtual == s.$1;
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Cores.outlineVariant),
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
                                  ? Cores.verdePrincipal
                                  : Cores.onSurface,
                            ),
                          ),
                          trailing: selecionada
                              ? const Icon(Icons.check_circle,
                                  color: Cores.verdePrincipal, size: 22)
                              : null,
                          tileColor: selecionada
                              ? Cores.verdePrincipal.withValues(alpha: 0.08)
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: ativo ? Cores.verdePrincipal : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ativo ? Cores.verdePrincipal : Cores.outlineVariant,
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
              Icon(icone, size: 13, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
