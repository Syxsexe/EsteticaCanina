import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

/// El trabajo que la app hace antes de enseñar la primera pantalla.
///
/// Hoy es poco —dejar el logotipo decodificado— porque el catálogo es
/// constante y no hay red ni sesión. Cuando entren, este es el único sitio
/// que crece: el splash ya sabe esperar a [run] y no hay que tocarlo.
class AppBootstrap {
  const AppBootstrap._();

  /// Tope duro del arranque.
  ///
  /// Una pantalla de apertura no puede encerrar a nadie: si el trabajo de
  /// arranque no termina —un asset que no resuelve, una red que no contesta—,
  /// se abandona y la app entra igual. Lo que falte se degrada solo, y eso
  /// siempre es mejor que un splash eterno.
  static const Duration deadline = Duration(seconds: 5);

  static Future<void> run(BuildContext context) async {
    await _precacheLogo(context).timeout(deadline, onTimeout: () {});
  }

  /// Deja el logotipo listo en memoria para que el Home no parpadee al
  /// entrar. Si el archivo todavía no está en el proyecto no pasa nada:
  /// [BrandLogo] dibuja su versión tipográfica y el arranque sigue.
  static Future<void> _precacheLogo(BuildContext context) async {
    await precacheImage(
      const AssetImage(BrandLogo.assetPath),
      context,
      onError: (_, _) {},
    );
  }
}
