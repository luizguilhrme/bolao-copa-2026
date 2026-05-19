import 'package:cloud_firestore/cloud_firestore.dart';

class Palpite {
  final String uid;
  final int jogoId;
  final int palpite1;
  final int palpite2;
  // Nullable porque FieldValue.serverTimestamp() chega como null
  // no cache local antes de o servidor responder.
  final DateTime? criadoEm;

  Palpite({
    required this.uid,
    required this.jogoId,
    required this.palpite1,
    required this.palpite2,
    this.criadoEm,
  });

  String get docId => '${uid}_$jogoId';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'jogoId': jogoId,
      'palpite1': palpite1,
      'palpite2': palpite2,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }

  factory Palpite.fromMap(Map<String, dynamic> map) {
    return Palpite(
      uid: map['uid'] as String,
      jogoId: map['jogoId'] as int,
      palpite1: map['palpite1'] as int,
      palpite2: map['palpite2'] as int,
      criadoEm: map['criadoEm'] != null
          ? (map['criadoEm'] as Timestamp).toDate()
          : null,
    );
  }
}