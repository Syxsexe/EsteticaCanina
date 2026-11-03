import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/time/salon_time.dart';
import 'package:perro_look/features/booking/models/booking.dart';
import 'package:perro_look/features/booking/models/service.dart';

const bano = Service(
  id: 'bano',
  name: 'Baño',
  note: 'Agua caliente, cepillado y secado.',
  price: 35000,
  minutes: 60,
);

void main() {
  group('la hora de la estética', () {
    test('las 09:00 de Bogotá son las 14:00 UTC', () {
      final instante = desdeHoraEstetica(DateTime(2026, 11, 4, 9, 0));

      expect(instante, DateTime.utc(2026, 11, 4, 14, 0));
      expect(instante.isUtc, isTrue);
    });

    test('las 14:00 UTC se leen como las 09:00 en la estética', () {
      final pared = enHoraEstetica(DateTime.utc(2026, 11, 4, 14, 0));

      expect(pared.hour, 9);
      expect(pared.day, 4);
    });

    test('ida y vuelta no pierde nada', () {
      final original = DateTime(2026, 11, 4, 16, 45);

      expect(enHoraEstetica(desdeHoraEstetica(original)).hour, 16);
      expect(enHoraEstetica(desdeHoraEstetica(original)).minute, 45);
    });

    test('cerca de medianoche el día no se adelanta', () {
      // Las 23:00 del 4 en Bogotá son las 04:00 del 5 en UTC. Leer el día
      // en UTC daría el 5, y la agenda abriría en el día equivocado.
      final instante = desdeHoraEstetica(DateTime(2026, 11, 4, 23, 0));

      expect(instante, DateTime.utc(2026, 11, 5, 4, 0));
      expect(enHoraEstetica(instante).day, 4);
    });
  });

  group('la hora que se le manda a Postgres', () {
    test('una cita a las 09:00 viaja como las 14:00 UTC', () {
      // Esta es la regresión. Antes `startsAt` usaba la hora del
      // dispositivo: en un emulador en UTC, elegir las 09:00 mandaba
      // 09:00Z, que para Postgres son las 04:00 de Bogotá —fuera del
      // horario— y la reserva fallaba con "no cabe en el horario".
      final booking = Booking(
        selection: const BookingSelection(mainService: bano),
        date: DateTime(2026, 11, 4),
        startMinutes: 9 * 60,
      );

      expect(booking.startsAt.toUtc().toIso8601String(),
          '2026-11-04T14:00:00.000Z');
    });

    test('la hora de fin también sale en el momento correcto', () {
      final booking = Booking(
        selection: const BookingSelection(mainService: bano),
        date: DateTime(2026, 11, 4),
        startMinutes: 9 * 60,
      );

      expect(booking.endsAt(const [bano]), DateTime.utc(2026, 11, 4, 15, 0));
    });

    test('el último hueco de la tarde sigue dentro del día', () {
      final booking = Booking(
        selection: const BookingSelection(mainService: bano),
        date: DateTime(2026, 11, 4),
        startMinutes: 16 * 60 + 45,
      );

      // 16:45 en Bogotá son las 21:45 UTC: mismo día, sin cruzar a mañana.
      expect(booking.startsAt, DateTime.utc(2026, 11, 4, 21, 45));
    });
  });
}
