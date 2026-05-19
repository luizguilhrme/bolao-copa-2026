import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/palpite.dart';

class PalpiteService {
  final _colecao = FirebaseFirestore.instance.collection('palpites');

  // Salva ou sobrescreve o palpite do usuário para um jogo.
  Future<void> salvar(Palpite palpite) async {
    await _colecao.doc(palpite.docId).set(palpite.toMap());
  }

  // Busca o palpite de um usuário para um jogo específico.
  // Retorna null se o usuário ainda não palpitou nesse jogo.
  Future<Palpite?> buscarPorJogo(String uid, int jogoId) async {
    final doc = await _colecao.doc('${uid}_$jogoId').get();
    if (!doc.exists) return null;
    return Palpite.fromMap(doc.data()!);
  }

  // Busca todos os palpites de um usuário — útil para o ranking.
  Future<List<Palpite>> buscarPorUsuario(String uid) async {
    final snap = await _colecao
        .where('uid', isEqualTo: uid)
        .orderBy('jogoId')
        .get();
    return snap.docs.map((d) => Palpite.fromMap(d.data())).toList();
  }

  // Busca todos os palpites de um jogo específico — usado pelo admin
  // para calcular pontuação de todos os participantes após inserir o placar.
  // Usa apenas um where() → nenhum índice composto necessário.
  Future<List<Palpite>> buscarTodosPorJogo(int jogoId) async {
    final snap = await _colecao
        .where('jogoId', isEqualTo: jogoId)
        .get();
    return snap.docs.map((d) => Palpite.fromMap(d.data())).toList();
  }
}