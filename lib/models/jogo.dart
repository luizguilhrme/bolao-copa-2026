import 'package:cloud_firestore/cloud_firestore.dart';

class Jogo {
  final int id;
  final String round;
  final String? matchday;
  final String date;       // mantemos os Strings originais do JSON
  final String time;       // para não quebrar o fromJson que já funciona
  final String team1;
  final String team2;
  final String? group;
  final String ground;
  int? placar1;
  int? placar2;

  Jogo({
    required this.id,
    required this.round,
    this.matchday,
    required this.date,
    required this.time,
    required this.team1,
    required this.team2,
    this.group,
    required this.ground,
    this.placar1,
    this.placar2,
  });

  // fromJson original — continua funcionando para ler o jogos.json local
  factory Jogo.fromJson(Map<String, dynamic> json) {
    return Jogo(
      id: json['id'],
      round: json['round'],
      matchday: json['matchday'],
      date: json['date'],
      time: json['time'],
      team1: json['team1'],
      team2: json['team2'],
      group: json['group'],
      ground: json['ground'],
      placar1: json['placar1'],
      placar2: json['placar2'],
    );
  }

  // Propriedade computada que combina date + time em um DateTime do Dart.
  // É como um getter no Kotlin — não armazena nada, só calcula na hora que
  // você acessa. Usamos isso no toMap() para gerar o Timestamp do Firestore.
  // Assume que date vem como "2026-06-11" e time como "18:00".
  DateTime get dataHora {
    final horaMinuto = time.substring(0, 5);
    final partes = horaMinuto.split(':');
    final hora = int.parse(partes[0]);
    final minuto = int.parse(partes[1]);

    // "15:00 UTC-4" → split em "UTC" → pega o segundo elemento → "-4"
    final fusoTexto = time.split('UTC')[1].trim();
    final offsetHoras = int.parse(fusoTexto); // -4, -5, -6 ou -7

    // Primeiro construímos o DateTime "ingênuo" — sem fuso, só hora e data locais.
    final semFuso = DateTime.utc(
      int.parse(date.split('-')[0]),
      int.parse(date.split('-')[1]),
      int.parse(date.split('-')[2]),
      hora,
      minuto,
    );

    // Depois subtraímos o offset para converter para UTC.
    // "subtrair -4 horas" = "somar 4 horas", que é exatamente o que queremos:
    // 15:00 UTC-4 → 15:00 - (-4h) = 19:00 UTC.
    // O DateTime.utc() ao final marca explicitamente que esse valor está em UTC.
    return semFuso.subtract(Duration(hours: offsetHoras));
  }

  // toMap: prepara o objeto para ser salvo no Firestore.
  // A diferença principal em relação ao toJson é o Timestamp.fromDate()
  // que converte o DateTime para o formato nativo do Firestore,
  // permitindo queries como "jogos entre meia-noite e 23:59 de hoje".
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round': round,
      'matchday': matchday,
      'date': date,
      'time': time,
      // dataHora é o campo que o JogoService usa para filtrar por data.
      // Salvamos como Timestamp — o tipo de data nativo do Firestore.
      'dataHora': Timestamp.fromDate(dataHora),
      'team1': team1,
      'team2': team2,
      'group': group,
      'ground': ground,
      'placar1': placar1,
      'placar2': placar2,
    };
  }

  // fromMap: reconstrói o objeto a partir do que o Firestore devolve.
  // O espelho do toMap() — cada campo que salvamos, precisamos saber ler.
  factory Jogo.fromMap(Map<String, dynamic> map) {
    return Jogo(
      id: map['id'] as int,
      round: map['round'] as String,
      matchday: map['matchday'] as String?,
      date: map['date'] as String,
      time: map['time'] as String,
      team1: map['team1'] as String,
      team2: map['team2'] as String,
      group: map['group'] as String?,
      ground: map['ground'] as String,
      placar1: map['placar1'] as int?,
      placar2: map['placar2'] as int?,
    );
  }
}