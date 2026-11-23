import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/admin_analytics_screen.dart';
import 'package:perro_look/features/admin/data/analytics_repository.dart';
import 'package:perro_look/features/assistant/assistant_screen.dart';
import 'package:perro_look/features/assistant/data/asistente_repository.dart';
import 'package:perro_look/features/booking/service_selection_screen.dart';
import 'package:perro_look/features/home/home_screen.dart';

/// Un asistente que responde lo que se le diga y anota lo que recibe.
class AsistenteFalso implements AsistenteRepository {
  AsistenteFalso({
    this.fallaEnviar = false,
    this.fallasEnviar = 0,
    this.fallasResumen = 0,
  });

  /// Falla siempre.
  final bool fallaEnviar;

  /// Falla solo las primeras veces.
  int fallasEnviar;
  int fallasResumen;
  final List<List<dynamic>> historialesRecibidos = [];

  @override
  Future<RespuestaAsistente> enviar(List<dynamic> historial, String texto) async {
    historialesRecibidos.add(historial);
    if (fallaEnviar) throw const AsistenteNoDisponible();
    if (fallasEnviar > 0) {
      fallasEnviar--;
      throw const AsistenteNoDisponible();
    }
    return RespuestaAsistente(
      historial: [...historial, 'opaco-$texto'],
      texto: 'El baño cuesta \$35.000.',
    );
  }

  @override
  Future<String> resumen() async {
    if (fallasResumen > 0) {
      fallasResumen--;
      throw const AsistenteNoDisponible();
    }
    return 'Hoy vienen Ana a las 09:00 y Luis a las 14:30.';
  }
}

Widget app(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Future<void> escribirYEnviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('mensaje-asistente')), texto);
  await tester.pump();
  await tester.tap(find.byTooltip('Enviar'));
  await tester.pumpAndSettle();
}

void main() {
  test('la muestra devuelve historial y texto', () async {
    final respuesta =
        await const SampleAsistenteRepository().enviar(const [], 'hola');
    expect(respuesta.historial, isNotEmpty);
    expect(respuesta.texto, isNotEmpty);
  });

  group('chat de reservas', () {
    testWidgets('enviar muestra la respuesta y reenvía el historial tal cual',
        (tester) async {
      final asistente = AsistenteFalso();
      await tester.pumpWidget(app(AssistantScreen(repository: asistente)));

      await escribirYEnviar(tester, '¿cuánto cuesta un baño?');
      expect(find.text('¿cuánto cuesta un baño?'), findsOneWidget);
      expect(find.text('El baño cuesta \$35.000.'), findsOneWidget);

      await escribirYEnviar(tester, 'gracias');
      // El segundo mensaje lleva exactamente lo que devolvió el primero.
      expect(asistente.historialesRecibidos.last,
          ['opaco-¿cuánto cuesta un baño?']);
    });

    testWidgets('más de 1000 caracteres no se envían', (tester) async {
      final asistente = AsistenteFalso();
      await tester.pumpWidget(app(AssistantScreen(repository: asistente)));

      await tester.enterText(
        find.byKey(const Key('mensaje-asistente')),
        'a' * 1001,
      );
      await tester.pump();

      expect(find.text('Máximo 1000 caracteres'), findsOneWidget);
      final enviar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(enviar.onPressed, isNull);
      expect(asistente.historialesRecibidos, isEmpty);
    });

    testWidgets('reintentar reenvía el mismo mensaje sin salir',
        (tester) async {
      final asistente = AsistenteFalso(fallasEnviar: 1);
      await tester.pumpWidget(app(AssistantScreen(repository: asistente)));

      await escribirYEnviar(tester, '¿cuánto cuesta un baño?');
      expect(find.text('El asistente no está disponible ahora.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('El baño cuesta \$35.000.'), findsOneWidget);
      expect(find.text('El asistente no está disponible ahora.'), findsNothing);
      // La burbuja del cliente no se duplica.
      expect(find.text('¿cuánto cuesta un baño?'), findsOneWidget);
      expect(asistente.historialesRecibidos, [[], []]);
    });

    testWidgets('si falla, ofrece la reserva normal', (tester) async {
      await tester.pumpWidget(
        app(AssistantScreen(repository: AsistenteFalso(fallaEnviar: true))),
      );

      await escribirYEnviar(tester, 'hola');
      expect(find.text('El asistente no está disponible ahora.'), findsOneWidget);

      await tester.tap(find.text('Usar la reserva normal'));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceSelectionScreen), findsOneWidget);
    });
  });

  testWidgets('el inicio y el chat caben en un teléfono de 360 px',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // A 640 px de alto el botón queda bajo el pliegue: hay que desplazarse.
    await tester.ensureVisible(find.text('Agendar con el asistente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar con el asistente'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('resumen con IA', () {
    Future<void> abrirResumen(WidgetTester tester, AsistenteFalso asistente) async {
      await tester.pumpWidget(app(Scaffold(
        body: AdminAnalyticsScreen(
          repository: SampleAnalyticsRepository(hoy: DateTime(2026, 11, 23)),
          hoy: DateTime(2026, 11, 23),
          asistenteRepository: asistente,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resumen con IA'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el parte', (tester) async {
      await abrirResumen(tester, AsistenteFalso());
      expect(find.text('Hoy vienen Ana a las 09:00 y Luis a las 14:30.'),
          findsOneWidget);
    });

    testWidgets('un fallo se puede reintentar', (tester) async {
      await abrirResumen(tester, AsistenteFalso(fallasResumen: 1));
      expect(find.text('El asistente no está disponible ahora.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Hoy vienen Ana a las 09:00 y Luis a las 14:30.'),
          findsOneWidget);
    });
  });
}
