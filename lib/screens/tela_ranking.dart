import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grupo.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../services/jogo_service.dart';
import '../services/palpite_service.dart';
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

  final Stream<List<Usuario>> _streamRanking = FirebaseFirestore.instance
      .collection('usuarios')
      .orderBy('pontuacao', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Usuario.fromMap(d.data())).toList());

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

        return StreamBuilder<List<Usuario>>(
          stream: _streamRanking,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Erro ao carregar ranking.',
                    style: GoogleFonts.hankenGrotesk(
                        color: Cores.onSurfaceVariant)),
              );
            }

            final todosUsuarios = snapshot.data ?? [];
            final usuarios = todosUsuarios
                .where((u) => grupoEfetivo.membros.contains(u.uid))
                .toList();

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
  });

  final Usuario primeiro;
  final Usuario segundo;
  final Usuario terceiro;
  final String uidAtual;

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
            corBorda: const Color(0xFFC0C0C0),
            corBase: Cores.surfaceContainerHigh,
            euSou: segundo.uid == uidAtual,
          ),
        ),
        const SizedBox(width: 8),
        // 1º lugar — centro (maior)
        Expanded(
          child: _ColunaPodio(
            usuario: primeiro,
            posicao: 1,
            alturaBase: 170,
            corBorda: Cores.secondaryContainer,
            corBase: Cores.secondaryContainer,
            euSou: primeiro.uid == uidAtual,
          ),
        ),
        const SizedBox(width: 8),
        // 3º lugar — direita
        Expanded(
          child: _ColunaPodio(
            usuario: terceiro,
            posicao: 3,
            alturaBase: 110,
            corBorda: const Color(0xFFCD7F32),
            corBase: Cores.surfaceContainer,
            euSou: terceiro.uid == uidAtual,
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
  });

  final Usuario usuario;
  final int posicao;
  final double alturaBase;
  final Color corBorda;
  final Color corBase;
  final bool euSou;

  double get _tamanhoAvatar => posicao == 1 ? 72.0 : 56.0;
  double get _fontePontos => posicao == 1 ? 22.0 : 17.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarPalpitesUsuario(context, usuario),
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
                '${usuario.pontuacao}',
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
  });

  final int posicao;
  final Usuario usuario;
  final bool euSou;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarPalpitesUsuario(context, usuario),
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
            '${usuario.pontuacao} pts',
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

Future<void> _mostrarPalpitesUsuario(BuildContext context, Usuario usuario) {
  return showDialog(
    context: context,
    builder: (_) => _DialogPalpitesUsuario(usuario: usuario),
  );
}

class _ItemPalpiteUsuario {
  const _ItemPalpiteUsuario(
      {required this.jogo, required this.palpite, required this.pontos});
  final Jogo jogo;
  final Palpite palpite;
  final int pontos;
}

class _DialogPalpitesUsuario extends StatefulWidget {
  const _DialogPalpitesUsuario({required this.usuario});
  final Usuario usuario;

  @override
  State<_DialogPalpitesUsuario> createState() => _DialogPalpitesUsuarioState();
}

class _DialogPalpitesUsuarioState extends State<_DialogPalpitesUsuario> {
  late final Future<List<_ItemPalpiteUsuario>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<List<_ItemPalpiteUsuario>> _carregar() async {
    final results = await Future.wait([
      PalpiteService().buscarTodosPorUsuario(widget.usuario.uid),
      JogoService().buscarTodos(),
    ]);
    final palpites = results[0] as List<Palpite>;
    final jogos = results[1] as List<Jogo>;

    final palpitesMap = {for (final p in palpites) p.jogoId: p};

    return jogos
        .where((j) => j.placar1 != null && palpitesMap.containsKey(j.id))
        .map((j) {
          final p = palpitesMap[j.id]!;
          return _ItemPalpiteUsuario(
            jogo: j,
            palpite: p,
            pontos: calcularPontosComFase(p.palpite1, p.palpite2, j.placar1!, j.placar2!, j.round),
          );
        })
        .toList()
      ..sort((a, b) => b.jogo.dataHora.compareTo(a.jogo.dataHora));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho verde
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            color: Cores.verdePrincipal,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.usuario.nome,
                            style: GoogleFonts.anybody(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Palpites nos jogos encerrados',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.usuario.palpiteCampeao != null ||
                    widget.usuario.palpiteArtilheiro != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (widget.usuario.palpiteCampeao != null)
                          Row(
                            children: [
                              const Icon(Icons.emoji_events,
                                  size: 15, color: Colors.white70),
                              const SizedBox(width: 8),
                              Text(
                                'Campeão',
                                style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12, color: Colors.white70),
                              ),
                              const Spacer(),
                              Container(
                                width: 20,
                                height: 20,
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle),
                                child: Bandeira(widget.usuario.palpiteCampeao!,
                                    tamanho: 20),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                nomePtDe(widget.usuario.palpiteCampeao!),
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        if (widget.usuario.palpiteCampeao != null &&
                            widget.usuario.palpiteArtilheiro != null)
                          const Divider(color: Colors.white24, height: 14),
                        if (widget.usuario.palpiteArtilheiro != null)
                          Row(
                            children: [
                              const Icon(Icons.sports_soccer,
                                  size: 15, color: Colors.white70),
                              const SizedBox(width: 8),
                              Text(
                                'Artilheiro',
                                style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12, color: Colors.white70),
                              ),
                              const Spacer(),
                              Text(
                                widget.usuario.palpiteArtilheiro!,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Lista de palpites
          FutureBuilder<List<_ItemPalpiteUsuario>>(
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
                    style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itens.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Cores.outlineVariant),
                  itemBuilder: (_, i) => _buildLinha(itens[i]),
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
                child: Text('FECHAR',
                    style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinha(_ItemPalpiteUsuario item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Times e resultado
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
              '${item.jogo.placar1}–${item.jogo.placar2}',
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Cores.verdePrincipal,
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

          // Palpite do usuário
          Text(
            '${item.palpite.palpite1}–${item.palpite.palpite2}',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Cores.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),

          // Badge de pontos
          _BadgePontos(item.pontos),
        ],
      ),
    );
  }
}

// ─── Badge de pontuação ───────────────────────────────────────────────────────

class _BadgePontos extends StatelessWidget {
  const _BadgePontos(this.pontos);
  final int pontos;

  Color get _cor {
    switch (pontos) {
      case 10: return const Color(0xFF006D32);
      case 7:  return const Color(0xFF1B7F3A);
      case 5:  return const Color(0xFF4CAF50);
      case 4:  return const Color(0xFFFCD400);
      default: return const Color(0xFFBBCBB9);
    }
  }

  Color get _corTexto => pontos == 4 ? Cores.onSecondaryContainer : Colors.white;

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