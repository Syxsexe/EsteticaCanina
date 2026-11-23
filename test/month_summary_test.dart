import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/time/salon_time.dart';
import 'package:perro_look/features/admin/data/analytics_repository.dart';
import 'package:perro_look/features/admin/models/agenda_entry.dart';
import 'package:perro_look/features/admin/models/month_summary.dart';

final octubre = DateTime(2026, 10);

AgendaEntry cita({
  required String id,
  required DateTime empieza,
  EstadoCita estado = EstadoCita.cumplida,
  int total = 35000,
  List<String> servicios = const ['Baño'],
}) =>
    AgendaEntry(
      id: id,
      empieza: empieza,
      minutos: 60,
      estado: estado,
      totalCop: total,
      servicios: servicios,
    );

void main() {
  group('meses disponibles', () {
    final hoy = DateTime(2026, 11, 23);

    test('van del mes en curso hacia atrás hasta la primera cita', () async {
      final repositorio = SampleAnalyticsRepository(
        hoy: hoy,
        historico: [
          cita(id: 'oct', empieza: DateTime(2026, 10, 2, 9)),
          cita(id: 'ago', empieza: DateTime(2026, 8, 14, 9)),
        ],
      );

      // Septiembre no tuvo citas y aparece igual.
      expect(await repositorio.mesesDisponibles(), [
        DateTime(2026, 11),
        DateTime(2026, 10),
        DateTime(2026, 9),
        DateTime(2026, 8),
      ]);
    });

    test('sin citas solo está el mes en curso', () async {
      final repositorio =
          SampleAnalyticsRepository(hoy: hoy, historico: const []);
      expect(await repositorio.mesesDisponibles(), [DateTime(2026, 11)]);
    });

    test('cruzan el cambio de año', () {
      expect(
        mesesEntre(primera: DateTime(2025, 12, 30), hoy: DateTime(2026, 2, 1)),
        [DateTime(2026, 2), DateTime(2026, 1), DateTime(2025, 12)],
      );
    });

    test('la muestra sin histórico ofrece el mes en curso y dos más', () async {
      final repositorio = SampleAnalyticsRepository(hoy: hoy);
      expect(await repositorio.mesesDisponibles(), hasLength(3));
      final octubre = await repositorio.resumenDelMes(DateTime(2026, 10));
      expect(octubre.citas, isNotEmpty);
    });
  });

  test('octubre: 4 citas, 105000 de ingresos y 25 % de no asistencia', () {
    final resumen = MonthSummary.fromData(
      mes: octubre,
      citas: [
        cita(id: 'c3', empieza: DateTime(2026, 10, 20, 9)),
        cita(id: 'c1', empieza: DateTime(2026, 10, 5, 9)),
        cita(id: 'c2', empieza: DateTime(2026, 10, 12, 9)),
        cita(
          id: 'ausente',
          empieza: DateTime(2026, 10, 14, 10),
          estado: EstadoCita.noAsistio,
          servicios: const ['Corte completo'],
        ),
        cita(
          id: 'cancelada',
          empieza: DateTime(2026, 10, 15, 10),
          estado: EstadoCita.cancelada,
        ),
        // De noviembre: no cuenta.
        cita(id: 'noviembre', empieza: DateTime(2026, 11, 2, 9)),
      ],
      clientesNuevos: 2,
    );

    expect(resumen.totalCitas, 4);
    // Cinco agendadas en octubre, una cancelada: 1 y 20 %.
    expect(resumen.canceladas, 1);
    expect(resumen.canceladasPct, 20);
    expect(resumen.ingresosCop, 105000);
    expect(resumen.noAsistenciaPct, 25);
    expect(resumen.clientesNuevos, 2);
    expect(resumen.topServicios.first.name, 'Baño');
    expect(resumen.topServicios.first.count, 3);

    // La lista lleva también la cancelada, en orden de inicio.
    expect(
      resumen.citas.map((c) => c.id),
      ['c1', 'c2', 'ausente', 'cancelada', 'c3'],
    );
  });

  test('un mes sin citas da ceros y lista vacía', () {
    final resumen = MonthSummary.fromData(
      mes: DateTime(2026, 9),
      citas: const [],
      clientesNuevos: 0,
    );

    expect(resumen.totalCitas, 0);
    expect(resumen.canceladas, 0);
    expect(resumen.canceladasPct, 0);
    expect(resumen.ingresosCop, 0);
    expect(resumen.noAsistenciaPct, 0);
    expect(resumen.topServicios, isEmpty);
    expect(resumen.citas, isEmpty);
  });

  test('el 31 de octubre a las 20:00 de Bogotá es de octubre', () {
    // Postgres la manda como 1 de noviembre 01:00 UTC; el repositorio la
    // convierte con enHoraEstetica antes de llegar aquí.
    final instante = DateTime.utc(2026, 11, 1, 1);
    final enBogota = enHoraEstetica(instante);

    final deOctubre = MonthSummary.fromData(
      mes: octubre,
      citas: [cita(id: 'tarde', empieza: enBogota)],
      clientesNuevos: 0,
    );
    final deNoviembre = MonthSummary.fromData(
      mes: DateTime(2026, 11),
      citas: [cita(id: 'tarde', empieza: enBogota)],
      clientesNuevos: 0,
    );

    expect(deOctubre.totalCitas, 1);
    expect(deNoviembre.totalCitas, 0);
  });
}
