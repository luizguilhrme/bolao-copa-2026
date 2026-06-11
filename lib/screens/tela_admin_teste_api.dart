import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';

// Cores e sombra em teste nesta tela (não fazem parte da paleta oficial):
// cards branco puro com sombra suave, sem borda.
const _azulAgendado = Color(0xFF1A7AE8);
const _sombraCard = [
  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
];

/// Tela de simulação da integração com a API football-data.org.
///
/// Todos os dados são fictícios, escritos manualmente no formato exato do
/// JSON retornado pela API (v4) — nenhuma requisição é feita e nada é
/// gravado no Firestore. Serve para validar o visual das seções que
/// futuramente usarão a API: chip de status ao vivo, placar parcial,
/// resultado com pênaltis e classificação de artilharia.
///
/// Nota: os nomes de time aqui usam a grafia do nosso jogos.json
/// ("Bosnia & Herzegovina", "Czech Republic"...). Na integração real, a API
/// usa grafias próprias ("Bosnia-Herzegovina", "Czechia") e o cruzamento
/// será feito por data/hora UTC + grupo, com o id da API salvo em cada jogo.

// ─── Dados simulados ──────────────────────────────────────────────────────────

/// Resposta simulada de GET /v4/competitions/WC/matches?dateFrom=...&dateTo=...
/// Um jogo por status possível: TIMED, IN_PLAY, PAUSED, FINISHED (90 min),
/// FINISHED na prorrogação (duration EXTRA_TIME) e FINISHED nos pênaltis
/// (duration PENALTY_SHOOTOUT). regularTime = placar dos 90 min, que é o
/// que vale para o bolão; fullTime inclui gols de prorrogação.
const List<Map<String, dynamic>> _jogosSimulados = [
  {
    'id': 537327,
    'utcDate': '2026-06-11T19:00:00Z',
    'status': 'TIMED',
    'stage': 'GROUP_STAGE',
    'group': 'GROUP_A',
    'homeTeam': {'name': 'Mexico'},
    'awayTeam': {'name': 'South Africa'},
    'score': {
      'winner': null,
      'duration': 'REGULAR',
      'fullTime': {'home': null, 'away': null},
    },
  },
  {
    'id': 537339,
    'utcDate': '2026-06-13T22:00:00Z',
    'status': 'IN_PLAY',
    'stage': 'GROUP_STAGE',
    'group': 'GROUP_C',
    'homeTeam': {'name': 'Brazil'},
    'awayTeam': {'name': 'Morocco'},
    'score': {
      'winner': null,
      'duration': 'REGULAR',
      'fullTime': {'home': 1, 'away': 0},
    },
  },
  {
    'id': 537357,
    'utcDate': '2026-06-14T20:00:00Z',
    'status': 'PAUSED',
    'stage': 'GROUP_STAGE',
    'group': 'GROUP_F',
    'homeTeam': {'name': 'Netherlands'},
    'awayTeam': {'name': 'Japan'},
    'score': {
      'winner': null,
      'duration': 'REGULAR',
      'fullTime': {'home': 2, 'away': 1},
    },
  },
  {
    'id': 537333,
    'utcDate': '2026-06-12T19:00:00Z',
    'status': 'FINISHED',
    'stage': 'GROUP_STAGE',
    'group': 'GROUP_B',
    'homeTeam': {'name': 'Canada'},
    'awayTeam': {'name': 'Bosnia & Herzegovina'},
    'score': {
      'winner': 'AWAY_TEAM',
      'duration': 'REGULAR',
      'fullTime': {'home': 0, 'away': 2},
    },
  },
  {
    'id': 537401,
    'utcDate': '2026-06-29T23:00:00Z',
    'status': 'FINISHED',
    'stage': 'LAST_32',
    'group': null,
    'homeTeam': {'name': 'Germany'},
    'awayTeam': {'name': 'Ivory Coast'},
    'score': {
      'winner': 'HOME_TEAM',
      'duration': 'PENALTY_SHOOTOUT',
      'fullTime': {'home': 1, 'away': 1},
      'regularTime': {'home': 1, 'away': 1},
      'penalties': {'home': 4, 'away': 2},
    },
  },
  {
    'id': 537410,
    'utcDate': '2026-07-05T19:00:00Z',
    'status': 'FINISHED',
    'stage': 'LAST_16',
    'group': null,
    'homeTeam': {'name': 'Argentina'},
    'awayTeam': {'name': 'England'},
    'score': {
      'winner': 'AWAY_TEAM',
      'duration': 'EXTRA_TIME',
      'fullTime': {'home': 1, 'away': 2},
      'regularTime': {'home': 1, 'away': 1},
    },
  },
];

/// Resposta simulada de GET /v4/competitions/WC/scorers?limit=100
/// A API só retorna jogadores com pelo menos 1 gol, já ordenados.
const Map<String, dynamic> _artilhariaSimulada = {
  'scorers': [
    {
      'player': {'name': 'Carlos Mendes'},
      'team': {'name': 'Brazil'},
      'goals': 7,
      'assists': 2,
      'penalties': 1,
    },
    {
      'player': {'name': 'Hans Zimmermann'},
      'team': {'name': 'Germany'},
      'goals': 6,
      'assists': 1,
      'penalties': 2,
    },
    {
      'player': {'name': 'Yuki Tanaka'},
      'team': {'name': 'Japan'},
      'goals': 5,
      'assists': 3,
      'penalties': 0,
    },
    {
      'player': {'name': 'Pierre Lefebvre'},
      'team': {'name': 'France'},
      'goals': 5,
      'assists': 0,
      'penalties': 1,
    },
    {
      'player': {'name': 'Diego Fernández'},
      'team': {'name': 'Argentina'},
      'goals': 4,
      'assists': 2,
      'penalties': 0,
    },
    {
      'player': {'name': 'Jan de Vries'},
      'team': {'name': 'Netherlands'},
      'goals': 3,
      'assists': 1,
      'penalties': 0,
    },
    {
      'player': {'name': 'Min-jun Park'},
      'team': {'name': 'South Korea'},
      'goals': 3,
      'assists': 0,
      'penalties': 1,
    },
    {
      'player': {'name': 'Ahmed Mansour'},
      'team': {'name': 'Egypt'},
      'goals': 2,
      'assists': 2,
      'penalties': 0,
    },
    {
      'player': {'name': 'Tiago Costa'},
      'team': {'name': 'Portugal'},
      'goals': 2,
      'assists': 0,
      'penalties': 0,
    },
    {
      'player': {'name': 'James Whitmore'},
      'team': {'name': 'England'},
      'goals': 1,
      'assists': 1,
      'penalties': 0,
    },
  ],
};

// ─── Parse do JSON — mesmo código que a integração real usará ─────────────────

class _JogoApi {
  final int id;
  final DateTime dataUtc;
  final String status;
  final String stage;
  final String? grupo;
  final String time1;
  final String time2;
  final int? fullTime1;
  final int? fullTime2;
  final int? regular1;
  final int? regular2;
  final int? penaltis1;
  final int? penaltis2;
  final String duracao;
  final String? winner;

  _JogoApi({
    required this.id,
    required this.dataUtc,
    required this.status,
    required this.stage,
    required this.grupo,
    required this.time1,
    required this.time2,
    required this.fullTime1,
    required this.fullTime2,
    required this.regular1,
    required this.regular2,
    required this.penaltis1,
    required this.penaltis2,
    required this.duracao,
    required this.winner,
  });

  factory _JogoApi.fromJson(Map<String, dynamic> json) {
    final score = json['score'] as Map<String, dynamic>;
    final fullTime = score['fullTime'] as Map<String, dynamic>;
    final regularTime = score['regularTime'] as Map<String, dynamic>?;
    final penalties = score['penalties'] as Map<String, dynamic>?;
    return _JogoApi(
      id: json['id'] as int,
      dataUtc: DateTime.parse(json['utcDate'] as String),
      status: json['status'] as String,
      stage: json['stage'] as String,
      grupo: json['group'] as String?,
      time1: (json['homeTeam'] as Map<String, dynamic>)['name'] as String,
      time2: (json['awayTeam'] as Map<String, dynamic>)['name'] as String,
      fullTime1: fullTime['home'] as int?,
      fullTime2: fullTime['away'] as int?,
      regular1: regularTime?['home'] as int?,
      regular2: regularTime?['away'] as int?,
      penaltis1: penalties?['home'] as int?,
      penaltis2: penalties?['away'] as int?,
      duracao: score['duration'] as String,
      winner: score['winner'] as String?,
    );
  }

  bool get aoVivo => status == 'IN_PLAY' || status == 'PAUSED';
  bool get encerrado => status == 'FINISHED';

  /// Placar principal — sempre o resultado dos 90 minutos (regra do bolão).
  /// A API só envia regularTime quando houve prorrogação; nos demais casos
  /// o fullTime já é o placar dos 90 min.
  int? get placar1 => regular1 ?? fullTime1;
  int? get placar2 => regular2 ?? fullTime2;

  /// Placar pequeno exibido sob o principal quando os 90 min empataram:
  /// pênaltis se houve disputa; senão, o placar final da prorrogação
  /// (mesmo que a prorrogação também tenha empatado, prevalecem os pênaltis).
  String? get placarDecisao {
    if (duracao == 'PENALTY_SHOOTOUT') return '($penaltis1 x $penaltis2)';
    if (duracao == 'EXTRA_TIME') return '($fullTime1 x $fullTime2)';
    return null;
  }

  /// Time que avançou quando decidido fora dos 90 min (campo `vencedor` nosso).
  String? get vencedorDecisao {
    if (duracao == 'REGULAR') return null;
    if (winner == 'HOME_TEAM') return time1;
    if (winner == 'AWAY_TEAM') return time2;
    return null;
  }

  /// "Grupo A" a partir de "GROUP_A"; nome da fase nos jogos de mata-mata.
  String get faseLabel {
    if (grupo != null) return 'Grupo ${grupo!.substring(6)}';
    const fases = {
      'LAST_32': '16 avos de Final',
      'LAST_16': 'Oitavas de Final',
      'QUARTER_FINALS': 'Quartas de Final',
      'SEMI_FINALS': 'Semifinal',
      'THIRD_PLACE': 'Disputa de 3º Lugar',
      'FINAL': 'Final',
    };
    return fases[stage] ?? stage;
  }
}

class _ArtilheiroApi {
  final String nome;
  final String selecao;
  final int gols;
  final int assistencias;

  _ArtilheiroApi({
    required this.nome,
    required this.selecao,
    required this.gols,
    required this.assistencias,
  });

  factory _ArtilheiroApi.fromJson(Map<String, dynamic> json) {
    return _ArtilheiroApi(
      nome: (json['player'] as Map<String, dynamic>)['name'] as String,
      selecao: (json['team'] as Map<String, dynamic>)['name'] as String,
      gols: json['goals'] as int,
      assistencias: (json['assists'] as int?) ?? 0,
    );
  }
}

// ─── Tela ─────────────────────────────────────────────────────────────────────

class TelaAdminTesteApi extends StatelessWidget {
  const TelaAdminTesteApi({super.key});

  @override
  Widget build(BuildContext context) {
    final jogos = _jogosSimulados.map(_JogoApi.fromJson).toList();
    final artilheiros =
        (_artilhariaSimulada['scorers'] as List)
            .map((j) => _ArtilheiroApi.fromJson(j as Map<String, dynamic>))
            .toList();

    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.verdePrincipal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'TESTE DE API',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _BannerSimulacao(),
          const SizedBox(height: 20),
          const _LabelSecao('JOGOS DE HOJE'),
          const SizedBox(height: 8),
          // Carrossel horizontal — mesmo funcionamento da seção da tela Home.
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: jogos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _CardJogoApi(jogo: jogos[i]),
            ),
          ),
          const SizedBox(height: 20),
          const _LabelSecao('ARTILHARIA'),
          const SizedBox(height: 8),
          _CardArtilharia(artilheiros: artilheiros),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Banner de aviso ──────────────────────────────────────────────────────────

class _BannerSimulacao extends StatelessWidget {
  const _BannerSimulacao();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Cores.azulTerciario.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cores.azulTerciario.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            color: Cores.azulTerciario,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Simulação com dados fictícios no formato real da API '
              'football-data.org. Nenhuma requisição é feita e nada é '
              'gravado no Firestore.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                color: Cores.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Label de seção ───────────────────────────────────────────────────────────

class _LabelSecao extends StatelessWidget {
  const _LabelSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: GoogleFonts.anybody(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Cores.onSurfaceVariant,
      ),
    );
  }
}

// ─── Chip de status ───────────────────────────────────────────────────────────

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, corFundo, corTexto, comPonto) = switch (status) {
      'IN_PLAY' => ('AO VIVO', Cores.error, Colors.white, true),
      'PAUSED' => (
        'INTERVALO',
        Cores.secondaryContainer,
        Cores.onSecondaryContainer,
        true,
      ),
      'FINISHED' => ('ENCERRADO', Cores.onSurfaceVariant, Colors.white, false),
      _ => ('AGENDADO', _azulAgendado, Colors.white, false),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (comPonto) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: corTexto,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.anybody(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: corTexto,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de jogo ─────────────────────────────────────────────────────────────

class _CardJogoApi extends StatelessWidget {
  const _CardJogoApi({required this.jogo});

  final _JogoApi jogo;

  String get _horarioLocal {
    final local = jogo.dataUtc.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}h'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: _sombraCard,
      ),
      child: Column(
        children: [
          // Linha superior: chip de status à esquerda, fase e horário à direita
          Row(
            children: [
              _ChipStatus(status: jogo.status),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${jogo.faseLabel} • $_horarioLocal',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        color: Cores.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linha principal: time1 — placar — time2.
          // Decisão fora dos 90 min: placar pequeno sob o principal (pênaltis
          // ou prorrogação) e check verde na bandeira de quem avançou.
          Row(
            children: [
              Expanded(
                child: _LadoTime(
                  time: jogo.time1,
                  avancou: jogo.vencedorDecisao == jogo.time1,
                ),
              ),
              _Placar(jogo: jogo),
              Expanded(
                child: _LadoTime(
                  time: jogo.time2,
                  avancou: jogo.vencedorDecisao == jogo.time2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LadoTime extends StatelessWidget {
  const _LadoTime({required this.time, this.avancou = false});

  final String time;

  /// Check verde sobre a bandeira — time que avançou após empate nos 90 min
  /// (decidido na prorrogação ou nos pênaltis).
  final bool avancou;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Cores.surfaceContainerHigh,
                border: Border.all(color: Cores.outlineVariant),
              ),
              child: Bandeira(time, tamanho: 36),
            ),
            if (avancou)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Cores.verdePrincipal,
                    size: 17,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          nomePtDe(time),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.anybody(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Cores.onSurface,
          ),
        ),
      ],
    );
  }
}

class _Placar extends StatelessWidget {
  const _Placar({required this.jogo});

  final _JogoApi jogo;

  @override
  Widget build(BuildContext context) {
    // Jogo ainda não começou: exibe "VS" no lugar do placar.
    if (jogo.placar1 == null || jogo.placar2 == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'VS',
          style: GoogleFonts.anybody(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Cores.outline,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${jogo.placar1}  x  ${jogo.placar2}',
            style: GoogleFonts.anybody(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: jogo.aoVivo ? Cores.error : Cores.onSurface,
            ),
          ),
          // Decisão fora dos 90 min: pênaltis ou placar da prorrogação
          if (jogo.placarDecisao != null)
            Text(
              jogo.placarDecisao!,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Cores.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Card de artilharia ───────────────────────────────────────────────────────

class _CardArtilharia extends StatelessWidget {
  const _CardArtilharia({required this.artilheiros});

  final List<_ArtilheiroApi> artilheiros;

  void _abrirDialogCompleto(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _DialogArtilharia(artilheiros: artilheiros),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top5 = artilheiros.take(5).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: _sombraCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _abrirDialogCompleto(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_soccer_rounded,
                      color: Cores.verdePrincipal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CHUTEIRA DE OURO',
                      style: GoogleFonts.anybody(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Cores.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < top5.length; i++) ...[
                  _LinhaArtilheiro(posicao: i + 1, artilheiro: top5[i]),
                  if (i < top5.length - 1)
                    const Divider(height: 12, color: Cores.surfaceVariant),
                ],
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Toque para ver a classificação completa',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11,
                      color: Cores.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinhaArtilheiro extends StatelessWidget {
  const _LinhaArtilheiro({required this.posicao, required this.artilheiro});

  final int posicao;
  final _ArtilheiroApi artilheiro;

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

// ─── Dialog com a classificação completa ──────────────────────────────────────

class _DialogArtilharia extends StatelessWidget {
  const _DialogArtilharia({required this.artilheiros});

  final List<_ArtilheiroApi> artilheiros;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: Cores.verdePrincipal,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'ARTILHARIA — COPA 2026',
                  style: GoogleFonts.anybody(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Cores.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Jogadores com pelo menos um gol.',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  color: Cores.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Cores.outlineVariant),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: artilheiros.length,
              separatorBuilder:
                  (_, _) =>
                      const Divider(height: 14, color: Cores.surfaceVariant),
              itemBuilder:
                  (_, i) => _LinhaArtilheiro(
                    posicao: i + 1,
                    artilheiro: artilheiros[i],
                  ),
            ),
          ),
          const Divider(height: 1, color: Cores.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'FECHAR',
                  style: GoogleFonts.anybody(
                    fontWeight: FontWeight.w700,
                    color: Cores.verdePrincipal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
