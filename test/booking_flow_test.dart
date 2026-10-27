import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/booking/models/service.dart';
import 'package:perro_look/features/booking/booking_confirmed_screen.dart';
import 'package:perro_look/features/booking/models/booking.dart';
import 'package:perro_look/features/booking/schedule_selection_screen.dart';
import 'package:perro_look/features/booking/service_selection_screen.dart';
import 'package:perro_look/features/home/home_screen.dart';

/// Un lunes fijo: la agenda de muestra se deriva de la fecha, así que sin
/// fijarla los tests dirían cosas distintas cada día.
final lunes = DateTime(2026, 11, 2);

/// El baño del catálogo: 60 minutos, el servicio corto.
const bano = Service(
  id: 'bano',
  name: 'Baño',
  note: 'Agua caliente, cepillado y secado.',
  price: 35000,
  minutes: 60,
);

/// La visita de cachorro: 120 minutos, de los que no caben en cualquier sitio.
const cachorro = Service(
  id: 'cachorro',
  name: 'Visita de cachorro',
  note: 'Primera vez, con calma y sin máquina.',
  price: 45000,
  minutes: 120,
);

Future<void> _abrirPaso2(
  WidgetTester tester, {
  required Service servicio,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: ScheduleSelectionScreen(
      // La key obliga a un estado nuevo. Sin ella, un segundo `pumpWidget`
      // en el mismo test reutiliza el elemento anterior —mismo tipo, misma
      // posición— y no vuelve a pasar por `initState`, así que la pantalla
      // se quedaría con la duración del servicio anterior. En la app no
      // pasa: cada push crea un elemento nuevo.
      key: ValueKey(servicio.id),
      selection: BookingSelection(mainService: servicio),
      today: lunes,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('paso 2', () {
    testWidgets('abre en el primer día con sitio y anuncia la duración',
        (tester) async {
      await _abrirPaso2(tester, servicio: bano);

      expect(find.text('PASO 02 DE 02'), findsOneWidget);
      expect(find.textContaining('Tu cita dura 1 h'), findsOneWidget);
      expect(find.text('Sáb y dom cerrado'), findsOneWidget);
      // El lunes 2 abre, así que no hace falta saltar a otro día.
      expect(find.textContaining('Lunes 2 de noviembre'), findsOneWidget);
    });

    testWidgets('no deja reservar hasta que se elige una hora', (tester) async {
      await _abrirPaso2(tester, servicio: bano);

      final boton = find.widgetWithText(ElevatedButton, 'Elige una hora');
      expect(boton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(boton).onPressed, isNull);

      await tester.tap(find.text('09:30'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Reservar cita'), findsOneWidget);
      expect(find.textContaining('Lunes 2 de noviembre, 09:30'), findsOneWidget);
    });

    testWidgets('una hora ocupada no se puede tocar', (tester) async {
      await _abrirPaso2(tester, servicio: bano);

      // La agenda de muestra del lunes 2 ocupa de 11:00 a 12:00.
      await tester.tap(find.text('11:00'));
      await tester.pumpAndSettle();

      // Sigue sin haber hora elegida.
      expect(find.widgetWithText(ElevatedButton, 'Elige una hora'), findsOneWidget);
    });

    testWidgets('cambiar de día descarta la hora que se había elegido',
        (tester) async {
      await _abrirPaso2(tester, servicio: bano);

      await tester.tap(find.text('09:30'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Reservar cita'), findsOneWidget);

      // El martes 3, en la tira de días.
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Elige una hora'), findsOneWidget);
      expect(find.textContaining('Martes 3 de noviembre'), findsOneWidget);
    });

    testWidgets('una cita de 2 h descarta una hora que la de 1 h sí permite',
        (tester) async {
      // El lunes 2 tiene la mañana ocupada de 11:00 a 12:00. Las 09:30 son
      // la frontera: con una hora de cita sobra sitio, con dos no.
      await _abrirPaso2(tester, servicio: bano);
      await tester.tap(find.text('09:30'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Reservar cita'),
        findsOneWidget,
        reason: 'de 09:30 a 10:30 no pisa nada',
      );

      await _abrirPaso2(tester, servicio: cachorro);
      await tester.tap(find.text('09:30'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Elige una hora'),
        findsOneWidget,
        reason: 'de 09:30 a 11:30 se mete en la cita de las 11:00',
      );
    });

    testWidgets('el sábado se muestra cerrado en vez de vacío', (tester) async {
      await _abrirPaso2(tester, servicio: bano);

      // El sábado 7 está en la tira pero no se deja tocar.
      final sabado = find.text('7');
      expect(sabado, findsOneWidget);
      await tester.tap(sabado);
      await tester.pumpAndSettle();

      // Sigue en el lunes: el día cerrado no acepta la selección.
      expect(find.textContaining('Lunes 2 de noviembre'), findsOneWidget);
    });
  });

  group('del paso 1 al paso 2', () {
    testWidgets('lo elegido en el paso 1 llega al paso 2', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const ServiceSelectionScreen(),
      ));

      await tester.tap(find.text('Corte completo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleSelectionScreen), findsOneWidget);
      // El corte completo dura 2 h, y el paso 2 lo sabe sin que nadie se lo
      // vuelva a preguntar.
      expect(find.textContaining('Tu cita dura 2 h'), findsOneWidget);
    });
  });

  group('confirmación', () {
    /// La primera hora que se deje tocar en el paso 2.
    ///
    /// Se busca así y no por una hora fija porque este recorrido usa el día
    /// de hoy: la agenda de muestra cambia según la fecha, pero siempre deja
    /// algún hueco libre, que es lo que garantiza `hasRoomFor`.
    Finder primeraHoraLibre(WidgetTester tester) {
      final horas = find.byWidgetPredicate(
        (w) => w is Text &&
            w.data != null &&
            RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data!),
      );
      for (var i = 0; i < horas.evaluate().length; i++) {
        final hora = horas.at(i);
        final boton =
            find.ancestor(of: hora, matching: find.byType(InkWell)).first;
        if (tester.widget<InkWell>(boton).onTap != null) return hora;
      }
      fail('El paso 2 no ofreció ninguna hora libre');
    }

    /// Recorre el flujo entero desde el Home hasta la cita confirmada.
    Future<void> reservarTodo(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const HomeScreen(),
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reservar cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Baño'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(primeraHoraLibre(tester));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reservar cita'));
      await tester.pumpAndSettle();
    }

    testWidgets('la cita confirmada resume día, hora, servicio y total',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: BookingConfirmedScreen(
          booking: Booking(
            selection: const BookingSelection(mainService: bano),
            date: lunes,
            startMinutes: 9 * 60 + 30,
          ),
        ),
      ));

      expect(find.text('¡Cita confirmada!'), findsOneWidget);
      expect(find.text('Lunes 2 de noviembre'), findsOneWidget);
      expect(find.textContaining('09:30'), findsOneWidget);
      expect(find.textContaining('1 h'), findsOneWidget);
      expect(find.text('Baño'), findsOneWidget);
      expect(find.text(r'$35.000'), findsOneWidget);
    });

    testWidgets('lista todos los servicios elegidos, no solo el principal',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: BookingConfirmedScreen(
          booking: Booking(
            selection: const BookingSelection(
              mainService: bano,
              extras: {'unas', 'oidos'},
            ),
            date: lunes,
            startMinutes: 9 * 60 + 30,
          ),
        ),
      ));

      expect(find.text('SERVICIOS'), findsOneWidget);
      // Baño 35.000 + uñas 10.000 + oídos 5.000, y 60 + 10 + 10 minutos.
      expect(find.text(r'$50.000'), findsOneWidget);
      expect(find.textContaining('1 h 20'), findsOneWidget);
    });

    testWidgets('confirmar saca los dos pasos de la pila', (tester) async {
      await reservarTodo(tester);

      expect(find.byType(BookingConfirmedScreen), findsOneWidget);
      expect(find.byType(ScheduleSelectionScreen), findsNothing);

      // Atrás desde aquí lleva al inicio, no a la hora recién reservada:
      // volver allí solo serviría para reservar dos veces.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Listo'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ScheduleSelectionScreen), findsNothing);
      expect(find.byType(BookingConfirmedScreen), findsNothing);
    });
  });
}
