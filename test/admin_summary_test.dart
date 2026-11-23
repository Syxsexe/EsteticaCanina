import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/features/admin/models/admin_summary.dart';
import 'package:perro_look/features/admin/models/agenda_entry.dart';

/// Un lunes fijo, para que la semana no dependa de cuándo se corra la prueba.
final lunes = DateTime(2026, 11, 2);

AgendaEntry cita({
  String id = 'c1',
  required DateTime empieza,
  EstadoCita estado = EstadoCita.reservada,
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
  test('sin citas cerradas el porcentaje de no asistencia es cero', () {
    final resumen = AdminSummary.fromData(
      citas: const [],
      hoy: lunes,
      clientesNuevos: 0,
      proximas: const [],
    );

    expect(resumen.citasHoy, 0);
    expect(resumen.citasSemana, 0);
    expect(resumen.ingresosMesCop, 0);
    expect(resumen.noAsistenciaPct, 0);
    expect(resumen.topServicios, isEmpty);
    expect(resumen.proximas, isEmpty);
  });

  test('cuenta hoy y la semana, y suma solo las citas cumplidas', () {
    final resumen = AdminSummary.fromData(
      citas: [
        cita(id: 'hoy', empieza: lunes.add(const Duration(hours: 9))),
        cita(
          id: 'hoy-cumplida',
          empieza: lunes.add(const Duration(hours: 11)),
          estado: EstadoCita.cumplida,
          total: 40000,
        ),
        cita(
          id: 'domingo',
          empieza: lunes.add(const Duration(days: 6, hours: 10)),
          estado: EstadoCita.cumplida,
          total: 50000,
        ),
        cita(
          id: 'fuera-de-semana',
          empieza: lunes.add(const Duration(days: 8)),
          estado: EstadoCita.cumplida,
          total: 99000,
        ),
        cita(
          id: 'cancelada',
          empieza: lunes.add(const Duration(hours: 15)),
          estado: EstadoCita.cancelada,
        ),
      ],
      hoy: lunes,
      clientesNuevos: 3,
      proximas: const [],
    );

    expect(resumen.citasHoy, 2);
    expect(resumen.citasSemana, 3);
    // Los ingresos son del mes entero, aunque la cita quede fuera de la semana.
    expect(resumen.ingresosMesCop, 189000);
    expect(resumen.clientesNuevosMes, 3);
  });

  test('el porcentaje usa cumplidas más no asistió como denominador', () {
    final resumen = AdminSummary.fromData(
      citas: [
        cita(
          id: 'cumplida',
          empieza: lunes.add(const Duration(days: 2)),
          estado: EstadoCita.cumplida,
        ),
        cita(
          id: 'ausente-1',
          empieza: lunes.add(const Duration(days: 1)),
          estado: EstadoCita.noAsistio,
        ),
        cita(
          id: 'ausente-2',
          empieza: lunes.add(const Duration(days: 3)),
          estado: EstadoCita.noAsistio,
        ),
        cita(
          id: 'cancelada',
          empieza: lunes.add(const Duration(days: 4)),
          estado: EstadoCita.cancelada,
        ),
      ],
      hoy: lunes,
      clientesNuevos: 0,
      proximas: const [],
    );

    expect(resumen.noAsistenciaPct, 67);
  });

  test('el top de servicios ordena por cantidad y desempata por nombre', () {
    final resumen = AdminSummary.fromData(
      citas: [
        cita(id: '1', empieza: lunes, servicios: const ['Baño', 'Corte']),
        cita(id: '2', empieza: lunes, servicios: const ['Baño']),
        cita(id: '3', empieza: lunes, servicios: const ['Corte']),
        cita(id: '4', empieza: lunes, servicios: const ['Uñas']),
        cita(id: '5', empieza: lunes, servicios: const ['Dientes']),
      ],
      hoy: lunes,
      clientesNuevos: 0,
      proximas: const [],
    );

    expect(resumen.topServicios.length, 3);
    expect(resumen.topServicios[0].name, 'Baño');
    expect(resumen.topServicios[0].count, 2);
    expect(resumen.topServicios[1].name, 'Corte');
    expect(resumen.topServicios[1].count, 2);
    expect(resumen.topServicios[2].name, 'Dientes');
  });

  test('mezclar fechas UTC con un hoy local no mueve la semana', () {
    // Postgres manda los instantes marcados como UTC; hoyEnLaEstetica()
    // devuelve la fecha con marca local. Compararlas como instantes
    // desplazaría la semana por el desfase del dispositivo.
    final resumen = AdminSummary.fromData(
      citas: [cita(id: 'madrugada', empieza: DateTime.utc(2026, 11, 2, 0, 30))],
      hoy: lunes,
      clientesNuevos: 0,
      proximas: const [],
    );

    expect(resumen.citasHoy, 1);
    expect(resumen.citasSemana, 1);
  });

  group('semana que cruza de mes', () {
    // Martes 1 de diciembre: la semana empieza el lunes 30 de noviembre.
    final primeroDeDiciembre = DateTime(2026, 12, 1);
    final treintaDeNoviembre = DateTime(2026, 11, 30);

    test('los ingresos solo suman el mes en curso', () {
      final resumen = AdminSummary.fromData(
        citas: [
          cita(
            id: 'noviembre',
            empieza: treintaDeNoviembre.add(const Duration(hours: 10)),
            estado: EstadoCita.cumplida,
            total: 40000,
          ),
          cita(
            id: 'diciembre',
            empieza: primeroDeDiciembre.add(const Duration(hours: 10)),
            estado: EstadoCita.cumplida,
            total: 35000,
          ),
        ],
        hoy: primeroDeDiciembre,
        clientesNuevos: 0,
        proximas: const [],
      );

      expect(resumen.ingresosMesCop, 35000);
      expect(resumen.citasSemana, 2);
    });

    test('una ausencia del mes anterior no cuenta para el porcentaje', () {
      final resumen = AdminSummary.fromData(
        citas: [
          cita(
            id: 'ausente-noviembre',
            empieza: treintaDeNoviembre.add(const Duration(hours: 9)),
            estado: EstadoCita.noAsistio,
          ),
          cita(
            id: 'cumplida-diciembre',
            empieza: primeroDeDiciembre.add(const Duration(hours: 9)),
            estado: EstadoCita.cumplida,
          ),
        ],
        hoy: primeroDeDiciembre,
        clientesNuevos: 0,
        proximas: const [],
      );

      expect(resumen.noAsistenciaPct, 0);
    });

    test('un servicio pedido solo en el mes siguiente no entra al top', () {
      // Lunes 30 de noviembre: la semana termina el domingo 6 de diciembre.
      final resumen = AdminSummary.fromData(
        citas: [
          cita(
            id: 'noviembre',
            empieza: treintaDeNoviembre.add(const Duration(hours: 9)),
            servicios: const ['Baño'],
          ),
          cita(
            id: 'diciembre',
            empieza: primeroDeDiciembre.add(const Duration(hours: 9)),
            servicios: const ['Corte'],
          ),
        ],
        hoy: treintaDeNoviembre,
        clientesNuevos: 0,
        proximas: const [],
      );

      expect(resumen.topServicios.map((s) => s.name), ['Baño']);
      expect(resumen.citasSemana, 2);
    });
  });

  test('cuenta las canceladas del mes y su porcentaje sobre lo agendado', () {
    final resumen = AdminSummary.fromData(
      citas: [
        for (var i = 0; i < 8; i++)
          cita(id: 'ok-$i', empieza: lunes.add(Duration(days: i, hours: 9))),
        for (var i = 0; i < 2; i++)
          cita(
            id: 'cancelada-$i',
            empieza: lunes.add(Duration(days: i, hours: 15)),
            estado: EstadoCita.cancelada,
          ),
      ],
      hoy: lunes,
      clientesNuevos: 0,
      proximas: const [],
    );

    expect(resumen.canceladasMes, 2);
    expect(resumen.canceladasPct, 20);
  });

  test('las próximas se recortan a cinco y respetan el orden recibido', () {
    final proximas = [
      for (var i = 0; i < 7; i++)
        cita(id: 'p$i', empieza: lunes.add(Duration(days: i + 1))),
    ];

    final resumen = AdminSummary.fromData(
      citas: const [],
      hoy: lunes,
      clientesNuevos: 0,
      proximas: proximas,
    );

    expect(resumen.proximas.length, 5);
    expect(resumen.proximas.first.id, 'p0');
    expect(resumen.proximas.last.id, 'p4');
  });
}
