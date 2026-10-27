/// Cada cuánto puede empezar una cita, en minutos.
///
/// La rejilla es de 45 minutos y no de la duración del servicio: así todos
/// los días ofrecen las mismas horas en punto y el cliente ve una agenda
/// estable, no una que cambia de forma según lo que haya marcado.
const int slotStep = 45;

/// Una franja en la que la estética atiende, en minutos desde medianoche.
///
/// Son dos al día —mañana y tarde— y el hueco del almuerzo es justo lo que
/// queda entre ellas. Modelarlo así, en vez de con una franja larga y una
/// excepción, hace que "la cita tiene que terminar antes de cerrar" sea una
/// sola comparación.
class TimeWindow {
  const TimeWindow({required this.start, required this.end});

  final int start;
  final int end;
}

/// Una cita que ya ocupa sitio en la agenda.
class BusySlot {
  const BusySlot({required this.start, required this.minutes});

  final int start;
  final int minutes;

  int get end => start + minutes;

  /// Dos citas chocan si cada una empieza antes de que termine la otra.
  ///
  /// No basta con mirar si coinciden los comienzos: un baño de dos horas a
  /// las 08:00 pisa también las 08:45 y las 09:30, aunque ahí no empiece
  /// nada.
  bool overlaps(int otherStart, int otherMinutes) =>
      otherStart < end && start < otherStart + otherMinutes;
}

/// Por qué un horario se puede o no se puede elegir.
enum SlotStatus {
  /// Cabe entero y no choca con nada.
  free,

  /// Ya hay otra cita encima.
  taken,

  /// Libre, pero la cita no terminaría antes de cerrar.
  tooLong,
}

/// Un horario concreto con su veredicto ya calculado.
///
/// La pantalla no vuelve a razonar sobre disponibilidad: recibe la lista ya
/// resuelta y solo decide cómo se pinta cada estado.
class SlotOption {
  const SlotOption({required this.start, required this.status});

  final int start;
  final SlotStatus status;

  bool get isFree => status == SlotStatus.free;
}

/// Un día de la agenda.
class DaySchedule {
  const DaySchedule({
    required this.date,
    this.windows = const [],
    this.busy = const [],
  });

  final DateTime date;

  /// Las franjas de atención. Una lista vacía significa cerrado.
  final List<TimeWindow> windows;

  final List<BusySlot> busy;

  bool get isClosed => windows.isEmpty;

  /// Los comienzos posibles dentro de [window] para una cita de [minutes],
  /// cada uno con el motivo por el que sirve o no.
  List<SlotOption> slotsIn(TimeWindow window, int minutes) {
    return [
      for (var start = window.start; start < window.end; start += slotStep)
        SlotOption(start: start, status: _statusAt(start, minutes, window)),
    ];
  }

  SlotStatus _statusAt(int start, int minutes, TimeWindow window) {
    // Que esté ocupado manda sobre que no quepa: de las dos razones es la
    // concreta, y es la que el cliente entiende de un vistazo.
    for (final slot in busy) {
      if (slot.overlaps(start, minutes)) return SlotStatus.taken;
    }
    if (start + minutes > window.end) return SlotStatus.tooLong;
    return SlotStatus.free;
  }

  /// Si no queda ni un comienzo bueno, el día entero no sirve para esta cita
  /// y la tira de días puede decirlo antes de que nadie lo toque.
  bool hasRoomFor(int minutes) =>
      windows.any((window) => slotsIn(window, minutes).any((s) => s.isFree));
}
