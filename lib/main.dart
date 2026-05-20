import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/menu_principal.dart';
import 'screens/tela_login.dart';
import 'utils/cores.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      // StreamBuilder ouve o estado de autenticação em tempo real
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Ainda conectando ao Firebase — mostra tela de espera
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // snapshot.data é o usuário logado (null = ninguém logado)
          if (snapshot.hasData) {
            return const MenuPrincipal(); // logado → vai pro app
          }

          return const TelaLogin(); // deslogado → vai pro login
        },
      ),
    );
  }
}