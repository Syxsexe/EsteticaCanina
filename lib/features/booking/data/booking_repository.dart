import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/session/anonymous_session.dart';
import '../models/booking.dart';
import 'service_catalog.dart';

/// Guardar la cita.
///
/// Separado de [AvailabilityRepository] a propósito: leer la agenda es
/// público y anónimo, reservar exige sesión. Son dos permisos distintos y
/// dos momentos distintos del flujo.
abstract interface class BookingRepository {
  /// Guarda [booking] y devuelve el id que le asignó la base.
  ///
  /// Lanza [SlotTakenException] si el hueco se ocupó mientras el cliente
  /// decidía.
  Future<String> reservar(Booking booking);
}

/// Alguien tomó esa hora entre que se pintó la pantalla y se pulsó el botón.
///
/// Tiene tipo propio porque tiene respuesta propia: no es un error que se
/// resuelva reintentando lo mismo, sino uno que obliga a recargar la agenda
/// y elegir otra hora.
class SlotTakenException implements Exception {
  const SlotTakenException();

  @override
  String toString() => 'SlotTakenException: el horario ya está ocupado';
}

/// No guarda nada. Es lo que se usa cuando no hay credenciales.
///
/// Devuelve un id falso para que el flujo se pueda recorrer entero sin
/// backend —en los tests y en una demostración sin red—, pero nadie debería
/// confundir eso con haber reservado. Mientras no haya Supabase configurado,
/// la app es una maqueta navegable.
class SampleBookingRepository implements BookingRepository {
  const SampleBookingRepository();

  @override
  Future<String> reservar(Booking booking) async => 'muestra';
}

/// La reserva de verdad, contra Postgres.
class SupabaseBookingRepository implements BookingRepository {
  const SupabaseBookingRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<String> reservar(Booking booking) async {
    await asegurarSesion(_db);

    final servicios = [
      for (final s in booking.selection.chosenServices(ServiceCatalog.todos))
        s.id,
    ];

    try {
      final id = await _db.rpc<dynamic>(
        'reservar_cita',
        params: {
          // Todavía no se registran mascotas; la función lo admite nulo.
          'p_mascota_id': null,
          'p_empieza': booking.startsAt.toUtc().toIso8601String(),
          // Solo viajan los ids. El precio y la duración los calcula la
          // función leyendo la tabla, para que no se puedan falsear desde
          // el teléfono.
          'p_servicios': servicios,
        },
      );
      return id.toString();
    } on PostgrestException catch (error) {
      if (error.code == _choque) throw const SlotTakenException();
      rethrow;
    }
  }

  /// `exclusion_violation`: el código que `reservar_cita` vuelve a lanzar
  /// cuando la restricción `sin_solapes` rechaza la cita. Se compara el
  /// código y no el mensaje, que cambia en cuanto alguien corrige una tilde.
  static const String _choque = '23P01';

}

/// El repositorio de reservas que usa la app.
///
/// Mismo criterio que la agenda: con credenciales, Postgres; sin ellas, la
/// maqueta.
BookingRepository defaultBookingRepository() {
  if (!AppConfig.hasSupabase) return const SampleBookingRepository();
  return SupabaseBookingRepository(Supabase.instance.client);
}
