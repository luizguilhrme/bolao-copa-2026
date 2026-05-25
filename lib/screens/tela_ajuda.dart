import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/cores.dart';

class TelaAjuda extends StatelessWidget {
  const TelaAjuda({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.surface,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Cores.verdePrincipal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AJUDA & FAQ',
          style: TextStyle(
            color: Cores.verdePrincipal,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          _SecaoHeader(icone: Icons.emoji_events_rounded, titulo: 'PONTUAÇÃO'),
          const SizedBox(height: 16),
          const _ItemPontuacao(
            pontos: 10,
            descricao: 'Placar exato',
            exemplo: 'Palpitou 2×1  →  jogo foi 2×1',
          ),
          const _ItemPontuacao(
            pontos: 7,
            descricao: 'Vencedor + saldo de gols',
            exemplo: 'Palpitou 2×0  →  jogo foi 3×1',
          ),
          const _ItemPontuacao(
            pontos: 5,
            descricao: 'Apenas o vencedor',
            exemplo: 'Palpitou 2×0  →  jogo foi 1×0',
          ),
          const _ItemPontuacao(
            pontos: 4,
            descricao: 'Empate (sem placar exato)',
            exemplo: 'Palpitou 1×1  →  jogo foi 0×0',
          ),
          const _ItemPontuacao(
            pontos: 0,
            descricao: 'Errou tudo',
            exemplo: 'Nenhum critério acima',
          ),
          const _ItemPontuacao(
            pontos: -1,
            descricao: 'Esqueceu de palpitar',
            exemplo: 'Sem palpite registrado antes do jogo',
          ),
          const SizedBox(height: 32),
          _SecaoHeader(icone: Icons.help_outline_rounded, titulo: 'PERGUNTAS FREQUENTES'),
          const SizedBox(height: 8),
          const _FaqItem(
            pergunta: 'Até quando posso fazer meu palpite?',
            resposta:
                'Palpites ficam disponíveis até 5 minutos antes do início de cada jogo. '
                'Após esse prazo, o botão de salvar é bloqueado automaticamente.',
          ),
          const _FaqItem(
            pergunta: 'Posso alterar meu palpite?',
            resposta:
                'Sim, você pode alterar seu palpite quantas vezes quiser antes do prazo de 5 minutos.',
          ),
          const _FaqItem(
            pergunta: 'Quando os pontos são calculados?',
            resposta:
                'O admin insere o placar após o jogo. Os pontos são calculados '
                'automaticamente pelo servidor e o ranking é atualizado em tempo real.',
          ),
          const _FaqItem(
            pergunta: 'Como funciona o ranking?',
            resposta:
                'O ranking é a soma das pontuações de todos os seus palpites acertados. '
                'Em caso de empate na pontuação, os jogadores aparecem na mesma posição.',
          ),
          const _FaqItem(
            pergunta: 'O que acontece se eu não palpitar em um jogo?',
            resposta:
                'Se você não registrar um palpite em um jogo disputado após a sua data de cadastro, '
                'você perde 1 ponto (−1). Jogos disputados antes do seu cadastro não geram penalidade.',
          ),
          const _FaqItem(
            pergunta: 'Posso ver os palpites dos outros participantes?',
            resposta:
                'Sim — após o jogo ser encerrado, você pode tocar no card de qualquer jogador no Ranking '
                'para ver os palpites dele. Na Tabela de jogos, toque em um jogo encerrado para ver '
                'todos os palpites registrados, ordenados por pontuação.',
          ),
        ],
      ),
    );
  }
}

// ─── Cabeçalho de seção ───────────────────────────────────────────────────────

class _SecaoHeader extends StatelessWidget {
  const _SecaoHeader({required this.icone, required this.titulo});

  final IconData icone;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, color: Cores.verdePrincipal, size: 20),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: GoogleFonts.anybody(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Cores.verdePrincipal,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Item de pontuação ────────────────────────────────────────────────────────

class _ItemPontuacao extends StatelessWidget {
  const _ItemPontuacao({
    required this.pontos,
    required this.descricao,
    required this.exemplo,
  });

  final int pontos;
  final String descricao;
  final String exemplo;

  Color get _corBadge {
    if (pontos == -1) return const Color(0xFFE53935);
    if (pontos == 10) return const Color(0xFF006D32);
    if (pontos == 7) return const Color(0xFF1B7F3A);
    if (pontos == 5) return const Color(0xFF4CAF50);
    if (pontos == 4) return const Color(0xFFFCD400);
    return const Color(0xFFBBCBB9);
  }

  Color get _corTexto => pontos == 4 ? Cores.onSecondaryContainer : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _corBadge,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$pontos',
                  style: GoogleFonts.anybody(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _corTexto,
                    height: 1,
                  ),
                ),
                Text(
                  'pts',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _corTexto.withValues(alpha: 0.8),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descricao,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exemplo,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: Cores.onSurfaceVariant,
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

// ─── Item FAQ ─────────────────────────────────────────────────────────────────

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.pergunta, required this.resposta});

  final String pergunta;
  final String resposta;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Cores.surface,
        border: Border.all(color: Cores.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            pergunta,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Cores.onSurface,
            ),
          ),
          iconColor: Cores.verdePrincipal,
          collapsedIconColor: Cores.onSurfaceVariant,
          children: [
            Text(
              resposta,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: Cores.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
