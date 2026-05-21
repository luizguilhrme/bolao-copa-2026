import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'models/usuario.dart';
import 'screens/menu_principal.dart';
import 'screens/tela_login.dart';
import 'screens/tela_setup_perfil.dart';
import 'services/usuario_service.dart';
import 'utils/cores.dart';

// Deve ser top-level: o Flutter executa em isolate separado quando o app está fechado.
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolão Copa 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.verdePrincipal),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const _Carregando();
          }

          final firebaseUser = authSnapshot.data;
          if (firebaseUser == null) {
            return const TelaLogin();
          }

          // Logado — verifica se o perfil Firestore já foi criado
          return StreamBuilder<Usuario?>(
            stream: UsuarioService().observarUsuario(firebaseUser.uid),
            builder: (context, perfilSnapshot) {
              if (perfilSnapshot.connectionState == ConnectionState.waiting) {
                return const _Carregando();
              }
              if (perfilSnapshot.data != null) {
                return const MenuPrincipal();
              }
              // Conta criada mas perfil ainda não configurado
              return TelaSetupPerfil(user: firebaseUser);
            },
          );
        },
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Cores.verdePrincipal),
      ),
    );
  }
}
