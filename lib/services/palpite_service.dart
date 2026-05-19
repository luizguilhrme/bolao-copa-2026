import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/palpite.dart';

class PalpiteService {
  final _colecao = FirebaseFirestore.instance.collection('palpites');

  Future<void> salvar(Palpite palpite) async {
    await _colecao.doc(palpite.docId).set(palpite.toMap());
  }

  Future<Palpite?> buscarPorJogo(String uid, int jogoId) async {
    final doc = await _colecao.doc('${uid}_$jogoId').get();
    if (!doc.exists) return null;
    return Palpite.fromMap(doc.data()!);
  }

  // Sem orderBy → sem índice composto necessário.
  // Usado na tela de palpites para precarregar todos os palpites do usuário
  // de uma vez, evitando N queries individuais por card.
  Future<List<Palpite>> buscarTodosPorUsuario(String uid) async {
    final snap = await _colecao.where('uid', isEqualTo: uid).get();
    return snap.docs.map((d) => Palpite.fromMap(d.data())).toList();
  }

  // Com orderBy — requer índice composto (uid + jogoId).
  // Reservado para uso futuro (ranking detalhado etc.).
  Future<List<Palpite>> buscarPorUsuario(String uid) async {
    final snap = await _colecao
        .where('uid', isEqualTo: uid)
        .orderBy('jogoId')
        .get();
    return snap.docs.map((d) => Palpite.fromMap(d.data())).toList();
  }

  // Todos os palpites de um jogo — usado pelo admin para calcular pontuação.
  Future<List<Palpite>> buscarTodosPorJogo(int jogoId) async {
    final snap =
    await _colecao.where('jogoId', isEqualTo: jogoId).get();
    return snap.docs.map((d) => Palpite.fromMap(d.data())).toList();
  }
}