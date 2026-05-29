import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cores.dart';

// =============================================================================
// biblioteca.dart — funções utilitárias do projeto Bolão Copa 2026
//
// Todas as funções aqui são top-level: existem soltas no arquivo, sem classe
// container. Isso é idiomático em Dart — funções top-level são cidadãs de
// primeira classe na linguagem, exatamente como runApp() e showDialog() do
// próprio Flutter.
//
// Para usar em qualquer tela ou service, basta importar este arquivo:
//   import '../utils/biblioteca.dart';
//
// E chamar diretamente pelo nome, sem prefixo de classe:
//   flagDe('Brazil')       → '🇧🇷'
//   siglaDe('Germany')     → 'GER'
//   formatarData(agora)    → '12/06/2026 às 20h00'
// =============================================================================

// -----------------------------------------------------------------------------
// Formatação de data
// -----------------------------------------------------------------------------

/// Formata um [DateTime] para exibição legível ao usuário.
/// Exemplo: DateTime de 2026-06-12 20:00 → "12/06/2026 às 20h00"
///
/// Recebe um [DateTime] já convertido para o fuso local do dispositivo.
/// A conversão de UTC → local deve ser feita antes de chamar esta função:
///   formatarData(jogo.dataHora.toLocal())
String formatarData(DateTime data) {
  final local = data.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} às '
      '${local.hour.toString().padLeft(2, '0')}h'
      '${local.minute.toString().padLeft(2, '0')}';
}

// -----------------------------------------------------------------------------
// Feedback visual
// -----------------------------------------------------------------------------

/// Exibe um [SnackBar] padronizado em qualquer tela.
///
/// O [ScaffoldMessenger] é um widget que vive acima do Scaffold na árvore
/// e gerencia a fila de SnackBars. Usar `of(context)` localiza o messenger
/// mais próximo — o mesmo padrão de Theme.of(context) e Navigator.of(context).
void mostrarMensagem(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(mensagem)),
  );
}

// -----------------------------------------------------------------------------
// Bandeiras e siglas
//
// Usadas em tela_home.dart e tela_tabela.dart para converter o nome completo
// do time (como vem do Firestore) para emoji de bandeira e sigla de 3 letras.
//
// Os mapas são declarados como `const` dentro das funções: isso significa que
// Dart os compila como constantes em tempo de compilação — a memória é alocada
// uma única vez e o mapa nunca é recriado, independente de quantas vezes a
// função for chamada.
// -----------------------------------------------------------------------------

/// Retorna o emoji de bandeira correspondente ao nome completo do país.
/// Para times ainda indefinidos nas fases eliminatórias ("Vencedor 73", "1A"),
/// retorna '🏳️' como fallback.
String flagDe(String team) {
  const flags = {
    'Mexico': '🇲🇽',
    'Poland': '🇵🇱',
    'USA': '🇺🇸',
    'United States': '🇺🇸',
    'Canada': '🇨🇦',
    'Brazil': '🇧🇷',
    'Argentina': '🇦🇷',
    'France': '🇫🇷',
    'Germany': '🇩🇪',
    'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
    'Spain': '🇪🇸',
    'Portugal': '🇵🇹',
    'Netherlands': '🇳🇱',
    'Belgium': '🇧🇪',
    'Croatia': '🇭🇷',
    'Morocco': '🇲🇦',
    'Japan': '🇯🇵',
    'South Korea': '🇰🇷',
    'Australia': '🇦🇺',
    'Senegal': '🇸🇳',
    'Ecuador': '🇪🇨',
    'Uruguay': '🇺🇾',
    'Colombia': '🇨🇴',
    'Chile': '🇨🇱',
    'Peru': '🇵🇪',
    'Venezuela': '🇻🇪',
    'Paraguay': '🇵🇾',
    'Bolivia': '🇧🇴',
    'Iran': '🇮🇷',
    'Saudi Arabia': '🇸🇦',
    'Qatar': '🇶🇦',
    'Turkey': '🇹🇷',
    'Ukraine': '🇺🇦',
    'Switzerland': '🇨🇭',
    'Serbia': '🇷🇸',
    'Denmark': '🇩🇰',
    'Austria': '🇦🇹',
    'Czech Republic': '🇨🇿',
    'Slovakia': '🇸🇰',
    'Hungary': '🇭🇺',
    'Romania': '🇷🇴',
    'Greece': '🇬🇷',
    'Algeria': '🇩🇿',
    'Nigeria': '🇳🇬',
    'Ghana': '🇬🇭',
    'Cameroon': '🇨🇲',
    'Ivory Coast': '🇨🇮',
    'Egypt': '🇪🇬',
    'Tunisia': '🇹🇳',
    'Mali': '🇲🇱',
    'South Africa': '🇿🇦',
    'DR Congo': '🇨🇩',
    'New Zealand': '🇳🇿',
    'Panama': '🇵🇦',
    'Costa Rica': '🇨🇷',
    'Honduras': '🇭🇳',
    'Jamaica': '🇯🇲',
    'Indonesia': '🇮🇩',
    'Vietnam': '🇻🇳',
    'China': '🇨🇳',
    'Philippines': '🇵🇭',
    'Wales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
    'Scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
    'Ireland': '🇮🇪',
    'Norway': '🇳🇴',
    'Sweden': '🇸🇪',
    'Finland': '🇫🇮',
    'Iceland': '🇮🇸',
    'Israel': '🇮🇱',
    'UAE': '🇦🇪',
    'Iraq': '🇮🇶',
    'Kuwait': '🇰🇼',
    'Guatemala': '🇬🇹',
    'El Salvador': '🇸🇻',
    'Trinidad and Tobago': '🇹🇹',
    'Kenya': '🇰🇪',
    'Tanzania': '🇹🇿',
    'Uganda': '🇺🇬',
    'Cuba': '🇨🇺',
  };
  return flags[team] ?? '🏳️';
}

/// Retorna o nome do país em português a partir do nome em inglês.
/// Cobre todos os 48 seleções da Copa 2026. Retorna o próprio nome
/// em inglês como fallback para times não mapeados.
String nomePtDe(String team) {
  const nomes = {
    // Copa 2026 — Grupo A
    'Mexico': 'México',
    'South Africa': 'África do Sul',
    'South Korea': 'Coreia do Sul',
    'Czech Republic': 'Rep. Tcheca',
    // Grupo B
    'Canada': 'Canadá',
    'Bosnia & Herzegovina': 'Bósnia e Herzeg.',
    'Qatar': 'Catar',
    'Switzerland': 'Suíça',
    // Grupo C
    'Brazil': 'Brasil',
    'Morocco': 'Marrocos',
    'Haiti': 'Haiti',
    'Scotland': 'Escócia',
    // Grupo D
    'USA': 'EUA',
    'Paraguay': 'Paraguai',
    'Australia': 'Austrália',
    'Turkey': 'Turquia',
    // Grupo E
    'Germany': 'Alemanha',
    'Curaçao': 'Curaçao',
    'Ivory Coast': 'Costa do Marfim',
    'Ecuador': 'Equador',
    // Grupo F
    'Netherlands': 'Holanda',
    'Japan': 'Japão',
    'Sweden': 'Suécia',
    'Tunisia': 'Tunísia',
    // Grupo G
    'Belgium': 'Bélgica',
    'Egypt': 'Egito',
    'Iran': 'Irã',
    'New Zealand': 'Nova Zelândia',
    // Grupo H
    'Spain': 'Espanha',
    'Cape Verde': 'Cabo Verde',
    'Saudi Arabia': 'Arábia Saudita',
    'Uruguay': 'Uruguai',
    // Grupo I
    'France': 'França',
    'Senegal': 'Senegal',
    'Iraq': 'Iraque',
    'Norway': 'Noruega',
    // Grupo J
    'Argentina': 'Argentina',
    'Algeria': 'Argélia',
    'Austria': 'Áustria',
    'Jordan': 'Jordânia',
    // Grupo K
    'Portugal': 'Portugal',
    'DR Congo': 'Congo',
    'Uzbekistan': 'Uzbequistão',
    'Colombia': 'Colômbia',
    // Grupo L
    'England': 'Inglaterra',
    'Croatia': 'Croácia',
    'Ghana': 'Gana',
    'Panama': 'Panamá',
  };
  return nomes[team] ?? team;
}

/// Retorna o código ISO 3166-1 alpha-2 do país (ex: 'BR', 'FR').
/// Para nações do Reino Unido usa o formato de subdivisão (ex: 'GB-ENG').
/// Retorna string vazia como fallback para times não mapeados.
String isoDe(String team) {
  const isos = {
    // Copa 2026 — todos os 48 times
    'Mexico': 'MX', 'Canada': 'CA', 'Brazil': 'BR', 'Argentina': 'AR',
    'France': 'FR', 'Germany': 'DE', 'Spain': 'ES', 'Portugal': 'PT',
    'Netherlands': 'NL', 'Belgium': 'BE', 'Croatia': 'HR', 'Morocco': 'MA',
    'Japan': 'JP', 'South Korea': 'KR', 'Australia': 'AU', 'Senegal': 'SN',
    'Ecuador': 'EC', 'Uruguay': 'UY', 'Colombia': 'CO', 'Iran': 'IR',
    'Saudi Arabia': 'SA', 'Qatar': 'QA', 'Turkey': 'TR', 'Switzerland': 'CH',
    'Austria': 'AT', 'Norway': 'NO', 'Sweden': 'SE', 'Denmark': 'DK',
    'Algeria': 'DZ', 'Tunisia': 'TN', 'Egypt': 'EG', 'Ghana': 'GH',
    'Ivory Coast': 'CI', 'DR Congo': 'CD', 'Nigeria': 'NG', 'Cameroon': 'CM',
    'New Zealand': 'NZ', 'Panama': 'PA', 'Paraguay': 'PY', 'South Africa': 'ZA',
    'Iraq': 'IQ', 'Jordan': 'JO', 'Serbia': 'RS', 'Czech Republic': 'CZ',
    'Cape Verde': 'CV', 'Uzbekistan': 'UZ', 'Haiti': 'HT',
    'Bosnia & Herzegovina': 'BA', 'Curaçao': 'CW',
    // UK nações com subdivison ISO 3166-2
    'England': 'GB-ENG', 'Wales': 'GB-WLS', 'Scotland': 'GB-SCT',
    // Outros países que aparecem nos dados
    'USA': 'US', 'United States': 'US', 'Poland': 'PL', 'Ukraine': 'UA',
    'Slovakia': 'SK', 'Hungary': 'HU', 'Romania': 'RO', 'Greece': 'GR',
    'Chile': 'CL', 'Peru': 'PE', 'Venezuela': 'VE', 'Bolivia': 'BO',
    'Indonesia': 'ID', 'Vietnam': 'VN', 'China': 'CN', 'Philippines': 'PH',
    'Ireland': 'IE', 'Finland': 'FI', 'Iceland': 'IS', 'Israel': 'IL',
    'UAE': 'AE', 'Kuwait': 'KW', 'Guatemala': 'GT', 'El Salvador': 'SV',
    'Trinidad and Tobago': 'TT', 'Cuba': 'CU', 'Costa Rica': 'CR',
    'Honduras': 'HN', 'Jamaica': 'JM', 'Kenya': 'KE', 'Tanzania': 'TZ',
    'Uganda': 'UG', 'Mali': 'ML',
  };
  return isos[team] ?? '';
}

/// Widget que exibe a bandeira de um país como imagem (via country_flags).
/// [tamanho] define largura e altura em pixels lógicos.
/// Para uso em containers circulares, o pai deve usar clipBehavior: Clip.antiAlias.
/// Mostra '🏳️' como fallback para times não mapeados.
class Bandeira extends StatelessWidget {
  const Bandeira(this.team, {super.key, this.tamanho = 24});

  final String team;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final iso = isoDe(team);
    if (iso.isEmpty) {
      return SizedBox(
        width: tamanho,
        height: tamanho,
        child: Center(
          child: Text('🏳️', style: TextStyle(fontSize: tamanho * 0.5)),
        ),
      );
    }
    return CountryFlag.fromCountryCode(
      iso,
      theme: ImageTheme(width: tamanho, height: tamanho),
    );
  }
}

/// Calcula os pontos BASE de um palpite (sem multiplicador de fase).
/// Espelha _calcularPontos em tela_palpites.dart.
int calcularPontos(int p1, int p2, int r1, int r2) {
  if (p1 == r1 && p2 == r2) return 100;
  final sP = p1 - p2, sR = r1 - r2;
  final vP = p1.compareTo(p2), vR = r1.compareTo(r2);
  if (vP != vR) return 0;
  if (vP != 0) {
    if (sP == sR) return 70;
    if (p1 == r1 || p2 == r2) return 60;
    return 50;
  }
  return 50;
}

/// Multiplicador de pontuação por fase eliminatória.
/// Espelha _multiplicador em tela_palpites.dart.
double multiplicadorFase(String round) {
  switch (round) {
    case '16 avos de Final':    return 1.2;
    case 'Oitavas de Final':    return 1.4;
    case 'Quartas de Final':    return 1.6;
    case 'Semifinal':
    case 'Disputa de 3º Lugar': return 1.8;
    case 'Final':               return 2.0;
    default:                    return 1.0;
  }
}

/// Pontos reais considerando a fase do jogo.
int calcularPontosComFase(int p1, int p2, int r1, int r2, String round) {
  final base = calcularPontos(p1, p2, r1, r2);
  if (base == 0) return 0;
  return (base * multiplicadorFase(round)).round();
}

/// Lista dos 48 times da Copa 2026 (nomes em inglês, mesmos usados no Firestore).
/// Usada no diálogo de palpite especial (seleção de campeão).
const kTimesCopa2026 = [
  // Grupo A
  'Mexico', 'South Africa', 'South Korea', 'Czech Republic',
  // Grupo B
  'Canada', 'Bosnia & Herzegovina', 'Qatar', 'Switzerland',
  // Grupo C
  'Brazil', 'Morocco', 'Haiti', 'Scotland',
  // Grupo D
  'USA', 'Paraguay', 'Australia', 'Turkey',
  // Grupo E
  'Germany', 'Curaçao', 'Ivory Coast', 'Ecuador',
  // Grupo F
  'Netherlands', 'Japan', 'Sweden', 'Tunisia',
  // Grupo G
  'Belgium', 'Egypt', 'Iran', 'New Zealand',
  // Grupo H
  'Spain', 'Cape Verde', 'Saudi Arabia', 'Uruguay',
  // Grupo I
  'France', 'Senegal', 'Iraq', 'Norway',
  // Grupo J
  'Argentina', 'Algeria', 'Austria', 'Jordan',
  // Grupo K
  'Portugal', 'DR Congo', 'Uzbekistan', 'Colombia',
  // Grupo L
  'England', 'Croatia', 'Ghana', 'Panama',
];

/// Retorna true se o nome do time ainda é um placeholder (confronto não definido).
/// Exemplos: "1A", "2B", "3°", "Vencedor 73", "Perdedor 101".
bool ehPlaceholder(String team) =>
    RegExp(r'^[12][A-L]$').hasMatch(team) ||
    team.contains('°') ||
    team.startsWith('Vencedor ') ||
    team.startsWith('Perdedor ');

/// Exibe o bottom sheet de regras de pontuação (Modo Clássico + Modo Copa).
/// Pode ser chamado de qualquer tela que tenha um [BuildContext] válido.
void mostrarRegras(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BottomSheetRegras(),
  );
}

class _BottomSheetRegras extends StatelessWidget {
  const _BottomSheetRegras();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Cores.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Alça de arrasto
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Cores.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Título fixo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Cores.verdePrincipal, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'REGRAS DE PONTUAÇÃO',
                    style: GoogleFonts.anybody(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Cores.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Cores.outlineVariant),
            // Conteúdo scrollável
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  // ── Modo Clássico ──────────────────────────────────────
                  _SecaoRegra(
                    cor: Cores.verdePrincipal,
                    icone: Icons.sports_soccer_rounded,
                    titulo: 'MODO CLÁSSICO',
                    subtitulo: 'Palpite no placar de cada jogo',
                  ),
                  const SizedBox(height: 12),
                  const _LinhaRegra(
                    pontos: 100,
                    descricao: 'Placar exato',
                    exemplo: 'Palpitou 2×1, jogo foi 2×1',
                  ),
                  const _LinhaRegra(
                    pontos: 70,
                    descricao: 'Vencedor + saldo de gols',
                    exemplo: 'Palpitou 2×0, jogo foi 3×1',
                  ),
                  const _LinhaRegra(
                    pontos: 60,
                    descricao: 'Vencedor + gols exatos de um time',
                    exemplo: 'Palpitou 3×1, jogo foi 2×1',
                  ),
                  const _LinhaRegra(
                    pontos: 50,
                    descricao: 'Só o vencedor certo',
                    exemplo: 'Palpitou 2×0, jogo foi 1×0',
                  ),
                  const _LinhaRegra(
                    pontos: 50,
                    descricao: 'Empate certo (placar errado)',
                    exemplo: 'Palpitou 1×1, jogo foi 2×2',
                  ),
                  const _LinhaRegra(
                    pontos: 0,
                    descricao: 'Errou tudo',
                    exemplo: 'Palpitou vitória, deu empate',
                  ),
                  const _LinhaRegra(
                    pontos: -10,
                    descricao: 'Não palpitou',
                    exemplo: 'Sem palpite antes do jogo começar',
                  ),
                  const SizedBox(height: 16),
                  // Multiplicadores
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Cores.verdePrincipal.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Cores.verdePrincipal.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multiplicadores por fase',
                            style: GoogleFonts.anybody(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Cores.verdePrincipal)),
                        const SizedBox(height: 8),
                        _LinhaMultiplicador('Fase de Grupos', '×1,0'),
                        _LinhaMultiplicador('16 avos de Final', '×1,2'),
                        _LinhaMultiplicador('Oitavas de Final', '×1,4'),
                        _LinhaMultiplicador('Quartas de Final', '×1,6'),
                        _LinhaMultiplicador('Semifinal + 3º lugar', '×1,8'),
                        _LinhaMultiplicador('Final', '×2,0'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Modo Copa ──────────────────────────────────────────
                  _SecaoRegra(
                    cor: Cores.azulTerciario,
                    icone: Icons.leaderboard_rounded,
                    titulo: 'MODO COPA',
                    subtitulo: 'Palpite na classificação de cada grupo',
                  ),
                  const SizedBox(height: 12),
                  const _LinhaRegra(
                    pontos: 200,
                    corOverride: Cores.azulTerciario,
                    descricao: 'Posição exata (1º, 2º ou 3º)',
                    exemplo: 'Palpitou Brasil em 1º, foi 1º',
                  ),
                  const _LinhaRegra(
                    pontos: 100,
                    corOverride: Color(0xFF3B6FD4),
                    descricao: 'Classificou, mas posição errada',
                    exemplo: 'Palpitou 1º, time terminou em 2º',
                  ),
                  const _LinhaRegra(
                    pontos: 0,
                    descricao: 'Time não classificou',
                    exemplo: 'Time ficou em 4º ou foi eliminado',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Cores.azulTerciario.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Cores.azulTerciario.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Cores.azulTerciario,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('+100',
                              style: GoogleFonts.anybody(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bônus por grupo: acertou todas as posições exatas',
                            style: GoogleFonts.hankenGrotesk(
                                fontSize: 13, color: Cores.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pontuação por time — ex: 1º e 2º exatos + 3º errado = +400 pts no grupo.',
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: Cores.onSurfaceVariant,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No mata-mata, o Modo Copa segue as mesmas regras do Modo Clássico com os multiplicadores de fase.',
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: Cores.onSurfaceVariant,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 28),

                  // ── Palpites Especiais ─────────────────────────────────
                  _SecaoRegra(
                    cor: const Color(0xFFB8860B),
                    icone: Icons.star_rounded,
                    titulo: 'PALPITES ESPECIAIS',
                    subtitulo: 'Calculados uma única vez após o torneio',
                  ),
                  const SizedBox(height: 12),
                  const _LinhaEspecial('Campeão do Torneio', '+500'),
                  const _LinhaEspecial('Artilheiro da Copa', '+300'),
                  const _LinhaEspecial('Melhor Jogador da Copa', '+300'),
                  const _LinhaEspecial('Melhor Goleiro', '+300'),
                  const _LinhaEspecial('Equipe Mais Goleadora', '+200'),
                  const _LinhaEspecial('Equipe Menos Vazada', '+200'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecaoRegra extends StatelessWidget {
  const _SecaoRegra({
    required this.cor,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
  });

  final Color cor;
  final IconData icone;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: cor, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cor,
                    letterSpacing: 0.3)),
            Text(subtitulo,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 12, color: Cores.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _LinhaRegra extends StatelessWidget {
  const _LinhaRegra({
    required this.pontos,
    required this.descricao,
    required this.exemplo,
    this.corOverride,
  });

  final int pontos;
  final String descricao;
  final String exemplo;
  final Color? corOverride;

  Color get _cor {
    if (corOverride != null) return corOverride!;
    if (pontos < 0) return const Color(0xFFE53935);
    if (pontos >= 100) return const Color(0xFF006D32);
    if (pontos >= 70) return const Color(0xFF1B7F3A);
    if (pontos >= 60) return const Color(0xFF2E7D52);
    if (pontos >= 50) return const Color(0xFF4CAF50);
    return const Color(0xFFBBCBB9);
  }

  Color get _corTexto =>
      _cor == const Color(0xFFBBCBB9) ? Cores.onSurface : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 40,
            decoration:
                BoxDecoration(color: _cor, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(
              pontos > 0 ? '+$pontos' : '$pontos',
              style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _corTexto),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(descricao,
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Cores.onSurface)),
                Text(exemplo,
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        color: Cores.onSurfaceVariant,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaMultiplicador extends StatelessWidget {
  const _LinhaMultiplicador(this.fase, this.valor);
  final String fase;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(fase,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 12, color: Cores.onSurface)),
          Text(valor,
              style: GoogleFonts.anybody(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Cores.verdePrincipal)),
        ],
      ),
    );
  }
}

class _LinhaEspecial extends StatelessWidget {
  const _LinhaEspecial(this.label, this.pontos);
  final String label;
  final String pontos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 13, color: Cores.onSurface)),
          Text(pontos,
              style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFB8860B))),
        ],
      ),
    );
  }
}

/// Retorna a sigla de 3 letras correspondente ao nome completo do país.
/// Para times não mapeados, usa as 3 primeiras letras do nome em maiúsculo
/// como fallback — ex: "Vencedor 73" → "VEN".
String siglaDe(String team) {
  const siglas = {
    'Mexico': 'MEX',
    'Poland': 'POL',
    'USA': 'USA',
    'United States': 'USA',
    'Canada': 'CAN',
    'Brazil': 'BRA',
    'Argentina': 'ARG',
    'France': 'FRA',
    'Germany': 'GER',
    'England': 'ENG',
    'Spain': 'ESP',
    'Portugal': 'POR',
    'Netherlands': 'NED',
    'Belgium': 'BEL',
    'Croatia': 'CRO',
    'Morocco': 'MAR',
    'Japan': 'JPN',
    'South Korea': 'KOR',
    'Australia': 'AUS',
    'Senegal': 'SEN',
    'Ecuador': 'ECU',
    'Uruguay': 'URU',
    'Colombia': 'COL',
    'Chile': 'CHI',
    'Peru': 'PER',
    'Venezuela': 'VEN',
    'Paraguay': 'PAR',
    'Bolivia': 'BOL',
    'Iran': 'IRN',
    'Saudi Arabia': 'KSA',
    'Qatar': 'QAT',
    'Turkey': 'TUR',
    'Ukraine': 'UKR',
    'Switzerland': 'SUI',
    'Serbia': 'SRB',
    'Denmark': 'DEN',
    'Austria': 'AUT',
    'Norway': 'NOR',
    'Sweden': 'SWE',
    'Wales': 'WAL',
    'Scotland': 'SCO',
    'Ireland': 'IRL',
    'Nigeria': 'NGA',
    'Ghana': 'GHA',
    'Cameroon': 'CMR',
    'Ivory Coast': 'CIV',
    'Egypt': 'EGY',
    'Algeria': 'ALG',
    'Indonesia': 'IDN',
    'China': 'CHN',
    'Philippines': 'PHI',
  };
  return siglas[team] ??
      team.substring(0, team.length.clamp(0, 3)).toUpperCase();
}