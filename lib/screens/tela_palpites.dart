import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../services/jogo_service.dart';
import '../services/palpite_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaPalpites extends StatefulWidget {
  const TelaPalpites({super.key});

  @override
  State<TelaPalpites> createState() => _TelaPalpitesState();
}

class _TelaPalpitesState extends State<TelaPalpites> {
  late Future<void> _futureCarregar;

  Map<String, List<Jogo>> _grupos = {};
  List<String> _todasAsDatas = [];
  int _datasVisiveis = 1;

  @override
  void initState() {
    super.initState();
    _futureCarregar = _carregarJogos();
  }

  Future<void> _carregarJogos() async {
    final todos = await JogoService().buscarTodos();

    final mapa = <String, List<Jogo>>{};
    for (final jogo in todos) {
      if (jogo.placar1 != null) continue;
      final local = jogo.dataHora.toLocal();
      final chave =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      mapa.putIfAbsent(chave, () => []).add(jogo);
    }

    setState(() {
      _grupos = mapa;
      _todasAsDatas = mapa.keys.toList();
      _datasVisiveis = 1;
    });
  }

  void _verMais() => setState(() => _datasVisiveis++);

  bool get _temMais => _datasVisiveis < _todasAsDatas.length;

  List<String> get _datasAtivas =>
      _todasAsDatas.take(_datasVisiveis).toList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _futureCarregar,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar jogos.',
              style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
            ),
          );
        }

        if (_grupos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_soccer_rounded,
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
                  'Todos os palpites já foram registrados.',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEUS PALPITES',
                      style: GoogleFonts.anybody(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Cores.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Insira seus placares para os próximos jogos.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16,
                        color: Cores.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            for (final chave in _datasAtivas) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _CabecalhoData(dataChave: chave),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: _CardPalpite(jogo: _grupos[chave]![i]),
                    ),
                    childCount: _grupos[chave]!.length,
                  ),
                ),
              ),
            ],

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              sliver: SliverToBoxAdapter(
                child: _temMais
                    ? _BotaoVerMais(onTap: _verMais)
                    : const _FimDaLista(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Cabeçalho de data ────────────────────────────────────────────────────────

class _CabecalhoData extends StatelessWidget {
  const _CabecalhoData({required this.dataChave});

  final String dataChave;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  static const _diasSemana = [
    'Segunda-feira', 'Terça-feira', 'Quarta-feira',
    'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final data = DateTime.parse(dataChave).toLocal();
    final mes = _meses[data.month - 1];
    final diaSemana = _diasSemana[data.weekday - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.day} de $mes de ${data.year} · $diaSemana',
          style: GoogleFonts.anybody(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Cores.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Cores.outlineVariant, height: 1),
      ],
    );
  }
}

// ─── Card de palpite ──────────────────────────────────────────────────────────

class _CardPalpite extends StatefulWidget {
  const _CardPalpite({required this.jogo});

  final Jogo jogo;

  @override
  State<_CardPalpite> createState() => _CardPalpiteState();
}

class _CardPalpiteState extends State<_CardPalpite> {
  final _ctrl1 = TextEditingController();
  final _ctrl2 = TextEditingController();

  // UID garantido não-nulo: o StreamBuilder do main.dart só chega aqui
  // se o usuário estiver logado.
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _salvo = false;
  bool _carregando = true; // busca palpite existente no initState
  bool _salvando = false;  // operação de escrita em andamento

  @override
  void initState() {
    super.initState();
    _carregarPalpiteExistente();
  }

  // Busca no Firestore se o usuário já palpitou nesse jogo.
  // Se sim, pré-preenche os campos e marca como salvo.
  Future<void> _carregarPalpiteExistente() async {
    final palpite =
    await PalpiteService().buscarPorJogo(_uid, widget.jogo.id);

    if (!mounted) return; // widget pode ter sido removido enquanto aguardava

    if (palpite != null) {
      _ctrl1.text = palpite.palpite1.toString();
      _ctrl2.text = palpite.palpite2.toString();
      _salvo = true;
    }

    setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    final v1 = int.tryParse(_ctrl1.text);
    final v2 = int.tryParse(_ctrl2.text);

    if (v1 == null || v2 == null) {
      mostrarMensagem(context, 'Preencha os dois placares antes de salvar.');
      return;
    }

    setState(() => _salvando = true);

    try {
      await PalpiteService().salvar(Palpite(
        uid: _uid,
        jogoId: widget.jogo.id,
        palpite1: v1,
        palpite2: v2,
        criadoEm: DateTime.now(), // substituído pelo serverTimestamp no toMap()
      ));

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      setState(() {
        _salvo = true;
        _salvando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarMensagem(context, 'Erro ao salvar palpite. Tente novamente.');
    }
  }

  void _editar() => setState(() => _salvo = false);

  String get _horario {
    final local = widget.jogo.dataHora.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Card principal ─────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _salvo ? Cores.surfaceContainer : Cores.surface,
            border: Border.all(
              color: _salvo ? Cores.verdePrincipal : Cores.outlineVariant,
              width: _salvo ? 2.0 : 1.0,
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
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: _carregando
          // Enquanto busca o palpite existente, exibe um placeholder
          // com a mesma altura do conteúdo real para evitar layout jump.
              ? const SizedBox(
            height: 80,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
              : Row(
            children: [
              Expanded(child: _Time(nome: widget.jogo.team1)),
              Expanded(
                flex: 2,
                child: _Inputs(
                  ctrl1: _ctrl1,
                  ctrl2: _ctrl2,
                  salvo: _salvo,
                ),
              ),
              Expanded(child: _Time(nome: widget.jogo.team2)),
            ],
          ),
        ),

        // ── Pill de horário ────────────────────────────────────────────────
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Cores.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Cores.outlineVariant),
              ),
              child: Text(
                _horario,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),

        // ── Ícone de lock (ou loading de salvamento) ───────────────────────
        if (!_carregando)
          Positioned(
            top: 8,
            right: 8,
            child: _salvando
            // Spinner pequeno enquanto o set() do Firestore está em andamento
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Cores.verdePrincipal,
              ),
            )
                : GestureDetector(
              onTap: _salvo ? _editar : _salvar,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _salvo
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  key: ValueKey(_salvo),
                  size: 20,
                  color: _salvo
                      ? Cores.verdePrincipal
                      : Cores.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cores.surfaceContainerHigh,
            border: Border.all(color: Cores.outlineVariant),
          ),
          child: Center(
            child: Text(flagDe(nome), style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          siglaDe(nome),
          style: GoogleFonts.anybody(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Cores.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Par de campos de placar ──────────────────────────────────────────────────

class _Inputs extends StatelessWidget {
  const _Inputs({
    required this.ctrl1,
    required this.ctrl2,
    required this.salvo,
  });

  final TextEditingController ctrl1;
  final TextEditingController ctrl2;
  final bool salvo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CampoGol(controller: ctrl1, salvo: salvo),
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
        _CampoGol(controller: ctrl2, salvo: salvo),
      ],
    );
  }
}

class _CampoGol extends StatelessWidget {
  const _CampoGol({required this.controller, required this.salvo});

  final TextEditingController controller;
  final bool salvo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 68,
      child: TextField(
        controller: controller,
        readOnly: salvo,
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
          fillColor: salvo ? Cores.surfaceContainer : Cores.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: salvo ? Cores.verdePrincipal : Cores.outlineVariant,
              width: salvo ? 2.0 : 1.0,
            ),
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

// ─── Botão "Ver mais" ─────────────────────────────────────────────────────────

class _BotaoVerMais extends StatelessWidget {
  const _BotaoVerMais({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.expand_more_rounded),
      label: Text(
        'VER MAIS',
        style: GoogleFonts.anybody(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.verdePrincipal,
        side: const BorderSide(color: Cores.verdePrincipal),
        minimumSize: const Size(double.infinity, 48),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── Fim da lista ─────────────────────────────────────────────────────────────

class _FimDaLista extends StatelessWidget {
  const _FimDaLista();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Cores.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Todos os jogos exibidos',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Cores.outlineVariant)),
      ],
    );
  }
}