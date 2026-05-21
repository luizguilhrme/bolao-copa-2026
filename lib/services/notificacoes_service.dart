import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificacoesService {
  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> inicializar(String uid) async {
    // Push notifications não são suportadas na versão web (PWA iOS/desktop).
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _salvarToken(uid, token);

    _messaging.onTokenRefresh.listen((token) => _salvarToken(uid, token));
  }

  Future<void> _salvarToken(String uid, String token) async {
    await _firestore
        .collection('usuarios')
        .doc(uid)
        .update({'fcmToken': token});
  }

  Future<Map<String, bool>> buscarPrefs(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    final data = doc.data() ?? {};
    return {
      'lembretes': data['notifLembretes'] as bool? ?? true,
      'ranking': data['notifRanking'] as bool? ?? true,
    };
  }

  Future<void> atualizarPrefs(
    String uid, {
    bool? lembretes,
    bool? ranking,
  }) async {
    final updates = <String, dynamic>{};
    if (lembretes != null) updates['notifLembretes'] = lembretes;
    if (ranking != null) updates['notifRanking'] = ranking;
    if (updates.isNotEmpty) {
      await _firestore.collection('usuarios').doc(uid).update(updates);
    }
  }

  static String get uid => FirebaseAuth.instance.currentUser!.uid;
}
