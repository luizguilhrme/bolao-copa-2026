import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/jogo.dart';

class JogoService {
  final CollectionReference _colecao = FirebaseFirestore.instance.collection('jogos');

  Future<void> popularJogosNoFirestore({bool teste = false}) async {
    final asset = teste ? 'assets/dados/jogos_teste.json' : 'assets/dados/jogos.json';
    final jsonString = await rootBundle.loadString(asset);

    // jsonDecode transforma a String em uma List<dynamic>,
    // onde cada item é um Map<String, dynamic> — um jogo.
    final Map<String, dynamic> mapa = jsonDecode(jsonString);
    final List<dynamic> lista = mapa['jogos'];

    // Converte cada Map em um objeto Jogo usando o fromJson que já existe.
    final jogos = lista.map((item) => Jogo.fromJson(item)).toList();

    // Cria o batch — é a nossa "lista de compras" que vamos
    // entregar de uma vez para o Firestore.
    final batch = FirebaseFirestore.instance.batch();

    for (final jogo in jogos) {
      // Usamos o id do jogo como ID do documento para facilitar
      // buscas diretas — igual ao que fizemos com o UID do usuário.
      final docRef = _colecao.doc(jogo.id.toString());

      // Cada set() adiciona uma instrução ao batch, mas ainda
      // não faz nenhuma chamada de rede nesse momento.
      batch.set(docRef, jogo.toMap());
    }

    // Aqui sim acontece a mágica: uma única chamada de rede
    // que grava todos os 104 jogos de forma atômica.
    await batch.commit();
  }

  // Busca todos os jogos do Firestore, ordenados por data.
  // Vamos usar isso para substituir os dados hardcoded da TelaHome.
  Future<List<Jogo>> buscarTodos() async {
    final snapshot = await _colecao.orderBy('dataHora').get();

    return snapshot.docs
        .map((doc) => Jogo.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Retorna apenas os jogos de uma data específica.
  // Útil para a seção "Jogos de Hoje" da TelaHome.
  Future<List<Jogo>> buscarPorData(DateTime data) async {
    // Firestore não tem um operador "mesmo dia", então criamos
    // um intervalo: de meia-noite até 23:59:59 daquele dia.
    final inicio = DateTime(data.year, data.month, data.day);
    final fim = inicio.add(const Duration(days: 1));

    final snapshot = await _colecao
        .where('dataHora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('dataHora', isLessThan: Timestamp.fromDate(fim))
        .orderBy('dataHora')
        .get();

    return snapshot.docs
        .map((doc) => Jogo.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
}