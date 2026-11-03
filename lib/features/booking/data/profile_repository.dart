import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/session/anonymous_session.dart';
import '../models/customer_profile.dart';

/// Los datos de contacto del cliente.
abstract interface class ProfileRepository {
  /// Lo que ya se sabe de quien está usando la app.
  Future<CustomerProfile> cargar();

  Future<void> guardar(CustomerProfile perfil);
}

/// Guarda en memoria. Para los tests y para la app sin credenciales.
class SampleProfileRepository implements ProfileRepository {
  SampleProfileRepository([this._perfil = const CustomerProfile()]);

  CustomerProfile _perfil;

  @override
  Future<CustomerProfile> cargar() async => _perfil;

  @override
  Future<void> guardar(CustomerProfile perfil) async => _perfil = perfil;
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<CustomerProfile> cargar() async {
    await asegurarSesion(_db);
    // La fila la creó el disparador al nacer la cuenta, así que existe
    // siempre; lo que puede faltar es su contenido.
    final fila = await _db
        .from('perfiles')
        .select('nombre, telefono')
        .eq('id', _db.auth.currentUser!.id)
        .maybeSingle();

    if (fila == null) return const CustomerProfile();
    return CustomerProfile(
      nombre: fila['nombre'] as String?,
      telefono: fila['telefono'] as String?,
    );
  }

  @override
  Future<void> guardar(CustomerProfile perfil) async {
    await asegurarSesion(_db);
    await _db.from('perfiles').update({
      'nombre': perfil.nombre,
      'telefono': perfil.telefono,
    }).eq('id', _db.auth.currentUser!.id);
  }
}

ProfileRepository defaultProfileRepository() {
  if (!AppConfig.hasSupabase) return SampleProfileRepository();
  return SupabaseProfileRepository(Supabase.instance.client);
}
