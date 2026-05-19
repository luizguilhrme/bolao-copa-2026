import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../utils/cores.dart';

class TelaRanking extends StatelessWidget {
  const TelaRanking({super.key});

  // Stream do Firestore — emite nova lista sempre que alguma pontuação mudar.
  // orderBy direto aqui dispensa um método extra no UsuarioService.
  Stream<List<Usuario>> get _streamRanking => FirebaseFirestore.instance
      .collection('usuarios')
      .orderBy('pontuacao', descending: true)
      .snapshots()
      .map((snap) =>
      snap.docs.map((d) => Usuario.fromMap(d.data())).toList());

  @override
  Widget build(BuildContext context) {
    final uidAtual = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Usuario>>(
      stream: _streamRanking,
      builder: (context, snapshot) {
        // ── Carregando ──────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── Erro ────────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return Center(
            child: Text('Erro ao carregar ranking.',
                style: GoogleFonts.hankenGrotesk(
                    color: Cores.onSurfaceVariant)),
          );
        }

        final usuarios = snapshot.data ?? [];

        // ── Vazio ────────────────────────────────────────────────────────────
        if (usuarios.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.leaderboard_outlined,
                    size: 64, color: Cores.outlineVariant),
                const SizedBox(height: 16),
                Text('Nenhum participante ainda.',
                    style: GoogleFonts.anybody(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Cores.onSurface)),
              ],
            ),
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
                      'Ranking geral do bolão',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        color: Cores.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                    uidAtual: uidAtual,
                  ),
                ),
              ),

            // Lista (4º em diante, ou todos se < 3)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    // Se tem pódio, começa do índice 3; senão, do 0
                    final indiceReal =
                    usuarios.length >= 3 ? i + 3 : i;
                    if (indiceReal >= usuarios.length) return null;
                    final usuario = usuarios[indiceReal];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ItemRanking(
                        posicao: indiceReal + 1,
                        usuario: usuario,
                        euSou: usuario.uid == uidAtual,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar com badge de posição
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _tamanhoAvatar,
              height: _tamanhoAvatar,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: corBorda.withOpacity(0.2),
                border: Border.all(
                  color: corBorda,
                  width: posicao == 1 ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: corBorda.withOpacity(0.4),
                    blurRadius: posicao == 1 ? 16 : 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _inicial(usuario.nome),
                  style: GoogleFonts.anybody(
                    fontSize: posicao == 1 ? 28 : 22,
                    fontWeight: FontWeight.w800,
                    color: Cores.onSurface,
                  ),
                ),
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
                        color: Colors.black.withOpacity(0.15),
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
            color: corBase,
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
                  color: Cores.onSurface,
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
                  color: Cores.onSurfaceVariant,
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
    );
  }

  String _inicial(String nome) =>
      nome.isNotEmpty ? nome[0].toUpperCase() : '?';
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

  String get _inicial =>
      usuario.nome.isNotEmpty ? usuario.nome[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
                ? Cores.verdePrincipal.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
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

          // Avatar com inicial
          Container(
            width: euSou ? 48 : 44,
            height: euSou ? 48 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: euSou
                  ? Cores.verdePrincipal
                  : Cores.surfaceContainerHigh,
              border: Border.all(
                color: euSou
                    ? Cores.verdePrincipal
                    : Cores.outlineVariant,
              ),
            ),
            child: Center(
              child: Text(
                _inicial,
                style: GoogleFonts.anybody(
                  fontSize: euSou ? 20 : 18,
                  fontWeight: FontWeight.w800,
                  color: euSou ? Colors.white : Cores.onSurface,
                ),
              ),
            ),
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
    );
  }
}