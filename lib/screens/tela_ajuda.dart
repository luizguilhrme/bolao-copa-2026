import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/biblioteca.dart';
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
          _SecaoHeader(icone: Icons.emoji_events_rounded, titulo: 'PONTUAÇÃO — MODO CLÁSSICO'),
          const SizedBox(height: 16),
          const _ItemPontuacao(
            pontos: 100,
            descricao: 'Placar exato',
            exemplo: 'Palpitou 2×1  →  jogo foi 2×1',
          ),
          const _ItemPontuacao(
            pontos: 70,
            descricao: 'Vencedor + saldo de gols',
            exemplo: 'Palpitou 2×0  →  jogo foi 3×1',
          ),
          const _ItemPontuacao(
            pontos: 60,
            descricao: 'Vencedor + gols exatos de um time',
            exemplo: 'Palpitou 3×1  →  jogo foi 2×1',
          ),
          const _ItemPontuacao(
            pontos: 50,
            descricao: 'Só o vencedor / empate certo',
            exemplo: 'Palpitou 2×0  →  jogo foi 1×0',
          ),
          const _ItemPontuacao(
            pontos: 0,
            descricao: 'Errou tudo',
            exemplo: 'Nenhum critério acima',
          ),
          const _ItemPontuacao(
            pontos: -10,
            descricao: 'Não palpitou',
            exemplo: 'Sem palpite registrado antes do jogo',
          ),
          const SizedBox(height: 10),
          _CardMultiplicadores(),
          const SizedBox(height: 32),
          _SecaoHeader(icone: Icons.table_chart_rounded, titulo: 'PONTUAÇÃO — MODO COPA'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Palpite na classificação final de cada grupo (1º, 2º e 3º lugar).',
              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Cores.onSurfaceVariant),
            ),
          ),
          const _ItemPontuacao(
            pontos: 200,
            descricao: 'Posição exata',
            exemplo: 'Palpitou Brasil em 1º e ele ficou em 1º',
          ),
          const _ItemPontuacao(
            pontos: 100,
            descricao: 'Classificou, mas posição errada',
            exemplo: 'Palpitou 1º, time passou mas ficou em 2º',
          ),
          const _ItemPontuacao(
            pontos: 0,
            descricao: 'Time não classificou',
            exemplo: 'Palpitou que classificaria e não passou',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 18, color: Cores.verdePrincipal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bônus de +100 pts se acertar todas as posições do grupo (1º, 2º e 3º)',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Cores.verdePrincipal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _SecaoHeader(icone: Icons.stars_rounded, titulo: 'PALPITES ESPECIAIS'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Feitos antes da Copa começar. Calculados uma vez ao fim do torneio e '
              'valem em ambos os modos.',
              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Cores.onSurfaceVariant),
            ),
          ),
          const _ItemPontuacao(
            pontos: 500,
            descricao: 'Campeão do Torneio',
            exemplo: 'Time vencedor da Copa do Mundo 2026',
          ),
          const _ItemPontuacao(
            pontos: 300,
            descricao: 'Artilheiro da Copa',
            exemplo: 'Jogador com mais gols no torneio',
          ),
          const _ItemPontuacao(
            pontos: 300,
            descricao: 'Melhor Jogador da Copa',
            exemplo: 'Prêmio Bola de Ouro do torneio',
          ),
          const _ItemPontuacao(
            pontos: 300,
            descricao: 'Melhor Goleiro',
            exemplo: 'Prêmio Luva de Ouro do torneio',
          ),
          const _ItemPontuacao(
            pontos: 200,
            descricao: 'Equipe Mais Goleadora',
            exemplo: 'Time com mais gols marcados',
          ),
          const _ItemPontuacao(
            pontos: 200,
            descricao: 'Equipe Menos Vazada',
            exemplo: 'Time com menos gols sofridos',
          ),
          const SizedBox(height: 32),
          _SecaoHeader(icone: Icons.help_outline_rounded, titulo: 'PERGUNTAS FREQUENTES'),
          const SizedBox(height: 8),
          const _FaqItem(
            pergunta: 'Até quando posso fazer meu palpite?',
            resposta:
                'Palpites ficam disponíveis até 5 minutos antes do início de cada jogo. '
                'Após esse prazo, o botão de salvar é bloqueado automaticamente. '
                'Jogos das fases eliminatórias só aparecem na tela depois que os dois '
                'times do confronto forem definidos.',
          ),
          const _FaqItem(
            pergunta: 'Posso alterar meu palpite?',
            resposta:
                'Sim, você pode alterar seu palpite quantas vezes quiser antes do prazo '
                'de 5 minutos. Os Palpites Especiais e os palpites do Modo Copa ficam '
                'bloqueados com o início da Copa (ou quando o admin acionar o travamento '
                'antes disso).',
          ),
          const _FaqItem(
            pergunta: 'Quando os pontos são calculados?',
            resposta:
                'O admin insere o placar após o jogo e os pontos são calculados '
                'automaticamente pelo servidor. Nas fases eliminatórias, os pontos base '
                'são multiplicados pela fase: ×1,2 nos 16 avos, ×1,4 nas Oitavas, ×1,6 '
                'nas Quartas, ×1,8 na Semifinal e no 3º lugar, e ×2,0 na Final.',
          ),
          const _FaqItem(
            pergunta: 'Como funciona o ranking?',
            resposta:
                'O ranking mostra a classificação dentro de cada grupo e soma todas as '
                'pontuações (fase de grupos + eliminatórias + palpites especiais). '
                'Em caso de empate na pontuação, os critérios de desempate são, em ordem: '
                '(1) mais placares exatos acertados; (2) menos jogos sem palpite; '
                '(3) acerto do campeão; (4) acerto do artilheiro.',
          ),
          const _FaqItem(
            pergunta: 'O que acontece se eu não palpitar em um jogo?',
            resposta:
                'Se você não registrar um palpite em um jogo disputado após a sua data '
                'de cadastro, você perde 10 pontos (−10). Jogos disputados antes do seu '
                'cadastro não geram penalidade.',
          ),
          const _FaqItem(
            pergunta: 'Posso ver os palpites dos outros participantes?',
            resposta:
                'Sim — você pode ver os palpites de qualquer participante que compartilhe '
                'pelo menos um grupo com você. No Ranking, toque no card de um jogador. '
                'Na Tabela de Jogos, toque em um jogo encerrado para ver todos os '
                'palpites, ordenados por pontuação.',
          ),
          const _FaqItem(
            pergunta: 'Como funcionam os grupos?',
            resposta:
                'Grupos são o coração do bolão: o ranking só existe dentro dos grupos. '
                'Você pode criar um grupo (escolhendo Modo Clássico ou Modo Copa), '
                'compartilhar o código de 6 caracteres com os amigos e entrar em '
                'quantos grupos quiser. O dono do grupo pode editar o nome; os membros '
                'podem sair a qualquer momento.',
          ),
          const _FaqItem(
            pergunta: 'O que é o Modo Copa?',
            resposta:
                'No Modo Copa você palpita na classificação final de cada um dos '
                '12 grupos da Copa: quem ficou em 1º, 2º e 3º. Posição exata vale '
                '200 pts por time; classificou mas posição errada vale 100 pts; e há '
                'bônus de 100 pts ao acertar todas as posições do grupo. Os palpites '
                'ficam bloqueados com o início da Copa.',
          ),
          const _FaqItem(
            pergunta: 'O que são os Palpites Especiais?',
            resposta:
                'São 6 palpites feitos antes da Copa começar: Campeão (500 pts), '
                'Artilheiro (300 pts), Melhor Jogador (300 pts), Melhor Goleiro (300 pts), '
                'Equipe Mais Goleadora (200 pts) e Equipe Menos Vazada (200 pts). '
                'Os pontos são calculados uma única vez ao fim do torneio e contam '
                'tanto no Modo Clássico quanto no Modo Copa.',
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

// ─── Card de multiplicadores de fase ─────────────────────────────────────────

class _CardMultiplicadores extends StatelessWidget {
  static const _fases = [
    ('Fase de Grupos', '×1,0'),
    ('16 avos de Final', '×1,2'),
    ('Oitavas de Final', '×1,4'),
    ('Quartas de Final', '×1,6'),
    ('Semifinal / 3º Lugar', '×1,8'),
    ('Final', '×2,0'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Cores.verdePrincipal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cores.verdePrincipal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Multiplicadores de fase (eliminatórias)',
            style: GoogleFonts.anybody(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Cores.verdePrincipal,
            ),
          ),
          const SizedBox(height: 10),
          ..._fases.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      f.$2,
                      style: GoogleFonts.anybody(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Cores.verdePrincipal,
                      ),
                    ),
                  ),
                  Text(
                    f.$1,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: Cores.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Color get _corBadge => corPontuacao(pontos);
  Color get _corTexto => Colors.white;

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
                if (exemplo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    exemplo,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
                ],
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
