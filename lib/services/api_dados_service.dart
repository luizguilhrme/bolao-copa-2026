import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/artilharia.dart';

// =============================================================================
// api_dados_service.dart — leitura dos dados vindos da football-data.org
//
// A coleção `api` é escrita exclusivamente pelas Cloud Functions
// (sincronizarApi / mapearJogosApi); o app só lê. Dois documentos:
//   api/artilharia    → { artilheiros: [{nome, selecao, gols, assistencias}],
//                         atualizadoEm }
//   api/classificacao → { grupos: { "A": [{posicao, time, jogos, vitorias,
//                         empates, derrotas, pontos, golsPro, golsContra,
//                         saldo}], ... }, atualizadoEm }
// =============================================================================

/// Linha da classificação oficial de um grupo (standings da API).
class ClassificacaoApiTime {
  const ClassificacaoApiTime({
    required this.time,
    required this.jogos,
    required this.vitorias,
    required this.empates,
    required this.derrotas,
    required this.golsPro,
    required this.golsContra,
  });

  /// Nome do time em inglês, já na grafia do nosso jogos.json
  /// (a Cloud Function converte os nomes divergentes da API).
  final String time;
  final int jogos;
  final int vitorias;
  final int empates;
  final int derrotas;
  final int golsPro;
  final int golsContra;

  factory ClassificacaoApiTime.fromMap(Map<String, dynamic> map) {
    return ClassificacaoApiTime(
      time: map['time'] as String? ?? '',
      jogos: (map['jogos'] as num?)?.toInt() ?? 0,
      vitorias: (map['vitorias'] as num?)?.toInt() ?? 0,
      empates: (map['empates'] as num?)?.toInt() ?? 0,
      derrotas: (map['derrotas'] as num?)?.toInt() ?? 0,
      golsPro: (map['golsPro'] as num?)?.toInt() ?? 0,
      golsContra: (map['golsContra'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiDadosService {
  final CollectionReference<Map<String, dynamic>> _colecao =
      FirebaseFirestore.instance.collection('api');

  /// Artilharia completa, já ordenada pela API. Lista vazia enquanto o
  /// documento não existir (nenhum gol marcado ainda / sync não rodou).
  Future<List<Artilheiro>> buscarArtilharia() async {
    final doc = await _colecao.doc('artilharia').get();
    final lista = doc.data()?['artilheiros'] as List? ?? [];
    return lista
        .map((e) => Artilheiro.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Classificação oficial dos grupos, na ordem da API (critérios FIFA
  /// completos). Chave: letra do grupo ("A".."L"). Retorna null quando o
  /// documento ainda não existe — o chamador usa o cálculo local de fallback.
  Future<Map<String, List<ClassificacaoApiTime>>?> buscarClassificacao() async {
    final doc = await _colecao.doc('classificacao').get();
    final grupos = doc.data()?['grupos'] as Map<String, dynamic>?;
    if (grupos == null || grupos.isEmpty) return null;
    return grupos.map(
      (letra, lista) => MapEntry(
        letra,
        (lista as List)
            .map(
              (e) => ClassificacaoApiTime.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      ),
    );
  }
}
