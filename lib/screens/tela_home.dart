import 'package:bolao/utils/biblioteca.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/jogo.dart';
import '../models/usuario.dart';
import '../services/jogo_service.dart';
import '../services/usuario_service.dart';
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
          _buildBentoGrid(context),
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

  Widget _buildBentoGrid(BuildContext context) {
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
          _CardPalpiteEspecial(
            onTap: () => showDialog(
              context: context,
              builder: (_) => const _DialogPalpiteEspecial(),
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

// ─── Card: Palpite Especial (Campeão & Artilheiro) ───────────────────────────

class _CardPalpiteEspecial extends StatelessWidget {
  const _CardPalpiteEspecial({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.azulTerciario,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: 0,
                bottom: 0,
                child: Icon(
                  Icons.emoji_events,
                  size: 100,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAMPEÃO & ARTILHEIRO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Palpite no vencedor da Copa e no artilheiro.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'REGISTRAR PALPITE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.white),
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

// ─── Diálogo: Palpite Especial ────────────────────────────────────────────────

class _DialogPalpiteEspecial extends StatefulWidget {
  const _DialogPalpiteEspecial();

  @override
  State<_DialogPalpiteEspecial> createState() => _DialogPalpiteEspecialState();
}

class _DialogPalpiteEspecialState extends State<_DialogPalpiteEspecial> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  bool _salvando = false;
  bool _bloqueado = false;

  String? _campeaoSelecionado;
  late final TextEditingController _ctrlArtilheiro;
  String? _erro;

  late final List<String> _timesSorted;

  @override
  void initState() {
    super.initState();
    _ctrlArtilheiro = TextEditingController();
    _timesSorted = kTimesCopa2026.toList()
      ..sort((a, b) => nomePtDe(a).compareTo(nomePtDe(b)));
    _inicializar();
  }

  @override
  void dispose() {
    _ctrlArtilheiro.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final results = await Future.wait([
      UsuarioService().buscarPorUid(_uid),
      JogoService().buscarTodos(),
    ]);
    if (!mounted) return;
    final usuario = results[0] as Usuario?;
    final jogos = results[1] as List<Jogo>;

    String? campeao = usuario?.palpiteCampeao;
    final artilheiro = usuario?.palpiteArtilheiro ?? '';
    bool bloqueado = false;

    if (jogos.isNotEmpty) {
      jogos.sort((a, b) => a.dataHora.compareTo(b.dataHora));
      bloqueado = DateTime.now().isAfter(jogos.first.dataHora);
    }

    setState(() {
      _campeaoSelecionado = campeao;
      _ctrlArtilheiro.text = artilheiro;
      _bloqueado = bloqueado;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    if (_campeaoSelecionado == null) {
      setState(() => _erro = 'Selecione o campeão.');
      return;
    }
    if (_ctrlArtilheiro.text.trim().isEmpty) {
      setState(() => _erro = 'Digite o nome do artilheiro.');
      return;
    }
    setState(() { _salvando = true; _erro = null; });
    try {
      await UsuarioService().salvarPalpiteEspecial(
        uid: _uid,
        campeao: _campeaoSelecionado!,
        artilheiro: _ctrlArtilheiro.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { _erro = 'Erro ao salvar. Tente novamente.'; _salvando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Cores.azulTerciario)),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho azul
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          color: Cores.azulTerciario,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'PALPITES ESPECIAIS',
                    style: GoogleFonts.anybody(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _bloqueado
                    ? 'Bloqueado — a Copa já começou.'
                    : 'Válidos até o início do primeiro jogo.',
                style: GoogleFonts.hankenGrotesk(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),

        // Conteúdo rolável
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seção: Artilheiro
                Text(
                  'ARTILHEIRO',
                  style: GoogleFonts.anybody(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrlArtilheiro,
                  enabled: !_bloqueado,
                  decoration: InputDecoration(
                    hintText: 'Nome do jogador',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Cores.azulTerciario, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.hankenGrotesk(fontSize: 15),
                ),

                const SizedBox(height: 20),

                // Seção: Campeão
                Text(
                  'CAMPEÃO',
                  style: GoogleFonts.anybody(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Cores.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 280,
                    child: ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: _timesSorted.length,
                      itemBuilder: (_, i) {
                        final time = _timesSorted[i];
                        final selecionado = _campeaoSelecionado == time;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 32,
                            height: 32,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Cores.outlineVariant),
                            ),
                            child: Bandeira(time, tamanho: 32),
                          ),
                          title: Text(
                            nomePtDe(time),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 14,
                              fontWeight: selecionado ? FontWeight.w700 : FontWeight.w400,
                              color: selecionado ? Cores.azulTerciario : Cores.onSurface,
                            ),
                          ),
                          trailing: selecionado
                              ? const Icon(Icons.check_circle, color: Cores.azulTerciario, size: 20)
                              : null,
                          tileColor: selecionado
                              ? Cores.azulTerciario.withOpacity(0.08)
                              : null,
                          onTap: _bloqueado ? null : () => setState(() => _campeaoSelecionado = time),
                        );
                      },
                    ),
                  ),
                ),

                if (_erro != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _erro!,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Botões
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Cores.azulTerciario,
                    side: const BorderSide(color: Cores.azulTerciario),
                  ),
                  child: Text('FECHAR',
                      style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
                ),
              ),
              if (!_bloqueado) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Cores.azulTerciario,
                      foregroundColor: Colors.white,
                    ),
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('CONFIRMAR',
                            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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