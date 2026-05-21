import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../services/jogo_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaAdmin extends StatefulWidget {
  const TelaAdmin({super.key});

  @override
  State<TelaAdmin> createState() => _TelaAdminState();
}

class _TelaAdminState extends State<TelaAdmin> {
  late Future<List<Jogo>> _futureJogos;
  bool _populando = false;
  bool _recalculando = false;

  @override
  void initState() {
    super.initState();
    _futureJogos = _carregarElegiveis();
  }

  Future<void> _popularJogos() async {
    final ambiente = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogAmbiente(),
    );
    if (ambiente == null || !mounted) return;

    setState(() => _populando = true);
    try {
      await JogoService().popularJogosNoFirestore(teste: ambiente == 'teste');
      if (mounted) {
        final label = ambiente == 'teste' ? 'TESTE' : 'PRODUÇÃO';
        mostrarMensagem(context, 'Jogos populados ($label)!');
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _populando = false);
    }
  }

  Future<void> _recalcularTudo() async {
    setState(() => _recalculando = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('recalcularTudo').call();
      final atualizados = result.data['atualizados'];
      if (mounted) mostrarMensagem(context, 'Pontuações recalculadas ($atualizados usuários).');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao recalcular: $e');
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  Future<List<Jogo>> _carregarElegiveis() async {
    final todos = await JogoService().buscarTodos();
    final agora = DateTime.now();

    return todos.where((jogo) {
      final liberadoEm =
          jogo.dataHora.toLocal().add(const Duration(minutes: 105));
      return agora.isAfter(liberadoEm);
    }).toList();
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
          'ATUALIZAR PLACARES',
          style: TextStyle(
            color: Cores.verdePrincipal,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          _recalculando
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Cores.verdePrincipal),
                  tooltip: 'Recalcular todas as pontuações',
                  onPressed: _recalcularTudo,
                ),
          _populando
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined,
                      color: Cores.verdePrincipal),
                  tooltip: 'Popular jogos no Firestore',
                  onPressed: _popularJogos,
                ),
        ],
      ),
      body: FutureBuilder<List<Jogo>>(
        future: _futureJogos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar jogos.',
                style: GoogleFonts.hankenGrotesk(
                    color: Cores.onSurfaceVariant),
              ),
            );
          }

          final jogos = snapshot.data ?? [];

          if (jogos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 64, color: Cores.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum jogo disponível',
                    style: GoogleFonts.anybody(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Cores.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os jogos aparecem aqui\n105 minutos após o início.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      color: Cores.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            itemCount: jogos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _CardAdmin(
              jogo: jogos[i],
              onSalvo: () => setState(() { _futureJogos = _carregarElegiveis(); }),
            ),
          );
        },
      ),
    );
  }
}

// ─── Card de inserção de placar ───────────────────────────────────────────────

class _CardAdmin extends StatefulWidget {
  const _CardAdmin({
    required this.jogo,
    required this.onSalvo,
  });

  final Jogo jogo;
  final VoidCallback onSalvo;

  @override
  State<_CardAdmin> createState() => _CardAdminState();
}

class _CardAdminState extends State<_CardAdmin> {
  late final TextEditingController _ctrl1;
  late final TextEditingController _ctrl2;
  bool _salvando = false;
  bool _salvo = false;

  @override
  void initState() {
    super.initState();
    // Pré-preenche se o jogo já tiver placar (modo de correção)
    _ctrl1 = TextEditingController(
        text: widget.jogo.placar1?.toString() ?? '');
    _ctrl2 = TextEditingController(
        text: widget.jogo.placar2?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  // ── Salvar placar — pontuação calculada pela Cloud Function ──────────────
  Future<void> _salvar() async {
    final novoP1 = int.tryParse(_ctrl1.text);
    final novoP2 = int.tryParse(_ctrl2.text);

    if (novoP1 == null || novoP2 == null) {
      mostrarMensagem(context, 'Insira os dois placares para salvar.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final jogoSnap = await FirebaseFirestore.instance
          .collection('jogos')
          .where('id', isEqualTo: widget.jogo.id)
          .limit(1)
          .get();

      if (jogoSnap.docs.isEmpty) {
        throw Exception('Jogo ${widget.jogo.id} não encontrado no Firestore.');
      }

      await jogoSnap.docs.first.reference.update({
        'placar1': novoP1,
        'placar2': novoP2,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarMensagem(context, 'Erro ao salvar. Tente novamente. $e');
      return;
    }

    if (!mounted) return;
    setState(() {
      _salvando = false;
      _salvo = true;
    });

    mostrarMensagem(context, 'Placar salvo! Pontuações sendo calculadas...');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSalvo();
    });
  }

  String get _horario {
    final local = widget.jogo.dataHora.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  bool get _jaTemPlacar =>
      widget.jogo.placar1 != null && widget.jogo.placar2 != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cores.surface,
        border: Border.all(
          color: _jaTemPlacar ? Cores.verdePrincipal : Cores.outlineVariant,
          width: _jaTemPlacar ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Cabeçalho do card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fase / grupo
                Text(
                  widget.jogo.group ?? widget.jogo.round,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurfaceVariant,
                  ),
                ),

                Text(
                  _horario,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // ── Times + campos de placar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Expanded(child: _Time(nome: widget.jogo.team1)),
                Expanded(
                  flex: 2,
                  child: _Inputs(ctrl1: _ctrl1, ctrl2: _ctrl2),
                ),
                Expanded(child: _Time(nome: widget.jogo.team2)),
              ],
            ),
          ),

          // Resultado atual (modo de correção)
          if (_jaTemPlacar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Resultado atual: ${widget.jogo.placar1} × ${widget.jogo.placar2}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  color: Cores.verdePrincipal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // ── Botão salvar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: (_salvando || _salvo) ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  _jaTemPlacar
                      ? Icons.edit_rounded
                      : Icons.check_rounded,
                ),
                label: Text(
                  _salvo ? 'SALVO ✓' :
                  _salvando ? 'Salvando...' :
                  _jaTemPlacar ? 'CORRIGIR PLACAR' :
                  'SALVAR PLACAR',
                  style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Cores.verdePrincipal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bandeira + sigla ─────────────────────────────────────────────────────────

class _Time extends StatelessWidget {
  const _Time({required this.nome});
  final String nome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cores.surfaceContainerHigh,
            border: Border.all(color: Cores.outlineVariant),
          ),
          child: Bandeira(nome, tamanho: 48),
        ),
        const SizedBox(height: 6),
        Text(
          nomePtDe(nome),
          style: GoogleFonts.anybody(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Cores.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Campos de placar ─────────────────────────────────────────────────────────

class _Inputs extends StatelessWidget {
  const _Inputs({required this.ctrl1, required this.ctrl2});
  final TextEditingController ctrl1;
  final TextEditingController ctrl2;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Campo(controller: ctrl1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'X',
            style: GoogleFonts.anybody(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ),
        _Campo(controller: ctrl2),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 68,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        style: GoogleFonts.hankenGrotesk(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Cores.onSurface,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          hintText: '–',
          hintStyle: GoogleFonts.hankenGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: Cores.outlineVariant,
          ),
          filled: true,
          fillColor: Cores.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Cores.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: Cores.azulTerciario, width: 2),
          ),
        ),
      ),
    );
  }
}

// ─── Dialog de seleção de ambiente ───────────────────────────────────────────

class _DialogAmbiente extends StatelessWidget {
  const _DialogAmbiente();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: Cores.verdePrincipal),
          const SizedBox(width: 8),
          Text(
            'Popular jogos',
            style: GoogleFonts.anybody(
              fontWeight: FontWeight.w800,
              color: Cores.onSurface,
            ),
          ),
        ],
      ),
      content: Text(
        'Escolha o ambiente. Os 104 jogos serão gravados no Firestore sobrescrevendo os dados atuais.',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: Cores.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.science_outlined, size: 18),
          label: Text(
            'Teste',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Cores.azulTerciario,
            side: const BorderSide(color: Cores.azulTerciario),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop('teste'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.public_rounded, size: 18),
          label: Text(
            'Produção',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Cores.verdePrincipal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop('producao'),
        ),
      ],
    );
  }
}