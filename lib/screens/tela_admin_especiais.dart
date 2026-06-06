import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/jogo_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import '../utils/dialogos.dart';

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

  List<JogadorData> _jogadores = [];

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

  Future<List<JogadorData>> _carregarJogadores() async {
    final raw = await rootBundle.loadString('assets/dados/jogadores.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final result = <JogadorData>[];
    for (final sel in data['selecoes'] as List) {
      final selNome   = sel['nome']   as String;
      final selNomePt = sel['nomePt'] as String;
      for (final j in sel['jogadores'] as List) {
        result.add(JogadorData(
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
      final jogadores = results[1] as List<JogadorData>;

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
      builder: (_) => BottomSheetJogadores(
        titulo: titulo,
        jogadores: _jogadores,
        selecionadoAtual: selecionadoAtual,
        apenasGoleiros: apenasGoleiros,
        cor: Cores.verdePrincipal,
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
