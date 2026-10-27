/// La configuración que entra al compilar.
///
/// Los valores llegan con `--dart-define-from-file=env/dev.json`, no desde
/// un `.env` leído en caliente. La diferencia importa: un `.env` en Flutter
/// hay que declararlo como asset, o sea que viaja dentro del paquete de la
/// app igualmente, y además añade una dependencia y una carga asíncrona que
/// puede fallar. Esto son constantes resueltas al compilar.
///
/// Nada de esto es un secreto, y conviene tenerlo claro: la anon key está
/// pensada para vivir en el cliente, cualquiera puede leerla abriendo las
/// DevTools, y lo que protege los datos es el RLS. Se saca del repo para
/// que cada quien apunte a su propio proyecto, no para ocultarla.
///
/// La `service_role` key nunca entra aquí: esa sí se salta todas las
/// políticas y solo tiene sitio en el servidor.
class AppConfig {
  const AppConfig._();

  /// Ojo: `String.fromEnvironment` solo funciona en contexto `const`. Si se
  /// le quita el `const` a estos campos, devuelven siempre cadena vacía y
  /// el fallo es silencioso.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Si hay con qué hablarle a Supabase.
  ///
  /// Cuando es falso la app no se rompe: tira de la agenda de muestra. Eso
  /// mantiene los tests sin red, deja que alguien clone el repo y la
  /// ejecute sin pedirle credenciales a nadie, y convierte "se me olvidó el
  /// --dart-define" en una app que funciona con datos falsos en vez de una
  /// pantalla de error.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
