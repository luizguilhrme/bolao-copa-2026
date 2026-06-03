import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

void registrarBotaoGoogle() {}

/// Retorna o botão oficial do Google (renderButton via GIS).
///
/// Usa a API oficial `renderButton` de `google_sign_in_web/web_only.dart`,
/// que é o ponto de entrada recomendado pelo pacote (faz internamente o cast
/// para GoogleSignInPlugin com a identidade de tipo correta).
///
/// ATENÇÃO: se o botão não aparecer no build release (`flutter build web`),
/// rode `flutter clean` antes de rebuildar. O registrant de plugin web pode
/// ficar desatualizado e deixar GoogleSignInPlatform.instance como a instância
/// default em vez de GoogleSignInPlugin — nesse caso renderButton lança
/// TypeError ("type X is not a subtype of Y") e o botão some. Funciona em
/// debug mesmo assim, então o sintoma só aparece em produção.
Widget buildBotaoGoogleWeb({double? largura}) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.signinWith,
      shape: web.GSIButtonShape.rectangular,
      minimumWidth: largura,
    ),
  );
}
