import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/app.dart';
import 'package:perro_look/core/navigation/flow_page_route.dart';
import 'package:perro_look/core/startup/app_bootstrap.dart';
import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/core/widgets/brand_logo.dart';
import 'package:perro_look/features/booking/service_selection_screen.dart';
import 'package:perro_look/features/home/home_screen.dart';
import 'package:perro_look/features/splash/splash_screen.dart';

/// Adelanta el reloj hasta que el splash cede y deja que el fundido al Home
/// termine.
///
/// Dos razones para el `pump` explícito. Una, `pumpAndSettle` solo bombea
/// mientras haya frames agendados, y el temporizador del splash vive más que
/// su animación de entrada. Dos, bajo el reloj simulado de un test la
/// precarga del logotipo no resuelve —no hay bundle de verdad—, así que el
/// arranque sale por [AppBootstrap.deadline] y no por la vía rápida. En la
/// app real el 404 del asset llega enseguida y el tope no se toca.
Future<void> _pasarElSplash(WidgetTester tester) async {
  await tester.pump(AppBootstrap.deadline + SplashScreen.minimumVisible);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la app abre en el splash con la marca', (tester) async {
    await tester.pumpWidget(const PerroLookApp());
    await tester.pump(SplashScreen.entrance);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('APP DE RESERVAS'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await _pasarElSplash(tester);
  });

  testWidgets('el splash aguanta el mínimo aunque el arranque sea instantáneo',
      (tester) async {
    // Arranque que termina de inmediato: lo único que puede retener la
    // pantalla es el mínimo, que es justo lo que se quiere medir.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: SplashScreen(bootstrap: (_) async {}),
    ));
    await tester.pump(
      SplashScreen.minimumVisible - const Duration(milliseconds: 1),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
      'tras el splash, la pantalla inicial muestra la promesa y los dos pasos',
      (tester) async {
    await tester.pumpWidget(const PerroLookApp());
    await _pasarElSplash(tester);

    expect(find.textContaining('dos pasos'), findsOneWidget);
    expect(find.text('Elige el servicio'), findsOneWidget);
    expect(find.text('Elige día y hora'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reservar cita'), findsOneWidget);
  });

  testWidgets('el Home no deja volver al splash con el botón atrás',
      (tester) async {
    await tester.pumpWidget(const PerroLookApp());
    await _pasarElSplash(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });

  testWidgets('abrir la reserva cruza las dos pantallas en vez de cortar',
      (tester) async {
    await tester.pumpWidget(const PerroLookApp());
    await _pasarElSplash(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reservar cita'));
    await tester.pump();

    // A media transición conviven: eso es lo que distingue un eje compartido
    // de un corte seco.
    await tester.pump(flowTransitionDuration ~/ 2);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ServiceSelectionScreen), findsOneWidget);

    // Y el Home ya viene desplazado hacia la izquierda, no quieto.
    expect(_desplazamientoDe(tester, find.byType(HomeScreen)), isNegative);

    await tester.pumpAndSettle();
    expect(find.text('PASO 01 DE 02'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('volver del paso 1 deja el Home como estaba', (tester) async {
    await tester.pumpWidget(const PerroLookApp());
    await _pasarElSplash(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reservar cita'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ServiceSelectionScreen), findsNothing);
    // Sin residuos de la animación: vuelve a su sitio exacto.
    expect(_desplazamientoDe(tester, find.byType(HomeScreen)), isZero);
  });
}

/// Cuánto lleva corrido en horizontal lo que hay bajo [pantalla], sumando las
/// traslaciones que le aplica la transición.
double _desplazamientoDe(WidgetTester tester, Finder pantalla) {
  final transforms = tester.widgetList<Transform>(
    find.ancestor(of: pantalla, matching: find.byType(Transform)),
  );
  return transforms.fold<double>(
    0,
    (total, t) => total + t.transform.getTranslation().x,
  );
}
