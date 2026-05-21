import 'package:bolao/utils/biblioteca.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/jogo.dart';
import '../services/jogo_service.dart';
import '../utils/cores.dart';

// ─── Tela Home ────────────────────────────────────────────────────────────────

// StatefulWidget porque precisamos gerenciar o estado de carregamento
// e guardar a lista de jogos depois que o Future resolver.
class TelaHome extends StatefulWidget {
  const TelaHome({super.key, required this.onNavegar});

  final void Function(int) onNavegar;

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  // Guardamos o Future como variável de instância — isso é importante!
  // Se fosse criado direto no build(), um novo Future seria gerado a cada
  // rebuild, causando um loop infinito de carregamento. Aqui ele é criado
  // uma única vez quando a tela é inicializada.
  late final Future<List<Jogo>> _jogosDeHoje;

  @override
  void initState() {
    super.initState();
    // initState é o equivalente ao onCreate() do Android —
    // roda uma única vez quando o widget é inserido na árvore.
    _jogosDeHoje = JogoService().buscarPorData(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSecaoJogosDeHoje(),
          const SizedBox(height: 24),
          _buildBentoGrid(),
        ],
      ),
    );
  }

  // ── Seção "Jogos de Hoje" ───────────────────────────────────────────────────

  Widget _buildSecaoJogosDeHoje() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'JOGOS DE HOJE',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: Cores.onSurface,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavegar(3),
                style: TextButton.styleFrom(
                  foregroundColor: Cores.azulTerciario,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  children: [
                    Text(
                      'VER TODOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // FutureBuilder é o widget que "ouve" um Future e reconstrói
          // a UI conforme o estado muda: carregando → com dados → com erro.
          // É o equivalente ao observe() do LiveData no Android.
          FutureBuilder<List<Jogo>>(
            future: _jogosDeHoje,
            builder: (context, snapshot) {
              // Estado: ainda buscando no Firestore
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 168,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Estado: deu algum erro na busca
              if (snapshot.hasError) {
                return SizedBox(
                  height: 168,
                  child: Center(
                    child: Text(
                      'Erro ao carregar jogos.',
                      style: TextStyle(color: Cores.onSurfaceVariant),
                    ),
                  ),
                );
              }

              final jogos = snapshot.data ?? [];

              // Estado: busca ok, mas nenhum jogo hoje
              if (jogos.isEmpty) {
                return SizedBox(
                  height: 168,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_soccer,
                            size: 40, color: Cores.outlineVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum jogo hoje.',
                          style: TextStyle(color: Cores.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Estado: tem jogos — ordena (encerrados por último) e renderiza
              final jogosOrdenados = jogos.toList()
                ..sort((a, b) {
                  final aEnc = a.placar1 != null ? 1 : 0;
                  final bEnc = b.placar1 != null ? 1 : 0;
                  if (aEnc != bEnc) return aEnc - bEnc;
                  return a.dataHora.compareTo(b.dataHora);
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: jogosOrdenados.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) =>
                          _CardJogo(jogo: jogosOrdenados[i]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 13, color: Cores.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(
                        'O placar é atualizado somente ao final da partida.',
                        style: TextStyle(
                            fontSize: 11.5, color: Cores.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Bento Grid de navegação ─────────────────────────────────────────────────
  // Mantido exatamente igual — não depende de dados do Firestore

  Widget _buildBentoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CardNav(
                    titulo: 'MEUS\nPALPITES',
                    subtitulo: 'Faça e gerencie suas apostas.',
                    labelBotao: 'IR PARA PALPITES',
                    icone: Icons.edit_square,
                    corFundo: Cores.verdePrincipal,
                    corTexto: Cores.onPrimary,
                    onTap: () => widget.onNavegar(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CardNav(
                    titulo: 'CLASSI-\nFICAÇÃO',
                    subtitulo: 'Veja quem está liderando o bolão.',
                    labelBotao: 'VER RANKING',
                    icone: Icons.leaderboard,
                    corFundo: Cores.secondaryContainer,
                    corTexto: Cores.onSecondaryContainer,
                    onTap: () => widget.onNavegar(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CardNavLargo(onTap: () => widget.onNavegar(3)),
        ],
      ),
    );
  }
}

// ─── Widget: Card de Jogo ─────────────────────────────────────────────────────
// Agora recebe um Jogo real do Firestore em vez do _JogoCard hardcoded.
// O visual é idêntico ao anterior.

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
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: chip de horário + chip AO VIVO (se tiver placar)
          Row(
            children: [
              _Chip(
                texto: horarioLocal,
                corFundo: aoVivo
                    ? Cores.secondaryContainer
                    : Cores.surfaceVariant,
                corTexto: aoVivo
                    ? Cores.onSecondaryContainer
                    : Cores.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              if (aoVivo) const _ChipAoVivo(),
              if (encerrado) const _ChipEncerrado(),
            ],
          ),
          const SizedBox(height: 16),

          // Placar: bandeiras, siglas e gols (ou "VS" se não começou)
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
                    color: Cores.onSurfaceVariant.withOpacity(0.5),
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

// ─── Os widgets abaixo são idênticos ao original ──────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.texto,
        required this.corFundo,
        required this.corTexto});

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

class _CardNav extends StatelessWidget {
  const _CardNav({
    required this.titulo,
    required this.subtitulo,
    required this.labelBotao,
    required this.icone,
    required this.corFundo,
    required this.corTexto,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final String labelBotao;
  final IconData icone;
  final Color corFundo;
  final Color corTexto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: corFundo,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -8,
                child:
                Icon(icone, size: 80, color: corTexto.withOpacity(0.15)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: corTexto,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitulo,
                    style: TextStyle(
                        fontSize: 12, color: corTexto.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: corTexto.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labelBotao,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: corTexto,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 13, color: corTexto),
                      ],
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

class _CardNavLargo extends StatelessWidget {
  const _CardNavLargo({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Cores.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: 0,
                bottom: 0,
                child: Icon(
                  Icons.calendar_month,
                  size: 100,
                  color: Cores.onSurface.withOpacity(0.08),
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODOS OS JOGOS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: Cores.azulTerciario,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tabela completa, resultados e simulador.',
                    style: TextStyle(
                        fontSize: 13, color: Cores.onSurfaceVariant),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'ACESSAR TABELA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Cores.azulTerciario,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward,
                          size: 14, color: Cores.azulTerciario),
                    ],
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