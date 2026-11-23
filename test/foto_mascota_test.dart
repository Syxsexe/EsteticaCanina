import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/admin_customer_detail_screen.dart';
import 'package:perro_look/features/admin/data/admin_appointment_repository.dart';
import 'package:perro_look/features/admin/data/customer_directory_repository.dart';
import 'package:perro_look/features/admin/data/foto_mascota_service.dart';
import 'package:perro_look/features/admin/models/pet_record.dart';

/// Unos bytes con cabecera WebP, distintos según [n].
Uint8List webpFalso(int n) => Uint8List.fromList(
      [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, n],
    );

/// Un selector y conversor sin plugins: devuelve lo que se le diga.
class FotoFalsa implements FotoMascotaService {
  FotoFalsa({this.eleccion, this.falla});

  /// Lo que "elige" el usuario; nulo es cerrar el selector.
  Uint8List? eleccion;

  /// Si no es nulo, `aWebp` lo lanza.
  Object? falla;

  int conversiones = 0;

  @override
  Future<Uint8List?> elegir() async => eleccion;

  @override
  Future<Uint8List> aWebp(Uint8List original) async {
    conversiones++;
    if (falla != null) throw falla!;
    return webpFalso(original.first);
  }
}

Future<SampleCustomerDirectoryRepository> abrirDetalleDeAna(
  WidgetTester tester,
  FotoFalsa foto, {
  SampleCustomerDirectoryRepository? repo,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final clientes = repo ?? SampleCustomerDirectoryRepository();
  final ana = (await clientes.clientes(busqueda: 'Ana')).single;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: AdminCustomerDetailScreen(
      cliente: ana,
      customersRepository: clientes,
      appointmentsRepository:
          SampleAdminAppointmentRepository(hoy: DateTime(2026, 11, 2)),
      fotoService: foto,
    ),
  ));
  await tester.pumpAndSettle();
  return clientes;
}

Future<void> tocarOpcion(WidgetTester tester, String opcion) async {
  await tester.tap(find.byTooltip('Foto de Toby'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion));
  await tester.pumpAndSettle();
}

void main() {
  group('foto en el detalle del cliente', () {
    testWidgets('sin foto se ve la huella; elegir una la guarda en WebP',
        (tester) async {
      final foto = FotoFalsa(eleccion: Uint8List.fromList([7, 7, 7]));
      final repo = await abrirDetalleDeAna(tester, foto);

      expect(find.byKey(const Key('sin-foto')), findsOneWidget);

      await tocarOpcion(tester, 'Elegir foto');

      expect(foto.conversiones, 1);
      expect(find.byKey(const Key('foto-mascota')), findsOneWidget);
      final guardada = repo.fotos.values.single;
      expect(esWebp(guardada), isTrue);
    });

    testWidgets('cerrar el selector sin elegir no cambia nada',
        (tester) async {
      final foto = FotoFalsa();
      final repo = await abrirDetalleDeAna(tester, foto);

      await tocarOpcion(tester, 'Elegir foto');

      expect(foto.conversiones, 0);
      expect(repo.fotos, isEmpty);
      expect(find.byKey(const Key('sin-foto')), findsOneWidget);
    });

    testWidgets('un archivo ilegible avisa y no guarda', (tester) async {
      final foto = FotoFalsa(
        eleccion: Uint8List.fromList([1]),
        falla: const ArchivoNoLegibleException(),
      );
      final repo = await abrirDetalleDeAna(tester, foto);

      await tocarOpcion(tester, 'Elegir foto');

      expect(find.text('No pudimos usar ese archivo como imagen.'),
          findsOneWidget);
      expect(repo.fotos, isEmpty);
    });

    testWidgets('un navegador sin WebP avisa y no guarda', (tester) async {
      final foto = FotoFalsa(
        eleccion: Uint8List.fromList([1]),
        falla: const WebpNoDisponibleException(),
      );
      final repo = await abrirDetalleDeAna(tester, foto);

      await tocarOpcion(tester, 'Elegir foto');

      expect(find.textContaining('Usa Chrome, Edge o Firefox'), findsOneWidget);
      expect(repo.fotos, isEmpty);
    });

    Future<SampleCustomerDirectoryRepository> conFotoDeToby() async {
      final repo = SampleCustomerDirectoryRepository();
      final toby = (await repo.mascotasDe('cliente-ana')).single;
      await repo.guardarFotoMascota(toby, webpFalso(3));
      return repo;
    }

    Future<void> abrirVisor(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Foto de Toby'));
      await tester.pumpAndSettle();
    }

    testWidgets('tocar una foto la abre en grande con el nombre',
        (tester) async {
      await abrirDetalleDeAna(tester, FotoFalsa(), repo: await conFotoDeToby());
      expect(find.byKey(const Key('foto-mascota')), findsOneWidget);

      await abrirVisor(tester);

      expect(find.byKey(const Key('visor-foto')), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Toby'), findsOneWidget);
    });

    testWidgets('el doble toque amplía y otro doble toque vuelve',
        (tester) async {
      await abrirDetalleDeAna(tester, FotoFalsa(), repo: await conFotoDeToby());
      await abrirVisor(tester);

      double escala() => tester
          .widget<InteractiveViewer>(find.byKey(const Key('visor-foto')))
          .transformationController!
          .value
          .getMaxScaleOnAxis();

      final centro = tester.getCenter(find.byKey(const Key('visor-foto')));
      Future<void> dobleToque() async {
        await tester.tapAt(centro);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(centro);
        await tester.pumpAndSettle();
      }

      expect(escala(), 1);
      await dobleToque();
      expect(escala(), greaterThan(1));
      await dobleToque();
      expect(escala(), 1);
    });

    testWidgets('"Cambiar foto" desde el visor guarda la nueva',
        (tester) async {
      final repo = await conFotoDeToby();
      final anterior = repo.fotos.keys.single;
      await abrirDetalleDeAna(
        tester,
        FotoFalsa(eleccion: Uint8List.fromList([9])),
        repo: repo,
      );
      await abrirVisor(tester);

      await tester.tap(find.byTooltip('Cambiar foto'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('visor-foto')), findsNothing);
      expect(repo.fotos.keys.single, isNot(anterior));
      expect(repo.fotos.values.single, webpFalso(9));
    });

    testWidgets('"Quitar foto" desde el visor vuelve a la huella',
        (tester) async {
      final repo = await conFotoDeToby();
      await abrirDetalleDeAna(tester, FotoFalsa(), repo: repo);
      await abrirVisor(tester);

      await tester.tap(find.byTooltip('Quitar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sin-foto')), findsOneWidget);
      expect(repo.fotos, isEmpty);
    });
  });

  group('fotos en el repositorio de muestra', () {
    test('cambiar la foto deja solo la nueva', () async {
      final repo = SampleCustomerDirectoryRepository();
      final toby = (await repo.mascotasDe('cliente-ana')).single;

      final conUna = await repo.guardarFotoMascota(toby, webpFalso(1));
      final conOtra = await repo.guardarFotoMascota(conUna, webpFalso(2));

      expect(repo.fotos.keys, [conOtra.fotoPath]);
      expect(await repo.fotoDe(conOtra.fotoPath!), webpFalso(2));
      expect((await repo.mascotasDe('cliente-ana')).single.fotoPath,
          conOtra.fotoPath);
    });

    test('quitar la foto la borra', () async {
      final repo = SampleCustomerDirectoryRepository();
      final toby = (await repo.mascotasDe('cliente-ana')).single;
      final conFoto = await repo.guardarFotoMascota(toby, webpFalso(1));

      final sinFoto = await repo.quitarFotoMascota(conFoto);

      expect(sinFoto.fotoPath, isNull);
      expect(repo.fotos, isEmpty);
    });

    test('editar la ficha conserva la foto', () async {
      final repo = SampleCustomerDirectoryRepository();
      final toby = (await repo.mascotasDe('cliente-ana')).single;
      final conFoto = await repo.guardarFotoMascota(toby, webpFalso(1));

      await repo.guardarMascota(PetRecord(
        id: conFoto.id,
        duenoId: conFoto.duenoId,
        nombre: 'Toby',
        pesoKg: 13,
      ));

      expect((await repo.mascotasDe('cliente-ana')).single.fotoPath,
          conFoto.fotoPath);
    });

    test('eliminar el cliente borra las fotos de sus mascotas', () async {
      final repo = SampleCustomerDirectoryRepository();
      final toby = (await repo.mascotasDe('cliente-ana')).single;
      await repo.guardarFotoMascota(toby, webpFalso(1));
      final canela = (await repo.mascotasDe('cliente-luis')).single;
      final deLuis = await repo.guardarFotoMascota(canela, webpFalso(2));

      await repo.eliminarCliente('cliente-ana');

      // Solo queda la de Luis.
      expect(repo.fotos.keys, [deLuis.fotoPath]);
    });
  });

  group('tamaño destino', () {
    test('una foto horizontal grande queda en 1280 de ancho', () {
      expect(tamanoDestino(4000, 3000), (1280, 960));
    });

    test('una foto vertical grande queda en 1280 de alto', () {
      expect(tamanoDestino(3000, 4000), (960, 1280));
    });

    test('una foto pequeña no se agranda', () {
      expect(tamanoDestino(800, 600), (800, 600));
    });

    test('justo en el límite se queda igual', () {
      expect(tamanoDestino(1280, 720), (1280, 720));
    });
  });

  group('cabecera WebP', () {
    Uint8List bytes(String texto) => Uint8List.fromList(texto.codeUnits);

    test('reconoce un WebP', () {
      expect(esWebp(bytes('RIFF\x00\x00\x00\x00WEBPVP8 ')), isTrue);
    });

    test('rechaza un PNG, que es lo que devuelve Safari', () {
      expect(
        esWebp(Uint8List.fromList(
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0],
        )),
        isFalse,
      );
    });

    test('rechaza un archivo demasiado corto', () {
      expect(esWebp(bytes('RIFF')), isFalse);
    });
  });
}
