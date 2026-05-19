import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String uid;          // mesmo UID do Firebase Auth — é a "chave primária"
  final String email;
  final String nome;         // nome de exibição no ranking
  final int pontuacao;       // pontuação total acumulada no bolão
  final DateTime criadoEm;   // data de cadastro

  const Usuario({
    required this.uid,
    required this.email,
    required this.nome,
    this.pontuacao = 0,      // novo usuário começa com zero pontos
    required this.criadoEm,
  });

  // fromMap é equivalente ao fromJson do Gson —
  // recebe o Map que o Firestore entrega e constrói o objeto
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      uid: map['uid'] as String,
      email: map['email'] as String,
      nome: map['nome'] as String,
      pontuacao: (map['pontuacao'] as num?)?.toInt() ?? 0,
      // Timestamp é o tipo de data do Firestore — convertemos para DateTime do Dart
      criadoEm: (map['criadoEm'] as Timestamp).toDate(),
    );
  }

  // toMap é o caminho inverso — prepara o objeto para ser salvo no Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nome': nome,
      'pontuacao': pontuacao,
      // FieldValue.serverTimestamp() deixa o servidor do Firebase
      // registrar o horário exato — mais confiável do que usar DateTime.now()
      // no celular do usuário, que pode estar com o horário errado
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }

  // copyWith permite criar uma cópia do objeto com alguns campos alterados,
  // sem modificar o original — equivalente ao padrão Builder do Java.
  // Você vai usar isso para atualizar a pontuação sem recriar o objeto inteiro.
  Usuario copyWith({
    String? nome,
    int? pontuacao,
  }) {
    return Usuario(
      uid: uid,
      email: email,
      nome: nome ?? this.nome,
      pontuacao: pontuacao ?? this.pontuacao,
      criadoEm: criadoEm,
    );
  }
}