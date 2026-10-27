import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/schedule.dart';
import 'availability_repository.dart';

/// La agenda real, desde Postgres.
///
/// Son tres consultas que se lanzan a la vez: el horario de atención, los
/// cierres y las horas ya tomadas. Con eso se arman los mismos
/// [DaySchedule] que antes salían de una constante, y de ahí en adelante
/// todo el razonamiento sobre huecos sigue ocurriendo en el modelo, igual
/// que siempre.
///
/// Las horas ocupadas llegan por la función `horarios_ocupados`, que
/// devuelve solo dos columnas de tiempo. La tabla `citas` no se consulta
/// nunca desde aquí: saber que el miércoles a las 10:00 no hay sitio no
/// debe implicar saber de quién es la cita.
class SupabaseAvailabilityRepository implements AvailabilityRepository {
  const SupabaseAvailabilityRepository(this._db, {this.horizonDays = 14});

  final SupabaseClient _db;

  /// Cuántos días por delante se ofrecen. El póster promete dos semanas.
  final int horizonDays;

  @override
  Future<List<DaySchedule>> daysFrom(DateTime from) async {
    final desde = DateTime(from.year, from.month, from.day);
    final hasta = DateTime(desde.year, desde.month, desde.day + horizonDays - 1);

    final resultados = await Future.wait([
      _db.from('horario_atencion').select('dia_semana, abre, cierra'),
      _db
          .from('cierres')
          .select('fecha')
          .gte('fecha', _fecha(desde))
          .lte('fecha', _fecha(hasta)),
      _db.rpc(
        'horarios_ocupados',
        params: {'desde': _fecha(desde), 'hasta': _fecha(hasta)},
      ),
    ]);

    return armarDias(
      desde: desde,
      horizonDays: horizonDays,
      horario: resultados[0] as List<dynamic>,
      cierres: resultados[1] as List<dynamic>,
      ocupados: resultados[2] as List<dynamic>,
    );
  }

  /// Convierte las tres respuestas en los días que entiende el modelo.
  ///
  /// Está separado de [daysFrom] a propósito: todo lo que puede salir mal
  /// —horas mal parseadas, citas en el día equivocado, cierres que no
  /// pisan— vive aquí, y aquí no hay red, así que se puede probar con las
  /// mismas formas que devuelve la API de verdad.
  @visibleForTesting
  static List<DaySchedule> armarDias({
    required DateTime desde,
    required int horizonDays,
    required List<dynamic> horario,
    required List<dynamic> cierres,
    required List<dynamic> ocupados,
  }) {
    final franjas = _franjasPorDia(horario);
    final cerrados = {
      for (final fila in cierres) DateTime.parse(fila['fecha'] as String),
    };
    final tomados = _ocupadosPorDia(ocupados);

    return [
      for (var i = 0; i < horizonDays; i++)
        _dia(
          DateTime(desde.year, desde.month, desde.day + i),
          franjas,
          cerrados,
          tomados,
        ),
    ];
  }

  static DaySchedule _dia(
    DateTime fecha,
    Map<int, List<TimeWindow>> franjas,
    Set<DateTime> cerrados,
    Map<DateTime, List<BusySlot>> ocupados,
  ) {
    // Un cierre puntual pesa más que el horario habitual: el 25 de
    // diciembre es jueves y no por eso se abre.
    if (cerrados.contains(fecha)) return DaySchedule(date: fecha);

    return DaySchedule(
      date: fecha,
      windows: franjas[fecha.weekday] ?? const [],
      busy: ocupados[fecha] ?? const [],
    );
  }

  /// Agrupa el horario por día de la semana.
  ///
  /// `dia_semana` se guardó en ISO —1 es lunes— justamente para que coincida
  /// con `DateTime.weekday` y no haya que traducir nada aquí.
  static Map<int, List<TimeWindow>> _franjasPorDia(List<dynamic> filas) {
    final porDia = <int, List<TimeWindow>>{};
    for (final fila in filas) {
      final dia = fila['dia_semana'] as int;
      porDia.putIfAbsent(dia, () => []).add(
            TimeWindow(
              start: _minutos(fila['abre'] as String),
              end: _minutos(fila['cierra'] as String),
            ),
          );
    }
    // La pantalla las pinta en orden, así que llegan ordenadas.
    for (final franjas in porDia.values) {
      franjas.sort((a, b) => a.start.compareTo(b.start));
    }
    return porDia;
  }

  /// Agrupa las citas ajenas por el día al que pertenecen.
  ///
  /// Postgres las manda como instantes absolutos; el modelo razona en
  /// minutos desde medianoche. La conversión usa la zona del dispositivo,
  /// que para la clientela de una estética de barrio es la de la estética.
  /// Si algún día importa de verdad, el sitio donde arreglarlo es este.
  static Map<DateTime, List<BusySlot>> _ocupadosPorDia(List<dynamic> filas) {
    final porDia = <DateTime, List<BusySlot>>{};
    for (final fila in filas) {
      final empieza = DateTime.parse(fila['empieza'] as String).toLocal();
      final termina = DateTime.parse(fila['termina'] as String).toLocal();
      final dia = DateTime(empieza.year, empieza.month, empieza.day);

      porDia.putIfAbsent(dia, () => []).add(
            BusySlot(
              start: empieza.hour * 60 + empieza.minute,
              minutes: termina.difference(empieza).inMinutes,
            ),
          );
    }
    return porDia;
  }

  /// `HH:MM:SS` de Postgres a minutos desde medianoche.
  static int _minutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// `YYYY-MM-DD`, que es lo que esperan las consultas por fecha.
  static String _fecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
