import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Instância única de GoogleSignIn compartilhada pelo app.
/// Necessário para que onCurrentUserChanged (disparado pelo botão GIS na web)
/// e entrarComGoogle (mobile) usem o mesmo canal de eventos.
final _googleSignIn = GoogleSignIn(
  // clientId: APENAS na web. No Android, o client vem do google-services.json;
  // passar clientId no Android faz o seletor retornar null após selecionar conta.
  clientId: kIsWeb
      ? '847953336398-4vsrvm2ldqf2k7daaigssdjq0iacg478.apps.googleusercontent.com'
      : null,
  // serverClientId: necessário no Android para que googleUser.authentication
  // devolva um idToken válido para trocar com o Firebase Auth.
  // Deve ser o Web OAuth client ID (não o Android client ID).
  serverClientId: '847953336398-4vsrvm2ldqf2k7daaigssdjq0iacg478.apps.googleusercontent.com',
);

/// Lançada quando o e-mail do Google já tem uma conta com senha.
class ContaJaExisteException implements Exception {
  final AuthCredential credencial;
  final String email;
  ContaJaExisteException({required this.credencial, required this.email});
}

class AuthService {
  final _auth = FirebaseAuth.instance;

  // ── Web: botão GIS ──────────────────────────────────────────────────────────

  /// Stream que emite sempre que o usuário do Google muda.
  /// Na web, disparado pelo botão renderButton() após autenticação via
  /// FedCM ou popup. Mapeado para void para não vazar o tipo GoogleSignInAccount
  /// fora deste serviço.
  Stream<void> get onGoogleUserChanged =>
      _googleSignIn.onCurrentUserChanged.map((_) {});

  /// Autentica no Firebase com a conta Google atualmente ativa no plugin.
  /// Chamado logo após onGoogleUserChanged disparar (web).
  Future<User?> processarUltimaContaGoogle() async {
    final googleUser = _googleSignIn.currentUser;
    if (googleUser == null) return null;
    return _autenticarNoFirebase(googleUser);
  }

  // ── Mobile: fluxo nativo ────────────────────────────────────────────────────

  /// Abre o seletor de conta Google nativo (Android/iOS) e autentica.
  ///
  /// Retorna null se o usuário fechou o seletor.
  /// Lança [ContaJaExisteException] se o e-mail já existe com senha.
  Future<User?> entrarComGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    return _autenticarNoFirebase(googleUser);
  }

  // ── Compartilhado ───────────────────────────────────────────────────────────

  Future<User?> _autenticarNoFirebase(GoogleSignInAccount googleUser) async {
    final googleAuth = await googleUser.authentication;
    final credencial = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    try {
      final result = await _auth.signInWithCredential(credencial);
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw ContaJaExisteException(
          credencial: credencial,
          email: googleUser.email,
        );
      }
      rethrow;
    }
  }

  /// Inicializa o plugin Google Sign-In na web e verifica silenciosamente se
  /// há sessão ativa. Sem essa chamada, a Future `initialized` dentro do
  /// renderButton() nunca completa e o botão GIS não aparece.
  Future<void> inicializar() async {
    try {
      await _googleSignIn.signInSilently();
    } catch (_) {}
  }

  /// Desloga do Firebase e do GoogleSignIn.
  /// Sem o signOut do GoogleSignIn, o seletor não reaparece no próximo login.
  Future<void> sair() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Reautentica o usuário logado com a conta Google dele.
  /// Necessário antes de operações sensíveis (excluir conta, definir senha)
  /// quando o usuário não tem provedor de senha.
  ///
  /// Retorna false se o usuário fechou o seletor de conta sem confirmar.
  /// Lança FirebaseAuthException com code 'user-mismatch' se a conta Google
  /// selecionada não for a mesma do login.
  Future<bool> reautenticarComGoogle() async {
    final user = _auth.currentUser!;
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return true;
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return false;
    final googleAuth = await googleUser.authentication;
    final credencial = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    await user.reauthenticateWithCredential(credencial);
    return true;
  }

  /// Vincula uma credencial Google a uma conta que já existe com e-mail/senha.
  Future<User?> vincularGoogle({
    required String email,
    required String senha,
    required AuthCredential credencialGoogle,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
    await result.user!.linkWithCredential(credencialGoogle);
    return result.user;
  }
}
