import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/features/admin/models/agenda_entry.dart';
import 'package:perro_look/features/admin/recordatorio.dart';

import 'agenda_test.dart' show AgendaFalsa, abrir, cita, lunes;

AgendaEntry citaEl(
  DateTime dia, {
  String? cliente = 'Ana Pérez',
  String? mascota = 'Toby',
}) => AgendaEntry(
  id: 'c1',
  empieza: DateTime(dia.year, dia.month, dia.day, 9),
  minutos: 60,
  estado: EstadoCita.reservada,
  totalCop: 45000,
  clienteNombre: cliente,
  clienteTelefono: '+573001112233',
  mascotaNombre: mascota,
  servicios: const ['Baño', 'Uñas'],
);

void main() {
  group('mensaje', () {
    test('mañana, con nombre, mascota, hora y servicios', () {
      expect(
        mensajeRecordatorio(citaEl(DateTime(2026, 11, 3)), lunes),
        'Hola Ana, te recordamos la cita de Toby en Perro Look mañana a las '
        '09:00 (Baño, Uñas). Si no puedes venir, avísanos por aquí, por favor.',
      );
    });

    test('hoy y otro día', () {
      expect(
        mensajeRecordatorio(citaEl(lunes), lunes),
        contains('Perro Look hoy a las'),
      );
      expect(
        mensajeRecordatorio(citaEl(DateTime(2026, 11, 5)), lunes),
        contains('Perro Look el jueves 5 de noviembre a las'),
      );
    });

    test('sin nombre ni mascota', () {
      final texto = mensajeRecordatorio(
        citaEl(lunes, cliente: null, mascota: null),
        lunes,
      );
      expect(texto, startsWith('Hola, te recordamos tu cita en Perro Look'));
    });
  });

  test('enlaces de WhatsApp y SMS con el texto codificado', () {
    expect(
      whatsappRecordatorio('+573001112233', 'Hola Ana, mañana').toString(),
      'https://wa.me/573001112233?text=Hola%20Ana%2C%20ma%C3%B1ana',
    );
    expect(
      smsRecordatorio('+573001112233', 'Hola Ana').toString(),
      'sms:+573001112233?body=Hola%20Ana',
    );
  });

  testWidgets('Recordar solo en citas reservadas y muestra el mensaje', (
    tester,
  ) async {
    await abrir(
      tester,
      AgendaFalsa({
        lunes: [
          cita(id: 'a', hora: 9),
          cita(id: 'b', hora: 11, estado: EstadoCita.cumplida, mascota: 'Luna'),
        ],
      }),
    );

    expect(find.text('Recordar'), findsOneWidget);

    await tester.tap(find.text('Recordar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Hola Ana, te recordamos la cita de Toby'),
      findsOneWidget,
    );
    expect(find.text('Enviar por WhatsApp'), findsOneWidget);
    expect(find.text('Enviar por SMS'), findsOneWidget);
  });
}
