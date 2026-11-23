import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/admin_analytics_screen.dart';
import 'package:perro_look/features/admin/data/analytics_repository.dart';
import 'package:perro_look/features/admin/models/admin_summary.dart';
import 'package:perro_look/features/admin/models/agenda_entry.dart';
import 'package:perro_look/features/admin/models/month_summary.dart';

final hoy = DateTime(2026, 11, 23);

AgendaEntry cita(
  String id,
  DateTime empieza, {
  EstadoCita estado = EstadoCita.cumplida,
  String cliente = 'Ana',
}) =>
    AgendaEntry(
      id: id,
      empieza: empieza,
      minutos: 60,
      estado: estado,
      totalCop: 35000,
      clienteNombre: cliente,
      mascotaNombre: 'Toby',
      servicios: const ['Baño'],
      servicioIds: const ['bano'],
    );

/// Octubre con citas, septiembre vacío y agosto con una cita, para que el
/// desplegable tenga un mes sin citas en medio.
class Historico extends SampleAnalyticsRepository {
  Historico({this.fallaMeses = false, this.fallaMesUnaVez = false})
      : super(
          hoy: hoy,
          historico: [
            cita('oct-1', DateTime(2026, 10, 5, 9), cliente: 'Luis'),
            cita(
              'oct-2',
              DateTime(2026, 10, 12, 9),
              estado: EstadoCita.cancelada,
              cliente: 'Camila',
            ),
            cita('ago-1', DateTime(2026, 8, 14, 9)),
          ],
        );

  final bool fallaMeses;
  bool fallaMesUnaVez;
  final List<DateTime> mesesPedidos = [];

  @override
  Future<AdminSummary> resumen() async => const AdminSummary(
        citasHoy: 2,
        citasSemana: 5,
        ingresosMesCop: 90000,
        noAsistenciaPct: 0,
        clientesNuevosMes: 1,
        topServicios: [],
        proximas: [],
      );

  @override
  Future<List<DateTime>> mesesDisponibles() async {
    if (fallaMeses) throw Exception('sin red');
    return super.mesesDisponibles();
  }

  @override
  Future<MonthSummary> resumenDelMes(DateTime mes) async {
    mesesPedidos.add(mes);
    if (fallaMesUnaVez) {
      fallaMesUnaVez = false;
      throw Exception('sin red');
    }
    return super.resumenDelMes(mes);
  }
}

Future<void> abrir(WidgetTester tester, AnalyticsRepository repositorio) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: AdminAnalyticsScreen(repository: repositorio, hoy: hoy),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> elegir(WidgetTester tester, String mes) async {
  await tester.tap(find.byKey(const Key('selector-mes')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mes).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abre en el mes en curso y lista los meses hasta la primera cita',
      (tester) async {
    await abrir(tester, Historico());

    expect(find.text('Noviembre 2026 (este mes)'), findsOneWidget);
    expect(find.text('CITAS HOY'), findsOneWidget);
    expect(find.text('CANCELADAS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('selector-mes')));
    await tester.pumpAndSettle();

    for (final mes in ['Octubre 2026', 'Septiembre 2026', 'Agosto 2026']) {
      expect(find.text(mes), findsWidgets);
    }
    expect(find.text('Julio 2026'), findsNothing);
  });

  testWidgets('un mes pasado muestra sus citas y oculta el presente',
      (tester) async {
    await abrir(tester, Historico());
    await elegir(tester, 'Octubre 2026');

    expect(find.text('CITAS DE OCTUBRE'), findsOneWidget);
    // Luis cumplida y Camila cancelada, las dos en la lista.
    expect(find.textContaining('Luis'), findsOneWidget);
    expect(find.textContaining('Camila'), findsOneWidget);
    expect(find.text('CANCELADA'), findsOneWidget);
    // Una sola no cancelada y sus ingresos.
    expect(find.text('CITAS DEL MES'), findsOneWidget);
    expect(find.text('\$35.000'), findsWidgets);

    // Dos agendadas en octubre, una cancelada.
    expect(find.text('CANCELADAS'), findsOneWidget);
    expect(find.text('1 · 50 %'), findsOneWidget);

    expect(find.text('CITAS HOY'), findsNothing);
    expect(find.text('CITAS SEMANA'), findsNothing);
    expect(find.text('PRÓXIMAS CITAS'), findsNothing);
  });

  testWidgets('un mes sin citas lo dice', (tester) async {
    await abrir(tester, Historico());
    await elegir(tester, 'Septiembre 2026');

    expect(find.text('En Septiembre no hubo citas.'), findsOneWidget);
    expect(find.text('Ese mes no hubo servicios.'), findsOneWidget);
  });

  testWidgets('volver al mes en curso recupera hoy, semana y próximas',
      (tester) async {
    await abrir(tester, Historico());
    await elegir(tester, 'Octubre 2026');
    await elegir(tester, 'Noviembre 2026 (este mes)');

    expect(find.text('CITAS HOY'), findsOneWidget);
    expect(find.text('PRÓXIMAS CITAS'), findsOneWidget);
  });

  testWidgets('reintentar tras un fallo consulta el mismo mes',
      (tester) async {
    final repositorio = Historico(fallaMesUnaVez: true);
    await abrir(tester, repositorio);
    await elegir(tester, 'Octubre 2026');

    expect(find.text('No pudimos traer las estadísticas.'), findsOneWidget);
    // El desplegable sigue en octubre.
    expect(find.text('Octubre 2026'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('CITAS DE OCTUBRE'), findsOneWidget);
    expect(repositorio.mesesPedidos, [DateTime(2026, 10), DateTime(2026, 10)]);
  });

  testWidgets('si no llegan los meses, queda el mes en curso y funciona',
      (tester) async {
    await abrir(tester, Historico(fallaMeses: true));

    expect(find.text('CITAS HOY'), findsOneWidget);
    await tester.tap(find.byKey(const Key('selector-mes')));
    await tester.pumpAndSettle();
    expect(find.text('Octubre 2026'), findsNothing);
  });
}
