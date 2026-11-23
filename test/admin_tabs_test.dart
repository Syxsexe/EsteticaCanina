import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/admin_appointment_form_screen.dart';
import 'package:perro_look/features/admin/admin_shell_screen.dart';
import 'package:perro_look/features/admin/agenda_screen.dart';
import 'package:perro_look/features/admin/data/admin_appointment_repository.dart';
import 'package:perro_look/features/admin/data/admin_session.dart';
import 'package:perro_look/features/admin/data/agenda_repository.dart';
import 'package:perro_look/features/admin/data/analytics_repository.dart';
import 'package:perro_look/features/admin/data/customer_directory_repository.dart';
import 'package:perro_look/features/admin/models/admin_summary.dart';
import 'package:perro_look/features/admin/models/agenda_entry.dart';
import 'package:perro_look/features/admin/models/month_summary.dart';
import 'package:perro_look/features/booking/data/availability_repository.dart';

/// Lunes fijo: la disponibilidad de muestra deriva los huecos de la fecha.
final lunes = DateTime(2026, 11, 2);

/// Una sola lista de citas que ven a la vez la agenda, el historial y el
/// resumen. Así un cambio en una pestaña se nota de verdad en las otras.
class Mundo
    implements AgendaRepository, AdminAppointmentRepository, AnalyticsRepository {
  Mundo(this.citas);

  List<AgendaEntry> citas;
  final List<DateTime> empiezasCreadas = [];
  final List<DateTime> empiezasEditadas = [];
  int resumenes = 0;
  int secuencia = 0;

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<List<AgendaEntry>> citasDe(DateTime dia) async => [
        for (final c in citas)
          if (_mismoDia(c.empieza, dia)) c,
      ]..sort((a, b) => a.empieza.compareTo(b.empieza));

  @override
  Future<void> marcar(String citaId, EstadoCita estado) async {
    citas = [
      for (final c in citas)
        if (c.id == citaId) c.copyWith(estado: estado) else c,
    ];
  }

  @override
  Future<List<AgendaEntry>> historial() async =>
      List.of(citas)..sort((a, b) => b.empieza.compareTo(a.empieza));

  @override
  Future<List<AgendaEntry>> historialDe(String clienteId) async => [
        for (final c in await historial())
          if (c.clienteId == clienteId) c,
      ];

  @override
  Future<void> editar({
    required String citaId,
    required DateTime empieza,
    required String? mascotaId,
    required List<String> servicios,
    required EstadoCita estado,
    required String? notas,
  }) async {
    empiezasEditadas.add(empieza);
  }

  @override
  Future<void> cancelar(String citaId) => marcar(citaId, EstadoCita.cancelada);

  @override
  Future<String> crear({
    required String clienteId,
    required String? mascotaId,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    empiezasCreadas.add(empieza);
    final id = 'nueva-${secuencia++}';
    citas = [
      ...citas,
      AgendaEntry(
        id: id,
        clienteId: clienteId,
        empieza: empieza,
        minutos: 60,
        estado: EstadoCita.reservada,
        totalCop: 35000,
        clienteNombre: 'Cita creada',
        servicios: const ['Baño'],
        servicioIds: const ['bano'],
      ),
    ];
    return id;
  }

  @override
  Future<String> crearPorCelular({
    required String nombre,
    required String telefono,
    required String mascotaNombre,
    required DateTime empieza,
    required List<String> servicios,
  }) =>
      crear(
        clienteId: 'cliente-$telefono',
        mascotaId: null,
        empieza: empieza,
        servicios: servicios,
      );

  @override
  Future<List<DateTime>> mesesDisponibles() async => [DateTime(2026, 11)];

  @override
  Future<MonthSummary> resumenDelMes(DateTime mes) async =>
      MonthSummary.fromData(mes: mes, citas: citas, clientesNuevos: 0);

  @override
  Future<AdminSummary> resumen() async {
    resumenes++;
    return AdminSummary.fromData(
      citas: citas,
      hoy: lunes,
      clientesNuevos: 0,
      proximas: const [],
    );
  }
}

AgendaEntry cita({
  required String id,
  required DateTime empieza,
  EstadoCita estado = EstadoCita.reservada,
  int total = 35000,
  String clienteNombre = 'Ana',
}) =>
    AgendaEntry(
      id: id,
      clienteId: 'cliente-ana',
      empieza: empieza,
      minutos: 60,
      estado: estado,
      totalCop: total,
      clienteNombre: clienteNombre,
      mascotaNombre: 'Toby',
      servicios: const ['Baño'],
      servicioIds: const ['bano'],
    );

class SessionFake implements AdminSession {
  @override
  Future<bool> esAdmin() async => true;

  @override
  Future<bool> entrar({
    required String correo,
    required String contrasena,
  }) async =>
      true;

  @override
  Future<void> salir() async {}
}

Widget app(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Widget panel(Mundo mundo) => app(AdminShellScreen(
      analyticsRepository: mundo,
      appointmentsRepository: mundo,
      customersRepository: SampleCustomerDirectoryRepository(),
      agendaRepository: mundo,
      availabilityRepository: const SampleAvailabilityRepository(),
      session: SessionFake(),
      today: lunes,
      now: lunes.add(const Duration(hours: 7)),
    ));

void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Elige Baño, el primer horario libre y guarda.
Future<void> llenarYGuardar(WidgetTester tester) async {
  await tester.tap(find.text('Baño'));
  await tester.pumpAndSettle();
  // La muestra marca horarios ocupados según el día: el primer chip puede
  // estar desactivado.
  final libre = find.byWidgetPredicate(
    (w) => w is ChoiceChip && w.onSelected != null,
  );
  await tester.ensureVisible(libre.first);
  await tester.tap(libre.first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Guardar cita'));
  await tester.tap(find.text('Guardar cita'));
  await tester.pumpAndSettle();
}

void main() {
  group('refresco entre pestañas', () {
    testWidgets('marcar cumplida en Agenda actualiza los ingresos del Resumen',
        (tester) async {
      pantallaAlta(tester);
      final mundo = Mundo([
        cita(
          id: 'ya-cumplida',
          empieza: lunes.add(const Duration(hours: 8)),
          estado: EstadoCita.cumplida,
        ),
        cita(
          id: 'por-marcar',
          empieza: lunes.add(const Duration(hours: 10)),
          total: 40000,
        ),
      ]);

      await tester.pumpWidget(panel(mundo));
      await tester.pumpAndSettle();
      expect(find.text('\$35.000'), findsOneWidget);

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cumplida'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();

      expect(find.text('\$75.000'), findsOneWidget);
      expect(mundo.resumenes, 2);
    });

    testWidgets('cancelar en Historial se ve al volver a Agenda',
        (tester) async {
      pantallaAlta(tester);
      final mundo = Mundo([
        cita(id: 'c1', empieza: lunes.add(const Duration(hours: 9))),
      ]);

      await tester.pumpWidget(panel(mundo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('RESERVADA'), findsOneWidget);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      expect(find.text('CANCELADA'), findsOneWidget);
      expect(find.text('RESERVADA'), findsNothing);
    });

    testWidgets('recargar el Historial conserva el filtro Futuras',
        (tester) async {
      pantallaAlta(tester);
      final mundo = Mundo([
        cita(
          id: 'pasada',
          empieza: lunes.subtract(const Duration(days: 1)),
          clienteNombre: 'Pasada',
        ),
      ]);

      await tester.pumpWidget(panel(mundo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Futuras'));
      await tester.pumpAndSettle();
      expect(find.text('Pasada'), findsNothing);

      // Una cita futura creada en otra pestaña.
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').first);
      await tester.pumpAndSettle();
      await llenarYGuardar(tester);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      final chip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Futuras'));
      expect(chip.selected, isTrue);
      expect(find.text('Cita creada'), findsOneWidget);
      expect(find.text('Pasada'), findsNothing);
    });
  });

  group('Nueva cita en Agenda', () {
    testWidgets('Historial ya no ofrece crear citas', (tester) async {
      final mundo = Mundo([]);

      await tester.pumpWidget(panel(mundo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva cita'), findsNothing);

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva cita'), findsOneWidget);
    });

    testWidgets('la cita creada desde la agenda cae en el día visible',
        (tester) async {
      pantallaAlta(tester);
      final mundo = Mundo([]);
      final jueves = lunes.add(const Duration(days: 3));

      await tester.pumpWidget(app(AgendaScreen(
        repository: mundo,
        appointmentsRepository: mundo,
        availabilityRepository: const SampleAvailabilityRepository(),
        customersRepository: SampleCustomerDirectoryRepository(),
        today: lunes,
        embedded: true,
      )));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Nueva cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').first);
      await tester.pumpAndSettle();
      await llenarYGuardar(tester);

      expect(mundo.empiezasCreadas, hasLength(1));
      final creada = mundo.empiezasCreadas.single;
      expect(
        [creada.year, creada.month, creada.day],
        [jueves.year, jueves.month, jueves.day],
      );
      // La agenda recargó el mismo día y ya muestra la cita.
      expect(find.text('Cita creada'), findsOneWidget);
    });
  });

  group('día inicial del formulario', () {
    Future<DateTime> crearCon(
      WidgetTester tester, {
      required DateTime diaInicial,
    }) async {
      pantallaAlta(tester);
      final mundo = Mundo([]);
      final clientes = SampleCustomerDirectoryRepository();

      await tester.pumpWidget(app(AdminAppointmentFormScreen(
        appointmentsRepository: mundo,
        availabilityRepository: const SampleAvailabilityRepository(),
        customersRepository: clientes,
        cliente: (await clientes.clientes(busqueda: 'Ana')).first,
        hoy: lunes,
        diaInicial: diaInicial,
      )));
      await tester.pumpAndSettle();
      await llenarYGuardar(tester);

      return mundo.empiezasCreadas.single;
    }

    testWidgets('un día futuro abre elegido', (tester) async {
      final miercoles = lunes.add(const Duration(days: 2));
      final creada = await crearCon(tester, diaInicial: miercoles);
      expect(creada.day, miercoles.day);
    });

    testWidgets('un día pasado abre en hoy', (tester) async {
      final viernesAnterior = lunes.subtract(const Duration(days: 3));
      final creada = await crearCon(tester, diaInicial: viernesAnterior);
      expect(creada.day, lunes.day);
      expect(creada.month, lunes.month);
    });

    testWidgets('al editar manda el día de la cita, no el inicial',
        (tester) async {
      pantallaAlta(tester);
      final mundo = Mundo([
        cita(id: 'c1', empieza: lunes.add(const Duration(days: 1, hours: 9))),
      ]);

      await tester.pumpWidget(app(AdminAppointmentFormScreen(
        appointmentsRepository: mundo,
        availabilityRepository: const SampleAvailabilityRepository(),
        customersRepository: SampleCustomerDirectoryRepository(),
        cita: mundo.citas.single,
        hoy: lunes,
        diaInicial: lunes.add(const Duration(days: 3)),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cita'));
      await tester.pumpAndSettle();

      expect(mundo.empiezasEditadas.single.day, lunes.day + 1);
    });
  });
}
