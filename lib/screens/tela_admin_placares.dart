import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../services/jogo_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaAdminPlacares extends StatefulWidget {
  const TelaAdminPlacares({super.key});

  @override
  State<TelaAdminPlacares> createState() => _TelaAdminPlacaresState();
}

class _TelaAdminPlacaresState extends State<TelaAdminPlacares>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<Jogo>> _futureJogos;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _futureJogos = JogoService().buscarTodos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recarregar() {
    setState(() {
      _futureJogos = JogoService().buscarTodos();
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
          'PLACARES — REGRA CLÁSSICA',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.anybody(
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.anybody(
              fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'PRÓXIMOS'),
            Tab(text: 'ENCERRADOS'),
          ],
        ),
      ),
      body: FutureBuilder<List<Jogo>>(
        future: _futureJogos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Cores.verdePrincipal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar jogos.',
                  style: GoogleFonts.hankenGrotesk(
                      color: Cores.onSurfaceVariant)),
            );
          }

          final todos = snapshot.data ?? [];
          final proximos = todos
              .where((j) => j.placar1 == null || j.placar2 == null)
              .toList();
          final encerrados = todos
              .where((j) => j.placar1 != null && j.placar2 != null)
              .toList()
            ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

          return TabBarView(
            controller: _tabController,
            children: [
              _ListaJogos(
                jogos: proximos,
                vazia: 'Nenhum jogo pendente',
                descricaoVazia: 'Todos os jogos já têm placar registrado.',
                iconeVazio: Icons.check_circle_outline_rounded,
                onSalvo: _recarregar,
              ),
              _ListaJogos(
                jogos: encerrados,
                vazia: 'Nenhum placar registrado',
                descricaoVazia:
                    'Os jogos com placar salvo aparecerão aqui.',
                iconeVazio: Icons.sports_score_rounded,
                onSalvo: _recarregar,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Lista de jogos de uma aba ────────────────────────────────────────────────

class _ListaJogos extends StatelessWidget {
  const _ListaJogos({
    required this.jogos,
    required this.vazia,
    required this.descricaoVazia,
    required this.iconeVazio,
    required this.onSalvo,
  });

  final List<Jogo> jogos;
  final String vazia;
  final String descricaoVazia;
  final IconData iconeVazio;
  final VoidCallback onSalvo;

  @override
  Widget build(BuildContext context) {
    if (jogos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconeVazio, size: 64, color: Cores.outlineVariant),
            const SizedBox(height: 16),
            Text(
              vazia,
              style: GoogleFonts.anybody(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              descricaoVazia,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 14, color: Cores.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: jogos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _CardAdmin(
        jogo: jogos[i],
        onSalvo: onSalvo,
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

  Future<void> _salvar() async {
    final novoP1 = int.tryParse(_ctrl1.text);
    final novoP2 = int.tryParse(_ctrl2.text);

    // Se nao for correcao, exige os dois campos preenchidos
    if (!_jaTemPlacar && (novoP1 == null || novoP2 == null)) {
      mostrarMensagem(context, 'Insira os dois placares para salvar.');
      return;
    }

    // Se for correcao com campos vazios, confirma limpeza do placar
    final limpando = _jaTemPlacar && novoP1 == null && novoP2 == null;
    if (limpando) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remover placar?',
              style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          content: Text(
            'Os campos estão vazios. Deseja remover o placar registrado? O jogo voltará para a aba Próximos.',
            style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB00020)),
              child: const Text('REMOVER'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
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
        'placar1': limpando ? null : novoP1,
        'placar2': limpando ? null : novoP2,
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

    mostrarMensagem(
      context,
      limpando
          ? 'Placar removido. Jogo voltou para Próximos.'
          : 'Placar salvo! Pontuações sendo calculadas...',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSalvo();
    });
  }

  String get _horario {
    final local = widget.jogo.dataHora.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String get _data {
    final local = widget.jogo.dataHora.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.jogo.group ?? widget.jogo.round,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$_data  $_horario',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
          if (_jaTemPlacar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Placar atual: ${widget.jogo.placar1} × ${widget.jogo.placar2}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  color: Cores.verdePrincipal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
                  _salvo
                      ? 'SALVO ✓'
                      : _salvando
                          ? 'Salvando...'
                          : _jaTemPlacar
                              ? 'CORRIGIR PLACAR'
                              : 'SALVAR PLACAR',
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

// ─── Bandeira + nome ──────────────────────────────────────────────────────────

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
