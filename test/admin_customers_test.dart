import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/admin_appointment_form_screen.dart';
import 'package:perro_look/features/admin/admin_customer_detail_screen.dart';
import 'package:perro_look/features/admin/admin_customers_screen.dart';
import 'package:perro_look/features/admin/data/admin_appointment_repository.dart';
import 'package:perro_look/features/admin/data/agenda_repository.dart';
import 'package:perro_look/features/admin/data/customer_directory_repository.dart';
import 'package:perro_look/features/admin/models/customer_entry.dart';
import 'package:perro_look/features/admin/models/pet_record.dart';
import 'package:perro_look/features/booking/data/availability_repository.dart';

/// Lunes fijo: la disponibilidad de muestra deriva los huecos de la fecha.
final lunes = DateTime(2026, 11, 2);

Widget app(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Como cuando la base rechaza la eliminación o se cae la red.
class DirectorioQueNoElimina extends SampleCustomerDirectoryRepository {
  @override
  Future<void> eliminarCliente(String clienteId) async =>
      throw Exception('sin red');
}

void pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<CustomerEntry> clienteLlamado(
  CustomerDirectoryRepository repositorio,
  String nombre,
) async =>
    (await repositorio.clientes(busqueda: nombre)).single;

Future<void> abrirDetalle(
  WidgetTester tester, {
  required CustomerDirectoryRepository clientes,
  required String nombre,
  AdminAppointmentRepository? citas,
}) async {
  pantallaAlta(tester);
  await tester.pumpWidget(app(AdminCustomerDetailScreen(
    cliente: await clienteLlamado(clientes, nombre),
    customersRepository: clientes,
    appointmentsRepository:
        citas ?? SampleAdminAppointmentRepository(hoy: lunes),
    availabilityRepository: const SampleAvailabilityRepository(),
    today: lunes,
  )));
  await tester.pumpAndSettle();
}

void main() {
  group('ficha de mascota', () {
    test('los datos que faltan se dicen, no quedan en blanco', () {
      const mascota = PetRecord(duenoId: 'c', nombre: 'Lola');
      expect(mascota.razaVisible, 'Raza: No registrado');
      expect(mascota.edadVisible, 'Edad: No registrado');
      expect(mascota.pesoVisible, 'Peso: No registrado');
    });

    test('la ficha completa se lee en español', () {
      const mascota = PetRecord(
        duenoId: 'c',
        nombre: 'Toby',
        raza: 'Beagle',
        edadAnios: 4,
        pesoKg: 12.5,
      );
      expect(mascota.razaVisible, 'Beagle');
      expect(mascota.edadVisible, '4 años');
      expect(mascota.pesoVisible, '12,5 kg');
    });

    test('la validación repite los límites de la base', () {
      expect(validarMascota(nombre: ' ', edadAnios: null, pesoKg: null),
          isNotNull);
      expect(validarMascota(nombre: 'Toby', edadAnios: 40, pesoKg: null),
          isNotNull);
      expect(validarMascota(nombre: 'Toby', edadAnios: null, pesoKg: 0),
          isNotNull);
      expect(validarMascota(nombre: 'Toby', edadAnios: 30, pesoKg: 0.5),
          isNull);
    });
  });

  group('repositorio de muestra', () {
    test('registrar, editar y anotar una mascota persiste', () async {
      final repositorio = SampleCustomerDirectoryRepository();

      final canela = await repositorio.guardarMascota(
        const PetRecord(duenoId: 'cliente-camila', nombre: 'Canela'),
      );
      expect(canela.id, isNotNull);

      await repositorio.guardarMascota(canela.copyWith(pesoKg: 8));
      await repositorio.guardarNotaMascota(
        mascotaId: canela.id!,
        texto: 'Muerde si le tocan las patas.',
      );

      final mascotas = await repositorio.mascotasDe('cliente-camila');
      expect(mascotas.single.pesoKg, 8);
      expect(mascotas.single.nota!.texto, 'Muerde si le tocan las patas.');

      // La mascota nueva ya se puede elegir al crear una cita.
      final camila = await clienteLlamado(repositorio, 'Camila');
      expect(camila.mascotas.map((m) => m.nombre), ['Canela']);
    });

    test('editar la ficha conserva la nota interna', () async {
      final repositorio = SampleCustomerDirectoryRepository();
      final toby = (await repositorio.mascotasDe('cliente-ana')).single;

      await repositorio.guardarMascota(
        PetRecord(id: toby.id, duenoId: toby.duenoId, nombre: 'Toby', pesoKg: 13),
      );

      final editado = (await repositorio.mascotasDe('cliente-ana')).single;
      expect(editado.pesoKg, 13);
      expect(editado.nota?.texto, toby.nota?.texto);
    });

    test('el contacto corregido aparece en el directorio', () async {
      final repositorio = SampleCustomerDirectoryRepository();

      await repositorio.actualizarContacto(
        clienteId: 'cliente-ana',
        nombre: 'Ana María',
        telefono: '+573109998877',
      );

      final ana = await clienteLlamado(repositorio, 'Ana María');
      expect(ana.telefono, '+573109998877');
    });

    test('las citas de un cliente son solo las suyas', () async {
      final citas = SampleAdminAppointmentRepository(hoy: lunes);

      final deAna = await citas.historialDe('cliente-ana');
      expect(deAna, isNotEmpty);
      expect(deAna.every((c) => c.clienteId == 'cliente-ana'), isTrue);
      expect(await citas.historialDe('cliente-camila'), isEmpty);
    });
  });

  group('detalle del cliente', () {
    testWidgets('muestra la ficha de cada mascota con su nota interna',
        (tester) async {
      await abrirDetalle(
        tester,
        clientes: SampleCustomerDirectoryRepository(),
        nombre: 'Ana',
      );

      expect(find.text('Toby'), findsOneWidget);
      expect(find.text('Beagle · 4 años · 12 kg'), findsOneWidget);
      expect(
        find.text('Se incomoda con el secador cerca de las orejas.'),
        findsOneWidget,
      );
      // No hay forma de borrar una mascota.
      expect(find.byTooltip('Borrar mascota'), findsNothing);
      expect(find.text('1 cita registrada'), findsOneWidget);
    });

    testWidgets('un cliente sin mascotas lo dice y ofrece registrar',
        (tester) async {
      await abrirDetalle(
        tester,
        clientes: SampleCustomerDirectoryRepository(),
        nombre: 'Camila',
      );

      expect(
        find.text('Sin mascotas registradas. Registra la primera.'),
        findsOneWidget,
      );
      expect(find.text('Registrar'), findsOneWidget);
      expect(find.text('Este cliente todavía no tiene citas.'), findsOneWidget);
    });

    testWidgets('un teléfono inválido no se guarda; uno válido sí',
        (tester) async {
      final clientes = SampleCustomerDirectoryRepository();
      await abrirDetalle(tester, clientes: clientes, nombre: 'Ana');

      await tester.tap(find.byTooltip('Editar contacto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('contacto-telefono')), '12');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe un celular colombiano.'), findsOneWidget);
      expect((await clienteLlamado(clientes, 'Ana')).telefono, '+573001112233');

      await tester.enterText(
        find.byKey(const Key('contacto-telefono')),
        '310 999 8877',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('310 999 8877'), findsOneWidget);
      expect((await clienteLlamado(clientes, 'Ana')).telefono, '+573109998877');
    });

    testWidgets('el nombre del contacto es obligatorio', (tester) async {
      final clientes = SampleCustomerDirectoryRepository();
      await abrirDetalle(tester, clientes: clientes, nombre: 'Ana');

      await tester.tap(find.byTooltip('Editar contacto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('contacto-nombre')), '  ');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el nombre del tutor.'), findsOneWidget);
      expect((await clienteLlamado(clientes, 'Ana')).nombre, 'Ana');
    });

    testWidgets('registrar una mascota valida los rangos y la muestra',
        (tester) async {
      final clientes = SampleCustomerDirectoryRepository();
      await abrirDetalle(tester, clientes: clientes, nombre: 'Camila');

      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mascota-nombre')), 'Lola');
      await tester.enterText(find.byKey(const Key('mascota-edad')), '40');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('La edad va de 0 a 30 años.'), findsOneWidget);
      expect(await clientes.mascotasDe('cliente-camila'), isEmpty);

      await tester.enterText(find.byKey(const Key('mascota-edad')), '3');
      await tester.enterText(find.byKey(const Key('mascota-peso')), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('El peso tiene que ser mayor que 0.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('mascota-peso')), '6,5');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Lola'), findsOneWidget);
      expect(find.text('Raza: No registrado · 3 años · 6,5 kg'), findsOneWidget);
    });

    testWidgets('la nota interna guardada aparece en la ficha',
        (tester) async {
      final clientes = SampleCustomerDirectoryRepository();
      await abrirDetalle(tester, clientes: clientes, nombre: 'Luis');

      await tester.tap(find.byTooltip('Nota interna'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nota-mascota')),
        'Secar con calma.',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Secar con calma.'), findsOneWidget);
      expect(find.textContaining('Por la estética'), findsOneWidget);
    });

    testWidgets('una cita nueva desde el detalle queda a nombre del cliente',
        (tester) async {
      final citas = SampleAdminAppointmentRepository(hoy: lunes);
      await abrirDetalle(
        tester,
        clientes: SampleCustomerDirectoryRepository(),
        nombre: 'Camila',
        citas: citas,
      );

      await tester.tap(find.text('Nueva cita'));
      await tester.pumpAndSettle();
      // El cliente ya viene elegido: no hay que buscarlo.
      expect(find.text('Cambiar cliente'), findsOneWidget);

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

      expect(find.text('1 cita registrada'), findsOneWidget);
      expect(await citas.historialDe('cliente-camila'), hasLength(1));
    });
  });

  group('cliente nuevo por celular', () {
    test('un celular ya registrado reutiliza al cliente y a su mascota',
        () async {
      final clientes = SampleCustomerDirectoryRepository();
      final citas =
          SampleAdminAppointmentRepository(hoy: lunes, directorio: clientes);

      await citas.crearPorCelular(
        nombre: 'Otra persona',
        telefono: '+573001112233',
        mascotaNombre: ' toby ',
        empieza: lunes.add(const Duration(days: 1, hours: 9)),
        servicios: const ['bano'],
      );

      final todos = await clientes.clientes();
      expect(todos, hasLength(3));
      // No se renombró a Ana ni se le registró otra mascota.
      final ana = await clienteLlamado(clientes, 'Ana');
      expect(ana.mascotas.map((m) => m.nombre), ['Toby']);
      expect(await citas.historialDe('cliente-ana'), hasLength(2));
    });

    test('un celular nuevo crea al cliente y a su mascota', () async {
      final clientes = SampleCustomerDirectoryRepository();
      final citas =
          SampleAdminAppointmentRepository(hoy: lunes, directorio: clientes);

      await citas.crearPorCelular(
        nombre: 'Marta',
        telefono: '+573152223344',
        mascotaNombre: 'Lola',
        empieza: lunes.add(const Duration(days: 1, hours: 9)),
        servicios: const ['bano'],
      );

      final marta = await clienteLlamado(clientes, 'Marta');
      expect(marta.telefono, '+573152223344');
      expect(marta.mascotas.map((m) => m.nombre), ['Lola']);
      expect(await citas.historialDe(marta.id), hasLength(1));
    });

    testWidgets('el formulario pide los tres datos y agenda al cliente nuevo',
        (tester) async {
      pantallaAlta(tester);
      final clientes = SampleCustomerDirectoryRepository();
      final citas =
          SampleAdminAppointmentRepository(hoy: lunes, directorio: clientes);

      await tester.pumpWidget(app(AdminAppointmentFormScreen(
        appointmentsRepository: citas,
        availabilityRepository: const SampleAvailabilityRepository(),
        customersRepository: clientes,
        hoy: lunes,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cliente nuevo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el nombre del dueño.'), findsOneWidget);
      expect(find.text('Escribe un celular colombiano.'), findsOneWidget);
      expect(find.text('Escribe el nombre de la mascota.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('nuevo-nombre')), 'Marta');
      await tester.enterText(
        find.byKey(const Key('nuevo-telefono')),
        '315 222 3344',
      );
      await tester.enterText(find.byKey(const Key('nuevo-mascota')), 'Lola');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Marta'), findsOneWidget);
      expect(find.text('315 222 3344'), findsOneWidget);
      expect(find.text('Lola'), findsOneWidget);

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

      final marta = await clienteLlamado(clientes, 'Marta');
      expect(marta.mascotas.map((m) => m.nombre), ['Lola']);
      expect(await citas.historialDe(marta.id), hasLength(1));
    });
  });

  group('llamar al cliente', () {
    testWidgets('con celular hay botón; sin marcador muestra el número',
        (tester) async {
      await abrirDetalle(
        tester,
        clientes: SampleCustomerDirectoryRepository(),
        nombre: 'Ana',
      );

      // En las pruebas no hay plugin de url_launcher: es el caso "sin
      // marcador", como un navegador de escritorio.
      await tester.tap(find.byTooltip('Llamar'));
      // El canal de la plataforma responde fuera del reloj falso de la
      // prueba: hay que dejar pasar tiempo real.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Llama al 300 111 2233'), findsOneWidget);
    });

    testWidgets('sin celular no hay botón', (tester) async {
      await abrirDetalle(
        tester,
        clientes: SampleCustomerDirectoryRepository(clientes: const [
          CustomerEntry(id: 'c', nombre: 'Sin Celular', telefono: null, citas: 0),
        ]),
        nombre: 'Sin Celular',
      );

      expect(find.byTooltip('Llamar'), findsNothing);
    });
  });

  group('eliminar cliente', () {
    test('una cita de un cliente eliminado sale como "Cliente eliminado"', () {
      final cita = agendaEntryDesdeFila({
        'id': 'c1',
        'cliente_id': 'cliente-luis',
        'mascota_id': null,
        'empieza': '2026-10-05T14:00:00+00:00',
        'minutos': 60,
        'estado': 'cumplida',
        'total_cop': 35000,
        'notas_estilista': null,
        'perfiles': {
          'nombre': null,
          'telefono': null,
          'eliminado_en': '2026-11-23T10:00:00+00:00',
        },
        'mascotas': null,
        'cita_servicios': const [],
      });

      expect(cita.clienteNombre, 'Cliente eliminado');
      expect(cita.clienteTelefono, isNull);
      // La cifra se conserva.
      expect(cita.totalCop, 35000);
    });

    test('un cliente activo conserva su nombre', () {
      final cita = agendaEntryDesdeFila({
        'id': 'c1',
        'cliente_id': 'cliente-ana',
        'mascota_id': null,
        'empieza': '2026-10-05T14:00:00+00:00',
        'minutos': 60,
        'estado': 'cumplida',
        'total_cop': 35000,
        'notas_estilista': null,
        'perfiles': {
          'nombre': 'Ana',
          'telefono': '+573001112233',
          'eliminado_en': null,
        },
        'mascotas': null,
        'cita_servicios': const [],
      });

      expect(cita.clienteNombre, 'Ana');
      expect(cita.clienteTelefono, '+573001112233');
    });

    test('la muestra lo quita de la lista, la búsqueda, mascotas y notas',
        () async {
      final clientes = SampleCustomerDirectoryRepository();

      await clientes.eliminarCliente('cliente-ana');

      expect((await clientes.clientes()).map((c) => c.nombre),
          isNot(contains('Ana')));
      expect(await clientes.clientes(busqueda: '3001112233'), isEmpty);
      expect(await clientes.mascotasDe('cliente-ana'), isEmpty);
      expect(await clientes.observaciones('cliente-ana'), isEmpty);
    });

    Future<void> abrirLista(
      WidgetTester tester,
      CustomerDirectoryRepository clientes,
    ) async {
      pantallaAlta(tester);
      await tester.pumpWidget(app(Scaffold(
        body: AdminCustomersScreen(
          customersRepository: clientes,
          appointmentsRepository: SampleAdminAppointmentRepository(hoy: lunes),
          availabilityRepository: const SampleAvailabilityRepository(),
          today: lunes,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luis'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar cliente'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirmar lo quita de la lista', (tester) async {
      await abrirLista(tester, SampleCustomerDirectoryRepository());

      expect(find.textContaining('No se puede deshacer'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminCustomerDetailScreen), findsNothing);
      expect(find.text('Luis'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('"Volver" no cambia nada', (tester) async {
      final clientes = SampleCustomerDirectoryRepository();
      await abrirLista(tester, clientes);

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminCustomerDetailScreen), findsOneWidget);
      expect((await clientes.clientes()).map((c) => c.nombre), contains('Luis'));
    });

    testWidgets('si falla, el detalle sigue abierto con el error',
        (tester) async {
      final clientes = DirectorioQueNoElimina();
      await abrirLista(tester, clientes);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo eliminar el cliente.'), findsOneWidget);
      expect(find.byType(AdminCustomerDetailScreen), findsOneWidget);
      expect((await clientes.clientes()).map((c) => c.nombre), contains('Luis'));
    });
  });

  testWidgets('volver del detalle muestra el contacto corregido en la lista',
      (tester) async {
    pantallaAlta(tester);
    final clientes = SampleCustomerDirectoryRepository();

    await tester.pumpWidget(app(Scaffold(
      body: AdminCustomersScreen(
        customersRepository: clientes,
        appointmentsRepository: SampleAdminAppointmentRepository(hoy: lunes),
        availabilityRepository: const SampleAvailabilityRepository(),
        today: lunes,
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Luis'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar contacto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contacto-nombre')), 'Luis Ángel');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Luis Ángel'), findsOneWidget);
  });
}
