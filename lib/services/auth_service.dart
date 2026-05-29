import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Lançada quando o e-mail do Google já tem uma conta com senha.
/// Carrega a credencial Google e o e-mail para que a tela possa
/// fazer o account linking após o usuário digitar a senha.
class ContaJaExisteException implements Exception {
  final AuthCredential credencial;
  final String email;
  ContaJaExisteException({required this.credencial, required this.email});
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn(
    // Client ID web necessário para o Google Sign-In funcionar na versão PWA/browser.
    // No Android este valor é ignorado — o app usa o google-services.json.
    clientId: '847953336398-4vsrvm2ldqf2k7daaigssdjq0iacg478.apps.googleusercontent.com',
  );

  /// Abre o seletor de conta Google e autentica no Firebase.
  ///
  /// Retorna null se o usuário cancelou a janela do Google.
  /// Lança [ContaJaExisteException] se o e-mail já existe com senha.
  /// Lança [FirebaseAuthException] para outros erros do Firebase.
  Future<User?> entrarComGoogle() async {
    // 1. Abre o seletor de conta Google no dispositivo.
    //    O pacote google_sign_in cuida de toda a UI do Google.
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // usuário fechou a janela

    // 2. Pede os tokens de autenticação ao Google.
    //    idToken  → prova de identidade (quem o usuário é)
    //    accessToken → permissão de acesso aos dados do Google
    final googleAuth = await googleUser.authentication;

    // 3. Empacota os tokens em uma credencial que o Firebase entende.
    //    É como um "passaporte" emitido pelo Google para o Firebase validar.
    final credencial = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      // 4. Apresenta o passaporte ao Firebase Auth.
      //    Se tudo ok, Firebase cria/atualiza a sessão e retorna o User.
      final result = await _auth.signInWithCredential(credencial);
      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // O e-mail do Google já existe no Firebase com outro provedor (senha).
        // Guardamos a credencial Google para usá-la no linking depois.
        throw ContaJaExisteException(
          credencial: credencial,
          email: googleUser.email,
        );
      }
      rethrow;
    }
  }

  /// Vincula uma credencial Google a uma conta que já existe com e-mail/senha.
  ///
  /// Fluxo: faz login com senha → anexa a credencial Google → a conta
  /// passa a aceitar os dois métodos de autenticação.
  Future<User?> vincularGoogle({
    required String email,
    required String senha,
    required AuthCredential credencialGoogle,
  }) async {
    // 1. Autentica com a conta de senha existente
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
    // 2. Anexa o Google como segundo método de login dessa mesma conta
    await result.user!.linkWithCredential(credencialGoogle);
    return result.user;
  }
}
