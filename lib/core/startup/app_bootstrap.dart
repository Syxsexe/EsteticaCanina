import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
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
    await Future.wait([
      _precacheLogo(context),
      _conectarSupabase(),
    ]).timeout(deadline, onTimeout: () => const []);
  }

  /// Levanta el cliente de Supabase si hay con qué.
  ///
  /// Sin credenciales no es un error: la app tira de la agenda de muestra y
  /// funciona igual. Y si la conexión falla, tampoco: el tope de [deadline]
  /// la abandona y se entra de todos modos, que es justo para lo que estaba
  /// puesto.
  static Future<void> _conectarSupabase() async {
    if (!AppConfig.hasSupabase || _conectado) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // `anonKey` quedó obsoleto en el paquete; el nombre nuevo es el
      // mismo valor. La clave sigue siendo pública por diseño.
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _conectado = true;
  }

  /// `Supabase.initialize` protesta si se la llama dos veces, y en los tests
  /// la app se monta muchas.
  static bool _conectado = false;

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
