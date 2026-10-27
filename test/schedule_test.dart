import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/format/dates.dart';
import 'package:perro_look/features/booking/data/availability_catalog.dart';
import 'package:perro_look/features/booking/models/schedule.dart';

/// La mañana del catálogo: 08:00 a 12:00, en pasos de 45 minutos. Los
/// comienzos posibles son 08:00, 08:45, 09:30, 10:15, 11:00 y 11:45.
const manana = AvailabilityCatalog.morning;

/// Un lunes cualquiera, para no depender de qué día se corran los tests.
final lunes = DateTime(2026, 11, 2);

void main() {
  group('DaySchedule', () {
    test('sin citas encima, todo lo que cabe queda disponible', () {
      final day = DaySchedule(date: lunes, windows: const [manana]);

      final slots = day.slotsIn(manana, 60);

      expect(slots.first.start, 8 * 60);
      expect(slots, hasLength(6));
      // Todos menos el último: ese ya no termina antes de cerrar, y de eso
      // se ocupa el test siguiente.
      expect(slots.take(slots.length - 1).every((s) => s.isFree), isTrue);
    });

    test('el último comienzo se descarta si la cita no termina antes de cerrar',
        () {
      final day = DaySchedule(date: lunes, windows: const [manana]);

      // 11:45 + 60 min = 12:45, y la mañana cierra a las 12:00.
      final ultimo = day.slotsIn(manana, 60).last;

      expect(ultimo.start, 11 * 60 + 45);
      expect(ultimo.status, SlotStatus.tooLong);
    });

    test('una cita larga deja fuera más comienzos que una corta', () {
      final day = DaySchedule(date: lunes, windows: const [manana]);

      final cortos = day.slotsIn(manana, 60).where((s) => s.isFree).length;
      final largos = day.slotsIn(manana, 120).where((s) => s.isFree).length;

      expect(largos, lessThan(cortos));
    });

    test('una cita ocupada bloquea también los comienzos que la pisan', () {
      // Una cita de 08:45 a 09:45 no solo ocupa su propio comienzo.
      final day = DaySchedule(
        date: lunes,
        windows: const [manana],
        busy: const [BusySlot(start: 8 * 60 + 45, minutes: 60)],
      );

      final porHora = {
        for (final slot in day.slotsIn(manana, 60)) slot.start: slot.status,
      };

      // 08:00 + 60 min termina a las 09:00, dentro de la cita ajena.
      expect(porHora[8 * 60], SlotStatus.taken);
      expect(porHora[8 * 60 + 45], SlotStatus.taken);
      // 09:30 empieza dentro de la cita ajena.
      expect(porHora[9 * 60 + 30], SlotStatus.taken);
      // 10:15 ya está limpio.
      expect(porHora[10 * 60 + 15], SlotStatus.free);
    });

    test('un día sin franjas está cerrado y no tiene sitio para nada', () {
      final day = DaySchedule(date: lunes);

      expect(day.isClosed, isTrue);
      expect(day.hasRoomFor(60), isFalse);
    });
  });

  group('AvailabilityCatalog', () {
    test('ofrece dos semanas desde el día que se le pase', () {
      final days = AvailabilityCatalog.nextDays(lunes);

      expect(days, hasLength(AvailabilityCatalog.horizonDays));
      expect(days.first.date, lunes);
    });

    test('sábado y domingo están cerrados', () {
      final days = AvailabilityCatalog.nextDays(lunes);
      final finDeSemana =
          days.where((d) => d.date.weekday >= DateTime.saturday);

      expect(finDeSemana, isNotEmpty);
      expect(finDeSemana.every((d) => d.isClosed), isTrue);
    });

    test('los días laborables abren y tienen sitio para una cita normal', () {
      final days = AvailabilityCatalog.nextDays(lunes);
      final laborables =
          days.where((d) => d.date.weekday < DateTime.saturday);

      expect(laborables.every((d) => d.hasRoomFor(60)), isTrue);
    });

    test('la agenda de muestra es estable entre ejecuciones', () {
      // Si dependiera del azar, ningún test podría afirmar nada sobre un día
      // concreto.
      final unaVez = AvailabilityCatalog.nextDays(lunes).first;
      final otraVez = AvailabilityCatalog.nextDays(lunes).first;

      expect(
        unaVez.busy.map((b) => b.start),
        otraVez.busy.map((b) => b.start),
      );
    });

    test('todo día abierto deja sitio para la cita más larga', () {
      // Los huecos de muestra van pegados al borde de su franja justamente
      // para esto: uno en mitad la parte en dos trozos cortos y entonces un
      // corte de dos horas no cabría ningún día.
      for (final inicio in [DateTime(2026, 11, 2), DateTime(2026, 3, 9)]) {
        final abiertos =
            AvailabilityCatalog.nextDays(inicio).where((d) => !d.isClosed);

        expect(abiertos, isNotEmpty);
        expect(abiertos.every((d) => d.hasRoomFor(120)), isTrue);
      }
    });

    test('cruza el cambio de mes sin saltarse días', () {
      final days = AvailabilityCatalog.nextDays(DateTime(2026, 10, 29));

      expect(days[2].date, DateTime(2026, 10, 31));
      expect(days[3].date, DateTime(2026, 11, 1));
    });
  });

  group('formato', () {
    test('formatHour rellena con ceros', () {
      expect(formatHour(8 * 60), '08:00');
      expect(formatHour(14 * 60 + 30), '14:30');
    });

    test('formatWeekdayShort abrevia a tres letras con tilde', () {
      expect(formatWeekdayShort(lunes), 'Lun');
      expect(formatWeekdayShort(DateTime(2026, 11, 4)), 'Mié');
      expect(formatWeekdayShort(DateTime(2026, 11, 7)), 'Sáb');
    });

    test('formatLongDate escribe el día completo', () {
      expect(formatLongDate(lunes), 'Lunes 2 de noviembre');
    });

    test('formatMonth capitaliza el mes', () {
      expect(formatMonth(lunes), 'Noviembre');
    });
  });
}
