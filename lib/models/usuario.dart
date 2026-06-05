import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String uid;          // mesmo UID do Firebase Auth — é a "chave primária"
  final String email;
  final String nome;         // nome de exibição no ranking
  final int pontuacaoClassica;         // fase de grupos Clássico
  final int pontuacaoCopa;             // fase de grupos Copa
  final int pontuacaoEliminatorias;    // mata-mata — compartilhado pelos dois modos
  final int pontuacaoEspeciais;        // palpites especiais — compartilhado pelos dois modos
  final int placaresExatos;            // desempate 1: placares exatos acertados
  final int palpitesPerdidos;          // desempate 2: jogos não palpitados (cada um gera −10)
  final DateTime criadoEm;

  int get pontuacaoClassicaTotal =>
      pontuacaoClassica + pontuacaoEliminatorias + pontuacaoEspeciais;

  int get pontuacaoCopaTotal =>
      pontuacaoCopa + pontuacaoEliminatorias + pontuacaoEspeciais;

  final String? avatar;
  final String? palpiteCampeao;
  final String? palpiteArtilheiro;
  final String? palpiteGoleiro;
  final String? palpiteMelhorJogador;
  final String? palpiteMaisGoleadora;
  final String? palpiteMenosVazada;

  const Usuario({
    required this.uid,
    required this.email,
    required this.nome,
    this.pontuacaoClassica = 0,
    this.pontuacaoCopa = 0,
    this.pontuacaoEliminatorias = 0,
    this.pontuacaoEspeciais = 0,
    this.placaresExatos = 0,
    this.palpitesPerdidos = 0,
    required this.criadoEm,
    this.avatar,
    this.palpiteCampeao,
    this.palpiteArtilheiro,
    this.palpiteGoleiro,
    this.palpiteMelhorJogador,
    this.palpiteMaisGoleadora,
    this.palpiteMenosVazada,
  });

  // fromMap é equivalente ao fromJson do Gson —
  // recebe o Map que o Firestore entrega e constrói o objeto
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      uid: map['uid'] as String,
      email: map['email'] as String,
      nome: map['nome'] as String,
      pontuacaoClassica: (map['pontuacaoClassica'] as num?)?.toInt() ?? 0,
      pontuacaoCopa: (map['pontuacaoCopa'] as num?)?.toInt() ?? 0,
      pontuacaoEliminatorias: (map['pontuacaoEliminatorias'] as num?)?.toInt() ?? 0,
      pontuacaoEspeciais: (map['pontuacaoEspeciais'] as num?)?.toInt() ?? 0,
      placaresExatos: (map['placaresExatos'] as num?)?.toInt() ?? 0,
      palpitesPerdidos: (map['palpitesPerdidos'] as num?)?.toInt() ?? 0,
      criadoEm: map['criadoEm'] != null
          ? (map['criadoEm'] as Timestamp).toDate()
          : DateTime.now(),
      avatar: map['avatar'] as String?,
      palpiteCampeao: map['palpiteCampeao'] as String?,
      palpiteArtilheiro: map['palpiteArtilheiro'] as String?,
      palpiteGoleiro: map['palpiteGoleiro'] as String?,
      palpiteMelhorJogador: map['palpiteMelhorJogador'] as String?,
      palpiteMaisGoleadora: map['palpiteMaisGoleadora'] as String?,
      palpiteMenosVazada: map['palpiteMenosVazada'] as String?,
    );
  }

  // toMap é o caminho inverso — prepara o objeto para ser salvo no Firestore.
  // Campos de pontuação são gerenciados exclusivamente pelas Cloud Functions
  // via FieldValue.increment() — não incluí-los aqui evita conflitos com
  // regras do Firestore que protegem esses campos.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nome': nome,
      'criadoEm': FieldValue.serverTimestamp(),
      if (avatar != null) 'avatar': avatar,
    };
  }

  // copyWith permite criar uma cópia do objeto com alguns campos alterados,
  // sem modificar o original — equivalente ao padrão Builder do Java.
  // Você vai usar isso para atualizar a pontuação sem recriar o objeto inteiro.
  Usuario copyWith({
    String? nome,
    int? pontuacaoClassica,
    int? placaresExatos,
    int? palpitesPerdidos,
    String? avatar,
    String? palpiteCampeao,
    String? palpiteArtilheiro,
    String? palpiteGoleiro,
    String? palpiteMelhorJogador,
    String? palpiteMaisGoleadora,
    String? palpiteMenosVazada,
  }) {
    return Usuario(
      uid: uid,
      email: email,
      nome: nome ?? this.nome,
      pontuacaoClassica: pontuacaoClassica ?? this.pontuacaoClassica,
      placaresExatos: placaresExatos ?? this.placaresExatos,
      palpitesPerdidos: palpitesPerdidos ?? this.palpitesPerdidos,
      criadoEm: criadoEm,
      avatar: avatar ?? this.avatar,
      palpiteCampeao: palpiteCampeao ?? this.palpiteCampeao,
      palpiteArtilheiro: palpiteArtilheiro ?? this.palpiteArtilheiro,
      palpiteGoleiro: palpiteGoleiro ?? this.palpiteGoleiro,
      palpiteMelhorJogador: palpiteMelhorJogador ?? this.palpiteMelhorJogador,
      palpiteMaisGoleadora: palpiteMaisGoleadora ?? this.palpiteMaisGoleadora,
      palpiteMenosVazada: palpiteMenosVazada ?? this.palpiteMenosVazada,
    );
  }
}