import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bolao/utils/biblioteca.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/jogo.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../services/jogo_service.dart';
import '../services/usuario_service.dart';
import '../utils/artilharia.dart';
import '../utils/cores.dart';
import 'tela_palpites_especiais.dart';

// ─── Tela Home ────────────────────────────────────────────────────────────────

class TelaHome extends StatefulWidget {
  const TelaHome({
    super.key,
    required this.onNavegar,
    required this.onVerArtilharia,
    this.sinalAtualizar,
  });

  final void Function(int) onNavegar;

  /// Navega para a tela Tabela já na aba superior ARTILHARIA.
  final VoidCallback onVerArtilharia;

  /// Disparado pelo MenuPrincipal quando a tela precisa ressincronizar
  /// (aba selecionada ou retorno de rota do drawer).
  final Sinal? sinalAtualizar;

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late Future<List<Jogo>> _jogosDeHoje;
  late Future<List<_GrupoRank>> _rankInfo;

  @override
  void initState() {
    super.initState();
    _jogosDeHoje = JogoService().buscarPorData(DateTime.now());
    _rankInfo = _carregarRankInfo();
    widget.sinalAtualizar?.addListener(_recarregarSilencioso);
  }

  @override
  void dispose() {
    widget.sinalAtualizar?.removeListener(_recarregarSilencioso);
    super.dispose();
  }

  // Rebusca jogos do dia e posições no ranking sem flash de loading:
  // os dados novos só substituem os antigos quando já estão prontos.
  Future<void> _recarregarSilencioso() async {
    try {
      final jogos = await JogoService().buscarPorData(DateTime.now());
      final rank = await _carregarRankInfo();
      if (!mounted) return;
      setState(() {
        _jogosDeHoje = Future.value(jogos);
        _rankInfo = Future.value(rank);
      });
    } catch (_) {
      // Mantém os dados antigos em caso de erro
    }
  }

  Future<List<_GrupoRank>> _carregarRankInfo() async {
    try {
      final grupos = await GrupoService().buscarGruposDoUsuarioOnce(_uid);
      if (grupos.isEmpty) return [];

      final result = <_GrupoRank>[];
      for (final grupo in grupos) {
        final membros = grupo.membros;
        if (membros.isEmpty) continue;

        // whereIn suporta até 30 itens no Firestore
        final ids = membros.length > 30 ? membros.sublist(0, 30) : membros;
        final snap =
            await FirebaseFirestore.instance
                .collection('usuarios')
                .where(FieldPath.documentId, whereIn: ids)
                .get();

        final todos =
            snap.docs.map((d) => Usuario.fromMap(d.data())).toList()..sort(
              (a, b) =>
                  grupo.regra == 'copa'
                      ? b.pontuacaoCopaTotal.compareTo(a.pontuacaoCopaTotal)
                      : b.pontuacaoClassicaTotal.compareTo(
                        a.pontuacaoClassicaTotal,
                      ),
            );

        final idx = todos.indexWhere((u) => u.uid == _uid);
        if (idx >= 0) {
          result.add(
            _GrupoRank(
              posicao: idx + 1,
              grupoNome: grupo.nome,
              regra: grupo.regra,
            ),
          );
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 88),
      child: FutureBuilder<List<Jogo>>(
        future: _jogosDeHoje,
        builder: (context, snap) {
          final jogosHoje =
              (snap.hasData && snap.data!.isNotEmpty) ? snap.data! : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 20),
              if (jogosHoje != null) ...[
                _buildSecaoJogos(jogosHoje),
                const SizedBox(height: 20),
              ],
              _buildAcoes(),
              const SizedBox(height: 20),
              _buildArtilharia(),
            ],
          );
        },
      ),
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return StreamBuilder<Usuario?>(
      stream: UsuarioService().observarUsuario(_uid),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();
        final usuario = userSnap.data!;

        // Só exibe depois que algum resultado for registrado
        if (usuario.pontuacaoClassicaTotal == 0 &&
            usuario.pontuacaoCopaTotal == 0) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<List<_GrupoRank>>(
          future: _rankInfo,
          builder: (context, rankSnap) {
            if (!rankSnap.hasData) return const SizedBox.shrink();
            final ranks = rankSnap.data!;
            if (ranks.isEmpty) return const SizedBox.shrink();

            final hasClassico = ranks.any((r) => r.regra == 'classico');
            final hasCopa = ranks.any((r) => r.regra == 'copa');
            final hasBoth = hasClassico && hasCopa;
            final ptsClassico = usuario.pontuacaoClassicaTotal;
            final ptsCopa = usuario.pontuacaoCopaTotal;
            final tickerItems =
                ranks.map((r) => '${r.posicao}º no ${r.grupoNome}').toList();

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Cores.verdePrincipal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TickerRanking(items: tickerItems),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (hasClassico)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: Color(0xFFFCD400),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '$ptsClassico',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anybody(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'pts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Clássico',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasCopa)
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                hasBoth
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    hasBoth
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🏆',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '$ptsCopa',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anybody(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'pts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Copa',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
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
          },
        );
      },
    );
  }

  // ── Jogos de hoje ──────────────────────────────────────────────────────────

  Widget _buildSecaoJogos(List<Jogo> jogos) {
    final ordenados =
        jogos.toList()..sort((a, b) {
          final aEnc = a.placar1 != null ? 1 : 0;
          final bEnc = b.placar1 != null ? 1 : 0;
          if (aEnc != bEnc) return aEnc - bEnc;
          return a.dataHora.compareTo(b.dataHora);
        });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'JOGOS DE HOJE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Cores.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: ordenados.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _CardJogo(jogo: ordenados[i]),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: Cores.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                'O placar é atualizado somente ao final da partida.',
                style: TextStyle(fontSize: 11.5, color: Cores.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cards de ação ──────────────────────────────────────────────────────────

  Widget _buildAcoes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardAcao(
            titulo: 'PALPITES',
            imagemAsset: 'assets/background-cards/br.png',
            onTap: () => widget.onNavegar(1),
          ),
          const SizedBox(height: 12),
          _CardAcao(
            titulo: 'RANKING',
            imagemAsset: 'assets/background-cards/r9.png',
            onTap: () => widget.onNavegar(2),
          ),
          const SizedBox(height: 12),
          _CardAcao(
            titulo: 'PALPITES ESPECIAIS',
            imagemAsset: 'assets/background-cards/2022.png',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TelaPalpitesEspeciais(),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // ── Artilharia (top 5) ──────────────────────────────────────────────────────
  // Tocar no card abre a tela Tabela já na aba ARTILHARIA.

  Widget _buildArtilharia() {
    final top5 = kArtilhariaSimulada.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onVerArtilharia,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_soccer_rounded,
                        color: Cores.verdePrincipal,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ARTILHARIA',
                        style: GoogleFonts.anybody(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Cores.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < top5.length; i++) ...[
                    LinhaArtilheiro(posicao: i + 1, artilheiro: top5[i]),
                    if (i < top5.length - 1)
                      const Divider(height: 12, color: Cores.surfaceVariant),
                  ],
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Toque para ver a classificação completa',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        color: Cores.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dados de ranking ─────────────────────────────────────────────────────────

class _GrupoRank {
  final int posicao;
  final String grupoNome;
  final String regra;

  const _GrupoRank({
    required this.posicao,
    required this.grupoNome,
    required this.regra,
  });
}

// ─── Ticker animado de posições ───────────────────────────────────────────────
//
// Técnica de marquee seamless: conteúdo duplicado dentro de SingleChildScrollView.
// Anima de 0 → (contentWidth + gap); ao chegar lá, jumpTo(0) é invisível porque
// copy2[0] = copy1[0] visualmente. Loop contínuo sem salto percebível.

class _TickerRanking extends StatefulWidget {
  const _TickerRanking({required this.items});
  final List<String> items;

  @override
  State<_TickerRanking> createState() => _TickerRankingState();
}

class _TickerRankingState extends State<_TickerRanking> {
  final _scroll = ScrollController();
  final _contentKey = GlobalKey();
  double _contentWidth = 0;

  static const double _gap = 64.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_setup);
  }

  void _setup(_) async {
    if (!mounted || !_scroll.hasClients) return;

    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (contentBox == null) return;

    final viewW = _scroll.position.viewportDimension;
    final naturalW = contentBox.size.width;
    if (naturalW <= viewW) return; // cabe — sem animação

    setState(() => _contentWidth = naturalW);
    await Future.delayed(Duration.zero); // aguarda rebuild com 2 cópias
    if (mounted) _loop();
  }

  Future<void> _loop() async {
    while (mounted && _scroll.hasClients && _contentWidth > 0) {
      try {
        final target = _contentWidth + _gap;
        await _scroll.animateTo(
          target,
          duration: Duration(
            milliseconds: (target * 25).clamp(3000, 15000).round(),
          ),
          curve: Curves.linear,
        );
        if (!mounted) break;
        _scroll.jumpTo(0);
      } catch (_) {
        break;
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _buildRow({Key? key}) => Row(
    key: key,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (int i = 0; i < widget.items.length; i++) ...[
        if (i > 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '|',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),
        Text(
          widget.items[i],
          style: GoogleFonts.anybody(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(key: _contentKey),
            if (_contentWidth > 0) ...[
              const SizedBox(width: _gap),
              _buildRow(),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Card de Jogo ─────────────────────────────────────────────────────────────

class _CardJogo extends StatelessWidget {
  const _CardJogo({required this.jogo});

  final Jogo jogo;

  @override
  Widget build(BuildContext context) {
    final horarioLocal = DateFormat('HH:mm').format(jogo.dataHora.toLocal());
    final agora = DateTime.now();
    final encerrado = jogo.placar1 != null;
    final aoVivo = !encerrado && jogo.dataHora.toLocal().isBefore(agora);

    return Container(
      width: 272,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cores.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Chip(
                texto: horarioLocal,
                corFundo:
                    aoVivo ? Cores.secondaryContainer : Cores.surfaceVariant,
                corTexto:
                    aoVivo
                        ? Cores.onSecondaryContainer
                        : Cores.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              if (aoVivo) const _ChipAoVivo(),
              if (encerrado) const _ChipEncerrado(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTime(jogo.team1),
              if (encerrado)
                Text(
                  '${jogo.placar1}  –  ${jogo.placar2}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Cores.onSurface,
                    letterSpacing: 2,
                  ),
                )
              else if (aoVivo)
                const Text(
                  '0  –  0',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Cores.onSurface,
                    letterSpacing: 2,
                  ),
                )
              else
                Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              _buildTime(jogo.team2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTime(String nome) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Cores.outlineVariant),
            color: Cores.surfaceVariant,
          ),
          child: Bandeira(nome, tamanho: 48),
        ),
        const SizedBox(height: 6),
        Text(
          nomePtDe(nome),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: Cores.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─── Chips ────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.corFundo,
    required this.corTexto,
  });

  final String texto;
  final Color corFundo;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: corTexto,
        ),
      ),
    );
  }
}

class _ChipAoVivo extends StatelessWidget {
  const _ChipAoVivo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Cores.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Cores.verdePrincipal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'AO VIVO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipEncerrado extends StatelessWidget {
  const _ChipEncerrado();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Cores.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Cores.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'ENCERRADO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de ação (Palpites / Ranking) ───────────────────────────────────────

class _CardAcao extends StatelessWidget {
  const _CardAcao({
    required this.titulo,
    required this.imagemAsset,
    required this.onTap,
  });

  final String titulo;
  final String imagemAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: AssetImage(imagemAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.anybody(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
