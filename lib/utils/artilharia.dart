import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'biblioteca.dart';
import 'cores.dart';

// =============================================================================
// artilharia.dart — modelo, dados e widgets da classificação de artilharia
//
// Compartilhado entre a tela Home (top 5) e a aba ARTILHARIA da tela Tabela
// (lista completa). Os dados são SIMULADOS por enquanto; serão alimentados
// pela integração com a football-data.org (GET /competitions/WC/scorers),
// que retorna apenas jogadores com pelo menos um gol, já ordenados.
// =============================================================================

/// Um jogador na classificação de artilharia.
class Artilheiro {
  const Artilheiro({
    required this.nome,
    required this.selecao,
    required this.gols,
    this.assistencias = 0,
  });

  final String nome;

  /// Nome da seleção em inglês (mesma grafia do jogos.json) — usado em
  /// [Bandeira] e [nomePtDe].
  final String selecao;
  final int gols;
  final int assistencias;
}

/// Dados simulados — substituir pela resposta da API quando integrarmos.
const kArtilhariaSimulada = [
  Artilheiro(
    nome: 'Carlos Mendes',
    selecao: 'Brazil',
    gols: 7,
    assistencias: 2,
  ),
  Artilheiro(
    nome: 'Hans Zimmermann',
    selecao: 'Germany',
    gols: 6,
    assistencias: 1,
  ),
  Artilheiro(nome: 'Yuki Tanaka', selecao: 'Japan', gols: 5, assistencias: 3),
  Artilheiro(nome: 'Pierre Lefebvre', selecao: 'France', gols: 5),
  Artilheiro(
    nome: 'Diego Fernández',
    selecao: 'Argentina',
    gols: 4,
    assistencias: 2,
  ),
  Artilheiro(
    nome: 'Jan de Vries',
    selecao: 'Netherlands',
    gols: 3,
    assistencias: 1,
  ),
  Artilheiro(nome: 'Min-jun Park', selecao: 'South Korea', gols: 3),
  Artilheiro(nome: 'Ahmed Mansour', selecao: 'Egypt', gols: 2, assistencias: 2),
  Artilheiro(nome: 'Tiago Costa', selecao: 'Portugal', gols: 2),
  Artilheiro(
    nome: 'James Whitmore',
    selecao: 'England',
    gols: 1,
    assistencias: 1,
  ),
];

/// Linha da classificação: posição (pódio colorido no top 3), bandeira,
/// nome, seleção/assistências e gols.
class LinhaArtilheiro extends StatelessWidget {
  const LinhaArtilheiro({
    super.key,
    required this.posicao,
    required this.artilheiro,
  });

  final int posicao;
  final Artilheiro artilheiro;

  Color? get _corPosicao => switch (posicao) {
    1 => Cores.ouro,
    2 => Cores.prata,
    3 => Cores.bronze,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final cor = _corPosicao;
    return Row(
      children: [
        // Posição — círculo colorido no pódio, texto simples nos demais
        SizedBox(
          width: 26,
          child:
              cor != null
                  ? Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$posicao',
                      style: GoogleFonts.anybody(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                  : Text(
                    '$posicaoº',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anybody(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Cores.onSurfaceVariant,
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
          child: Bandeira(artilheiro.selecao, tamanho: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                artilheiro.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurface,
                ),
              ),
              Text(
                '${nomePtDe(artilheiro.selecao)}'
                '${artilheiro.assistencias > 0 ? ' • ${artilheiro.assistencias} assist.' : ''}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  color: Cores.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${artilheiro.gols}',
          style: GoogleFonts.anybody(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Cores.verdePrincipal,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          artilheiro.gols == 1 ? 'gol' : 'gols',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            color: Cores.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
