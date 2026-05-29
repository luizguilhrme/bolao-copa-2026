import 'package:cloud_firestore/cloud_firestore.dart';

class Grupo {
  final String id;
  final String nome;
  final String codigo;
  final String donoUid;
  final List<String> membros;
  final DateTime criadoEm;
  /// 'classico' (padrão) ou 'copa'. Grupos antigos sem campo defaultam para 'classico'.
  final String regra;

  const Grupo({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.donoUid,
    required this.membros,
    required this.criadoEm,
    this.regra = 'classico',
  });

  factory Grupo.fromMap(String id, Map<String, dynamic> map) {
    return Grupo(
      id: id,
      nome: map['nome'] as String,
      codigo: map['codigo'] as String,
      donoUid: map['donoUid'] as String,
      membros: List<String>.from(map['membros'] as List),
      criadoEm: map['criadoEm'] != null
          ? (map['criadoEm'] as Timestamp).toDate()
          : DateTime.now(),
      regra: map['regra'] as String? ?? 'classico',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'codigo': codigo,
      'donoUid': donoUid,
      'membros': membros,
      'regra': regra,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}
