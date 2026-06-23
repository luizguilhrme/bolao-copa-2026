import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'biblioteca.dart';
import 'cores.dart';

// =============================================================================
// artilharia.dart — modelo e widgets da classificação de artilharia
//
// Compartilhado entre a tela Home (top 5) e a aba ARTILHARIA da tela Tabela
// (lista completa). Os dados vêm do documento api/artilharia do Firestore,
// alimentado pela Cloud Function sincronizarApi (GET /competitions/WC/scorers
// da football-data.org), que retorna apenas jogadores com pelo menos um gol,
// já ordenados. Leitura via ApiDadosService.buscarArtilharia().
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

  /// Reconstrói a partir de um item da lista `artilheiros` de api/artilharia.
  factory Artilheiro.fromMap(Map<String, dynamic> map) {
    return Artilheiro(
      nome: map['nome'] as String? ?? '',
      selecao: map['selecao'] as String? ?? '',
      gols: (map['gols'] as num?)?.toInt() ?? 0,
      assistencias: (map['assistencias'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Posição na classificação de artilharia considerando empates por gols
/// (ranking de competição: jogadores com o mesmo número de gols dividem a
/// mesma posição — 1, 1, 3, 3, …). Não há critério de desempate, então só
/// o número de gols importa. [lista] precisa estar ordenada por gols (desc).
int posicaoArtilheiro(List<Artilheiro> lista, int indice) {
  var posicao = 1;
  for (var i = 1; i <= indice; i++) {
    if (lista[i].gols != lista[i - 1].gols) posicao = i + 1;
  }
  return posicao;
}

/// Linha da classificação: posição (pódio colorido no top 3), bandeira,
/// nome, seleção/assistências e gols. Jogadores empatados em gols recebem a
/// mesma [posicao] (e o mesmo medalhão), pois não há critério de desempate.
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
