import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';

class UsuarioService {
  // Pegamos a referência para a coleção 'usuarios' uma vez só e guardamos.
  // É como ter um DAO no Room — um ponto único de acesso à coleção.
  final CollectionReference _colecao =
  FirebaseFirestore.instance.collection('usuarios');

  // Cria o documento do usuário no Firestore logo após o cadastro.
  // O UID do Firebase Auth vira o ID do documento — assim a busca
  // por usuário é sempre O(1), sem precisar de query.
  Future<void> criarPerfil(Usuario usuario) async {
    // doc(uid) aponta para o documento com aquele ID específico.
    // Se não existir, o set() cria. Se já existir, substitui.
    // Usamos merge: true para não sobrescrever campos que já existam
    // (útil no futuro, quando o usuário puder editar o perfil).
    await _colecao.doc(usuario.uid).set(
      usuario.toMap(),
      SetOptions(merge: true),
    );
  }

  // Busca o perfil completo de um usuário pelo UID.
  // Retorna null se o documento não existir — isso pode acontecer
  // se o usuário foi criado no Auth mas o Firestore falhou por algum motivo.
  Future<Usuario?> buscarPorUid(String uid) async {
    final doc = await _colecao.doc(uid).get();

    // doc.exists verifica se o documento realmente existe no banco
    if (!doc.exists || doc.data() == null) return null;

    // data() retorna Map<String, dynamic> — exatamente o que fromMap espera
    return Usuario.fromMap(doc.data() as Map<String, dynamic>);
  }

  // Retorna um Stream do perfil do usuário — ele vai emitir um novo valor
  // toda vez que o documento for alterado no Firestore (pontuação, nome, etc).
  // As telas que exibirem o perfil podem usar um StreamBuilder com isso.
  Stream<Usuario?> observarUsuario(String uid) {
    return _colecao.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Usuario.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> atualizarNome(String uid, String novoNome) async {
    await _colecao.doc(uid).update({'nome': novoNome});
  }

  Future<void> atualizarAvatar(String uid, String avatarId) async {
    await _colecao.doc(uid).update({'avatar': avatarId});
  }

  Future<void> salvarPalpitesEspeciais({
    required String uid,
    required String campeao,
    String? chuteiradeOuro,
    String? boladeOuro,
    String? luvadeOuro,
    String? melhorJovem,
  }) async {
    await _colecao.doc(uid).update({
      'palpiteCampeao': campeao,
      if (chuteiradeOuro != null) 'palpiteChuteiradeOuro': chuteiradeOuro,
      if (boladeOuro != null) 'palpiteBoladeOuro': boladeOuro,
      if (luvadeOuro != null) 'palpiteLuvadeOuro': luvadeOuro,
      if (melhorJovem != null) 'palpiteMelhorJovem': melhorJovem,
    });
  }
}