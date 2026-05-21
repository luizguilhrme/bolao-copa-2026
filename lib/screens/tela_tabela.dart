import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jogo.dart';
import '../services/jogo_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

// =============================================================================
// TelaTabela
//
// Mostra os 104 jogos da Copa 2026 organizados em seções por fase/rodada.
// Tem dois modos: "Próximos" (sem placar) e "Resultados" (com placar).
//
// Conceitos novos introduzidos aqui:
//   - CustomScrollView + Slivers: permite misturar cabeçalhos e listas de
//     forma eficiente, sem precisar de um ListView "gigante" com ifs no meio.
//   - AnimationController: usado no chip "AO VIVO" para fazer o ponto pulsar.
//   - SingleTickerProviderStateMixin: o "motor" necessário para rodar animações.
// =============================================================================

class TelaTabela extends StatefulWidget {
  const TelaTabela({super.key});

  @override
  State<TelaTabela> createState() => _TelaTabelaState();
}

class _TelaTabelaState extends State<TelaTabela> {
  // 0 = Próximos  |  1 = Resultados
  int _abaAtiva = 0;

  // Guardamos o Future no initState, não dentro do build().
  // Se ficasse dentro do build(), um novo Future seria criado a cada setState
  // (ex: trocar de aba), causando um reload desnecessário do Firestore.
  late Future<List<Jogo>> _futureJogos;

  @override
  void initState() {
    super.initState();
    _futureJogos = JogoService().buscarTodos();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Jogo>>(
      future: _futureJogos,
      builder: (context, snapshot) {
        // ── Carregando ──────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
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

        // Column ocupa a tela toda: tabs fixas no topo + lista rolável embaixo
        return Column(
          children: [
            _buildTabs(),
            Expanded(child: _buildLista(todos)),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Seletor de abas (Próximos / Resultados)
  // ---------------------------------------------------------------------------

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      // Container externo: o "trilho" cinza arredondado
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildBotaoTab(indice: 0, rotulo: 'Próximos'),
            _buildBotaoTab(indice: 1, rotulo: 'Resultados'),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoTab({required int indice, required String rotulo}) {
    final ativo = _abaAtiva == indice;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaAtiva = indice),
        child: AnimatedContainer(
          // AnimatedContainer anima automaticamente qualquer mudança de
          // propriedade (cor, sombra) ao longo da duration informada.
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: ativo ? Cores.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: ativo
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
                : [],
          ),
          child: Text(
            rotulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: ativo ? Cores.onSurface : Cores.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lista principal — agrupa jogos por seção e monta os slivers
  // ---------------------------------------------------------------------------

  Widget _buildLista(List<Jogo> todos) {
    final agora = DateTime.now();

    // Filtra de acordo com a aba ativa
    final filtrados = todos.where((j) {
      return _abaAtiva == 0
          ? j.placar1 == null // Próximos: sem placar (inclui os ao vivo)
          : j.placar1 != null; // Resultados: com placar
    }).toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora)); // ordena por horário

    if (filtrados.isEmpty) {
      return Center(
        child: Text(
          _abaAtiva == 0 ? 'Nenhum jogo futuro.' : 'Nenhum resultado ainda.',
          style: const TextStyle(color: Cores.onSurfaceVariant),
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
      final chave =
      j.matchday != null ? '${j.round} — ${j.matchday}' : j.round;
      porSecao.putIfAbsent(chave, () => []).add(j);
    }

    // CustomScrollView permite misturar diferentes tipos de "fatias" (slivers):
    //   - SliverToBoxAdapter: encapsula qualquer widget avulso (cabeçalhos)
    //   - SliverPadding + SliverList: a lista de cards com padding lateral
    //
    // Isso é mais eficiente que um ListView com widgets intercalados porque
    // o Flutter consegue calcular o layout de cada sliver de forma independente.
    return CustomScrollView(
      slivers: [
        for (final entrada in porSecao.entries) ...[
          SliverToBoxAdapter(
            child: _buildCabecalhoSecao(entrada.key),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CardJogo(jogo: entrada.value[i], agora: agora),
                ),
                childCount: entrada.value.length,
              ),
            ),
          ),
        ],
        // Espaço final para o card não ficar colado atrás da NavigationBar
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
//   2. O Flutter pode reconstruir apenas os cards que mudaram, sem tocar nos
//      outros — especialmente útil quando o chip "AO VIVO" anima.
// =============================================================================

class _CardJogo extends StatelessWidget {
  const _CardJogo({required this.jogo, required this.agora});

  final Jogo jogo;
  final DateTime agora;

  // Ao vivo = já passou do horário de início, mas ainda não tem placar
  bool get _aoVivo => jogo.placar1 == null && jogo.dataHora.isBefore(agora);

  bool get _encerrado => jogo.placar1 != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cores.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cores.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // ClipRRect garante que a barra verde lateral não vaze para fora
      // do arredondamento do container pai.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Barra verde na lateral esquerda — só aparece em jogos ao vivo
            if (_aoVivo)
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: Container(width: 4, color: Cores.verdePrincipal),
              ),

            // Conteúdo principal (com padding extra à esquerda quando ao vivo)
            Padding(
              padding: EdgeInsets.fromLTRB(_aoVivo ? 20 : 16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCabecalho(),
                  const SizedBox(height: 14),
                  _buildCorpo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cabeçalho: chip do grupo + horário ou badge AO VIVO ──────────────────

  Widget _buildCabecalho() {
    // Nas eliminatórias não existe group, então mostramos só o round
    final labelEsquerda = jogo.group ?? jogo.round;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Chip esquerdo (grupo ou fase)
        _Chip(
          texto: labelEsquerda,
          corFundo: Cores.surfaceVariant,
          corTexto: Cores.onSurfaceVariant,
        ),

        // Direita: varia conforme o estado do jogo
        if (_aoVivo)
          const _ChipAoVivo()
        else if (_encerrado)
          Text(
            'Encerrado · ${formatarData(jogo.dataHora)}',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              color: Cores.onSurfaceVariant,
            ),
          )
        else
          Text(
            // Horário já convertido para o fuso local do dispositivo
            '${formatarData(jogo.dataHora)} · ${jogo.ground}',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              color: Cores.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  // ── Corpo: time1 — [placar x placar] — time2 ─────────────────────────────

  Widget _buildCorpo() {
    // As cores do placar mudam dependendo do estado
    final corBorda = _aoVivo ? Cores.verdePrincipal : Cores.outline;
    final corFundo = _aoVivo ? Cores.surfaceContainer : Colors.transparent;
    final corTexto = _aoVivo ? Cores.verdePrincipal : Cores.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time 1 (alinhado à esquerda)
        Expanded(child: _buildTime(jogo.team1, TextAlign.left)),

        // Placar central
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CaixaPlacar(
                valor: jogo.placar1?.toString() ?? '—',
                corBorda: corBorda,
                corFundo: corFundo,
                corTexto: corTexto,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'x',
                  style: GoogleFonts.anybody(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ),
              _CaixaPlacar(
                valor: jogo.placar2?.toString() ?? '—',
                corBorda: corBorda,
                corFundo: corFundo,
                corTexto: corTexto,
              ),
            ],
          ),
        ),

        // Time 2 (alinhado à direita)
        Expanded(child: _buildTime(jogo.team2, TextAlign.right)),
      ],
    );
  }

  Widget _buildTime(String nome, TextAlign alinhamento) {
    return Column(
      crossAxisAlignment: alinhamento == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Bandeira(nome, tamanho: 26),
        const SizedBox(height: 4),
        Text(
          nomePtDe(nome),
          textAlign: alinhamento,
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

// =============================================================================
// Widgets auxiliares reutilizáveis dentro desta tela
// =============================================================================

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: corTexto,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CaixaPlacar extends StatelessWidget {
  const _CaixaPlacar({
    required this.valor,
    required this.corBorda,
    required this.corFundo,
    required this.corTexto,
  });

  final String valor;
  final Color corBorda;
  final Color corFundo;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: corFundo,
        border: Border.all(color: corBorda, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          valor,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: corTexto,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _ChipAoVivo
//
// O chip com ponto pulsante requer um StatefulWidget próprio porque precisa de
// um AnimationController — e controllers são criados/destruídos junto com o
// State, não com o Widget (que pode ser recriado a qualquer momento).
//
// SingleTickerProviderStateMixin: fornece o "tick" do relógio interno do
// Flutter para o AnimationController. Sempre use isso quando tiver UMA animação.
// Para múltiplas, use TickerProviderStateMixin (sem "Single").
// =============================================================================

class _ChipAoVivo extends StatefulWidget {
  const _ChipAoVivo();

  @override
  State<_ChipAoVivo> createState() => _ChipAoVivoState();
}

class _ChipAoVivoState extends State<_ChipAoVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, // "vsync: this" liga o controller ao mixin acima
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true); // vai e volta em loop

    // Tween define o intervalo da animação (0.3 → 1.0 de opacidade)
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    // SEMPRE chame dispose() no controller para liberar recursos.
    // Esquecer isso causa memory leaks.
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Cores.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AnimatedBuilder escuta o controller e reconstrói só este trecho
          // da árvore a cada frame — muito mais eficiente que chamar setState.
          AnimatedBuilder(
            animation: _fade,
            builder: (_, __) => Opacity(
              opacity: _fade.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Cores.verdePrincipal,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'AO VIVO',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Cores.verdePrincipal,
            ),
          ),
        ],
      ),
    );
  }
}
