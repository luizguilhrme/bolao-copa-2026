import 'dart:typed_data';

// Stub do fallback de download direto da imagem — a implementação real só
// existe no Web (baixar_imagem_web.dart, via conditional import). Nas demais
// plataformas o share sheet nativo do share_plus já resolve, então esta
// função nunca deve ser chamada.
Future<void> baixarImagem(Uint8List bytes, String nomeArquivo) async {
  throw UnsupportedError('Download direto disponível apenas no Web.');
}
