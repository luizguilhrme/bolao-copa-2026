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

  // times por grupo: { "A": ["Brazil", "Mexico", ...], ... }
  final Map<String, List<String>> _timesPorGrupo = {};

  // classificacao selecionada: 1o, 2o e 3o por grupo
  final Map<String, Map<String, String?>> _classificacao = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final jogos = await JogoService().buscarTodos();
      _extrairTimesPorGrupo(jogos);
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
      final classMap = <String, dynamic>{};
      for (final letra in _letrasGrupos) {
        final c = _classificacao[letra]!;
        classMap[letra] = {
          'primeiro': c['primeiro'],
          'segundo': c['segundo'],
          'terceiro': c['terceiro'],
        };
      }

      await FirebaseFirestore.instance
          .collection('config')
          .doc('copa2026')
          .set({
        'classificacao_real': classMap,
      }, SetOptions(merge: true));

      if (mounted) mostrarMensagem(context, 'Classificação salva!');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // Quantos grupos ja tem terceiro colocado selecionado
  int get _gruposComTerceiro => _classificacao.values
      .where((c) => c['terceiro'] != null && c['terceiro']!.isNotEmpty)
      .length;

  void _onChanged(String letra, String posicao, String? time) {
    // Se estiver tentando selecionar terceiro e ja temos 8, bloquear
    if (posicao == 'terceiro' &&
        time != null &&
        _classificacao[letra]?['terceiro'] == null &&
        _gruposComTerceiro >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Somente 8 grupos podem ter 3º colocado selecionado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _classificacao[letra]![posicao] = time;
    });
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
              child: Text(
                '3º: $_gruposComTerceiro/8',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
                          terceiroBloqueado: _classificacao[l]?['terceiro'] == null &&
                              _gruposComTerceiro >= 8,
                          onChanged: (posicao, time) =>
                              _onChanged(l, posicao, time),
                        ),
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
      // bloqueado apenas quando o limite de 8 grupos com 3o foi atingido
      // e este grupo ainda nao tem terceiro selecionado
      onChanged: bloqueado ? null : (val) => onChanged(chave, val),
      decoration: InputDecoration(
        labelText: posicao,
        labelStyle: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            color: bloqueado ? Cores.onSurfaceVariant.withValues(alpha: 0.5) : Cores.onSurfaceVariant),
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
