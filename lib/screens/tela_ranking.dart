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
  const TelaRanking({super.key});

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

  // Não usa orderBy no Firestore porque documentos sem o campo seriam excluídos.
  // A ordenação completa (com desempates) é feita no build após filtrar por grupo.
  final Stream<List<Usuario>> _streamUsuarios = FirebaseFirestore.instance
      .collection('usuarios')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Usuario.fromMap(d.data())).toList());

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  Future<void> _carregarConfig() async {
    final doc = await FirebaseFirestore.instance
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

  List<Usuario> _ordenar(List<Usuario> lista, bool modoCopa) {
    final campNorm = _campeaoReal?.toLowerCase().trim();
    final chutNorm = _chuteiradeOuroReal?.toLowerCase().trim();
    lista.sort((a, b) {
      final ptA =
          modoCopa ? a.pontuacaoCopaTotal : a.pontuacaoClassicaTotal;
      final ptB =
          modoCopa ? b.pontuacaoCopaTotal : b.pontuacaoClassicaTotal;
      if (ptB != ptA) return ptB.compareTo(ptA);
      // 1. Mais placares exatos
      if (b.placaresExatos != a.placaresExatos) {
        return b.placaresExatos.compareTo(a.placaresExatos);
      }
      // 2. Menos palpites perdidos
      if (a.palpitesPerdidos != b.palpitesPerdidos) {
        return a.palpitesPerdidos.compareTo(b.palpitesPerdidos);
      }
      // 3. Acertou o campeão (case-insensitive, sem espaços extras)
      final aCamp =
          (campNorm != null &&
              a.palpiteCampeao?.toLowerCase().trim() == campNorm)
              ? 1
              : 0;
      final bCamp =
          (campNorm != null &&
              b.palpiteCampeao?.toLowerCase().trim() == campNorm)
              ? 1
              : 0;
      if (bCamp != aCamp) return bCamp.compareTo(aCamp);
      // 4. Acertou a Chuteira de Ouro (case-insensitive, sem espaços extras)
      final aChut = (chutNorm != null &&
              a.palpiteChuteiradeOuro?.toLowerCase().trim() == chutNorm)
          ? 1
          : 0;
      final bChut = (chutNorm != null &&
              b.palpiteChuteiradeOuro?.toLowerCase().trim() == chutNorm)
          ? 1
          : 0;
      return bChut.compareTo(aChut);
    });
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Grupo>>(
      stream: GrupoService().buscarGruposDoUsuario(_uidAtual),
      builder: (context, snapGrupos) {
        // Ainda carregando grupos — espera antes de mostrar qualquer coisa
        if (snapGrupos.connectionState == ConnectionState.waiting) {
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
                  Icon(Icons.group_outlined,
                      size: 64, color: Cores.outlineVariant),
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
        final grupoEfetivo = (_grupoSelecionado != null &&
                grupos.any((g) => g.id == _grupoSelecionado!.id))
            ? _grupoSelecionado!
            : grupos.first;

        final bool modoCopa = grupoEfetivo.regra == 'copa';

        return StreamBuilder<List<Usuario>>(
          stream: _streamUsuarios,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Erro ao carregar ranking.',
                    style: GoogleFonts.hankenGrotesk(
                        color: Cores.onSurfaceVariant)),
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
                        grupos: grupos,
                        selecionado: grupoEfetivo,
                        onSelecionar: (g) =>
                            setState(() => _grupoSelecionado = g),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.leaderboard_outlined,
                              size: 64, color: Cores.outlineVariant),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum membro neste grupo ainda.',
                            style: GoogleFonts.anybody(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Cores.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                // Cabeçalho
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Text(
                          'CLASSIFICAÇÃO',
                          style: GoogleFonts.anybody(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Cores.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          grupoEfetivo.nome,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15,
                            color: Cores.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Seletor de grupo (só aparece com 2 ou mais grupos)
                if (grupos.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SeletorGrupo(
                        grupos: grupos,
                        selecionado: grupoEfetivo,
                        onSelecionar: (g) =>
                            setState(() => _grupoSelecionado = g),
                      ),
                    ),
                  ),

                // Pódio (só aparece com 3 ou mais participantes)
                if (usuarios.length >= 3)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: _Podio(
                        primeiro: usuarios[0],
                        segundo: usuarios[1],
                        terceiro: usuarios[2],
                        uidAtual: _uidAtual,
                        modoCopa: modoCopa,
                      ),
                    ),
                  ),

                // Lista (4º em diante, ou todos se < 3)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final indiceReal =
                            usuarios.length >= 3 ? i + 3 : i;
                        if (indiceReal >= usuarios.length) return null;
                        final usuario = usuarios[indiceReal];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ItemRanking(
                            posicao: indiceReal + 1,
                            usuario: usuario,
                            euSou: usuario.uid == _uidAtual,
                            modoCopa: modoCopa,
                          ),
                        );
                      },
                      childCount: usuarios.length >= 3
                          ? usuarios.length - 3
                          : usuarios.length,
                    ),
                  ),
                ),
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
    required this.grupos,
    required this.selecionado,
    required this.onSelecionar,
  });

  final List<Grupo> grupos;
  final Grupo selecionado;
  final ValueChanged<Grupo> onSelecionar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: grupos
            .map((g) => Padding(
                  padding: EdgeInsets.only(
                      left: g == grupos.first ? 0 : 8),
                  child: _Chip(
                    label: g.nome,
                    selecionado: selecionado.id == g.id,
                    onTap: () => onSelecionar(g),
                  ),
                ))
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
            color:
                selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
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

// ─── Pódio (top 3) ────────────────────────────────────────────────────────────

class _Podio extends StatelessWidget {
  const _Podio({
    required this.primeiro,
    required this.segundo,
    required this.terceiro,
    required this.uidAtual,
    required this.modoCopa,
  });

  final Usuario primeiro;
  final Usuario segundo;
  final Usuario terceiro;
  final String uidAtual;
  final bool modoCopa;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2º lugar — esquerda
        Expanded(
          child: _ColunaPodio(
            usuario: segundo,
            posicao: 2,
            alturaBase: 130,
            corBorda: Cores.prata,
            corBase: Cores.surfaceContainerHigh,
            euSou: segundo.uid == uidAtual,
            modoCopa: modoCopa,
          ),
        ),
        const SizedBox(width: 8),
        // 1º lugar — centro (maior)
        Expanded(
          child: _ColunaPodio(
            usuario: primeiro,
            posicao: 1,
            alturaBase: 170,
            corBorda: Cores.ouro,
            corBase: Cores.ouro,
            euSou: primeiro.uid == uidAtual,
            modoCopa: modoCopa,
          ),
        ),
        const SizedBox(width: 8),
        // 3º lugar — direita
        Expanded(
          child: _ColunaPodio(
            usuario: terceiro,
            posicao: 3,
            alturaBase: 110,
            corBorda: Cores.bronze,
            corBase: Cores.surfaceContainer,
            euSou: terceiro.uid == uidAtual,
            modoCopa: modoCopa,
          ),
        ),
      ],
    );
  }
}

class _ColunaPodio extends StatelessWidget {
  const _ColunaPodio({
    required this.usuario,
    required this.posicao,
    required this.alturaBase,
    required this.corBorda,
    required this.corBase,
    required this.euSou,
    required this.modoCopa,
  });

  final Usuario usuario;
  final int posicao;
  final double alturaBase;
  final Color corBorda;
  final Color corBase;
  final bool euSou;
  final bool modoCopa;

  double get _tamanhoAvatar => posicao == 1 ? 72.0 : 56.0;
  double get _fontePontos => posicao == 1 ? 22.0 : 17.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarPalpitesUsuario(context, usuario, modoCopa),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar com badge de posição
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: corBorda.withValues(alpha: 0.4),
                    blurRadius: posicao == 1 ? 16 : 8,
                  ),
                ],
              ),
              child: WidgetAvatar(
                avatarId: usuario.avatar,
                nome: usuario.nome,
                tamanho: _tamanhoAvatar,
                corFundo: corBorda.withValues(alpha: 0.2),
                borderColor: corBorda,
                borderWidth: posicao == 1 ? 4 : 3,
              ),
            ),

            // Badge: troféu para 1º, número para 2º e 3º
            Positioned(
              bottom: -4,
              right: -4,
              child: posicao == 1
                  ? Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cores.secondaryContainer,
                  border: Border.all(
                      color: Cores.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4)
                  ],
                ),
                child: const Icon(Icons.military_tech_rounded,
                    size: 16,
                    color: Cores.onSecondaryContainer),
              )
                  : Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: corBorda,
                  border: Border.all(
                      color: Cores.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$posicao',
                    style: GoogleFonts.anybody(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Base do pódio
        Container(
          width: double.infinity,
          height: alturaBase,
          decoration: BoxDecoration(
            color: corBorda,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: euSou ? Cores.verdePrincipal : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                usuario.nome,
                style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: posicao == 1
                      ? Cores.onSecondaryContainer
                      : Cores.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${modoCopa ? usuario.pontuacaoCopaTotal : usuario.pontuacaoClassicaTotal}',
                style: GoogleFonts.anybody(
                  fontSize: _fontePontos,
                  fontWeight: FontWeight.w800,
                  color: posicao == 1
                      ? Cores.onSecondaryContainer
                      : Cores.onSurface,
                ),
              ),
              Text(
                'pts',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: posicao == 1
                      ? Cores.onSecondaryContainer
                      : Cores.onSurfaceVariant,
                ),
              ),
              if (euSou) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Cores.verdePrincipal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'VOCÊ',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ), // Column
    ); // GestureDetector
  }

}

// ─── Item da lista (4º em diante) ─────────────────────────────────────────────

class _ItemRanking extends StatelessWidget {
  const _ItemRanking({
    required this.posicao,
    required this.usuario,
    required this.euSou,
    required this.modoCopa,
  });

  final int posicao;
  final Usuario usuario;
  final bool euSou;
  final bool modoCopa;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarPalpitesUsuario(context, usuario, modoCopa),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: euSou ? Cores.primaryContainer : Cores.surface,
        border: Border.all(
          color: euSou ? Cores.verdePrincipal : Cores.outlineVariant,
          width: euSou ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: euSou
                ? Cores.verdePrincipal.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: euSou ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Posição
          SizedBox(
            width: 32,
            child: Text(
              '$posicao',
              style: GoogleFonts.anybody(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: euSou
                    ? Cores.verdePrincipal
                    : Cores.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          WidgetAvatar(
            avatarId: usuario.avatar,
            nome: usuario.nome,
            tamanho: euSou ? 48 : 44,
            corFundo: euSou ? Cores.verdePrincipal : Cores.surfaceContainerHigh,
            corTexto: euSou ? Colors.white : Cores.onSurface,
            borderColor: euSou ? Cores.verdePrincipal : Cores.outlineVariant,
          ),
          const SizedBox(width: 12),

          // Nome
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  euSou ? '${usuario.nome} (você)' : usuario.nome,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight:
                    euSou ? FontWeight.w800 : FontWeight.w600,
                    color: euSou
                        ? Cores.verdePrincipal
                        : Cores.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Pontuação
          Text(
            '${modoCopa ? usuario.pontuacaoCopaTotal : usuario.pontuacaoClassicaTotal} pts',
            style: GoogleFonts.anybody(
              fontSize: euSou ? 18 : 16,
              fontWeight: FontWeight.w700,
              color: euSou ? Cores.verdePrincipal : Cores.onSurface,
            ),
          ),
        ],
      ),
    ), // AnimatedContainer
    ); // GestureDetector
  }
}

// ─── Diálogo: palpites de um usuário ─────────────────────────────────────────

Future<void> _mostrarPalpitesUsuario(
    BuildContext context, Usuario usuario, bool modoCopa) {
  return showDialog(
    context: context,
    builder: (_) =>
        _DialogPalpitesUsuario(usuario: usuario, modoCopa: modoCopa),
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

  bool get temMataMata => jogos.any((j) => j.id > 72 && j.placar1 != null);
}

class _ItemPalpiteClassico {
  const _ItemPalpiteClassico(
      {required this.jogo, this.palpite, required this.pontos, this.semPalpite = false});
  final Jogo jogo;
  final Palpite? palpite;
  final int pontos;
  final bool semPalpite;
}

class _ItemEspecial {
  const _ItemEspecial(this.icone, this.label, this.valor,
      {this.isTime = false, this.acertou});
  final IconData icone;
  final String label;
  final String valor;
  final bool isTime;
  final bool? acertou;
}

class _DialogPalpitesUsuario extends StatefulWidget {
  const _DialogPalpitesUsuario(
      {required this.usuario, required this.modoCopa});
  final Usuario usuario;
  final bool modoCopa;

  @override
  State<_DialogPalpitesUsuario> createState() => _DialogPalpitesUsuarioState();
}

class _DialogPalpitesUsuarioState extends State<_DialogPalpitesUsuario> {
  late final Future<_DadosDialog> _future;
  String _filtroGrupo = 'A';

  static const _grupos = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
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
    final callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1')
        .httpsCallable('buscarPalpitesUsuario');

    final results = await Future.wait([
      callable.call({'targetUid': uid}),
      JogoService().buscarTodos(),
      FirebaseFirestore.instance.collection('config').doc('copa2026').get(),
    ]);

    final funcResult = results[0] as HttpsCallableResult<dynamic>;
    final funcData = Map<String, dynamic>.from(funcResult.data as Map);

    final palpites = (funcData['palpites'] as List).map((raw) {
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
    String? campeaoReal, chuteiradeOuroReal, boladeOuroReal, luvadeOuroReal, melhorJovemReal;
    if (configSnap.exists) {
      final data = configSnap.data() as Map<String, dynamic>?;
      classificacaoReal =
          (data?['classificacao_real'] as Map<String, dynamic>?) ?? {};
      palpitesTravados = (data?['palpitesTravados'] as bool?) ?? false;
      especiaisCalculados = (data?['palpitesEspeciaisCalculados'] as bool?) ?? false;
      if (especiaisCalculados) {
        campeaoReal       = data?['campeaoReal']        as String?;
        chuteiradeOuroReal = data?['chuteiradeOuroReal'] as String?;
        boladeOuroReal    = data?['boladeOuroReal']      as String?;
        luvadeOuroReal    = data?['luvadeOuroReal']      as String?;
        melhorJovemReal   = data?['melhorJovemReal']     as String?;
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
        _ItemEspecial(Icons.emoji_events, 'Campeão do Mundo', u.palpiteCampeao!,
            isTime: true,
            acertou: calc ? _acertou(u.palpiteCampeao, dados.campeaoReal) : null),
      if (u.palpiteChuteiradeOuro != null)
        _ItemEspecial(Icons.sports_soccer, 'Chuteira de Ouro', u.palpiteChuteiradeOuro!,
            acertou: calc ? _acertou(u.palpiteChuteiradeOuro, dados.chuteiradeOuroReal) : null),
      if (u.palpiteBoladeOuro != null)
        _ItemEspecial(Icons.star_rounded, 'Bola de Ouro', u.palpiteBoladeOuro!,
            acertou: calc ? _acertou(u.palpiteBoladeOuro, dados.boladeOuroReal) : null),
      if (u.palpiteLuvadeOuro != null)
        _ItemEspecial(Icons.sports_handball, 'Luva de Ouro', u.palpiteLuvadeOuro!,
            acertou: calc ? _acertou(u.palpiteLuvadeOuro, dados.luvadeOuroReal) : null),
      if (u.palpiteMelhorJovem != null)
        _ItemEspecial(Icons.person_rounded, 'Melhor Jogador Jovem', u.palpiteMelhorJovem!,
            acertou: calc ? _acertou(u.palpiteMelhorJovem, dados.melhorJovemReal) : null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final corAcento =
        widget.modoCopa ? Cores.azulTerciario : Cores.verdePrincipal;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: FutureBuilder<_DadosDialog>(
          future: _future,
          builder: (ctx, snap) {
            final dados = snap.data;
            final especiais = dados != null ? _especiais(dados) : <_ItemEspecial>[];
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
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0;
                                  i < especiais.length;
                                  i++) ...[
                                if (i > 0)
                                  const Divider(
                                      color: Colors.white24,
                                      height: 14),
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
                  child: snap.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                                color: Cores.verdePrincipal),
                          ),
                        )
                      : snap.hasError
                          ? Center(
                              child: Text('Erro ao carregar.',
                                  style: GoogleFonts.hankenGrotesk(
                                      color: Cores.onSurfaceVariant)),
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
                      child: Text('FECHAR',
                          style: GoogleFonts.anybody(
                              fontWeight: FontWeight.w700)),
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
        Text(e.label,
            style: GoogleFonts.hankenGrotesk(
                fontSize: 12, color: Colors.white70)),
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
            color: e.acertou! ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
          ),
        ],
      ],
    );
  }

  Widget _buildFiltro(_DadosDialog dados, Color corAcento) {
    final filtros = [
      ..._grupos,
      if (dados.temMataMata) 'MATA-MATA',
    ];
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? corAcento : Cores.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: sel ? corAcento : Cores.outlineVariant),
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

    final jogosRelevantes = dados.jogos.where((j) {
      if (j.placar1 == null) return false;
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
            'Nenhum resultado ainda.',
            style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
          ),
        ),
      );
    }

    final itens = jogosRelevantes.map((j) {
      final p = palpitesMap[j.id];
      if (p != null) {
        return _ItemPalpiteClassico(
          jogo: j,
          palpite: p,
          pontos: calcularPontosComFase(
              p.palpite1, p.palpite2, j.placar1!, j.placar2!, j.round),
        );
      }
      final deveMultar = j.dataHora.isAfter(criadoEm);
      return _ItemPalpiteClassico(
        jogo: j,
        pontos: deveMultar ? -10 : 0,
        semPalpite: true,
      );
    }).toList();

    return ListView.separated(
      itemCount: itens.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Cores.outlineVariant),
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
          Text(siglaDe(item.jogo.team1),
              style: GoogleFonts.anybody(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurface)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '${item.jogo.placar1}–${item.jogo.placar2}',
              style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Cores.verdePrincipal),
            ),
          ),
          Text(siglaDe(item.jogo.team2),
              style: GoogleFonts.anybody(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurface)),
          const SizedBox(width: 5),
          Bandeira(item.jogo.team2, tamanho: 20),
          const Spacer(),
          if (item.semPalpite)
            Text(
              'Não palpitado',
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Cores.onSurfaceVariant),
            )
          else
            Text(
              '${item.palpite!.palpite1}–${item.palpite!.palpite2}',
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurfaceVariant),
            ),
          const SizedBox(width: 8),
          _BadgePontos(item.pontos),
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
            style: GoogleFonts.hankenGrotesk(
                color: Cores.onSurfaceVariant),
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
      ('1º', palpitadoPrimeiro, primeiroReal, calcPts(palpitadoPrimeiro, primeiroReal)),
      ('2º', palpitadoSegundo, segundoReal, calcPts(palpitadoSegundo, segundoReal)),
      if (palpitadoTerceiro != null || terceiroReal != null)
        ('3º', palpitadoTerceiro, terceiroReal, calcPts(palpitadoTerceiro, terceiroReal)),
    ];

    // Bônus: todas as posições exatas
    int? bonus;
    if (temReal) {
      final todasExatas = palpitadoPrimeiro == primeiroReal &&
          palpitadoSegundo == segundoReal &&
          (terceiroReal == null || palpitadoTerceiro == terceiroReal);
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded,
                    size: 16, color: Cores.azulTerciario),
                const SizedBox(width: 8),
                Text(
                  'Bônus — grupo perfeito',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Cores.onSurface),
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
                const Icon(Icons.schedule_rounded,
                    size: 14, color: Cores.onSurfaceVariant),
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
      String posicao, String? palpitado, String? real, int? pontos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(posicao,
                style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Cores.onSurfaceVariant)),
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
                    color: Cores.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            Expanded(
              child: Text('—',
                  style: GoogleFonts.hankenGrotesk(
                      color: Cores.onSurfaceVariant)),
            ),
          // Resultado real (só quando diferente do palpitado)
          if (real != null && real != palpitado) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                size: 14, color: Cores.onSurfaceVariant),
            const SizedBox(width: 6),
            Container(
              width: 22,
              height: 22,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Bandeira(real, tamanho: 22),
            ),
            const SizedBox(width: 4),
            Text(siglaDe(real),
                style: GoogleFonts.anybody(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant)),
          ] else if (real != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle_rounded,
                  size: 16, color: Cores.verdePrincipal),
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