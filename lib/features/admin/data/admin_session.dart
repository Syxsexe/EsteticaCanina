import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

/// Entrar y salir como la estética.
///
/// Con correo y contraseña, no con el OTP de los clientes. Para la dueña es
/// lo correcto: entra a diario desde su propio dispositivo, así que no la
/// olvida, y no cuesta un mensaje cada vez.
abstract interface class AdminSession {
  /// Si quien está dentro ahora mismo es administradora.
  Future<bool> esAdmin();

  /// Devuelve `true` si entró y además es administradora.
  ///
  /// Lanza [CredencialesInvalidas] si el correo o la contraseña no valen, y
  /// devuelve `false` si la cuenta existe pero no tiene permisos.
  Future<bool> entrar({required String correo, required String contrasena});

  Future<void> salir();
}

/// El correo o la contraseña no corresponden a ninguna cuenta.
class CredencialesInvalidas implements Exception {
  const CredencialesInvalidas();
}

/// Sin Supabase no hay a quién preguntarle: nunca es administradora.
///
/// Es lo que mantiene la app navegable sin credenciales y los tests sin red.
class SampleAdminSession implements AdminSession {
  const SampleAdminSession();

  @override
  Future<bool> esAdmin() async => false;

  @override
  Future<bool> entrar({
    required String correo,
    required String contrasena,
  }) async =>
      false;

  @override
  Future<void> salir() async {}
}

class SupabaseAdminSession implements AdminSession {
  const SupabaseAdminSession(this._db);

  final SupabaseClient _db;

  @override
  Future<bool> esAdmin() async {
    if (_db.auth.currentSession == null) return false;
    // La respuesta la da Postgres, no el cliente. Aunque alguien forzara
    // esto a `true`, las políticas seguirían devolviéndole una agenda
    // vacía: la pantalla se abriría sin nada dentro.
    final respuesta = await _db.rpc<dynamic>('es_admin');
    return respuesta == true;
  }

  @override
  Future<bool> entrar({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await _db.auth.signInWithPassword(email: correo, password: contrasena);
    } on AuthException {
      throw const CredencialesInvalidas();
    }
    return esAdmin();
  }

  @override
  Future<void> salir() => _db.auth.signOut();
}

AdminSession defaultAdminSession() {
  if (!AppConfig.hasSupabase) return const SampleAdminSession();
  return SupabaseAdminSession(Supabase.instance.client);
}
