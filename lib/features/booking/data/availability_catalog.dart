import '../models/schedule.dart';

/// La agenda de la estética.
///
/// OJO: igual que los precios del catálogo, las citas ya tomadas son de
/// muestra. El horario de atención sí sale del póster (sábado y domingo
/// cerrado), pero quién ocupa qué hueco habrá que traerlo de la agenda real
/// antes de enseñarle esto a un cliente.
class AvailabilityCatalog {
  const AvailabilityCatalog._();

  /// Hasta dónde se puede reservar. El póster promete "las próximas dos
  /// semanas".
  static const int horizonDays = 14;

  static const TimeWindow morning = TimeWindow(start: 8 * 60, end: 12 * 60);
  static const TimeWindow afternoon =
      TimeWindow(start: 14 * 60 + 30, end: 18 * 60);

  /// La agenda de los próximos [horizonDays] días contando desde [from].
  static List<DaySchedule> nextDays(DateTime from) {
    return [
      for (var i = 0; i < horizonDays; i++)
        // Construir la fecha por componentes en vez de sumar duraciones deja
        // que DateTime normalice los saltos de mes y de año.
        _scheduleFor(DateTime(from.year, from.month, from.day + i)),
    ];
  }

  static DaySchedule _scheduleFor(DateTime date) {
    if (date.weekday >= DateTime.saturday) return DaySchedule(date: date);
    return DaySchedule(
      date: date,
      windows: const [morning, afternoon],
      busy: _busyOn(date),
    );
  }

  /// Citas de muestra, derivadas de la propia fecha.
  ///
  /// Se hace así y no al azar por dos motivos: la pantalla se ve poblada
  /// como se verá de verdad, y dos ejecuciones dan lo mismo, de modo que un
  /// test puede afirmar algo sobre un día concreto.
  ///
  /// Van pegadas a un extremo de su franja, alternando según el día. Suena
  /// arbitrario y lo es, pero tiene un motivo: una cita en mitad de una
  /// franja la parte en dos trozos cortos, y entonces un corte de dos horas
  /// no cabe en ninguno. Con los huecos al borde siempre queda un bloque
  /// continuo. Cuando esto se sustituya por la agenda real, el problema
  /// vuelve —una mañana de verdad sí se puede fragmentar—, y ahí tocará
  /// decidir qué se le dice al cliente cuando ningún día le sirve.
  static List<BusySlot> _busyOn(DateTime date) {
    final alPrincipio = (date.day + date.month).isEven;
    return [
      BusySlot(
        start: alPrincipio ? morning.start : morning.end - 60,
        minutes: 60,
      ),
      BusySlot(
        start: alPrincipio ? afternoon.end - 75 : afternoon.start,
        minutes: 60,
      ),
    ];
  }
}
