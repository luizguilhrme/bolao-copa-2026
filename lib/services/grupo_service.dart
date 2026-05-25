import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grupo.dart';

class GrupoService {
  final CollectionReference _colecao =
      FirebaseFirestore.instance.collection('grupos');

  Stream<List<Grupo>> buscarGruposDoUsuario(String uid) {
    return _colecao
        .where('membros', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Grupo.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm)));
  }

  Future<Grupo> criarGrupo(String nome, String donoUid) async {
    final codigo = await _gerarCodigoUnico();
    final ref = _colecao.doc();
    final grupo = Grupo(
      id: ref.id,
      nome: nome,
      codigo: codigo,
      donoUid: donoUid,
      membros: [donoUid],
      criadoEm: DateTime.now(),
    );
    await ref.set(grupo.toMap());
    return grupo;
  }

  Future<Grupo?> entrarComCodigo(String codigo, String uid) async {
    final snap = await _colecao
        .where('codigo', isEqualTo: codigo.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final membros = List<String>.from(
        (doc.data() as Map<String, dynamic>)['membros'] as List);
    if (membros.contains(uid)) throw Exception('ja_membro');
    await doc.reference.update({
      'membros': FieldValue.arrayUnion([uid]),
    });
    final atualizado = await doc.reference.get();
    return Grupo.fromMap(atualizado.id, atualizado.data() as Map<String, dynamic>);
  }

  Future<void> sairDoGrupo(String grupoId, String uid) async {
    final ref = _colecao.doc(grupoId);
    await ref.update({
      'membros': FieldValue.arrayRemove([uid]),
    });
    final doc = await ref.get();
    if (!doc.exists) return;
    final membros = List<String>.from(
        (doc.data() as Map<String, dynamic>)['membros'] as List);
    if (membros.isEmpty) await ref.delete();
  }

  String _gerarCodigo() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> _gerarCodigoUnico() async {
    while (true) {
      final codigo = _gerarCodigo();
      final snap = await _colecao
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return codigo;
    }
  }
}
