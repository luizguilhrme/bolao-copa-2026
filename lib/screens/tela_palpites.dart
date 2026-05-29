import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../models/usuario.dart';
import '../services/jogo_service.dart';
import '../services/palpite_service.dart';
import '../services/usuario_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

// ─── Modelo interno ───────────────────────────────────────────────────────────

class _ItemResultado {
  const _ItemResultado({required this.jogo, this.palpite, this.pontos, this.pontosBase});
  final Jogo jogo;
  final Palpite? palpite;
  final int? pontos;     // pontos reais exibidos (com multiplicador de fase)
  final int? pontosBase; // pontos base sem multiplicador — define a cor do card
}

enum _Status { prestesAComecar, aoVivo, encerrado }

// ─── Funções auxiliares (top-level) ──────────────────────────────────────────

// Retorna pontos BASE (sem multiplicador de fase).
// O multiplicador é aplicado separadamente em _calcularPontosComFase.
int _calcularPontos(int p1, int p2, int r1, int r2) {
  if (p1 == r1 && p2 == r2) return 100; // placar exato
  final sP = p1 - p2, sR = r1 - r2;
  final vP = p1.compareTo(p2), vR = r1.compareTo(r2);
  if (vP != vR) return 0; // errou o vencedor — sem pontos
  if (vP != 0) {
    // Acertou o vencedor (não empate)
    if (sP == sR) return 70;              // + saldo de gols correto
    if (p1 == r1 || p2 == r2) return 60; // + gols exatos de um dos times
    return 50;                            // só o vencedor
  }
  return 50; // empate certo, placar errado
}

// Multiplicador de pontuação por fase eliminatória.
double _multiplicador(String round) {
  switch (round) {
    case '16 avos de Final':  return 1.2;
    case 'Oitavas de Final':  return 1.4;
    case 'Quartas de Final':  return 1.6;
    case 'Semifinal':
    case 'Disputa de 3º Lugar': return 1.8;
    case 'Final':             return 2.0;
    default:                  return 1.0; // Fase de Grupos
  }
}

// Pontos reais considerando a fase do jogo.
int _calcularPontosComFase(int p1, int p2, int r1, int r2, String round) {
  final base = _calcularPontos(p1, p2, r1, r2);
  if (base == 0) return 0;
  return (base * _multiplicador(round)).round();
}

_Status _statusDe(Jogo jogo) {
  if (jogo.placar1 != null) return _Status.encerrado;
  return DateTime.now().isAfter(jogo.dataHora.toLocal())
      ? _Status.aoVivo
      : _Status.prestesAComecar;
}

bool _estaBloqueado(Jogo jogo) => DateTime.now().isAfter(
    jogo.dataHora.toLocal().subtract(const Duration(minutes: 5)));

String _formatarCriadoEm(DateTime? dt) {
  if (dt == null) return '';
  final l = dt.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')} às '
      '${l.hour.toString().padLeft(2, '0')}h'
      '${l.minute.toString().padLeft(2, '0')}';
}

// Cores baseadas em pontosBase (sem multiplicador) para manter consistência
// visual independente da fase. Escala: 100=exato, 70=v+saldo, 60=v+um time,
// 50=só vencedor ou empate certo, 0=errou, negativo=sem palpite.

Color _corFundo(int? pontosBase) {
  if (pontosBase == null) return Cores.surface;
  if (pontosBase < 0)    return const Color(0xFFE53935).withValues(alpha: 0.08);
  if (pontosBase >= 100) return const Color(0xFF006D32).withValues(alpha: 0.08);
  if (pontosBase >= 70)  return const Color(0xFF1B7F3A).withValues(alpha: 0.08);
  if (pontosBase >= 60)  return const Color(0xFF2E7D52).withValues(alpha: 0.08);
  if (pontosBase >= 50)  return const Color(0xFF4CAF50).withValues(alpha: 0.08);
  return const Color(0xFFBBCBB9).withValues(alpha: 0.2); // 0 pts
}

Color _corBorda(int? pontosBase) {
  if (pontosBase == null) return Cores.outlineVariant;
  if (pontosBase < 0)    return const Color(0xFFE53935);
  if (pontosBase >= 100) return const Color(0xFF006D32);
  if (pontosBase >= 70)  return const Color(0xFF1B7F3A);
  if (pontosBase >= 60)  return const Color(0xFF2E7D52);
  if (pontosBase >= 50)  return const Color(0xFF4CAF50);
  return const Color(0xFFBBCBB9);
}

Color _corBadge(int pontosBase) {
  if (pontosBase < 0)    return const Color(0xFFE53935);
  if (pontosBase >= 100) return const Color(0xFF006D32);
  if (pontosBase >= 70)  return const Color(0xFF1B7F3A);
  if (pontosBase >= 60)  return const Color(0xFF2E7D52);
  if (pontosBase >= 50)  return const Color(0xFF4CAF50);
  return const Color(0xFFBBCBB9);
}

// Todos os badges agora usam texto branco (não há mais badge amarelo)
Color _corTextoBadge(int pontosBase) => Colors.white;

// ─── Tela principal ───────────────────────────────────────────────────────────

class TelaPalpites extends StatefulWidget {
  const TelaPalpites({super.key});

  @override
  State<TelaPalpites> createState() => _TelaPalpitesState();
}

class _TelaPalpitesState extends State<TelaPalpites> {
  bool _abaProximos = true;
  bool _carregando = true;

  // Dados brutos — carregados uma vez do Firestore
  List<Jogo> _todosJogos = [];
  Map<int, Palpite> _palpitesMap = {};

  // Dados derivados — atualizados pelo timer
  Map<String, List<Jogo>> _gruposProximos = {};
  List<String> _todasAsDatas = [];
  int _datasVisiveis = 1;
  List<_ItemResultado> _resultados = [];

  DateTime? _criadoEm;
  Timer? _timer;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _carregar();
    // Reclassifica a cada 30s para mover jogos entre abas automaticamente
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _reclassificar(preservarDatasVisiveis: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final results = await Future.wait([
        JogoService().buscarTodos(),
        PalpiteService().buscarTodosPorUsuario(_uid),
        UsuarioService().buscarPorUid(_uid),
      ]);
      _todosJogos = results[0] as List<Jogo>;
      final palpites = results[1] as List<Palpite>;
      _criadoEm = (results[2] as Usuario?)?.criadoEm;
      _palpitesMap = {for (final p in palpites) p.jogoId: p};
      _reclassificar(preservarDatasVisiveis: false);
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  void _reclassificar({required bool preservarDatasVisiveis}) {
    final agora = DateTime.now();
    final proximos = <String, List<Jogo>>{};
    final resultados = <_ItemResultado>[];

    for (final jogo in _todosJogos) {
      // Pular jogos cujos times ainda não foram definidos (fase mata-mata)
      if (ehPlaceholder(jogo.team1) || ehPlaceholder(jogo.team2)) continue;

      final cutoff =
      jogo.dataHora.toLocal().subtract(const Duration(minutes: 5));

      if (agora.isBefore(cutoff) && jogo.placar1 == null) {
        // Disponível para palpite
        final local = jogo.dataHora.toLocal();
        final chave =
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        proximos.putIfAbsent(chave, () => []).add(jogo);
      } else {
        // Bloqueado, ao vivo ou encerrado
        final palpite = _palpitesMap[jogo.id];
        int? pontos;
        int? pontosBase;
        if (jogo.placar1 != null && jogo.placar2 != null) {
          if (palpite != null) {
            pontosBase = _calcularPontos(
              palpite.palpite1, palpite.palpite2,
              jogo.placar1!, jogo.placar2!,
            );
            pontos = _calcularPontosComFase(
              palpite.palpite1, palpite.palpite2,
              jogo.placar1!, jogo.placar2!,
              jogo.round,
            );
          } else if (_criadoEm != null && jogo.dataHora.isAfter(_criadoEm!)) {
            pontos = -10;
            pontosBase = -10;
          }
        }
        resultados.add(_ItemResultado(
            jogo: jogo, palpite: palpite, pontos: pontos, pontosBase: pontosBase));
      }
    }

    resultados.sort((a, b) => b.jogo.dataHora.compareTo(a.jogo.dataHora));

    final datas = proximos.keys.toList();

    setState(() {
      _gruposProximos = proximos;
      _todasAsDatas = datas;
      _datasVisiveis = preservarDatasVisiveis
          ? _datasVisiveis.clamp(1, datas.isEmpty ? 1 : datas.length)
          : 1;
      _resultados = resultados;
      _carregando = false;
    });
  }

  // Chamado pelo card quando o usuário salva um palpite novo
  void _onPalpiteSalvo(Palpite palpite) {
    _palpitesMap[palpite.jogoId] = palpite;
    // O jogo continua em Próximos — não precisa reclassificar
  }

  bool get _temMaisProximos => _datasVisiveis < _todasAsDatas.length;

  List<String> get _datasAtivas =>
      _todasAsDatas.take(_datasVisiveis).toList();

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seletor de abas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _SeletorAbas(
            abaProximos: _abaProximos,
            countProximos: _gruposProximos.values
                .fold(0, (s, l) => s + l.length),
            countResultados: _resultados.length,
            onChanged: (v) => setState(() => _abaProximos = v),
          ),
        ),

        // Conteúdo
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _abaProximos
                ? _AbaProximos(
              key: const ValueKey('proximos'),
              grupos: _gruposProximos,
              datasAtivas: _datasAtivas,
              palpitesMap: _palpitesMap,
              temMais: _temMaisProximos,
              onVerMais: () => setState(() => _datasVisiveis++),
              onPalpiteSalvo: _onPalpiteSalvo,
            )
                : _AbaResultados(
              key: const ValueKey('resultados'),
              resultados: _resultados,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Seletor de abas ──────────────────────────────────────────────────────────

class _SeletorAbas extends StatelessWidget {
  const _SeletorAbas({
    required this.abaProximos,
    required this.countProximos,
    required this.countResultados,
    required this.onChanged,
  });

  final bool abaProximos;
  final int countProximos;
  final int countResultados;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BotaoAba(
            label: 'Próximos',
            count: countProximos,
            ativo: abaProximos,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BotaoAba(
            label: 'Resultados',
            count: countResultados,
            ativo: !abaProximos,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _BotaoAba extends StatelessWidget {
  const _BotaoAba({
    required this.label,
    required this.count,
    required this.ativo,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: ativo ? Cores.verdePrincipal : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ativo ? Colors.white : Cores.onSurfaceVariant,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ativo
                      ? Colors.white.withValues(alpha: 0.25)
                      : Cores.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ativo ? Colors.white : Cores.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Aba Próximos ─────────────────────────────────────────────────────────────

class _AbaProximos extends StatefulWidget {
  const _AbaProximos({
    super.key,
    required this.grupos,
    required this.datasAtivas,
    required this.palpitesMap,
    required this.temMais,
    required this.onVerMais,
    required this.onPalpiteSalvo,
  });

  final Map<String, List<Jogo>> grupos;
  final List<String> datasAtivas;
  final Map<int, Palpite> palpitesMap;
  final bool temMais;
  final VoidCallback onVerMais;
  final void Function(Palpite) onPalpiteSalvo;

  @override
  State<_AbaProximos> createState() => _AbaProximosState();
}

class _AbaProximosState extends State<_AbaProximos> {
  final List<FocusNode> _focusNodes = [];

  int get _totalCards => widget.datasAtivas.fold<int>(
      0, (s, d) => s + (widget.grupos[d]?.length ?? 0));

  @override
  void initState() {
    super.initState();
    _reconstruirFocusNodes(_totalCards);
  }

  @override
  void didUpdateWidget(_AbaProximos old) {
    super.didUpdateWidget(old);
    final total = _totalCards;
    if (total != _focusNodes.length) _reconstruirFocusNodes(total);
  }

  void _reconstruirFocusNodes(int count) {
    for (final fn in _focusNodes) { fn.dispose(); }
    _focusNodes
      ..clear()
      ..addAll(List.generate(count, (_) => FocusNode()));
  }

  @override
  void dispose() {
    for (final fn in _focusNodes) { fn.dispose(); }
    super.dispose();
  }

  void _onSalvoComEnter(int index) {
    final next = index + 1;
    if (next < _focusNodes.length) {
      _focusNodes[next].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.grupos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer_rounded,
                size: 64, color: Cores.outlineVariant),
            const SizedBox(height: 16),
            Text('Nenhum jogo disponível',
                style: GoogleFonts.anybody(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurface)),
            const SizedBox(height: 8),
            Text('Todos os jogos já foram encerrados\nou estão prestes a começar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    color: Cores.onSurfaceVariant,
                    height: 1.5)),
          ],
        ),
      );
    }

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Insira seus placares para os próximos jogos.',
            style: GoogleFonts.hankenGrotesk(
                fontSize: 15, color: Cores.onSurfaceVariant),
          ),
        ),
      ),
    ];

    int cardIndex = 0;
    for (final chave in widget.datasAtivas) {
      final jogos = widget.grupos[chave]!;
      final baseIndex = cardIndex;

      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        sliver: SliverToBoxAdapter(child: _CabecalhoData(dataChave: chave)),
      ));
      slivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final idx = baseIndex + i;
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: _CardPalpite(
                  jogo: jogos[i],
                  palpiteInicial: widget.palpitesMap[jogos[i].id],
                  onPalpiteSalvo: widget.onPalpiteSalvo,
                  focusCtrl1: idx < _focusNodes.length ? _focusNodes[idx] : null,
                  onSalvoComEnter: () => _onSalvoComEnter(idx),
                ),
              );
            },
            childCount: jogos.length,
          ),
        ),
      ));
      cardIndex += jogos.length;
    }

    slivers.add(SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      sliver: SliverToBoxAdapter(
        child: widget.temMais
            ? _BotaoVerMais(onTap: widget.onVerMais)
            : const _FimDaLista(),
      ),
    ));

    return CustomScrollView(slivers: slivers);
  }
}

// ─── Aba Resultados ───────────────────────────────────────────────────────────

class _AbaResultados extends StatelessWidget {
  const _AbaResultados({super.key, required this.resultados});

  final List<_ItemResultado> resultados;

  @override
  Widget build(BuildContext context) {
    if (resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 64, color: Cores.outlineVariant),
            const SizedBox(height: 16),
            Text('Nenhum resultado ainda',
                style: GoogleFonts.anybody(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurface)),
            const SizedBox(height: 8),
            Text('Os jogos aparecerão aqui\nquando estiverem prestes a começar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    color: Cores.onSurfaceVariant,
                    height: 1.5)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _CardResultado(item: resultados[i]),
    );
  }
}

// ─── Card de palpite (aba Próximos) ──────────────────────────────────────────

class _CardPalpite extends StatefulWidget {
  const _CardPalpite({
    required this.jogo,
    required this.palpiteInicial,
    required this.onPalpiteSalvo,
    this.focusCtrl1,
    this.onSalvoComEnter,
  });

  final Jogo jogo;
  final Palpite? palpiteInicial;
  final void Function(Palpite) onPalpiteSalvo;
  final FocusNode? focusCtrl1;
  final VoidCallback? onSalvoComEnter;

  @override
  State<_CardPalpite> createState() => _CardPalpiteState();
}

class _CardPalpiteState extends State<_CardPalpite> {
  late final TextEditingController _ctrl1;
  late final TextEditingController _ctrl2;
  final _focusCtrl2 = FocusNode();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _salvo = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Pré-preenche com o palpite precarregado pelo pai — sem query adicional
    final p = widget.palpiteInicial;
    _ctrl1 = TextEditingController(text: p != null ? '${p.palpite1}' : '');
    _ctrl2 = TextEditingController(text: p != null ? '${p.palpite2}' : '');
    _salvo = p != null;
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _focusCtrl2.dispose();
    super.dispose();
  }

  Future<void> _salvar({bool fromEnter = false}) async {
    // Trava de segurança: impede salvar após o cutoff de 5 min
    if (_estaBloqueado(widget.jogo)) {
      mostrarMensagem(context, 'Palpites encerrados para este jogo.');
      return;
    }

    final v1 = int.tryParse(_ctrl1.text);
    final v2 = int.tryParse(_ctrl2.text);
    if (v1 == null || v2 == null) {
      mostrarMensagem(context, 'Preencha os dois placares antes de salvar.');
      return;
    }

    setState(() => _salvando = true);

    final novoPalpite = Palpite(
      uid: _uid,
      jogoId: widget.jogo.id,
      palpite1: v1,
      palpite2: v2,
      criadoEm: DateTime.now(),
    );

    try {
      await PalpiteService().salvar(novoPalpite);
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarMensagem(context, 'Erro ao salvar. Tente novamente.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _salvo = true;
      _salvando = false;
    });
    if (fromEnter && widget.onSalvoComEnter != null) {
      widget.onSalvoComEnter!();
    } else {
      FocusScope.of(context).unfocus();
    }
    widget.onPalpiteSalvo(novoPalpite);
  }

  void _editar() => setState(() => _salvo = false);

  String get _horario {
    final l = widget.jogo.dataHora.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _salvo ? Cores.surfaceContainer : Cores.surface,
            border: Border.all(
              color: _salvo ? Cores.verdePrincipal : Cores.outlineVariant,
              width: _salvo ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Row(
            children: [
              Expanded(child: _Time(nome: widget.jogo.team1)),
              Expanded(
                  flex: 2,
                  child: _InputsProximos(
                      ctrl1: _ctrl1, ctrl2: _ctrl2, salvo: _salvo,
                      focusCtrl1: widget.focusCtrl1,
                      focusCtrl2: _focusCtrl2,
                      onSalvar: () => _salvar(fromEnter: true))),
              Expanded(child: _Time(nome: widget.jogo.team2)),
            ],
          ),
        ),

        // Pill de horário
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    letterSpacing: 0.5),
              ),
            ),
          ),
        ),

        // Lock
        Positioned(
          top: 8,
          right: 8,
          child: _salvando
              ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Cores.verdePrincipal))
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
}

// ─── Card de resultado (aba Resultados) ───────────────────────────────────────

class _CardResultado extends StatelessWidget {
  const _CardResultado({required this.item});

  final _ItemResultado item;

  Jogo get jogo => item.jogo;
  Palpite? get palpite => item.palpite;
  int? get pontos => item.pontos;
  int? get pontosBase => item.pontosBase;

  String get _horario {
    final l = jogo.dataHora.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusDe(jogo);
    final encerrado = status == _Status.encerrado;

    return Container(
      decoration: BoxDecoration(
        color: encerrado ? _corFundo(pontosBase) : Cores.surface,
        border: Border.all(
          color: encerrado ? _corBorda(pontosBase) : Cores.outlineVariant,
          width: encerrado && pontosBase != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho: grupo/fase + status
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  jogo.group ?? jogo.round,
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Cores.onSurfaceVariant),
                ),
                _ChipStatus(status: status, horario: _horario),
              ],
            ),
          ),

          // Times + palpite
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _Time(nome: jogo.team1)),
                    Expanded(
                      flex: 2,
                      child: _ScoreDisplay(
                        valor1: palpite != null
                            ? '${palpite!.palpite1}'
                            : '—',
                        valor2: palpite != null
                            ? '${palpite!.palpite2}'
                            : '—',
                        label: palpite != null
                            ? 'Seu palpite'
                            : 'Sem palpite',
                        corTexto: Cores.onSurface,
                      ),
                    ),
                    Expanded(child: _Time(nome: jogo.team2)),
                  ],
                ),

                // Resultado real (só se encerrado)
                if (encerrado && jogo.placar1 != null) ...[
                  const SizedBox(height: 8),
                  Divider(
                      color: _corBorda(pontosBase).withValues(alpha: 0.3),
                      height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      _ScoreDisplay(
                        valor1: '${jogo.placar1}',
                        valor2: '${jogo.placar2}',
                        label: 'Resultado',
                        corTexto: Cores.onSurfaceVariant,
                        compacto: true,
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Rodapé: pontuação + horário do palpite
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge de pontos (só se encerrado)
                if (encerrado)
                  _BadgePontos(pontos: pontos, pontosBase: pontosBase, temPalpite: palpite != null)
                else
                  const SizedBox.shrink(),

                // criadoEm
                if (palpite?.criadoEm != null)
                  Text(
                    'Registrado em ${_formatarCriadoEm(palpite!.criadoEm)}',
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 11, color: Cores.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.status, required this.horario});

  final _Status status;
  final String horario;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _Status.aoVivo:
        return const _ChipAoVivo();
      case _Status.prestesAComecar:
        return Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFCD400).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: const Color(0xFFFCD400).withValues(alpha: 0.6)),
          ),
          child: Text(
            'PRESTES A COMEÇAR',
            style: GoogleFonts.hankenGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6E5C00)),
          ),
        );
      case _Status.encerrado:
        return Text(
          horario,
          style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Cores.onSurfaceVariant),
        );
    }
  }
}

class _ChipAoVivo extends StatefulWidget {
  const _ChipAoVivo();

  @override
  State<_ChipAoVivo> createState() => _ChipAoVivoState();
}

class _ChipAoVivoState extends State<_ChipAoVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Cores.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Cores.primaryContainer),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Cores.verdePrincipal
                    .withValues(alpha: 0.4 + 0.6 * _ctrl.value),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'AO VIVO',
            style: GoogleFonts.hankenGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Cores.verdePrincipal),
          ),
        ],
      ),
    );
  }
}

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({
    required this.valor1,
    required this.valor2,
    required this.label,
    required this.corTexto,
    this.compacto = false,
  });

  final String valor1;
  final String valor2;
  final String label;
  final Color corTexto;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final fontSize = compacto ? 18.0 : 24.0;
    final boxSize = compacto ? 40.0 : 52.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ScoreBox(valor: valor1, size: boxSize, fontSize: fontSize),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('×',
                  style: GoogleFonts.anybody(
                      fontSize: compacto ? 16 : 20,
                      fontWeight: FontWeight.w600,
                      color: Cores.onSurfaceVariant)),
            ),
            _ScoreBox(valor: valor2, size: boxSize, fontSize: fontSize),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Cores.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox(
      {required this.valor, required this.size, required this.fontSize});

  final String valor;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Cores.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cores.outlineVariant),
      ),
      child: Center(
        child: Text(
          valor,
          style: GoogleFonts.hankenGrotesk(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Cores.onSurface),
        ),
      ),
    );
  }
}

class _BadgePontos extends StatelessWidget {
  const _BadgePontos({
    required this.pontos,
    required this.pontosBase,
    required this.temPalpite,
  });

  final int? pontos;      // valor exibido (com multiplicador de fase)
  final int? pontosBase;  // valor base (define a cor)
  final bool temPalpite;

  @override
  Widget build(BuildContext context) {
    // Punição por não ter palpitado
    if ((pontosBase ?? 0) < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '−10 pts',
          style: GoogleFonts.anybody(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white),
        ),
      );
    }

    // Jogo encerrado mas sem palpite registrado (e sem punição = cadastro após o jogo)
    if (!temPalpite) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFBBCBB9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Sem palpite',
          style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      );
    }

    final pts = pontos ?? 0;
    final base = pontosBase ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _corBadge(base),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$pts pts',
        style: GoogleFonts.anybody(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _corTextoBadge(base)),
      ),
    );
  }
}

class _InputsProximos extends StatelessWidget {
  const _InputsProximos({
    required this.ctrl1,
    required this.ctrl2,
    required this.salvo,
    this.focusCtrl1,
    this.focusCtrl2,
    this.onSalvar,
  });

  final TextEditingController ctrl1;
  final TextEditingController ctrl2;
  final bool salvo;
  final FocusNode? focusCtrl1;
  final FocusNode? focusCtrl2;
  final VoidCallback? onSalvar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CampoGol(
          controller: ctrl1,
          salvo: salvo,
          focusNode: focusCtrl1,
          textInputAction: TextInputAction.next,
          onSubmitted: focusCtrl2 != null
              ? (_) => focusCtrl2!.requestFocus()
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('X',
              style: GoogleFonts.anybody(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurfaceVariant)),
        ),
        _CampoGol(
          controller: ctrl2,
          salvo: salvo,
          focusNode: focusCtrl2,
          textInputAction: TextInputAction.done,
          onSubmitted: onSalvar != null ? (_) => onSalvar!() : null,
        ),
      ],
    );
  }
}

class _CampoGol extends StatelessWidget {
  const _CampoGol({
    required this.controller,
    required this.salvo,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool salvo;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

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
        focusNode: focusNode,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        style: GoogleFonts.hankenGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Cores.onSurface,
            letterSpacing: 1),
        decoration: InputDecoration(
          hintText: '–',
          hintStyle: GoogleFonts.hankenGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w300,
              color: Cores.outlineVariant),
          filled: true,
          fillColor: salvo ? Cores.surfaceContainer : Cores.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: salvo ? Cores.verdePrincipal : Cores.outlineVariant,
                width: salvo ? 2 : 1),
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
              color: Cores.onSurface),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CabecalhoData extends StatelessWidget {
  const _CabecalhoData({required this.dataChave});

  final String dataChave;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];
  static const _dias = [
    'Segunda-feira', 'Terça-feira', 'Quarta-feira',
    'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final data = DateTime.parse(dataChave).toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.day} de ${_meses[data.month - 1]} de ${data.year} · ${_dias[data.weekday - 1]}',
          style: GoogleFonts.anybody(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Cores.onSurface),
        ),
        const SizedBox(height: 8),
        const Divider(color: Cores.outlineVariant, height: 1),
      ],
    );
  }
}

class _BotaoVerMais extends StatelessWidget {
  const _BotaoVerMais({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.expand_more_rounded),
      label: Text('VER MAIS',
          style: GoogleFonts.anybody(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
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

class _FimDaLista extends StatelessWidget {
  const _FimDaLista();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Cores.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Todos os jogos exibidos',
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 12, color: Cores.onSurfaceVariant)),
        ),
        const Expanded(child: Divider(color: Cores.outlineVariant)),
      ],
    );
  }
}