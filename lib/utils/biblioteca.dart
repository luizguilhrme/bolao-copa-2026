import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

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
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: CountryFlag.fromCountryCode(
          iso,
          theme: ImageTheme(width: tamanho * 2.2, height: tamanho),
        ),
      ),
    );
  }
}

/// Calcula os pontos de um palpite dado o resultado real.
int calcularPontos(int p1, int p2, int r1, int r2) {
  if (p1 == r1 && p2 == r2) return 10;
  final sP = p1 - p2, sR = r1 - r2;
  final vP = p1.compareTo(p2), vR = r1.compareTo(r2);
  if (sP == sR && vP == vR) return 7;
  if (vP == vR && vR != 0) return 5;
  if (vP == 0 && vR == 0) return 4;
  return 0;
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