import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/admin_analytics_screen.dart';
import 'package:perro_look/features/admin/admin_appointment_form_screen.dart';
import 'package:perro_look/features/admin/admin_customers_screen.dart';
import 'package:perro_look/features/admin/admin_history_screen.dart';
import 'package:perro_look/features/admin/admin_sign_in_screen.dart';
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
import 'package:perro_look/features/booking/data/booking_repository.dart';

final lunes = DateTime(2026, 11, 2);

AdminSummary resumenFijo() => const AdminSummary(
      citasHoy: 2,
      citasSemana: 5,
      ingresosMesCop: 90000,
      noAsistenciaPct: 25,
      clientesNuevosMes: 3,
      topServicios: [ServiceCount(name: 'Baño', count: 4)],
      proximas: [],
    );

class AnalyticsFake implements AnalyticsRepository {
  AnalyticsFake({this.fallaPrimera = false});

  final bool fallaPrimera;
  int llamadas = 0;

  @override
  Future<AdminSummary> resumen() async {
    llamadas++;
    if (fallaPrimera && llamadas == 1) throw Exception('sin red');
    return resumenFijo();
  }

  @override
  Future<List<DateTime>> mesesDisponibles() async => [DateTime(2026, 11)];

  @override
  Future<MonthSummary> resumenDelMes(DateTime mes) async =>
      MonthSummary.fromData(mes: mes, citas: const [], clientesNuevos: 0);
}

AgendaEntry cita({
  required String id,
  required DateTime empieza,
  EstadoCita estado = EstadoCita.reservada,
  String? clienteId,
  String? clienteNombre,
}) =>
    AgendaEntry(
      id: id,
      empieza: empieza,
      minutos: 60,
      estado: estado,
      totalCop: 35000,
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      mascotaNombre: 'Toby',
      servicios: const ['Baño'],
      servicioIds: const ['bano'],
    );

class CitasFake implements AdminAppointmentRepository {
  CitasFake(this.citas);

  List<AgendaEntry> citas;
  final List<String> canceladas = [];
  final List<String> creadas = [];
  final List<String> editadas = [];

  @override
  Future<List<AgendaEntry>> historial() async => List.of(citas);

  @override
  Future<List<AgendaEntry>> historialDe(String clienteId) async => [
        for (final c in citas)
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
    editadas.add(citaId);
    citas = [
      for (final c in citas)
        if (c.id == citaId) c.copyWith(estado: estado) else c,
    ];
  }

  @override
  Future<void> cancelar(String citaId) async {
    canceladas.add(citaId);
    citas = [
      for (final c in citas)
        if (c.id == citaId) c.copyWith(estado: EstadoCita.cancelada) else c,
    ];
  }

  @override
  Future<String> crear({
    required String clienteId,
    required String? mascotaId,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    creadas.add(clienteId);
    return 'nueva';
  }

  @override
  Future<String> crearPorCelular({
    required String nombre,
    required String telefono,
    required String mascotaNombre,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    creadas.add(telefono);
    return 'nueva';
  }
}

/// Un historial que falla la primera vez y responde después.
class HistorialIntermitente extends CitasFake {
  HistorialIntermitente(super.citas);

  int llamadas = 0;

  @override
  Future<List<AgendaEntry>> historial() async {
    llamadas++;
    if (llamadas == 1) throw Exception('sin red');
    return super.historial();
  }
}

/// Una base que rechaza la cita al crearla, con el error que se le diga.
class CitasQueRechazan extends CitasFake {
  CitasQueRechazan(this.error) : super([]);

  final Object error;

  @override
  Future<String> crear({
    required String clienteId,
    required String? mascotaId,
    required DateTime empieza,
    required List<String> servicios,
  }) async =>
      throw error;
}

/// Como cuando el RLS deja pasar el `update` pero no toca ninguna fila: el
/// repositorio real lanza [CitaNoActualizadaException].
class CitasQueNoCancelan extends CitasFake {
  CitasQueNoCancelan(super.citas);

  @override
  Future<void> cancelar(String citaId) async =>
      throw const CitaNoActualizadaException();
}

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

void main() {
  test('sin credenciales los repositorios del panel son los de muestra', () {
    expect(defaultAnalyticsRepository(), isA<SampleAnalyticsRepository>());
    expect(
      defaultAdminAppointmentRepository(),
      isA<SampleAdminAppointmentRepository>(),
    );
    expect(
      defaultCustomerDirectoryRepository(),
      isA<SampleCustomerDirectoryRepository>(),
    );
  });

  testWidgets('el panel conserva el filtro al cambiar de pestaña',
      (tester) async {
    final citas = CitasFake([
      cita(
        id: 'a',
        empieza: lunes.subtract(const Duration(days: 1)),
        estado: EstadoCita.cumplida,
      ),
      cita(id: 'b', empieza: lunes.add(const Duration(hours: 9))),
    ]);

    await tester.pumpWidget(app(AdminShellScreen(
      analyticsRepository: AnalyticsFake(),
      appointmentsRepository: citas,
      customersRepository: SampleCustomerDirectoryRepository(),
      agendaRepository: SampleAgendaRepository(),
      availabilityRepository: const SampleAvailabilityRepository(),
      session: SessionFake(),
      today: lunes,
      now: lunes.add(const Duration(hours: 10)),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasadas'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    final chip =
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pasadas'));
    expect(chip.selected, isTrue);
    expect(find.text('CANCELADA'), findsNothing);
  });

  testWidgets('el resumen muestra error y se recupera al reintentar',
      (tester) async {
    final repositorio = AnalyticsFake(fallaPrimera: true);

    // Dentro de un Scaffold, como en el panel: el desplegable de meses
    // necesita un Material encima.
    await tester.pumpWidget(app(Scaffold(
      body: AdminAnalyticsScreen(repository: repositorio, hoy: lunes),
    )));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos traer las estadísticas.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('\$90.000'), findsOneWidget);
    expect(find.text('25 %'), findsOneWidget);
    expect(repositorio.llamadas, 2);
  });

  testWidgets('el historial filtra por fecha y cancelar conserva la cita',
      (tester) async {
    final citas = CitasFake([
      cita(
        id: 'pasada',
        empieza: lunes.subtract(const Duration(days: 2)),
        estado: EstadoCita.cumplida,
        clienteNombre: 'Ana',
      ),
      cita(
        id: 'hoy',
        empieza: lunes.add(const Duration(hours: 11)),
        clienteNombre: 'Luis',
      ),
      cita(
        id: 'futura',
        empieza: lunes.add(const Duration(days: 2)),
        clienteNombre: 'Camila',
      ),
    ]);

    await tester.pumpWidget(app(AdminHistoryScreen(
      appointmentsRepository: citas,
      customersRepository: SampleCustomerDirectoryRepository(),
      availabilityRepository: const SampleAvailabilityRepository(),
      today: lunes,
      now: lunes.add(const Duration(hours: 10)),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('Camila'), findsOneWidget);

    await tester.tap(find.text('Pasadas'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsNothing);
    expect(find.text('Camila'), findsNothing);

    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();

    expect(citas.canceladas.length, 1);
    expect(find.text('CANCELADA'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('si la base no cancela la fila, la cita conserva su estado',
      (tester) async {
    final citas = CitasQueNoCancelan([
      cita(
        id: 'hoy',
        empieza: lunes.add(const Duration(hours: 11)),
        clienteNombre: 'Luis',
      ),
    ]);

    await tester.pumpWidget(app(AdminHistoryScreen(
      appointmentsRepository: citas,
      customersRepository: SampleCustomerDirectoryRepository(),
      availabilityRepository: const SampleAvailabilityRepository(),
      today: lunes,
      now: lunes.add(const Duration(hours: 10)),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cancelar. Intenta de nuevo.'), findsOneWidget);
    expect(find.text('RESERVADA'), findsOneWidget);
    expect(find.text('CANCELADA'), findsNothing);
  });

  testWidgets('el directorio va en orden alfabético y guarda observaciones',
      (tester) async {
    // El detalle ya trae mascotas antes de las observaciones: en 800x600
    // quedan fuera de la lista perezosa.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final clientes = SampleCustomerDirectoryRepository();
    final citas = CitasFake([
      cita(
        id: 'a',
        empieza: lunes.subtract(const Duration(days: 1)),
        clienteId: 'cliente-ana',
        clienteNombre: 'Ana',
      ),
    ]);

    await tester.pumpWidget(app(Scaffold(
      body: AdminCustomersScreen(
        customersRepository: clientes,
        appointmentsRepository: citas,
        availabilityRepository: const SampleAvailabilityRepository(),
        today: lunes,
      ),
    )));
    await tester.pumpAndSettle();

    final yAna = tester.getTopLeft(find.text('Ana')).dy;
    final yCamila = tester.getTopLeft(find.text('Camila')).dy;
    final yLuis = tester.getTopLeft(find.text('Luis')).dy;
    expect(yAna, lessThan(yCamila));
    expect(yCamila, lessThan(yLuis));

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();

    expect(find.text('Prefiere que la llamen antes de las 10.'), findsOneWidget);

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Le gusta el secado suave.');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Le gusta el secado suave.'), findsOneWidget);
  });

  testWidgets('entrar con una cuenta administradora abre el panel',
      (tester) async {
    await tester.pumpWidget(app(AdminSignInScreen(session: SessionFake())));

    await tester.enterText(
      find.byType(TextField).at(0),
      'juanfe20132@gmail.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'clave');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Resumen'), findsWidgets);
  });

  testWidgets('crear una cita usa el cliente elegido', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final citas = CitasFake([]);

    // Se crea desde la pestaña Agenda, que es donde vive el botón.
    await tester.pumpWidget(app(AgendaScreen(
      repository: SampleAgendaRepository(),
      appointmentsRepository: citas,
      availabilityRepository: const SampleAvailabilityRepository(),
      customersRepository: SampleCustomerDirectoryRepository(),
      today: lunes,
      embedded: true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva cita'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Baño'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(ChoiceChip).first);
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guardar cita'));
    await tester.tap(find.text('Guardar cita'));
    await tester.pumpAndSettle();

    expect(citas.creadas, ['cliente-ana']);
  });

  testWidgets('el historial muestra el error, se recupera y se desliza',
      (tester) async {
    final citas = HistorialIntermitente([
      cita(
        id: 'a',
        empieza: lunes.add(const Duration(hours: 9)),
        clienteNombre: 'Ana',
      ),
    ]);

    await tester.pumpWidget(app(AdminHistoryScreen(
      appointmentsRepository: citas,
      customersRepository: SampleCustomerDirectoryRepository(),
      availabilityRepository: const SampleAvailabilityRepository(),
      today: lunes,
      now: lunes,
    )));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos traer el historial.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);

    // Deslizar hacia abajo vuelve a consultar.
    await tester.fling(find.text('Ana'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(citas.llamadas, 3);
  });

  group('errores al guardar una cita', () {
    Future<void> intentarCrear(WidgetTester tester, Object error) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final clientes = SampleCustomerDirectoryRepository();
      await tester.pumpWidget(app(AdminAppointmentFormScreen(
        appointmentsRepository: CitasQueRechazan(error),
        availabilityRepository: const SampleAvailabilityRepository(),
        customersRepository: clientes,
        cliente: (await clientes.clientes(busqueda: 'Ana')).first,
        hoy: lunes,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Baño'));
      await tester.pumpAndSettle();
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

    /// Lo elegido sigue elegido: el formulario no se vació.
    void conservaElFormulario(WidgetTester tester) {
      expect(find.byType(AdminAppointmentFormScreen), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      final elegido = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((c) => c.selected);
      expect(elegido, hasLength(1));
    }

    testWidgets('servicios inválidos muestran el motivo de la base',
        (tester) async {
      await intentarCrear(
        tester,
        const CitaRechazadaException(
          'La cita necesita exactamente un servicio principal',
        ),
      );

      expect(
        find.text('La cita necesita exactamente un servicio principal'),
        findsOneWidget,
      );
      conservaElFormulario(tester);
    });

    testWidgets('un horario ocupado lo dice y deja elegir otro',
        (tester) async {
      await intentarCrear(tester, const SlotTakenException());

      expect(find.text('Ese horario lo acaban de tomar. Elige otro.'),
          findsOneWidget);
      conservaElFormulario(tester);
    });
  });

  testWidgets('el historial se ordena por fecha ascendente', (tester) async {
    final citas = CitasFake([
      cita(
        id: 'nueva',
        empieza: lunes.add(const Duration(days: 2)),
        clienteNombre: 'Nueva',
      ),
      cita(
        id: 'vieja',
        empieza: lunes.subtract(const Duration(days: 2)),
        clienteNombre: 'Vieja',
      ),
    ]);

    await tester.pumpWidget(app(AdminHistoryScreen(
      appointmentsRepository: citas,
      customersRepository: SampleCustomerDirectoryRepository(),
      availabilityRepository: const SampleAvailabilityRepository(),
      today: lunes,
      now: lunes,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fecha, más antigua primero'));
    await tester.pumpAndSettle();

    final yVieja = tester.getTopLeft(find.text('Vieja')).dy;
    final yNueva = tester.getTopLeft(find.text('Nueva')).dy;
    expect(yVieja, lessThan(yNueva));
  });

  testWidgets('editar una cita llama a la función y cierra el formulario',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final citas = CitasFake([
      cita(
        id: 'c1',
        empieza: lunes.add(const Duration(hours: 9)),
        clienteId: 'cliente-ana',
        clienteNombre: 'Ana',
      ),
    ]);

    await tester.pumpWidget(app(AdminAppointmentFormScreen(
      appointmentsRepository: citas,
      availabilityRepository: const SampleAvailabilityRepository(),
      customersRepository: SampleCustomerDirectoryRepository(),
      cita: citas.citas.first,
      hoy: lunes,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar cita'));
    await tester.pumpAndSettle();

    expect(citas.editadas, ['c1']);
  });
}
