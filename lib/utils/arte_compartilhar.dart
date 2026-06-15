import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/jogo.dart';
import '../models/palpite.dart';
import 'avatares.dart';
import 'biblioteca.dart';
import 'cores.dart';

// =============================================================================
// arte_compartilhar.dart — arte "Figurinha" (1080×1920, formato story)
//
// Card colecionável estilo álbum com moldura dourada sobre fundo verde com
// pontilhado e brilho neon. O que aparece é controlado por OpcoesArte
// (escolhido pelo usuário na TelaCompartilhar): perfil (avatar + nome),
// @usuário, pontuação e posição no ranking de um dos bolões.
// Design definido no protótipo post-instagram/ (stories.jsx).
// =============================================================================

// ─── Cores próprias da arte (fora da paleta de telas) ────────────────────────
const _verdeNeon = Color(0xFF00D166);
const _amarelo = Cores.secondaryContainer; // #FCD400
const _textoSobreNeon = Color(0xFF06240F);
const _cardEscuroTopo = Color(0xFF0B3B22);
const _cardEscuroBase = Color(0xFF06240F);
const _fundoBandeira = Color(0xFF0B271A);

/// Tom de acento de cada seleção — usado na borda da bandeira.
const _coresTimes = <String, Color>{
  'Mexico': Color(0xFF0B6E3B),
  'South Africa': Color(0xFF007749),
  'South Korea': Color(0xFFC8102E),
  'Czech Republic': Color(0xFF11457E),
  'Canada': Color(0xFFD52B1E),
  'Bosnia & Herzegovina': Color(0xFF002395),
  'Qatar': Color(0xFF8A1538),
  'Switzerland': Color(0xFFD52B1E),
  'Brazil': Color(0xFFFCD400),
  'Morocco': Color(0xFFC1272D),
  'Haiti': Color(0xFF00209F),
  'Scotland': Color(0xFF005EB8),
  'USA': Color(0xFF0A3161),
  'Paraguay': Color(0xFFD52B1E),
  'Australia': Color(0xFF00843D),
  'Turkey': Color(0xFFE30A17),
  'Germany': Color(0xFF1A1A1A),
  'Curaçao': Color(0xFF002B7F),
  'CuraÃ§ao': Color(0xFF002B7F),
  'Ivory Coast': Color(0xFFF77F00),
  'Ecuador': Color(0xFFFFD100),
  'Netherlands': Color(0xFFF36C21),
  'Japan': Color(0xFF0B3DA0),
  'Sweden': Color(0xFF006AA7),
  'Tunisia': Color(0xFFE70013),
  'Belgium': Color(0xFFC8102E),
  'Egypt': Color(0xFFC8102E),
  'Iran': Color(0xFF239F40),
  'New Zealand': Color(0xFF1A1A1A),
  'Spain': Color(0xFFC60B1E),
  'Cape Verde': Color(0xFF003893),
  'Saudi Arabia': Color(0xFF006C35),
  'Uruguay': Color(0xFF7B9FCB),
  'France': Color(0xFF0B3DA0),
  'Senegal': Color(0xFF00853F),
  'Iraq': Color(0xFF1A1A1A),
  'Norway': Color(0xFFBA0C2F),
  'Argentina': Color(0xFF75AADB),
  'Algeria': Color(0xFF006233),
  'Austria': Color(0xFFED2939),
  'Jordan': Color(0xFF007A3D),
  'Portugal': Color(0xFFC8102E),
  'DR Congo': Color(0xFF007FFF),
  'Uzbekistan': Color(0xFF1EB53A),
  'Colombia': Color(0xFFFCD116),
  'England': Color(0xFF1A4FA0),
  'Croatia': Color(0xFFC8102E),
  'Ghana': Color(0xFF006B3F),
  'Panama': Color(0xFF005293),
};

Color _corTimeDe(String team) => _coresTimes[team] ?? Cores.verdePrincipal;

/// Rótulo curto do acerto, para reforçar a "história" do palpite.
String _rotuloAcerto(int base) {
  if (base >= 100) return 'PLACAR EXATO';
  if (base >= 70) return 'VENCEDOR + SALDO';
  if (base >= 60) return 'VENCEDOR + 1 TIME';
  if (base >= 50) return 'SÓ O VENCEDOR';
  return 'NÃO FOI DESSA VEZ';
}

/// Selo colado na moldura do card — texto e cores variam conforme o acerto.
({String texto, Color corFundo, Color corTexto}) _seloAcerto(int base) {
  if (base >= 100) {
    return (texto: 'CRAVOU! 🎯', corFundo: _verdeNeon, corTexto: _textoSobreNeon);
  }
  if (base >= 70) {
    return (texto: 'QUASE! 🔥', corFundo: _amarelo, corTexto: _textoSobreNeon);
  }
  if (base >= 60) {
    return (texto: 'BOA! 👏', corFundo: const Color(0xFFFF8A33), corTexto: Colors.white);
  }
  if (base >= 50) {
    return (texto: 'MEIO CERTO! ✅', corFundo: const Color(0xFF7FD1A0), corTexto: _textoSobreNeon);
  }
  return (texto: 'FOI MAL! 👎', corFundo: const Color(0xFFEF5350), corTexto: Colors.white);
}

/// Linha superior da arte: "3ª RODADA" na fase de grupos · fase no mata-mata.
String _rotuloRodada(Jogo jogo) {
  if (jogo.round == 'Fase de Grupos') {
    final numero = RegExp(r'\d+').firstMatch(jogo.matchday ?? '')?.group(0);
    if (numero != null) return '$numeroª RODADA';
    return 'FASE DE GRUPOS';
  }
  return jogo.round.toUpperCase().replaceAll('16 AVOS', '16-AVOS');
}

// ─── Opções de exibição ──────────────────────────────────────────────────────

/// Posição do usuário em um bolão, exibida na arte quando selecionada.
class RankingArte {
  const RankingArte({
    required this.nomeGrupo,
    required this.posicao,
    required this.total,
  });

  final String nomeGrupo;
  final int posicao;
  final int total;
}

/// O que mostrar na arte — controlado pelos toggles da TelaCompartilhar.
class OpcoesArte {
  const OpcoesArte({
    this.mostrarPerfil = true,
    this.mostrarArroba = true,
    this.mostrarPontos = false,
    this.ranking,
  });

  final bool mostrarPerfil;
  final bool mostrarArroba; // só tem efeito com mostrarPerfil
  final bool mostrarPontos;
  final RankingArte? ranking; // null = não mostrar posição
}

// ─── Arte (1080×1920) ────────────────────────────────────────────────────────

class ArteFigurinha extends StatelessWidget {
  const ArteFigurinha({
    super.key,
    required this.jogo,
    required this.palpite,
    required this.pontos,
    required this.pontosBase,
    required this.nome,
    required this.arroba,
    this.avatarId,
    this.opcoes = const OpcoesArte(),
  });

  final Jogo jogo;
  final Palpite palpite;
  final int pontos; // pontos exibidos (com multiplicador de fase)
  final int pontosBase; // pontos base — cor do badge e selo CRAVOU!
  final String nome;
  final String arroba; // sem o @
  final String? avatarId;
  final OpcoesArte opcoes;

  bool get _cravou => pontosBase >= 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.58, 1],
          colors: [Cores.verdePrincipal, Color(0xFF00481F), Color(0xFF002E14)],
        ),
      ),
      child: Stack(
        children: [
          // Pontilhado sutil cobrindo o fundo
          const Positioned.fill(
            child: CustomPaint(painter: _PontilhadoPainter()),
          ),
          // Brilho neon atrás do cabeçalho
          Positioned(
            top: -260,
            left: (1080 - 1200) / 2,
            child: Container(
              width: 1200,
              height: 640,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _verdeNeon.withValues(alpha: 0.28),
                    _verdeNeon.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.65],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(70, 108, 70, 88),
            child: Column(
              children: [
                _cabecalho(),
                const Spacer(),
                _cardColecionavel(),
                const Spacer(),
                Text(
                  'bolaodasoci2026.web.app',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Column(
      children: [
        Text(
          'BOLÃO',
          style: GoogleFonts.anybody(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            letterSpacing: 14,
            height: 1,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'CRAVA AÍ!',
          maxLines: 1,
          style: GoogleFonts.anybody(
            fontSize: 104,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            height: 1,
            color: _amarelo,
            shadows: const [
              Shadow(color: Color(0x47000000), blurRadius: 24, offset: Offset(0, 6)),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 46, height: 3, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(width: 18),
            Text(
              _rotuloRodada(jogo),
              maxLines: 1,
              style: GoogleFonts.anybody(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 18),
            Container(width: 46, height: 3, color: Colors.white.withValues(alpha: 0.35)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'COPA DO MUNDO 2026',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            letterSpacing: 5,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }

  Widget _cardColecionavel() {
    return Transform.rotate(
      angle: -2 * pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Moldura dourada holográfica
          Container(
            width: 800,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, 0.28, 0.56, 0.82],
                colors: [_amarelo, Color(0xFFFFE873), Color(0xFFE9B800), _amarelo],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 48,
                  offset: Offset(0, 28),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_cardEscuroTopo, _cardEscuroBase],
                  ),
                ),
                child: Stack(
                  children: [
                    // Brilho neon no canto superior direito do card
                    Positioned(
                      top: -120,
                      right: -120,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              _verdeNeon.withValues(alpha: 0.45),
                              _verdeNeon.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.7],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(46, 40, 46, 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (opcoes.mostrarPerfil) ...[
                            _linhaPerfil(),
                            const SizedBox(height: 30),
                          ],
                          _linhaGrupoData(),
                          const SizedBox(height: 34),
                          _confronto(),
                          // Quem avançou nos pênaltis/prorrogação (regra dos 90 min)
                          if (jogo.vencedor != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              'AVANÇOU: ${nomePtDe(jogo.vencedor!).toUpperCase()}'
                              '${jogo.placarDecisao != null ? ' ${jogo.placarDecisao}' : ''}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                          const SizedBox(height: 34),
                          Container(height: 2, color: Colors.white.withValues(alpha: 0.16)),
                          const SizedBox(height: 28),
                          _linhaPalpite(),
                          if (opcoes.ranking != null) ...[
                            const SizedBox(height: 24),
                            _linhaRanking(opcoes.ranking!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Selo do acerto — fora da moldura, cor e texto conforme a pontuação
          Positioned(
            top: -46,
            right: 18,
            child: Transform.rotate(
              angle: 6 * pi / 180,
              child: Builder(
                builder: (_) {
                  final selo = _seloAcerto(pontosBase);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    decoration: BoxDecoration(
                      color: selo.corFundo,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Text(
                      selo.texto,
                      maxLines: 1,
                      style: GoogleFonts.anybody(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: selo.corTexto,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaPerfil() {
    return Row(
      children: [
        WidgetAvatar(
          avatarId: avatarId,
          nome: nome,
          tamanho: 78,
          corFundo: _fundoBandeira,
          borderColor: _amarelo,
          borderWidth: 3,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anybody(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: Colors.white,
                ),
              ),
              if (opcoes.mostrarArroba) ...[
                const SizedBox(height: 2),
                Text(
                  '@$arroba',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _linhaGrupoData() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          (jogo.group ?? jogo.round).toUpperCase(),
          style: GoogleFonts.anybody(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: _amarelo,
          ),
        ),
        Text(
          // Só a data, sem o horário ("13/06/2026")
          formatarData(jogo.dataHora.toLocal()).split(' às ').first,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }

  Widget _confronto() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _TimeFigurinha(nome: jogo.team1)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
          child: Column(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${jogo.placar1}'),
                    TextSpan(
                      text: ' : ',
                      style: const TextStyle(color: _amarelo, fontSize: 68),
                    ),
                    TextSpan(text: '${jogo.placar2}'),
                  ],
                ),
                style: GoogleFonts.anybody(
                  fontSize: 116,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'RESULTADO',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _TimeFigurinha(nome: jogo.team2)),
      ],
    );
  }

  Widget _linhaPalpite() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEU PALPITE',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${palpite.palpite1} × ${palpite.palpite2}',
                maxLines: 1,
                style: GoogleFonts.anybody(
                  fontSize: 76,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _rotuloAcerto(pontosBase),
                maxLines: 1,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: _cravou ? _verdeNeon : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        if (opcoes.mostrarPontos) ...[
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: _cravou ? _verdeNeon : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: _cravou
                  ? null
                  : Border.all(color: corPontuacao(pontosBase), width: 2),
            ),
            child: Column(
              children: [
                Text(
                  '$pontos',
                  style: GoogleFonts.anybody(
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: _cravou ? _textoSobreNeon : Colors.white,
                  ),
                ),
                Text(
                  'PONTOS',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: _cravou
                        ? _textoSobreNeon
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _linhaRanking(RankingArte ranking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _amarelo.withValues(alpha: 0.4), width: 2),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 40, height: 1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${ranking.posicao}º'),
                      TextSpan(
                        text: ' de ${ranking.total}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  style: GoogleFonts.anybody(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: _amarelo,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ranking.nomeGrupo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeFigurinha extends StatelessWidget {
  const _TimeFigurinha({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 168,
          height: 168,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _fundoBandeira,
            border: Border.all(color: _corTimeDe(nome), width: 5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.15),
                spreadRadius: 3,
              ),
            ],
          ),
          child: Bandeira(nome, tamanho: 168),
        ),
        const SizedBox(height: 16),
        Text(
          nomePtDe(nome),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.anybody(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Pontilhado branco sutil (grade 40×40, pontos de raio 2) sobre o fundo.
class _PontilhadoPainter extends CustomPainter {
  const _PontilhadoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 40) {
      for (double x = 0; x < size.width; x += 40) {
        canvas.drawCircle(Offset(x, y), 2, tinta);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PontilhadoPainter oldDelegate) => false;
}
