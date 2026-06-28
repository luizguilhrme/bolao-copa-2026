import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grupo.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../services/jogo_service.dart';
import '../utils/avatares.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

class TelaRanking extends StatefulWidget {
  const TelaRanking({super.key, this.sinalAtualizar});

  /// Disparado pelo MenuPrincipal quando a tela precisa ressincronizar
  /// (aba selecionada ou retorno de rota do drawer). Usuários e grupos já
  /// são reativos via streams; o sinal recarrega só o config (resultados
  /// reais usados nos desempates).
  final Sinal? sinalAtualizar;

  @override
  State<TelaRanking> createState() => _TelaRankingState();
}

class _TelaRankingState extends State<TelaRanking> {
  final _uidAtual = FirebaseAuth.instance.currentUser!.uid;

  // null = sem seleção explícita (usa o primeiro grupo disponível)
  Grupo? _grupoSelecionado;

  // Resultados reais para os critérios de desempate 3 e 4
  String? _campeaoReal;
  String? _chuteiradeOuroReal;

  // Estatísticas da última rodada (CF estatisticasRanking) do grupo efetivo.
  // Null enquanto carrega ou se a função falhar — a tela degrada graciosamente
  // (sem setas de movimento nem pontos da rodada).
  String? _statsGrupoId;
  Map<String, _StatRodada>? _stats;
  _InfoRodada? _rodada;

  // Não usa orderBy no Firestore porque documentos sem o campo seriam excluídos.
  // A ordenação completa (com desempates) é feita no build após filtrar por grupo.
  final Stream<List<Usuario>> _streamUsuarios = FirebaseFirestore.instance
      .collection('usuarios')
      .snapshots()
      .map((snap) => snap.docs.map((d) => Usuario.fromMap(d.data())).toList());

  // Stream estável (campo, não recriado no build): se fosse criado dentro do
  // build, cada setState faria o StreamBuilder reassinar e passar por
  // ConnectionState.waiting, piscando a tela e resetando o scroll dos chips.
  late final Stream<List<Grupo>> _streamGrupos =
      GrupoService().buscarGruposDoUsuario(_uidAtual);

  // Controlador próprio do carrossel de grupos: preserva a posição de scroll
  // dos chips entre rebuilds (troca de grupo, chegada das estatísticas etc.).
  final _scrollSeletor = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarConfig();
    widget.sinalAtualizar?.addListener(_aoSinal);
  }

  @override
  void dispose() {
    widget.sinalAtualizar?.removeListener(_aoSinal);
    _scrollSeletor.dispose();
    super.dispose();
  }

  void _aoSinal() {
    _carregarConfig();
    final grupoId = _statsGrupoId;
    if (grupoId != null) _carregarStats(grupoId);
  }

  Future<void> _carregarConfig() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('config')
            .doc('copa2026')
            .get();
    if (!mounted) return;
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _campeaoReal = data['campeaoReal'] as String?;
      _chuteiradeOuroReal = data['chuteiradeOuroReal'] as String?;
    });
  }

  Future<void> _carregarStats(String grupoId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('estatisticasRanking');
      final result = await callable.call({'grupoId': grupoId});
      // Descarta resposta se o usuário já trocou de grupo enquanto carregava
      if (!mounted || _statsGrupoId != grupoId) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final rawStats = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
      final stats = <String, _StatRodada>{};
      rawStats.forEach((uid, raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        stats[uid] = _StatRodada(
          pontosRodada: (m['pontosRodada'] as num).toInt(),
          movimento: (m['movimento'] as num).toInt(),
        );
      });
      _InfoRodada? rodada;
      if (data['rodada'] != null) {
        final r = Map<String, dynamic>.from(data['rodada'] as Map);
        rodada = _InfoRodada(
          numero: (r['numero'] as num).toInt(),
          label: r['label'] as String?,
        );
      }
      setState(() {
        _stats = stats;
        _rodada = rodada;
      });
    } catch (_) {
      // Sem estatísticas a tela funciona normalmente, só sem os extras
    }
  }

  // Critério oficial (pontos + desempates) extraído para biblioteca.dart —
  // compartilhado com a posição exibida na arte de compartilhamento.
  List<Usuario> _ordenar(List<Usuario> lista, bool modoCopa) => ordenarRanking(
    lista,
    modoCopa: modoCopa,
    campeaoReal: _campeaoReal,
    chuteiradeOuroReal: _chuteiradeOuroReal,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Grupo>>(
      stream: _streamGrupos,
      builder: (context, snapGrupos) {
        // Spinner só na primeira carga — com dados anteriores em mãos,
        // rebuilds não devem piscar a tela
        if (snapGrupos.connectionState == ConnectionState.waiting &&
            !snapGrupos.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final grupos = snapGrupos.data ?? [];

        // Sem grupos: orienta o usuário a criar ou entrar em um
        if (grupos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: Cores.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Você não está em nenhum grupo.',
                    style: GoogleFonts.anybody(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Cores.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acesse Meus Grupos no menu para criar ou entrar em um grupo.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      color: Cores.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Se o grupo selecionado foi removido da lista (ex: usuário saiu),
        // volta para o primeiro grupo disponível.
        final grupoEfetivo =
            (_grupoSelecionado != null &&
                    grupos.any((g) => g.id == _grupoSelecionado!.id))
                ? _grupoSelecionado!
                : grupos.first;

        final bool modoCopa = grupoEfetivo.regra == 'copa';

        // Carrega as estatísticas da rodada quando o grupo efetivo muda
        // (primeira carga ou troca pelo seletor). Não zera _rodada — o número
        // da rodada é da competição (igual para todos os grupos), então mantê-lo
        // evita o texto "Rodada N" piscar a cada troca; só _stats (movimento e
        // pontos por jogador) é específico do grupo.
        if (_statsGrupoId != grupoEfetivo.id) {
          _statsGrupoId = grupoEfetivo.id;
          _stats = null;
          Future.microtask(() => _carregarStats(grupoEfetivo.id));
        }

        return StreamBuilder<List<Usuario>>(
          stream: _streamUsuarios,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Erro ao carregar ranking.',
                  style: GoogleFonts.hankenGrotesk(
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              );
            }

            final todosUsuarios = snapshot.data ?? [];
            final usuarios = _ordenar(
              todosUsuarios
                  .where((u) => grupoEfetivo.membros.contains(u.uid))
                  .toList(),
              modoCopa,
            );

            if (snapshot.connectionState == ConnectionState.waiting &&
                usuarios.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Sem membros no grupo ainda
            if (usuarios.isEmpty) {
              return Column(
                children: [
                  if (grupos.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _SeletorGrupo(
                        controller: _scrollSeletor,
                        grupos: grupos,
                        selecionado: grupoEfetivo,
                        onSelecionar:
                            (g) => setState(() => _grupoSelecionado = g),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.leaderboard_outlined,
                            size: 64,
                            color: Cores.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum membro neste grupo ainda.',
                            style: GoogleFonts.anybody(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Cores.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Posição do usuário logado para a barra fixa do rodapé
            final indiceEu = usuarios.indexWhere((u) => u.uid == _uidAtual);
            final usuarioEu = indiceEu >= 0 ? usuarios[indiceEu] : null;

            // Top 3 em cards de medalha; do 4º em diante na lista
            final medalhas = usuarios.take(3).toList();
            final demais =
                usuarios.length > 3 ? usuarios.sublist(3) : <Usuario>[];

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // Seletor de grupo (só aparece com 2 ou mais grupos)
                    if (grupos.length > 1)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _SeletorGrupo(
                            controller: _scrollSeletor,
                            grupos: grupos,
                            selecionado: grupoEfetivo,
                            onSelecionar:
                                (g) => setState(() => _grupoSelecionado = g),
                          ),
                        ),
                      ),

                    // Contexto: dia da competição + rodada real + nº de jogadores
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      sliver: SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _rodada != null
                                ? 'Dia ${_rodada!.numero}'
                                    '${_rodada!.label != null ? ' · ${_rodada!.label}' : ''}'
                                    ' · ${usuarios.length} jogadores'
                                : '${usuarios.length} jogadores',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Cores.cinzaTexto,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top 3 — cards de medalha
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CardMedalha(
                              posicao: i + 1,
                              usuario: medalhas[i],
                              stat: _stats?[medalhas[i].uid],
                              modoCopa: modoCopa,
                            ),
                          ),
                          childCount: medalhas.length,
                        ),
                      ),
                    ),

                    // Demais colocados (4º em diante)
                    if (demais.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        sliver: SliverToBoxAdapter(
                          child: _RotuloSecao('DEMAIS COLOCADOS'),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ItemRanking(
                                posicao: i + 4,
                                usuario: demais[i],
                                stat: _stats?[demais[i].uid],
                                modoCopa: modoCopa,
                              ),
                            ),
                            childCount: demais.length,
                          ),
                        ),
                      ),
                    ],

                    // Espaço para a barra fixa "Você" não cobrir o fim da lista
                    SliverToBoxAdapter(
                      child: SizedBox(height: usuarioEu != null ? 104 : 24),
                    ),
                  ],
                ),

                // Fade do fundo + barra fixa do usuário logado
                if (usuarioEu != null) ...[
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _FadeRodape(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BarraVoce(
                      posicao: indiceEu + 1,
                      usuario: usuarioEu,
                      stat: _stats?[usuarioEu.uid],
                      modoCopa: modoCopa,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Seletor de grupo (chips) ─────────────────────────────────────────────────

class _SeletorGrupo extends StatelessWidget {
  const _SeletorGrupo({
    required this.controller,
    required this.grupos,
    required this.selecionado,
    required this.onSelecionar,
  });

  final ScrollController controller;
  final List<Grupo> grupos;
  final Grupo selecionado;
  final ValueChanged<Grupo> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            grupos
                .map(
                  (g) => Padding(
                    padding: EdgeInsets.only(left: g == grupos.first ? 0 : 8),
                    child: _Chip(
                      label: g.nome,
                      selecionado: selecionado.id == g.id,
                      onTap: () => onSelecionar(g),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado ? Cores.verdePrincipal : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.anybody(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selecionado ? Colors.white : Cores.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Modelos das estatísticas da rodada (CF estatisticasRanking) ─────────────

class _StatRodada {
  const _StatRodada({required this.pontosRodada, required this.movimento});

  /// Pontos ganhos na última rodada (último dia com jogo encerrado).
  final int pontosRodada;

  /// Posições ganhas (+) ou perdidas (−) em relação a antes da rodada.
  final int movimento;
}

class _InfoRodada {
  const _InfoRodada({required this.numero, this.label});

  /// Dia da competição = dias distintos com jogo encerrado até agora.
  final int numero;

  /// Rodada real (ex.: "1ª Rodada" na fase de grupos, ou o nome da fase nas
  /// eliminatórias). Pode ser null se a CF não conseguiu determinar.
  final String? label;
}

// ─── Card de medalha (top 3) ──────────────────────────────────────────────────

class _CardMedalha extends StatelessWidget {
  const _CardMedalha({
    required this.posicao,
    required this.usuario,
    required this.stat,
    required this.modoCopa,
  });

  final int posicao;
  final Usuario usuario;
  final _StatRodada? stat;
  final bool modoCopa;

  Color get _cor => switch (posicao) {
    1 => Cores.ouro,
    2 => Cores.prataMedalha,
    _ => Cores.bronze,
  };

  Color get _fundo => switch (posicao) {
    1 => Cores.ouroSuave,
    2 => Cores.prataSuave,
    _ => Cores.bronzeSuave,
  };

  Color get _borda => switch (posicao) {
    1 => Cores.ouroBorda,
    2 => Cores.prataBorda,
    _ => Cores.bronzeBorda,
  };

  @override
  Widget build(BuildContext context) {
    final lider = posicao == 1;
    final pontos =
        modoCopa ? usuario.pontuacaoCopaTotal : usuario.pontuacaoClassicaTotal;

    return GestureDetector(
      onTap: () => _mostrarPalpitesUsuario(context, usuario, modoCopa),
      child: Container(
        decoration: BoxDecoration(
          color: _fundo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borda, width: 1.5),
          boxShadow: [
            if (lider)
              BoxShadow(
                color: Cores.ouro.withValues(alpha: 0.2),
                blurRadius: 22,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: lider ? 14 : 11,
        ),
        child: Row(
          children: [
            // Selo com o número da posição
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cor,
                boxShadow: [
                  BoxShadow(
                    color: _cor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$posicao',
                  style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),

            // Avatar (coroa sobre a foto do líder)
            Stack(
              clipBehavior: Clip.none,
              children: [
                WidgetAvatar(
                  avatarId: usuario.avatar,
                  nome: usuario.nome,
                  tamanho: lider ? 50 : 44,
                  corFundo: _fundo,
                  corTexto: _cor,
                  borderColor: _cor,
                  borderWidth: lider ? 3 : 2,
                ),
                if (lider)
                  const Positioned(
                    top: -14,
                    left: 0,
                    right: 0,
                    child: Center(child: _Coroa(largura: 28)),
                  ),
              ],
            ),
            const SizedBox(width: 11),

            // Nome + movimento + linha de stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lider)
                    Text(
                      'LÍDER',
                      style: GoogleFonts.anybody(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Cores.ouroEscuro,
                      ),
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          usuario.nome,
                          style: GoogleFonts.anybody(
                            fontSize: lider ? 17 : 16,
                            fontWeight: FontWeight.w800,
                            color: Cores.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _Movimento(stat?.movimento),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _LinhaStats(
                    cravadas: usuario.placaresExatos,
                    pontosRodada: stat?.pontosRodada,
                    cor: Cores.onSurfaceVariant,
                    corIcone: _cor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Pontuação total
            Text(
              formatarPontos(pontos),
              style: GoogleFonts.anybody(
                fontSize: lider ? 23 : 21,
                fontWeight: FontWeight.w800,
                color: Cores.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Coroa dourada sobre o avatar do líder
class _Coroa extends StatelessWidget {
  const _Coroa({required this.largura});

  final double largura;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(largura, largura * 0.78),
      painter: _CoroaPainter(),
    );
  }
}

class _CoroaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Desenhada num viewBox 26×20 e escalada
    final sx = size.width / 26;
    final sy = size.height / 20;

    final corpo =
        Path()
          ..moveTo(2 * sx, 17.5 * sy)
          ..lineTo(24 * sx, 17.5 * sy)
          ..lineTo(22.4 * sx, 5.5 * sy)
          ..lineTo(17.4 * sx, 10.1 * sy)
          ..lineTo(13 * sx, 2 * sy)
          ..lineTo(8.6 * sx, 10.1 * sy)
          ..lineTo(3.6 * sx, 5.5 * sy)
          ..close();

    canvas.drawPath(corpo, Paint()..color = Cores.ouro);
    canvas.drawPath(
      corpo,
      Paint()
        ..color = Cores.ouroEscuro
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx
        ..strokeJoin = StrokeJoin.round,
    );

    final centroJoia = Offset(13 * sx, 2 * sy);
    canvas.drawCircle(
      centroJoia,
      1.7 * sx,
      Paint()..color = Cores.secondaryContainer,
    );
    canvas.drawCircle(
      centroJoia,
      1.7 * sx,
      Paint()
        ..color = Cores.ouroEscuro
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * sx,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Item da lista (4º em diante) ─────────────────────────────────────────────

class _ItemRanking extends StatelessWidget {
  const _ItemRanking({
    required this.posicao,
    required this.usuario,
    required this.stat,
    required this.modoCopa,
  });

  final int posicao;
  final Usuario usuario;
  final _StatRodada? stat;
  final bool modoCopa;

  @override
  Widget build(BuildContext context) {
    final pontos =
        modoCopa ? usuario.pontuacaoCopaTotal : usuario.pontuacaoClassicaTotal;

    return GestureDetector(
      onTap: () => _mostrarPalpitesUsuario(context, usuario, modoCopa),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$posicao',
                style: GoogleFonts.anybody(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Cores.cinzaTexto,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 11),
            WidgetAvatar(
              avatarId: usuario.avatar,
              nome: usuario.nome,
              tamanho: 42,
              corFundo: Cores.surfaceContainerHigh,
              corTexto: Cores.onSurface,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          usuario.nome,
                          style: GoogleFonts.anybody(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Cores.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _Movimento(stat?.movimento),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _LinhaStats(
                    cravadas: usuario.placaresExatos,
                    pontosRodada: stat?.pontosRodada,
                    cor: Cores.cinzaTexto,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatarPontos(pontos),
              style: GoogleFonts.anybody(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Cores.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barra fixa "Você" (azul, rodapé) ─────────────────────────────────────────

class _BarraVoce extends StatelessWidget {
  const _BarraVoce({
    required this.posicao,
    required this.usuario,
    required this.stat,
    required this.modoCopa,
  });

  final int posicao;
  final Usuario usuario;
  final _StatRodada? stat;
  final bool modoCopa;

  @override
  Widget build(BuildContext context) {
    final pontos =
        modoCopa ? usuario.pontuacaoCopaTotal : usuario.pontuacaoClassicaTotal;
    final s = stat;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GestureDetector(
        onTap: () => _mostrarPalpitesUsuario(context, usuario, modoCopa),
        child: Container(
          decoration: BoxDecoration(
            color: Cores.azulTerciario,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Cores.azulAgendado.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '$posicaoº',
                  style: GoogleFonts.anybody(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              WidgetAvatar(
                avatarId: usuario.avatar,
                nome: usuario.nome,
                tamanho: 42,
                corFundo: Colors.white24,
                corTexto: Colors.white,
                borderColor: Colors.white60,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Você',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Movimento(s?.movimento, claro: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        text:
                            '${usuario.placaresExatos} '
                            '${usuario.placaresExatos == 1 ? 'cravada' : 'cravadas'}',
                        children: [
                          if (s != null) ...[
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text:
                                  s.pontosRodada >= 0
                                      ? '+${s.pontosRodada}'
                                      : '${s.pontosRodada}',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const TextSpan(text: ' nesta rodada'),
                          ],
                        ],
                      ),
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatarPontos(pontos),
                    style: GoogleFonts.anybody(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PTS',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Esmaecimento do fundo atrás da barra "Você"
class _FadeRodape extends StatelessWidget {
  const _FadeRodape();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Cores.background.withValues(alpha: 0), Cores.background],
          ),
        ),
      ),
    );
  }
}

// ─── Átomos: rótulo de seção, movimento, linha de stats ───────────────────────

class _RotuloSecao extends StatelessWidget {
  const _RotuloSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          texto,
          style: GoogleFonts.anybody(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Cores.cinzaTexto,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Cores.outlineVariant)),
      ],
    );
  }
}

// Seta de movimento desde a última rodada (▲ n / ▼ n / traço quando 0).
// Sem estatísticas carregadas (null) não ocupa espaço.
class _Movimento extends StatelessWidget {
  const _Movimento(this.n, {this.claro = false});

  final int? n;
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final v = n;
    if (v == null) return const SizedBox.shrink();
    if (v == 0) {
      return Container(
        width: 8,
        height: 2.2,
        decoration: BoxDecoration(
          color: claro ? Colors.white70 : Cores.cinzaTexto,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final sobe = v > 0;
    final cor =
        claro
            ? Colors.white
            : (sobe ? Cores.pontVencedorSaldo : Cores.pontNegativo);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sobe ? '▲' : '▼',
          style: TextStyle(fontSize: 9, color: cor, height: 1.2),
        ),
        const SizedBox(width: 1),
        Text(
          '${v.abs()}',
          style: GoogleFonts.anybody(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: cor,
          ),
        ),
      ],
    );
  }
}

// Linha "N cravadas · X rodada" — pontos da rodada só com stats carregadas
class _LinhaStats extends StatelessWidget {
  const _LinhaStats({
    required this.cravadas,
    required this.pontosRodada,
    required this.cor,
    this.corIcone,
  });

  final int cravadas;
  final int? pontosRodada;
  final Color cor;
  final Color? corIcone;

  @override
  Widget build(BuildContext context) {
    final estilo = GoogleFonts.hankenGrotesk(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: cor,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Alvo(tamanho: 11, cor: corIcone ?? cor),
        const SizedBox(width: 4),
        Text(
          '$cravadas ${cravadas == 1 ? 'cravada' : 'cravadas'}',
          style: estilo,
        ),
        if (pontosRodada != null) ...[
          const SizedBox(width: 7),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$pontosRodada',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cor,
            ),
          ),
          Text(' rodada', style: estilo),
        ],
      ],
    );
  }
}

// Ícone de cravada (alvo concêntrico)
class _Alvo extends StatelessWidget {
  const _Alvo({required this.tamanho, required this.cor});

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(tamanho), painter: _AlvoPainter(cor));
  }
}

class _AlvoPainter extends CustomPainter {
  const _AlvoPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final escala = size.width / 14;
    canvas.drawCircle(
      centro,
      6 * escala,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * escala,
    );
    canvas.drawCircle(centro, 2.3 * escala, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _AlvoPainter oldDelegate) =>
      oldDelegate.cor != cor;
}

// ─── Diálogo: palpites de um usuário ─────────────────────────────────────────

Future<void> _mostrarPalpitesUsuario(
  BuildContext context,
  Usuario usuario,
  bool modoCopa,
) {
  return showDialog(
    context: context,
    builder:
        (_) => _DialogPalpitesUsuario(usuario: usuario, modoCopa: modoCopa),
  );
}

class _DadosDialog {
  const _DadosDialog({
    required this.jogos,
    required this.palpites,
    required this.palpitesCopa,
    required this.classificacaoReal,
    required this.palpitesTravados,
    required this.especiaisCalculados,
    this.campeaoReal,
    this.chuteiradeOuroReal,
    this.boladeOuroReal,
    this.luvadeOuroReal,
    this.melhorJovemReal,
  });

  final List<Jogo> jogos;
  final List<Palpite> palpites;
  final Map<String, Map<String, String?>> palpitesCopa;
  final Map<String, dynamic> classificacaoReal;
  final bool palpitesTravados;
  final bool especiaisCalculados;
  final String? campeaoReal;
  final String? chuteiradeOuroReal;
  final String? boladeOuroReal;
  final String? luvadeOuroReal;
  final String? melhorJovemReal;

  // O filtro MATA-MATA aparece quando algum jogo eliminatório já travou os
  // palpites (5 min antes do início) ou tem resultado.
  bool get temMataMata => jogos.any(
        (j) =>
            j.id > 72 &&
            (j.placar1 != null ||
                DateTime.now().isAfter(
                  j.dataHora.toLocal().subtract(const Duration(minutes: 5)),
                )),
      );
}

class _ItemPalpiteClassico {
  const _ItemPalpiteClassico({
    required this.jogo,
    this.palpite,
    this.pontos,
    this.semPalpite = false,
  });
  final Jogo jogo;
  final Palpite? palpite;

  /// Null enquanto o jogo não tem placar final (palpites visíveis a partir
  /// do travamento, pontos só depois do resultado).
  final int? pontos;
  final bool semPalpite;
}

class _ItemEspecial {
  const _ItemEspecial(
    this.icone,
    this.label,
    this.valor, {
    this.isTime = false,
    this.acertou,
  });
  final IconData icone;
  final String label;
  final String valor;
  final bool isTime;
  final bool? acertou;
}

class _DialogPalpitesUsuario extends StatefulWidget {
  const _DialogPalpitesUsuario({required this.usuario, required this.modoCopa});
  final Usuario usuario;
  final bool modoCopa;

  @override
  State<_DialogPalpitesUsuario> createState() => _DialogPalpitesUsuarioState();
}

class _DialogPalpitesUsuarioState extends State<_DialogPalpitesUsuario> {
  late final Future<_DadosDialog> _future;
  String _filtroGrupo = 'A';

  static const _grupos = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
  ];

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_DadosDialog> _carregar() async {
    final uid = widget.usuario.uid;

    // buscarPalpitesUsuario verifica que o solicitante compartilha um grupo
    // com o alvo antes de retornar os dados — sem leitura direta do Firestore.
    final callable = FirebaseFunctions.instanceFor(
      region: 'southamerica-east1',
    ).httpsCallable('buscarPalpitesUsuario');

    final results = await Future.wait([
      callable.call({'targetUid': uid}),
      JogoService().buscarTodos(),
      FirebaseFirestore.instance.collection('config').doc('copa2026').get(),
    ]);

    final funcResult = results[0] as HttpsCallableResult<dynamic>;
    final funcData = Map<String, dynamic>.from(funcResult.data as Map);

    final palpites =
        (funcData['palpites'] as List).map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          return Palpite(
            uid: uid,
            jogoId: (m['jogoId'] as num).toInt(),
            palpite1: (m['palpite1'] as num).toInt(),
            palpite2: (m['palpite2'] as num).toInt(),
          );
        }).toList();

    final rawCopa = funcData['palpitesCopa'] as Map? ?? {};
    final palpitesCopa = <String, Map<String, String?>>{};
    rawCopa.forEach((grupoKey, posicoes) {
      final m = Map<String, dynamic>.from(posicoes as Map);
      palpitesCopa[grupoKey as String] = {
        'primeiro': m['primeiro'] as String?,
        'segundo': m['segundo'] as String?,
        'terceiro': m['terceiro'] as String?,
      };
    });

    final jogos = results[1] as List<Jogo>;
    final configSnap = results[2] as DocumentSnapshot;

    Map<String, dynamic> classificacaoReal = {};
    bool palpitesTravados = false;
    bool especiaisCalculados = false;
    String? campeaoReal,
        chuteiradeOuroReal,
        boladeOuroReal,
        luvadeOuroReal,
        melhorJovemReal;
    if (configSnap.exists) {
      final data = configSnap.data() as Map<String, dynamic>?;
      classificacaoReal =
          (data?['classificacao_real'] as Map<String, dynamic>?) ?? {};
      palpitesTravados = (data?['palpitesTravados'] as bool?) ?? false;
      especiaisCalculados =
          (data?['palpitesEspeciaisCalculados'] as bool?) ?? false;
      if (especiaisCalculados) {
        campeaoReal = data?['campeaoReal'] as String?;
        chuteiradeOuroReal = data?['chuteiradeOuroReal'] as String?;
        boladeOuroReal = data?['boladeOuroReal'] as String?;
        luvadeOuroReal = data?['luvadeOuroReal'] as String?;
        melhorJovemReal = data?['melhorJovemReal'] as String?;
      }
    }

    return _DadosDialog(
      jogos: jogos,
      palpites: palpites,
      palpitesCopa: palpitesCopa,
      classificacaoReal: classificacaoReal,
      palpitesTravados: palpitesTravados,
      especiaisCalculados: especiaisCalculados,
      campeaoReal: campeaoReal,
      chuteiradeOuroReal: chuteiradeOuroReal,
      boladeOuroReal: boladeOuroReal,
      luvadeOuroReal: luvadeOuroReal,
      melhorJovemReal: melhorJovemReal,
    );
  }

  bool? _acertou(String? palpite, String? real) {
    if (palpite == null || real == null) return null;
    return palpite.toLowerCase().trim() == real.toLowerCase().trim();
  }

  List<_ItemEspecial> _especiais(_DadosDialog dados) {
    if (!dados.palpitesTravados) return [];
    final u = widget.usuario;
    final calc = dados.especiaisCalculados;
    return [
      if (u.palpiteCampeao != null)
        _ItemEspecial(
          Icons.emoji_events,
          'Campeão do Mundo',
          u.palpiteCampeao!,
          isTime: true,
          acertou: calc ? _acertou(u.palpiteCampeao, dados.campeaoReal) : null,
        ),
      if (u.palpiteChuteiradeOuro != null)
        _ItemEspecial(
          Icons.sports_soccer,
          'Chuteira de Ouro',
          u.palpiteChuteiradeOuro!,
          acertou:
              calc
                  ? _acertou(u.palpiteChuteiradeOuro, dados.chuteiradeOuroReal)
                  : null,
        ),
      if (u.palpiteBoladeOuro != null)
        _ItemEspecial(
          Icons.star_rounded,
          'Bola de Ouro',
          u.palpiteBoladeOuro!,
          acertou:
              calc ? _acertou(u.palpiteBoladeOuro, dados.boladeOuroReal) : null,
        ),
      if (u.palpiteLuvadeOuro != null)
        _ItemEspecial(
          Icons.sports_handball,
          'Luva de Ouro',
          u.palpiteLuvadeOuro!,
          acertou:
              calc ? _acertou(u.palpiteLuvadeOuro, dados.luvadeOuroReal) : null,
        ),
      if (u.palpiteMelhorJovem != null)
        _ItemEspecial(
          Icons.person_rounded,
          'Melhor Jogador Jovem',
          u.palpiteMelhorJovem!,
          acertou:
              calc
                  ? _acertou(u.palpiteMelhorJovem, dados.melhorJovemReal)
                  : null,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final corAcento =
        widget.modoCopa ? Cores.azulTerciario : Cores.verdePrincipal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: FutureBuilder<_DadosDialog>(
          future: _future,
          builder: (ctx, snap) {
            final dados = snap.data;
            final especiais =
                dados != null ? _especiais(dados) : <_ItemEspecial>[];
            return Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // ── Cabeçalho ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  color: corAcento,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WidgetAvatar(
                            avatarId: widget.usuario.avatar,
                            nome: widget.usuario.nome,
                            tamanho: 44,
                            corFundo: Colors.white24,
                            corTexto: Colors.white,
                            borderColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.usuario.nome,
                              style: GoogleFonts.anybody(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (especiais.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < especiais.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    color: Colors.white24,
                                    height: 14,
                                  ),
                                _buildLinhaEspecial(especiais[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Filtro de grupos ───────────────────────────────────
                if (dados != null) _buildFiltro(dados, corAcento),

                // ── Conteúdo ───────────────────────────────────────────
                Expanded(
                  child:
                      snap.connectionState == ConnectionState.waiting
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: Cores.verdePrincipal,
                              ),
                            ),
                          )
                          : snap.hasError
                          ? Center(
                            child: Text(
                              'Erro ao carregar.',
                              style: GoogleFonts.hankenGrotesk(
                                color: Cores.onSurfaceVariant,
                              ),
                            ),
                          )
                          : _buildConteudo(dados!),
                ),

                // ── Botão fechar ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: corAcento,
                        side: BorderSide(color: corAcento),
                      ),
                      child: Text(
                        'FECHAR',
                        style: GoogleFonts.anybody(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLinhaEspecial(_ItemEspecial e) {
    return Row(
      children: [
        Icon(e.icone, size: 15, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          e.label,
          style: GoogleFonts.hankenGrotesk(fontSize: 12, color: Colors.white70),
        ),
        const Spacer(),
        if (e.isTime) ...[
          Container(
            width: 20,
            height: 20,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Bandeira(e.valor, tamanho: 20),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          e.isTime ? nomePtDe(e.valor) : e.valor,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (e.acertou != null) ...[
          const SizedBox(width: 6),
          Icon(
            e.acertou! ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color:
                e.acertou! ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
          ),
        ],
      ],
    );
  }

  Widget _buildFiltro(_DadosDialog dados, Color corAcento) {
    final filtros = [..._grupos, if (dados.temMataMata) 'MATA-MATA'];
    return Container(
      color: Cores.surfaceContainer,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int i = 0; i < filtros.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _buildChipFiltro(filtros[i], corAcento),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChipFiltro(String label, Color corAcento) {
    final sel = _filtroGrupo == label;
    return GestureDetector(
      onTap: () => setState(() => _filtroGrupo = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? corAcento : Cores.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? corAcento : Cores.outlineVariant),
        ),
        child: Text(
          label,
          style: GoogleFonts.anybody(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : Cores.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo(_DadosDialog dados) {
    if (_filtroGrupo == 'MATA-MATA') {
      return _buildListaClassico(dados, mataMata: true);
    }
    if (widget.modoCopa) {
      if (!dados.palpitesTravados) return _buildPalpitesOcultos();
      return _buildGrupoCopa(dados);
    }
    return _buildListaClassico(dados, mataMata: false);
  }

  Widget _buildPalpitesOcultos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 40, color: Cores.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Palpites ocultos até o travamento pelo admin',
              style: GoogleFonts.anybody(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Cores.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista de palpites clássicos (fase de grupos ou mata-mata) ──────────

  Widget _buildListaClassico(_DadosDialog dados, {required bool mataMata}) {
    final palpitesMap = {for (final p in dados.palpites) p.jogoId: p};
    final criadoEm = widget.usuario.criadoEm;

    // Palpites visíveis a partir do travamento (5 min antes do início),
    // mesmo sem resultado — ninguém mais pode alterar o palpite.
    final agora = DateTime.now();
    final jogosRelevantes =
        dados.jogos.where((j) {
            final travado = agora.isAfter(
              j.dataHora.toLocal().subtract(const Duration(minutes: 5)),
            );
            if (!travado) return false;
            return mataMata
                ? j.id > 72
                : j.id <= 72 && j.group == 'Grupo $_filtroGrupo';
          }).toList()
          ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    if (jogosRelevantes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nenhum palpite liberado ainda.',
            style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
          ),
        ),
      );
    }

    final itens =
        jogosRelevantes.map((j) {
          final p = palpitesMap[j.id];
          final temPlacar = j.placar1 != null;
          if (p != null) {
            return _ItemPalpiteClassico(
              jogo: j,
              palpite: p,
              // Pontos só depois do resultado
              pontos:
                  temPlacar
                      ? calcularPontosComFase(
                        p.palpite1,
                        p.palpite2,
                        j.placar1!,
                        j.placar2!,
                        j.round,
                      )
                      : null,
            );
          }
          final deveMultar = j.dataHora.isAfter(criadoEm);
          return _ItemPalpiteClassico(
            jogo: j,
            pontos: temPlacar ? (deveMultar ? -10 : 0) : null,
            semPalpite: true,
          );
        }).toList();

    return ListView.separated(
      itemCount: itens.length,
      separatorBuilder:
          (_, __) => const Divider(height: 1, color: Cores.outlineVariant),
      itemBuilder: (_, i) => _buildLinhaClassico(itens[i]),
    );
  }

  Widget _buildLinhaClassico(_ItemPalpiteClassico item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Bandeira(item.jogo.team1, tamanho: 20),
          const SizedBox(width: 5),
          Text(
            siglaDe(item.jogo.team1),
            style: GoogleFonts.anybody(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Cores.onSurface,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              // Sem placar final ainda (jogo travado/em andamento): ×
              item.jogo.placar1 != null
                  ? '${item.jogo.placar1}–${item.jogo.placar2}'
                  : '×',
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color:
                    item.jogo.placar1 != null
                        ? Cores.verdePrincipal
                        : Cores.outline,
              ),
            ),
          ),
          Text(
            siglaDe(item.jogo.team2),
            style: GoogleFonts.anybody(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Cores.onSurface,
            ),
          ),
          const SizedBox(width: 5),
          Bandeira(item.jogo.team2, tamanho: 20),
          const Spacer(),
          if (item.semPalpite)
            Text(
              'Não palpitado',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Cores.onSurfaceVariant,
              ),
            )
          else
            Text(
              '${item.palpite!.palpite1}–${item.palpite!.palpite2}',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Cores.onSurfaceVariant,
              ),
            ),
          // Badge de pontos — só depois do placar final
          if (item.pontos != null) ...[
            const SizedBox(width: 8),
            _BadgePontos(item.pontos!),
          ],
        ],
      ),
    );
  }

  // ── Palpite Copa: classificação de grupo ──────────────────────────────

  Widget _buildGrupoCopa(_DadosDialog dados) {
    final grupoPalpite = dados.palpitesCopa[_filtroGrupo];
    final grupoReal =
        dados.classificacaoReal[_filtroGrupo] as Map<String, dynamic>?;

    if (grupoPalpite == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sem palpite para o Grupo $_filtroGrupo.',
            style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
          ),
        ),
      );
    }

    final primeiroReal = grupoReal?['primeiro'] as String?;
    final segundoReal = grupoReal?['segundo'] as String?;
    final terceiroReal = grupoReal?['terceiro'] as String?;
    final temReal = primeiroReal != null && segundoReal != null;
    final aguardandoResultado = !temReal;

    final qualificados = <String>{
      if (primeiroReal != null) primeiroReal,
      if (segundoReal != null) segundoReal,
      if (terceiroReal != null) terceiroReal,
    };

    final palpitadoPrimeiro = grupoPalpite['primeiro'];
    final palpitadoSegundo = grupoPalpite['segundo'];
    final palpitadoTerceiro = grupoPalpite['terceiro'];

    int? calcPts(String? palpitado, String? real) {
      if (!temReal || palpitado == null) return null;
      if (palpitado == real) return 200;
      if (qualificados.contains(palpitado)) return 100;
      return 0;
    }

    final posicoes = [
      (
        '1º',
        palpitadoPrimeiro,
        primeiroReal,
        calcPts(palpitadoPrimeiro, primeiroReal),
      ),
      (
        '2º',
        palpitadoSegundo,
        segundoReal,
        calcPts(palpitadoSegundo, segundoReal),
      ),
      if (palpitadoTerceiro != null || terceiroReal != null)
        (
          '3º',
          palpitadoTerceiro,
          terceiroReal,
          calcPts(palpitadoTerceiro, terceiroReal),
        ),
    ];

    // Bônus "grupo perfeito": palpite idêntico à classificação real em TODAS as
    // posições. Num grupo de só 2 classificados (terceiroReal == null), palpitar
    // um 3º que não classificou quebra o bônus (palpitadoTerceiro deve ser null).
    int? bonus;
    if (temReal) {
      final todasExatas =
          palpitadoPrimeiro == primeiroReal &&
          palpitadoSegundo == segundoReal &&
          palpitadoTerceiro == terceiroReal;
      bonus = todasExatas ? 100 : 0;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (pos, palpitado, real, pts) in posicoes)
          _buildLinhaCopa(pos, palpitado, real, pts),
        if (bonus != null && bonus > 0) ...[
          const Divider(height: 1, color: Cores.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color: Cores.azulTerciario,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bônus — grupo perfeito',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurface,
                  ),
                ),
                const Spacer(),
                _BadgePontos(100),
              ],
            ),
          ),
        ],
        if (aguardandoResultado) ...[
          const Divider(height: 1, color: Cores.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: Cores.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Resultado do grupo ainda não divulgado',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLinhaCopa(
    String posicao,
    String? palpitado,
    String? real,
    int? pontos,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              posicao,
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Cores.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (palpitado != null) ...[
            Container(
              width: 22,
              height: 22,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Bandeira(palpitado, tamanho: 22),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                nomePtDe(palpitado),
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            Expanded(
              child: Text(
                '—',
                style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
              ),
            ),
          // Resultado real (só quando diferente do palpitado)
          if (real != null && real != palpitado) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: Cores.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Bandeira(real, tamanho: 22),
            ),
            const SizedBox(width: 4),
            Text(
              siglaDe(real),
              style: GoogleFonts.anybody(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Cores.onSurfaceVariant,
              ),
            ),
          ] else if (real != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Cores.verdePrincipal,
              ),
            ),
          if (pontos != null) ...[
            const SizedBox(width: 8),
            _BadgePontos(pontos),
          ],
        ],
      ),
    );
  }
}

// ─── Badge de pontuação ───────────────────────────────────────────────────────

class _BadgePontos extends StatelessWidget {
  const _BadgePontos(this.pontos);
  final int pontos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: corPontuacao(pontos),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$pontos pts',
        style: GoogleFonts.anybody(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
