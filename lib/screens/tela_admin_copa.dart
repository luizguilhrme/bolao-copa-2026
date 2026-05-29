import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../services/jogo_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaAdminCopa extends StatefulWidget {
  const TelaAdminCopa({super.key});

  @override
  State<TelaAdminCopa> createState() => _TelaAdminCopaState();
}

class _TelaAdminCopaState extends State<TelaAdminCopa> {
  bool _carregando = true;
  bool _salvando = false;

  static const _letrasGrupos = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
  ];

  // IDs dos 8 jogos de 16 avos que têm um slot "3°" (sempre em team2)
  static const _idsSlots3Grau = ['74', '77', '79', '80', '81', '82', '85', '87'];

  // times por grupo: { "A": ["Brazil", "Mexico", ...], ... }
  final Map<String, List<String>> _timesPorGrupo = {};

  // classificacao selecionada: 1o, 2o e 3o por grupo
  final Map<String, Map<String, String?>> _classificacao = {};

  // alocação dos terceiros nos slots dos 16 avos (key = jogoId string)
  final Map<String, String?> _terceirosSlots = {
    for (final id in _idsSlots3Grau) id: null,
  };

  // jogos 73–88 carregados do Firestore (para exibir contexto e atualizar)
  List<Jogo> _jogos16Avos = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final jogos = await JogoService().buscarTodos();
      _extrairTimesPorGrupo(jogos);
      _jogos16Avos = jogos
          .where((j) => j.id >= 73 && j.id <= 88)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      await _carregarConfig();
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao carregar dados: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _extrairTimesPorGrupo(List<Jogo> jogos) {
    for (final letra in _letrasGrupos) {
      final timesGrupo = jogos
          .where((j) => j.group == 'Grupo $letra')
          .expand((j) => [j.team1, j.team2])
          .toSet()
          .toList()
        ..sort((a, b) => nomePtDe(a).compareTo(nomePtDe(b)));
      _timesPorGrupo[letra] = timesGrupo;
      _classificacao[letra] = {
        'primeiro': null,
        'segundo': null,
        'terceiro': null,
      };
    }
  }

  Future<void> _carregarConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('copa2026')
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;

    final classReal = data['classificacao_real'] as Map<String, dynamic>?;
    if (classReal != null) {
      for (final letra in _letrasGrupos) {
        final grupoData = classReal[letra] as Map<String, dynamic>?;
        if (grupoData != null) {
          _classificacao[letra] = {
            'primeiro': grupoData['primeiro'] as String?,
            'segundo': grupoData['segundo'] as String?,
            'terceiro': grupoData['terceiro'] as String?,
          };
        }
      }
    }

    final terceirosSalvos =
        data['terceiros_classificados'] as Map<String, dynamic>?;
    if (terceirosSalvos != null) {
      for (final id in _idsSlots3Grau) {
        _terceirosSlots[id] = terceirosSalvos[id] as String?;
      }
    }
  }

  String? _validar() {
    final semPrimeiro = _letrasGrupos
        .where((l) => _classificacao[l]?['primeiro'] == null)
        .toList();
    if (semPrimeiro.isNotEmpty) {
      return '1º lugar faltando: Grupo ${semPrimeiro.join(', ')}';
    }

    final semSegundo = _letrasGrupos
        .where((l) => _classificacao[l]?['segundo'] == null)
        .toList();
    if (semSegundo.isNotEmpty) {
      return '2º lugar faltando: Grupo ${semSegundo.join(', ')}';
    }

    if (_gruposComTerceiro < 8) {
      return 'Selecione o 3º colocado em exatamente 8 grupos ($_gruposComTerceiro/8 preenchidos)';
    }

    return null;
  }

  // Resolve um placeholder de slot para o time real.
  // "1A" → primeiro do grupo A; "2B" → segundo do grupo B; "3°" → slot do terceiro.
  String? _resolverSlot(String slot, String jogoId) {
    final m = RegExp(r'^([12])([A-L])$').firstMatch(slot);
    if (m != null) {
      final pos = m.group(1) == '1' ? 'primeiro' : 'segundo';
      final grupo = m.group(2)!;
      return _classificacao[grupo]?[pos];
    }
    if (slot.contains('°')) return _terceirosSlots[jogoId];
    return null;
  }

  Future<void> _salvar() async {
    final erro = _validar();
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB00020),
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Classificação dos grupos no config
      final classMap = <String, dynamic>{};
      for (final letra in _letrasGrupos) {
        final c = _classificacao[letra]!;
        classMap[letra] = {
          'primeiro': c['primeiro'],
          'segundo': c['segundo'],
          'terceiro': c['terceiro'],
        };
      }

      // 2. Alocação dos terceiros nos slots
      final terceirosSalvos = <String, dynamic>{
        for (final e in _terceirosSlots.entries)
          if (e.value != null) e.key: e.value,
      };

      batch.set(
        db.collection('config').doc('copa2026'),
        {
          'classificacao_real': classMap,
          'terceiros_classificados': terceirosSalvos,
        },
        SetOptions(merge: true),
      );

      // 3. Atualizar team1/team2 dos jogos 73–88 com os times reais
      for (final jogo in _jogos16Avos) {
        final updates = <String, dynamic>{};
        final t1 = _resolverSlot(jogo.team1, '${jogo.id}');
        if (t1 != null) updates['team1'] = t1;
        final t2 = _resolverSlot(jogo.team2, '${jogo.id}');
        if (t2 != null) updates['team2'] = t2;
        if (updates.isNotEmpty) {
          batch.update(db.collection('jogos').doc('${jogo.id}'), updates);
        }
      }

      await batch.commit();

      if (mounted) mostrarMensagem(context, 'Classificação salva!');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  int get _gruposComTerceiro => _classificacao.values
      .where((c) => c['terceiro'] != null && c['terceiro']!.isNotEmpty)
      .length;

  int get _slotsPreenchidos =>
      _terceirosSlots.values.where((v) => v != null).length;

  void _onChanged(String letra, String posicao, String? time) {
    if (posicao == 'terceiro' &&
        time != null &&
        _classificacao[letra]?['terceiro'] == null &&
        _gruposComTerceiro >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Somente 8 grupos podem ter 3º colocado selecionado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _classificacao[letra]![posicao] = time;
    });
  }

  // Monta a lista de terceiros disponíveis para um slot, excluindo os já usados
  List<String> _opcoesTerceiros(String jogoId) {
    final usados = _terceirosSlots.entries
        .where((e) => e.key != jogoId && e.value != null)
        .map((e) => e.value!)
        .toSet();

    return _letrasGrupos
        .map((l) => _classificacao[l]?['terceiro'])
        .whereType<String>()
        .where((t) => !usados.contains(t))
        .toList()
      ..sort((a, b) => nomePtDe(a).compareTo(nomePtDe(b)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.verdePrincipal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CLASSIFICAÇÃO — REGRA COPA',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '3º gr: $_gruposComTerceiro/8',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'slots: $_slotsPreenchidos/8',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: Cores.verdePrincipal))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      ..._letrasGrupos.map(
                        (l) => _CardGrupo(
                          letra: l,
                          times: _timesPorGrupo[l] ?? [],
                          classificacao: _classificacao[l]!,
                          terceiroBloqueado:
                              _classificacao[l]?['terceiro'] == null &&
                                  _gruposComTerceiro >= 8,
                          onChanged: (posicao, time) =>
                              _onChanged(l, posicao, time),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SecaoTerceiros(
                        jogos: _jogos16Avos,
                        idsSlots: _idsSlots3Grau,
                        terceirosSlots: _terceirosSlots,
                        opcoesFn: _opcoesTerceiros,
                        onChanged: (id, time) =>
                            setState(() => _terceirosSlots[id] = time),
                        slotsPreenchidos: _slotsPreenchidos,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                _buildBotaoSalvar(),
              ],
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
              : const Icon(Icons.save_rounded),
          label: Text(
            _salvando ? 'Salvando...' : 'SALVAR CLASSIFICAÇÃO',
            style: GoogleFonts.anybody(
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Cores.verdePrincipal,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// ─── Seção de alocação dos terceiros ─────────────────────────────────────────

class _SecaoTerceiros extends StatelessWidget {
  const _SecaoTerceiros({
    required this.jogos,
    required this.idsSlots,
    required this.terceirosSlots,
    required this.opcoesFn,
    required this.onChanged,
    required this.slotsPreenchidos,
  });

  final List<Jogo> jogos;
  final List<String> idsSlots;
  final Map<String, String?> terceirosSlots;
  final List<String> Function(String jogoId) opcoesFn;
  final void Function(String jogoId, String? time) onChanged;
  final int slotsPreenchidos;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Cores.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TERCEIROS — 16 AVOS DE FINAL',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$slotsPreenchidos/8 alocados',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: slotsPreenchidos == 8
                        ? Cores.verdePrincipal
                        : Cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(
                    'Aloque cada terceiro colocado classificado ao respectivo jogo dos 16 avos. '
                    'Os 8 slots marcados "3°" nos jogos de 16 avos foram definidos pela FIFA.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: Cores.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                ...idsSlots.map((id) {
                  final jogo = jogos.where((j) => j.id.toString() == id).firstOrNull;
                  if (jogo == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CardSlot3Grau(
                      jogoId: id,
                      jogo: jogo,
                      timeSelecionado: terceirosSlots[id],
                      opcoes: opcoesFn(id),
                      onChanged: (time) => onChanged(id, time),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de um slot "3°" nos 16 avos ────────────────────────────────────────

class _CardSlot3Grau extends StatelessWidget {
  const _CardSlot3Grau({
    required this.jogoId,
    required this.jogo,
    required this.timeSelecionado,
    required this.opcoes,
    required this.onChanged,
  });

  final String jogoId;
  final Jogo jogo;
  final String? timeSelecionado;
  final List<String> opcoes;
  final void Function(String?) onChanged;

  // Exibe o time ou, se ainda for placeholder, uma label amigável
  String _labelOponente(String team) {
    final m = RegExp(r'^([12])([A-L])$').firstMatch(team);
    if (m != null) return '${m.group(1)}º Grupo ${m.group(2)}';
    return nomePtDe(team);
  }

  @override
  Widget build(BuildContext context) {
    final local = jogo.dataHora.toLocal();
    final data =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    final isResolvido = !ehPlaceholder(jogo.team2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isResolvido
            ? Cores.verdePrincipal.withValues(alpha: 0.05)
            : Cores.surfaceContainer,
        border: Border.all(
          color: isResolvido ? Cores.verdePrincipal.withValues(alpha: 0.3) : Cores.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Jogo $jogoId · $data',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurfaceVariant,
                ),
              ),
              if (isResolvido) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded,
                    size: 14, color: Cores.verdePrincipal),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Oponente fixo
              Expanded(
                child: Row(
                  children: [
                    if (!ehPlaceholder(jogo.team1))
                      Container(
                        width: 28,
                        height: 28,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Bandeira(jogo.team1, tamanho: 28),
                      )
                    else
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Cores.surfaceContainerHigh,
                          border: Border.all(color: Cores.outlineVariant),
                        ),
                        child: Center(
                          child: Text('?',
                              style: GoogleFonts.anybody(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _labelOponente(jogo.team1),
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Cores.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('vs',
                    style: GoogleFonts.anybody(
                        fontSize: 12, color: Cores.onSurfaceVariant)),
              ),

              // Slot do terceiro — dropdown ou badge se já resolvido
              Expanded(
                child: isResolvido
                    ? Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            clipBehavior: Clip.antiAlias,
                            decoration:
                                const BoxDecoration(shape: BoxShape.circle),
                            child: Bandeira(jogo.team2, tamanho: 28),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              nomePtDe(jogo.team2),
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Cores.verdePrincipal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : DropdownButtonFormField<String>(
                        value: timeSelecionado != null &&
                                opcoes.contains(timeSelecionado)
                            ? timeSelecionado
                            : null,
                        isExpanded: true,
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Cores.verdePrincipal, width: 2),
                          ),
                        ),
                        hint: Text(
                          '3° colocado',
                          style: GoogleFonts.hankenGrotesk(
                              fontSize: 13,
                              color: Cores.onSurfaceVariant),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('—',
                                style: GoogleFonts.hankenGrotesk(
                                    color: Cores.onSurfaceVariant)),
                          ),
                          ...opcoes.map(
                            (time) => DropdownMenuItem<String>(
                              value: time,
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle),
                                    child: Bandeira(time, tamanho: 22),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      nomePtDe(time),
                                      style: GoogleFonts.hankenGrotesk(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card de um grupo ─────────────────────────────────────────────────────────

class _CardGrupo extends StatelessWidget {
  const _CardGrupo({
    required this.letra,
    required this.times,
    required this.classificacao,
    required this.terceiroBloqueado,
    required this.onChanged,
  });

  final String letra;
  final List<String> times;
  final Map<String, String?> classificacao;
  final bool terceiroBloqueado;
  final void Function(String posicao, String? time) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Text(
              'GRUPO $letra',
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurfaceVariant),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _SeletorPosicao(
                  posicao: '1º Lugar',
                  chave: 'primeiro',
                  times: times,
                  classificacao: classificacao,
                  bloqueado: false,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 10),
                _SeletorPosicao(
                  posicao: '2º Lugar',
                  chave: 'segundo',
                  times: times,
                  classificacao: classificacao,
                  bloqueado: false,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 10),
                _SeletorPosicao(
                  posicao: '3º Lugar',
                  chave: 'terceiro',
                  times: times,
                  classificacao: classificacao,
                  bloqueado: terceiroBloqueado,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seletor de posicao (dropdown) ───────────────────────────────────────────

class _SeletorPosicao extends StatelessWidget {
  const _SeletorPosicao({
    required this.posicao,
    required this.chave,
    required this.times,
    required this.classificacao,
    required this.bloqueado,
    required this.onChanged,
  });

  final String posicao;
  final String chave;
  final List<String> times;
  final Map<String, String?> classificacao;
  final bool bloqueado;
  final void Function(String posicao, String? time) onChanged;

  List<String> get _timesDisponiveis {
    final outras = classificacao.entries
        .where((e) => e.key != chave && e.value != null)
        .map((e) => e.value!)
        .toSet();
    return times.where((t) => !outras.contains(t)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final opcoes = _timesDisponiveis;
    final valorAtual = classificacao[chave];
    final valorValido =
        valorAtual != null && opcoes.contains(valorAtual) ? valorAtual : null;

    return DropdownButtonFormField<String>(
      value: valorValido,
      isExpanded: true,
      onChanged: bloqueado ? null : (val) => onChanged(chave, val),
      decoration: InputDecoration(
        labelText: posicao,
        labelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            color: bloqueado
                ? Cores.onSurfaceVariant.withValues(alpha: 0.5)
                : Cores.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Cores.verdePrincipal, width: 2),
        ),
      ),
      hint: Text(
        bloqueado ? 'Limite de 8 atingido' : 'Selecionar',
        style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: bloqueado
                ? Cores.onSurfaceVariant.withValues(alpha: 0.5)
                : Cores.onSurfaceVariant),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('—',
              style: GoogleFonts.hankenGrotesk(
                  color: Cores.onSurfaceVariant)),
        ),
        ...opcoes.map((time) => DropdownMenuItem<String>(
              value: time,
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    clipBehavior: Clip.antiAlias,
                    decoration:
                        const BoxDecoration(shape: BoxShape.circle),
                    child: Bandeira(time, tamanho: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nomePtDe(time),
                      style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Cores.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
