import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/features/booking/data/supabase_availability_repository.dart';

/// Las formas son las que devuelve la API de verdad, copiadas de una
/// consulta real al proyecto: `abre` y `cierra` llegan como `HH:MM:SS`, y
/// `dia_semana` en ISO, con el 1 en lunes.
const horarioReal = [
  {'dia_semana': 1, 'abre': '14:30:00', 'cierra': '18:00:00'},
  {'dia_semana': 1, 'abre': '08:00:00', 'cierra': '12:00:00'},
  {'dia_semana': 2, 'abre': '08:00:00', 'cierra': '12:00:00'},
  {'dia_semana': 3, 'abre': '08:00:00', 'cierra': '12:00:00'},
  {'dia_semana': 4, 'abre': '08:00:00', 'cierra': '12:00:00'},
  {'dia_semana': 5, 'abre': '08:00:00', 'cierra': '12:00:00'},
];

/// Lunes.
final lunes = DateTime(2026, 11, 2);

/// Una cita ajena, construida desde hora local y mandada en UTC, que es
/// como viaja por la API. Así el test dice lo mismo en cualquier máquina.
Map<String, dynamic> citaAjena(DateTime inicio, DateTime fin) => {
      'empieza': inicio.toUtc().toIso8601String(),
      'termina': fin.toUtc().toIso8601String(),
    };

void main() {
  group('armarDias', () {
    test('devuelve tantos días como diga el horizonte, desde el primero', () {
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 14,
        horario: horarioReal,
        cierres: const [],
        ocupados: const [],
      );

      expect(dias, hasLength(14));
      expect(dias.first.date, lunes);
      expect(dias.last.date, DateTime(2026, 11, 15));
    });

    test('las horas de Postgres se vuelven minutos desde medianoche', () {
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 1,
        horario: horarioReal,
        cierres: const [],
        ocupados: const [],
      );

      final franjas = dias.first.windows;
      expect(franjas, hasLength(2));
      // Y llegan ordenadas, aunque la consulta las haya devuelto al revés.
      expect(franjas[0].start, 8 * 60);
      expect(franjas[0].end, 12 * 60);
      expect(franjas[1].start, 14 * 60 + 30);
      expect(franjas[1].end, 18 * 60);
    });

    test('un día sin filas en el horario está cerrado', () {
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 7,
        horario: horarioReal,
        cierres: const [],
        ocupados: const [],
      );

      // Sábado 7 y domingo 8: el horario no los menciona.
      expect(dias[5].date.weekday, DateTime.saturday);
      expect(dias[5].isClosed, isTrue);
      expect(dias[6].isClosed, isTrue);
      // Los laborables sí abren.
      expect(dias.take(5).every((d) => d.isClosed), isFalse);
    });

    test('un cierre puntual pesa más que el horario habitual', () {
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 3,
        horario: horarioReal,
        cierres: const [
          {'fecha': '2026-11-03'},
        ],
        ocupados: const [],
      );

      expect(dias[0].isClosed, isFalse);
      // El martes 3 es laborable y aun así queda cerrado.
      expect(dias[1].date, DateTime(2026, 11, 3));
      expect(dias[1].isClosed, isTrue);
      expect(dias[2].isClosed, isFalse);
    });

    test('una cita ajena cae en su día, a su hora y con su duración', () {
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 3,
        horario: horarioReal,
        cierres: const [],
        ocupados: [
          citaAjena(
            DateTime(2026, 11, 3, 9, 0),
            DateTime(2026, 11, 3, 10, 30),
          ),
        ],
      );

      expect(dias[0].busy, isEmpty);

      final ocupado = dias[1].busy.single;
      expect(ocupado.start, 9 * 60);
      expect(ocupado.minutes, 90);
      expect(ocupado.end, 10 * 60 + 30);
    });

    test('varias citas el mismo día se agrupan juntas', () {
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 1,
        horario: horarioReal,
        cierres: const [],
        ocupados: [
          citaAjena(DateTime(2026, 11, 2, 8, 0), DateTime(2026, 11, 2, 9, 0)),
          citaAjena(DateTime(2026, 11, 2, 15, 0), DateTime(2026, 11, 2, 16, 0)),
        ],
      );

      expect(dias.first.busy, hasLength(2));
    });

    test('lo que llega de la base alimenta el modelo sin tocarlo', () {
      // La prueba de que la costura funciona: los DaySchedule que salen de
      // Postgres se razonan con el mismo `slotsIn` de siempre.
      final dias = SupabaseAvailabilityRepository.armarDias(
        desde: lunes,
        horizonDays: 1,
        horario: horarioReal,
        cierres: const [],
        ocupados: [
          citaAjena(DateTime(2026, 11, 2, 8, 0), DateTime(2026, 11, 2, 9, 0)),
        ],
      );

      final dia = dias.first;
      final manana = dia.windows.first;
      final huecos = {
        for (final s in dia.slotsIn(manana, 60)) s.start: s.status,
      };

      // Las 08:00 están tomadas y las 09:30 libres, con la misma lógica de
      // solapamiento que ya estaba probada.
      expect(huecos[8 * 60].toString(), contains('taken'));
      expect(huecos[9 * 60 + 30].toString(), contains('free'));
      expect(dia.hasRoomFor(60), isTrue);
    });
  });
}
