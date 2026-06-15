import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// Fallback de download direto da imagem no Web: usado quando a Web Share API
// não suporta compartilhar arquivos (ex: navegador desktop). Cria um Blob com
// o PNG e dispara o download via âncora temporária.
Future<void> baixarImagem(Uint8List bytes, String nomeArquivo) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final ancora =
      web.HTMLAnchorElement()
        ..href = url
        ..download = nomeArquivo;
  web.document.body!.appendChild(ancora);
  ancora.click();
  ancora.remove();
  web.URL.revokeObjectURL(url);
}
