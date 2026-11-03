import 'package:supabase_flutter/supabase_flutter.dart';

/// Asegura que haya sesión, aunque sea sin decir quién.
///
/// Reservar, guardar el perfil y registrar una mascota exigen `auth.uid()`.
/// La sesión se crea en el primer momento que haga falta y no al abrir la
/// app: mirar servicios y horarios no debería costar una cuenta.
///
/// Vive aquí y no dentro de un repositorio porque la necesitan varios, y
/// dos copias de esto acabarían creando dos sesiones distintas.
Future<void> asegurarSesion(SupabaseClient db) async {
  if (db.auth.currentSession != null) return;
  await db.auth.signInAnonymously();
}
