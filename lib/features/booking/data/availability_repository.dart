import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../models/schedule.dart';
import 'availability_catalog.dart';
import 'supabase_availability_repository.dart';

/// De dónde salen los días con sus huecos ocupados.
///
/// Existe para que el paso 2 no sepa si la agenda viene de una constante o
/// de Postgres. El modelo —`DaySchedule`, `BusySlot`, `slotsIn`— no cambia
/// en ninguno de los dos casos: son funciones puras sobre enteros, y lo
/// único que varía es quién les pasa los datos.
abstract interface class AvailabilityRepository {
  /// Los próximos días a partir de [from], con sus franjas y lo que ya está
  /// tomado.
  Future<List<DaySchedule>> daysFrom(DateTime from);
}

/// La agenda de muestra que ya traía la app.
///
/// Sigue siendo la que usan los tests: son 37 pruebas que no deberían
/// depender de que haya red ni de lo que haya hoy en la base.
class SampleAvailabilityRepository implements AvailabilityRepository {
  const SampleAvailabilityRepository();

  @override
  Future<List<DaySchedule>> daysFrom(DateTime from) async =>
      AvailabilityCatalog.nextDays(from);
}

/// El repositorio que usa la app.
///
/// Con credenciales, Postgres; sin ellas, la agenda de muestra. No es un
/// apaño: es lo que deja que los tests corran sin red, que alguien clone el
/// repo y ejecute la app sin pedir claves, y que olvidarse del
/// `--dart-define` dé datos falsos en vez de una pantalla rota.
AvailabilityRepository defaultAvailabilityRepository() {
  if (!AppConfig.hasSupabase) return const SampleAvailabilityRepository();
  return SupabaseAvailabilityRepository(Supabase.instance.client);
}
