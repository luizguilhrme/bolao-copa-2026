import 'package:cloud_firestore/cloud_firestore.dart';

/// Gerencia os palpites de classificação de grupos do MODO COPA.
/// Documento ID = UID do usuário (um documento por usuário).
///
/// Estrutura no Firestore:
/// palpites_copa/{uid}
///   uid: String
///   grupos: {
///     "A": { "primeiro": "Brazil", "segundo": "Mexico", "terceiro": "Czech Republic" },
///     "B": { ... },
///     ...
///   }
///   atualizadoEm: Timestamp
class PalpiteCopaService {
  final _colecao = FirebaseFirestore.instance.collection('palpites_copa');

  /// Retorna os palpites de classificação do usuário.
  /// Retorna mapa vazio se ainda não palpitou.
  Future<Map<String, Map<String, String?>>> buscarPorUid(String uid) async {
    final doc = await _colecao.doc(uid).get();
    if (!doc.exists) return {};
    final data = doc.data()!;
    final grupos = data['grupos'] as Map<String, dynamic>?;
    if (grupos == null) return {};
    return grupos.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(k, {
        'primeiro': m['primeiro'] as String?,
        'segundo':  m['segundo']  as String?,
        'terceiro': m['terceiro'] as String?,
      });
    });
  }

  /// Salva ou sobrescreve os palpites de classificação do usuário.
  Future<void> salvar(String uid, Map<String, Map<String, String?>> grupos) async {
    await _colecao.doc(uid).set({
      'uid': uid,
      'grupos': grupos.map((k, v) => MapEntry(k, {
        'primeiro': v['primeiro'],
        'segundo':  v['segundo'],
        'terceiro': v['terceiro'],
      })),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }
}
