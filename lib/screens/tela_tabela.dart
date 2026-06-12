import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../models/usuario.dart';
import '../services/api_dados_service.dart';
import '../services/jogo_service.dart';
import '../utils/artilharia.dart';
import '../utils/avatares.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import '../utils/dialogos.dart';

// Cards brancos com sombra suave sobre Cores.background.
const _sombraCard = [
  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
];

// Ordem canônica das rodadas/fases para o filtro "Por rodada".
const _ordemRodadas = [
  'Rodada 1',
  'Rodada 2',
  'Rodada 3',
  '16 avos de Final',
  'Oitavas de Final',
  'Quartas de Final',
  'Semifinal',
  'Disputa de 3º Lugar',
  'Final',
];

// =============================================================================
// TelaTabela
//
// Mostra os 104 jogos da Copa 2026 organizados em seções por fase/rodada.
// Tem dois modos: "Próximos" (sem placar) e "Resultados" (com placar).
//
// Conceitos novos introduzidos aqui:
//   - CustomScrollView + Slivers: permite misturar cabeçalhos e listas de
//     forma eficiente, sem precisar de um ListView "gigante" com ifs no meio.
// =============================================================================

class TelaTabela extends StatefulWidget {
  const TelaTabela({super.key, this.sinalAbrirArtilharia});

  /// Disparado pelo MenuPrincipal quando a Home pede a aba ARTILHARIA.
  final Sinal? sinalAbrirArtilharia;

  @override
  State<TelaTabela> createState() => _TelaTabelaState();
}

class _TelaTabelaState extends State<TelaTabela> {
  // Aba superior: 0 = JOGOS | 1 = CLASSIFICAÇÃO | 2 = ARTILHARIA
  int _abaSuperior = 0;

  // 0 = Próximos  |  1 = Resultados
  int _abaAtiva = 0;

  // Filtro de jogos: 0 = Por data | 1 = Por rodada | 2 = Por grupo
  int _filtroJogos = 0;
  String? _rodadaSelecionada;
  String? _grupoSelecionado;

  // Filtro da aba CLASSIFICAÇÃO: null = todos os grupos
  String? _grupoClassificacao;

  // Stream: placar ao vivo e chip de status atualizam em tempo real
  // conforme a sincronizarApi grava no Firestore.
  late Stream<List<Jogo>> _streamJogos;
  late Future<List<Artilheiro>> _futureArtilharia;
  late Future<Map<String, List<ClassificacaoApiTime>>?> _futureClassificacaoApi;

  @override
  void initState() {
    super.initState();
    _streamJogos = JogoService().observarTodos();
    _futureArtilharia = ApiDadosService().buscarArtilharia();
    _futureClassificacaoApi = ApiDadosService().buscarClassificacao();
    widget.sinalAbrirArtilharia?.addListener(_abrirArtilharia);
  }

  @override
  void dispose() {
    widget.sinalAbrirArtilharia?.removeListener(_abrirArtilharia);
    super.dispose();
  }

  void _abrirArtilharia() {
    if (mounted) setState(() => _abaSuperior = 2);
  }

  Future<void> _recarregar() async {
    // Os jogos chegam por stream (sempre atuais); o refresh manual rebusca
    // só a artilharia e a classificação oficial.
    setState(() {
      _futureArtilharia = ApiDadosService().buscarArtilharia();
      _futureClassificacaoApi = ApiDadosService().buscarClassificacao();
    });
    await _futureArtilharia;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Jogo>>(
      stream: _streamJogos,
      builder: (context, snapshot) {
        // ── Carregando ──────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── Erro ────────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erro ao carregar os jogos.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Cores.onSurfaceVariant),
              ),
            ),
          );
        }

        // ── Dados prontos ───────────────────────────────────────────────────
        final todos = snapshot.data ?? [];

        // Extrai grupos únicos da Copa presentes nos dados, em ordem alfabética
        final gruposCopa =
            todos.map((j) => j.group).whereType<String>().toSet().toList()
              ..sort();

        return Container(
          color: Cores.background,
          child: Column(
            children: [
              _SeletorModo(
                indice: _abaSuperior,
                onChanged: (i) => setState(() => _abaSuperior = i),
              ),
              if (_abaSuperior == 1)
                // CLASSIFICAÇÃO: seletor de grupo (Todos os grupos / A–L)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _CampoSeletorFiltro(
                    valor: _grupoClassificacao ?? 'Todos os grupos',
                    onTap: () => _abrirSeletorGrupoClassificacao(gruposCopa),
                  ),
                )
              else if (_abaSuperior == 0) ...[
                // Chips de filtro (Por data / Por rodada / Por grupo)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _ChipsFiltroJogos(
                    filtro: _filtroJogos,
                    onChanged:
                        (f) => setState(() {
                          _filtroJogos = f;
                          // Pré-seleciona a primeira opção ao entrar no filtro
                          if (f == 1 && _rodadaSelecionada == null) {
                            final ops = _opcoesRodada(todos);
                            if (ops.isNotEmpty) _rodadaSelecionada = ops.first;
                          }
                          if (f == 2 &&
                              _grupoSelecionado == null &&
                              gruposCopa.isNotEmpty) {
                            _grupoSelecionado = gruposCopa.first;
                          }
                        }),
                  ),
                ),
                if (_filtroJogos == 0)
                  _buildSubAbas(todos)
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _CampoSeletorFiltro(
                      valor:
                          _filtroJogos == 1
                              ? _rodadaSelecionada
                              : _grupoSelecionado,
                      onTap: () => _abrirSeletorFiltro(todos, gruposCopa),
                    ),
                  ),
              ],
              Expanded(
                child: switch (_abaSuperior) {
                  1 => _buildClassificacao(todos),
                  2 => _buildArtilharia(),
                  _ => _buildLista(todos),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ARTILHARIA — classificação completa (api/artilharia, via football-data.org)
  // ---------------------------------------------------------------------------

  Widget _buildArtilharia() {
    return FutureBuilder<List<Artilheiro>>(
      future: _futureArtilharia,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Cores.verdePrincipal),
          );
        }
        final artilheiros = snap.data ?? [];

        return RefreshIndicator(
          color: Cores.verdePrincipal,
          onRefresh: _recarregar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  boxShadow: _sombraCard,
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                          'CHUTEIRA DE OURO',
                          style: GoogleFonts.anybody(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Cores.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Jogadores com pelo menos um gol.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        color: Cores.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (artilheiros.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'A artilharia aparece após os primeiros gols da Copa.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12,
                              color: Cores.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    for (var i = 0; i < artilheiros.length; i++) ...[
                      LinhaArtilheiro(posicao: i + 1, artilheiro: artilheiros[i]),
                      if (i < artilheiros.length - 1)
                        const Divider(height: 14, color: Cores.surfaceVariant),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-abas Próximos / Encerrados — mesmo visual da tela de Palpites
  // ---------------------------------------------------------------------------

  Widget _buildSubAbas(List<Jogo> todos) {
    final countProximos = todos.where((j) => j.placar1 == null).length;
    final countEncerrados = todos.where((j) => j.placar1 != null).length;

    // Card único segmentado (mesmo aspecto do campo seletor de rodada/grupo):
    // seleção em branco suave, sem verde — a tela já tem verde nas abas e chips.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Cores.verdeSuave,
          border: Border.all(color: Cores.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SegmentoAba(
                label: 'Próximos',
                count: countProximos,
                ativo: _abaAtiva == 0,
                onTap: () => setState(() => _abaAtiva = 0),
              ),
            ),
            // Divisão central do card
            Container(
              width: 1,
              height: 20,
              color: Cores.outlineVariant,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            Expanded(
              child: _SegmentoAba(
                label: 'Encerrados',
                count: countEncerrados,
                ativo: _abaAtiva == 1,
                onTap: () => setState(() => _abaAtiva = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CLASSIFICAÇÃO — preferência pelo standings oficial da API (critérios FIFA
  // completos, incluindo confronto direto e fair play); enquanto api/
  // classificacao não existe, cai no cálculo local a partir dos placares.
  // ---------------------------------------------------------------------------

  Widget _buildClassificacao(List<Jogo> todos) {
    return FutureBuilder<Map<String, List<ClassificacaoApiTime>>?>(
      future: _futureClassificacaoApi,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Cores.verdePrincipal),
          );
        }

        // Monta "Grupo X" → linhas, da API quando disponível
        final porGrupo = <String, List<_TimeClassificacao>>{};
        final api = snap.data;
        if (api != null) {
          for (final entrada in api.entries) {
            porGrupo['Grupo ${entrada.key}'] =
                entrada.value.map(_TimeClassificacao.deApi).toList();
          }
        } else {
          final jogosPorGrupo = <String, List<Jogo>>{};
          for (final j in todos) {
            if (j.group == null) continue;
            jogosPorGrupo.putIfAbsent(j.group!, () => []).add(j);
          }
          for (final entrada in jogosPorGrupo.entries) {
            porGrupo[entrada.key] = _classificacaoDe(entrada.value);
          }
        }

        final chaves =
            porGrupo.keys
                .where(
                  (g) =>
                      _grupoClassificacao == null || g == _grupoClassificacao,
                )
                .toList()
              ..sort();

        return RefreshIndicator(
          color: Cores.verdePrincipal,
          onRefresh: _recarregar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (final g in chaves) ...[
                _CardClassificacaoGrupo(titulo: g, linhas: porGrupo[g]!),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Filtros Por rodada / Por grupo
  // ---------------------------------------------------------------------------

  /// Rodadas/fases presentes nos jogos, na ordem canônica do torneio.
  List<String> _opcoesRodada(List<Jogo> todos) {
    final presentes = todos.map((j) => j.matchday ?? j.round).toSet();
    return [
      for (final r in _ordemRodadas)
        if (presentes.contains(r)) r,
    ];
  }

  Future<void> _abrirSeletorFiltro(
    List<Jogo> todos,
    List<String> gruposCopa,
  ) async {
    final porRodada = _filtroJogos == 1;
    final escolha = await mostrarSeletorOpcoes(
      context,
      titulo: porRodada ? 'Rodada / Fase' : 'Grupo',
      opcoes: porRodada ? _opcoesRodada(todos) : gruposCopa,
      selecionada: porRodada ? _rodadaSelecionada : _grupoSelecionado,
    );
    if (escolha == null || !mounted) return;
    setState(() {
      if (porRodada) {
        _rodadaSelecionada = escolha;
      } else {
        _grupoSelecionado = escolha;
      }
    });
  }

  Future<void> _abrirSeletorGrupoClassificacao(List<String> gruposCopa) async {
    final escolha = await mostrarSeletorOpcoes(
      context,
      titulo: 'Grupo',
      opcoes: ['Todos os grupos', ...gruposCopa],
      selecionada: _grupoClassificacao ?? 'Todos os grupos',
    );
    if (escolha == null || !mounted) return;
    setState(
      () => _grupoClassificacao = escolha == 'Todos os grupos' ? null : escolha,
    );
  }

  // ---------------------------------------------------------------------------
  // Lista principal — agrupa jogos por seção e monta os slivers
  // ---------------------------------------------------------------------------

  Widget _buildLista(List<Jogo> todos) {
    // Aplica o filtro ativo: Por data (sub-abas), Por rodada ou Por grupo
    final filtrados =
        todos.where((j) {
            switch (_filtroJogos) {
              case 1:
                return (j.matchday ?? j.round) == _rodadaSelecionada;
              case 2:
                return j.group == _grupoSelecionado;
              default:
                return _abaAtiva == 0
                    ? j.placar1 ==
                        null // Próximos: sem placar
                    : j.placar1 != null; // Encerrados: com placar
            }
          }).toList()
          ..sort(
            (a, b) => a.dataHora.compareTo(b.dataHora),
          ); // ordena por horário

    if (filtrados.isEmpty) {
      return RefreshIndicator(
        color: Cores.verdePrincipal,
        onRefresh: _recarregar,
        child: ListView(
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  _abaAtiva == 0
                      ? 'Nenhum jogo futuro.'
                      : 'Nenhum resultado ainda.',
                  style: const TextStyle(color: Cores.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Agrupamento por seção.
    //
    // Map em Dart preserva a ordem de inserção — então os jogos chegam
    // já ordenados por dataHora e as seções aparecem na mesma sequência.
    //
    // Chave: "Fase de Grupos — Rodada 1" ou "Oitavas de Final" (sem matchday)
    final Map<String, List<Jogo>> porSecao = {};
    for (final j in filtrados) {
      final chave = j.matchday != null ? '${j.round} — ${j.matchday}' : j.round;
      porSecao.putIfAbsent(chave, () => []).add(j);
    }

    // CustomScrollView permite misturar diferentes tipos de "fatias" (slivers):
    //   - SliverToBoxAdapter: encapsula qualquer widget avulso (cabeçalhos)
    //   - SliverPadding + SliverList: a lista de cards com padding lateral
    //
    // Isso é mais eficiente que um ListView com widgets intercalados porque
    // o Flutter consegue calcular o layout de cada sliver de forma independente.
    return RefreshIndicator(
      color: Cores.verdePrincipal,
      onRefresh: _recarregar,
      child: CustomScrollView(
        slivers: [
          for (final entrada in porSecao.entries) ...[
            SliverToBoxAdapter(child: _buildCabecalhoSecao(entrada.key)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CardJogo(jogo: entrada.value[i]),
                  ),
                  childCount: entrada.value.length,
                ),
              ),
            ),
          ],
          // Espaço final para o card não ficar colado atrás da NavigationBar
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildCabecalhoSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        titulo.toUpperCase(),
        style: GoogleFonts.anybody(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.8,
          color: Cores.onSurface,
        ),
      ),
    );
  }
}

// =============================================================================
// _CardJogo
//
// Widget separado para cada jogo. Isolá-lo aqui tem duas vantagens:
//   1. O código fica mais organizado e fácil de ler.
//   2. O Flutter pode reconstruir apenas os cards que mudaram, sem tocar
//      nos outros.
// =============================================================================

class _CardJogo extends StatelessWidget {
  const _CardJogo({required this.jogo});

  final Jogo jogo;

  bool get _encerrado => jogo.placar1 != null;

  // Status efetivo (biblioteca.dart): alimenta o chip e o placar ao vivo.
  String get _status => statusEfetivoDe(jogo);

  // Palpites travados (5 min antes do início): a partir daí os palpites dos
  // outros podem ser vistos, mesmo antes do resultado.
  bool get _travado => DateTime.now().isAfter(
        jogo.dataHora.toLocal().subtract(const Duration(minutes: 5)),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _travado ? () => _mostrarPalpitesJogo(context, jogo) : null,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: _sombraCard,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCabecalho(),
            const SizedBox(height: 14),
            _buildCorpo(),
          ],
        ),
      ),
    );
  }

  // ── Cabeçalho: chip de status à esquerda, data e local à direita ──────────

  Widget _buildCabecalho() {
    return Row(
      children: [
        ChipStatusJogo(status: _status),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _status == 'FINISHED'
                    ? formatarData(jogo.dataHora)
                    // Horário já convertido para o fuso local do dispositivo
                    : '${formatarData(jogo.dataHora)} · ${jogo.ground}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  color: Cores.onSurfaceVariant,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Corpo: time1 — [placar x placar] — time2 ─────────────────────────────

  Widget _buildCorpo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTime(jogo.team1)),

        // Placar central
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildPlacar(),
        ),

        Expanded(child: _buildTime(jogo.team2)),
      ],
    );
  }

  // Placar em texto puro — sem caixas, que pareciam campos editáveis como
  // os da tela de palpites. Estados: encerrado com placar definitivo;
  // encerrado pela API aguardando confirmação do placar final (parcial em
  // cinza); ao vivo (parcial em vermelho, 0 x 0 até o 1º sync); ou
  // aguardando (— x —). Inclui a decisão (pênaltis/prorrogação) embaixo.
  Widget _buildPlacar() {
    if (_encerrado) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${jogo.placar1}  x  ${jogo.placar2}',
            style: GoogleFonts.anybody(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Cores.onSurface,
            ),
          ),
          if (jogo.placarDecisao != null)
            Text(
              jogo.placarDecisao!,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Cores.onSurfaceVariant,
              ),
            ),
        ],
      );
    }
    if (_status == 'IN_PLAY') {
      return Text(
        '${jogo.placarAoVivo1 ?? 0}  x  ${jogo.placarAoVivo2 ?? 0}',
        style: GoogleFonts.anybody(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Cores.error,
        ),
      );
    }
    // FINISHED na API mas placar final ainda não confirmado: último parcial
    if (_status == 'FINISHED' && jogo.placarAoVivo1 != null) {
      return Text(
        '${jogo.placarAoVivo1}  x  ${jogo.placarAoVivo2}',
        style: GoogleFonts.anybody(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Cores.onSurfaceVariant,
        ),
      );
    }
    return Text(
      '—  x  —',
      style: GoogleFonts.anybody(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Cores.outline,
      ),
    );
  }

  // Bandeira e nome centralizados no espaço lateral — mesmo padrão dos
  // cards da tela de Palpites e da tela Teste de API.
  Widget _buildTime(String nome) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cores.surfaceContainerHigh,
            border: Border.all(color: Cores.outlineVariant),
          ),
          child: Bandeira(nome, tamanho: 36),
        ),
        const SizedBox(height: 4),
        Text(
          nomePtDe(nome),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Cores.onSurface,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ─── Seletor de aba superior (JOGOS / CLASSIFICAÇÃO / ARTILHARIA) ────────────
// Mesmo visual da tela de Palpites — faixa verde com abas brancas.

class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.indice, required this.onChanged});

  final int indice;
  final void Function(int) onChanged;

  static const _labels = ['JOGOS', 'CLASSIFICAÇÃO', 'ARTILHARIA'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Cores.verdePrincipal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _BotaoModo(
                label: _labels[i],
                ativo: indice == i,
                onTap: () => onChanged(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BotaoModo extends StatelessWidget {
  const _BotaoModo({
    required this.label,
    required this.ativo,
    required this.onTap,
  });
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? Colors.white : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        // FittedBox encolhe o rótulo se faltar largura (ex: CLASSIFICAÇÃO
        // em telas estreitas), mantendo as três abas com a mesma largura.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.anybody(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ativo ? Cores.verdePrincipal : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Segmento de sub-aba (Próximos / Encerrados) ─────────────────────────────
// Mesmo visual da tela de Palpites — seleção em branco suave, com contador.

class _SegmentoAba extends StatelessWidget {
  const _SegmentoAba({
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow:
              ativo
                  ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ativo ? Cores.onSurface : Cores.onSurfaceVariant,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ativo ? Cores.verdeSuave : Cores.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
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

// ─── Chips de filtro de jogos (Por data / Por rodada / Por grupo) ─────────────
// Mesmo visual da tela de Palpites.

class _ChipsFiltroJogos extends StatelessWidget {
  const _ChipsFiltroJogos({required this.filtro, required this.onChanged});

  final int filtro;
  final void Function(int) onChanged;

  static const _labels = ['Por data', 'Por rodada', 'Por grupo'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildChip(_labels[i], i),
        ],
      ],
    );
  }

  Widget _buildChip(String label, int indice) {
    final selecionado = filtro == indice;
    return GestureDetector(
      onTap: () => onChanged(indice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? Cores.verdePrincipal : Cores.verdeSuave,
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
        ),
      ),
    );
  }
}

// ─── Campo seletor de rodada/grupo (abre bottom sheet de opções) ──────────────
// Mesmo visual da tela de Palpites.

class _CampoSeletorFiltro extends StatelessWidget {
  const _CampoSeletorFiltro({required this.valor, required this.onTap});

  final String? valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Cores.surfaceContainer,
          border: Border.all(color: Cores.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_list_rounded,
              size: 20,
              color: Cores.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valor ?? 'Selecionar...',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: valor != null ? FontWeight.w600 : FontWeight.w400,
                  color:
                      valor != null ? Cores.onSurface : Cores.onSurfaceVariant,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: Cores.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Classificação dos grupos (CLASSIFICAÇÃO) ────────────────────────────────

/// Estatísticas acumuladas de um time dentro do seu grupo.
class _TimeClassificacao {
  _TimeClassificacao(this.nome);

  /// Converte uma linha do standings oficial (api/classificacao) — a ordem
  /// da lista da API já é a classificação oficial, então não reordenamos.
  factory _TimeClassificacao.deApi(ClassificacaoApiTime l) {
    return _TimeClassificacao(l.time)
      ..jogos = l.jogos
      ..vitorias = l.vitorias
      ..empates = l.empates
      ..derrotas = l.derrotas
      ..golsPro = l.golsPro
      ..golsContra = l.golsContra;
  }

  final String nome;
  int jogos = 0;
  int vitorias = 0;
  int empates = 0;
  int derrotas = 0;
  int golsPro = 0;
  int golsContra = 0;

  int get pontos => vitorias * 3 + empates;
  int get saldo => golsPro - golsContra;
}

/// Calcula a classificação de um grupo a partir dos placares já inseridos.
/// Critérios de desempate FIFA: pontos > saldo de gols > gols pró > nome.
List<_TimeClassificacao> _classificacaoDe(List<Jogo> jogosGrupo) {
  final mapa = <String, _TimeClassificacao>{};
  for (final j in jogosGrupo) {
    final t1 = mapa.putIfAbsent(j.team1, () => _TimeClassificacao(j.team1));
    final t2 = mapa.putIfAbsent(j.team2, () => _TimeClassificacao(j.team2));
    if (j.placar1 == null || j.placar2 == null) continue;

    t1.jogos++;
    t2.jogos++;
    t1.golsPro += j.placar1!;
    t1.golsContra += j.placar2!;
    t2.golsPro += j.placar2!;
    t2.golsContra += j.placar1!;

    if (j.placar1! > j.placar2!) {
      t1.vitorias++;
      t2.derrotas++;
    } else if (j.placar1! < j.placar2!) {
      t2.vitorias++;
      t1.derrotas++;
    } else {
      t1.empates++;
      t2.empates++;
    }
  }

  return mapa.values.toList()..sort((a, b) {
    if (b.pontos != a.pontos) return b.pontos - a.pontos;
    if (b.saldo != a.saldo) return b.saldo - a.saldo;
    if (b.golsPro != a.golsPro) return b.golsPro - a.golsPro;
    return nomePtDe(a.nome).compareTo(nomePtDe(b.nome));
  });
}

class _CardClassificacaoGrupo extends StatelessWidget {
  const _CardClassificacaoGrupo({required this.titulo, required this.linhas});

  final String titulo; // "Grupo A"
  final List<_TimeClassificacao> linhas;

  static const _larguraColuna = 30.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: _sombraCard,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          // Título do grupo + cabeçalho das colunas
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.8,
                    color: Cores.onSurface,
                  ),
                ),
              ),
              for (final c in const ['J', 'SG', 'PTS'])
                SizedBox(
                  width: _larguraColuna,
                  child: Text(
                    c,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < linhas.length; i++) _buildLinha(i + 1, linhas[i]),
        ],
      ),
    );
  }

  Widget _buildLinha(int pos, _TimeClassificacao t) {
    // 1º e 2º avançam direto — destaque verde sutil
    final classificado = pos <= 2;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color:
            classificado
                ? Cores.verdePrincipal.withValues(alpha: 0.06)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$pos',
              textAlign: TextAlign.center,
              style: GoogleFonts.anybody(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    classificado
                        ? Cores.verdePrincipal
                        : Cores.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Cores.surfaceContainerHigh,
              border: Border.all(color: Cores.outlineVariant),
            ),
            child: Bandeira(t.nome, tamanho: 24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nomePtDe(t.nome),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Cores.onSurface,
              ),
            ),
          ),
          _celula('${t.jogos}'),
          _celula('${t.saldo}'),
          SizedBox(
            width: _larguraColuna,
            child: Text(
              '${t.pontos}',
              textAlign: TextAlign.center,
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Cores.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _celula(String valor) {
    return SizedBox(
      width: _larguraColuna,
      child: Text(
        valor,
        textAlign: TextAlign.center,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          color: Cores.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─── Diálogo: todos os palpites de um jogo ────────────────────────────────────

Future<void> _mostrarPalpitesJogo(BuildContext context, Jogo jogo) {
  return showDialog(
    context: context,
    builder: (_) => _DialogPalpitesJogo(jogo: jogo),
  );
}

class _ItemPalpiteJogo {
  const _ItemPalpiteJogo({
    required this.usuario,
    required this.palpite,
    this.pontos,
  });
  final Usuario usuario;
  final Palpite palpite;

  /// Null enquanto o jogo não tem placar final (palpites visíveis a partir
  /// do travamento, pontos só depois do resultado).
  final int? pontos;
}

class _DialogPalpitesJogo extends StatefulWidget {
  const _DialogPalpitesJogo({required this.jogo});
  final Jogo jogo;

  @override
  State<_DialogPalpitesJogo> createState() => _DialogPalpitesJogoState();
}

class _DialogPalpitesJogoState extends State<_DialogPalpitesJogo> {
  late final Future<List<_ItemPalpiteJogo>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<List<_ItemPalpiteJogo>> _carregar() async {
    // A Cloud Function verifica autenticação, filtra pelos membros dos grupos
    // do solicitante e retorna os dados prontos — sem leitura direta do Firestore.
    final callable = FirebaseFunctions.instanceFor(
      region: 'southamerica-east1',
    ).httpsCallable('buscarPalpitesJogo');
    final result = await callable.call({'jogoId': widget.jogo.id});
    final data = Map<String, dynamic>.from(result.data as Map);
    final rawItens = (data['itens'] as List).cast<Map>();

    return rawItens.map((raw) {
      final m = Map<String, dynamic>.from(raw);
      return _ItemPalpiteJogo(
        usuario: Usuario(
          uid: m['uid'] as String,
          email: '',
          nome: m['nome'] as String,
          criadoEm: DateTime.now(),
          avatar: m['avatar'] as String?,
        ),
        palpite: Palpite(
          uid: m['uid'] as String,
          jogoId: widget.jogo.id,
          palpite1: (m['palpite1'] as num).toInt(),
          palpite2: (m['palpite2'] as num).toInt(),
        ),
        pontos: (m['pontos'] as num?)?.toInt(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jogo;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho verde com times e resultado
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            color: Cores.verdePrincipal,
            child: Column(
              children: [
                Row(
                  children: [
                    // Time 1: nome à direita, bandeira na ponta
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              nomePtDe(j.team1),
                              style: GoogleFonts.anybody(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 28,
                            height: 28,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: Bandeira(j.team1, tamanho: 28),
                          ),
                        ],
                      ),
                    ),
                    // Placar central: final, parcial ao vivo ou VS antes
                    // do resultado existir
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        j.placar1 != null
                            ? '${j.placar1}×${j.placar2}'
                            : j.placarAoVivo1 != null
                                ? '${j.placarAoVivo1}×${j.placarAoVivo2}'
                                : 'VS',
                        style: GoogleFonts.anybody(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Time 2: bandeira na ponta, nome à esquerda
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: Bandeira(j.team2, tamanho: 28),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              nomePtDe(j.team2),
                              style: GoogleFonts.anybody(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Palpites registrados',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Lista de palpites
          FutureBuilder<List<_ItemPalpiteJogo>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Cores.verdePrincipal),
                );
              }
              final itens = snap.data ?? [];
              if (itens.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nenhum palpite registrado.',
                    style: GoogleFonts.hankenGrotesk(
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itens.length,
                  separatorBuilder:
                      (_, __) =>
                          const Divider(height: 1, color: Cores.outlineVariant),
                  itemBuilder: (_, i) => _buildLinha(itens[i], i + 1),
                ),
              );
            },
          ),

          // Botão fechar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Cores.verdePrincipal,
                  side: const BorderSide(color: Cores.verdePrincipal),
                ),
                child: Text(
                  'FECHAR',
                  style: GoogleFonts.anybody(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinha(_ItemPalpiteJogo item, int posicao) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Posição
          SizedBox(
            width: 20,
            child: Text(
              '$posicao',
              style: GoogleFonts.anybody(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Cores.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          WidgetAvatar(
            avatarId: item.usuario.avatar,
            nome: item.usuario.nome,
            tamanho: 32,
            corFundo: Cores.surfaceContainerHigh,
          ),
          const SizedBox(width: 8),

          // Nome
          Expanded(
            child: Text(
              item.usuario.nome,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Cores.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Palpite
          Text(
            '${item.palpite.palpite1}–${item.palpite.palpite2}',
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
}

// ─── Badge de pontuação ───────────────────────────────────────────────────────

class _BadgePontos extends StatelessWidget {
  const _BadgePontos(this.pontos);
  final int pontos;

  Color get _cor => corPontuacao(pontos);
  Color get _corTexto => Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _cor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$pontos pts',
        style: GoogleFonts.anybody(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _corTexto,
        ),
      ),
    );
  }
}
