import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/app.dart';

void main() {
  testWidgets('la pantalla inicial muestra la promesa y los dos pasos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PerroLookApp());

    expect(find.textContaining('dos pasos'), findsOneWidget);
    expect(find.text('Elige el servicio'), findsOneWidget);
    expect(find.text('Elige dia y hora'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reservar cita'), findsOneWidget);
  });
}
