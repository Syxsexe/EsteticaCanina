import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/theme/app_theme.dart';
import 'package:perro_look/features/admin/agenda_screen.dart';
import 'package:perro_look/features/admin/data/agenda_repository.dart';
import 'package:perro_look/features/admin/models/agenda_entry.dart';

/// Un lunes fijo, para no depender de qué día se corran los tests.
final lunes = DateTime(2026, 11, 2);

AgendaEntry cita({
  String id = 'c1',
  int hora = 9,
  EstadoCita estado = EstadoCita.reservada,
  String? mascota = 'Toby',
  String? cliente = 'Ana',
}) =>
    AgendaEntry(
      id: id,
      empieza: DateTime(2026, 11, 2, hora),
      minutos: 60,
      estado: estado,
      totalCop: 35000,
      clienteNombre: cliente,
      clienteTelefono: '+573001112233',
      mascotaNombre: mascota,
      servicios: const ['Baño'],
    );

/// Devuelve lo que se le diga, y anota lo que se le manda marcar.
class AgendaFalsa implements AgendaRepository {
  AgendaFalsa(this._porDia);

  final Map<DateTime, List<AgendaEntry>> _porDia;
  final List<(String, EstadoCita)> marcadas = [];

  Object? falla;
  Completer<void>? bloqueo;

  @override
  Future<List<AgendaEntry>> citasDe(DateTime dia) async {
    if (falla != null) throw falla!;
    return _porDia[DateTime(dia.year, dia.month, dia.day)] ?? const [];
  }

  @override
  Future<void> marcar(String citaId, EstadoCita estado) async {
    if (bloqueo != null) await bloqueo!.future;
    if (falla != null) throw falla!;
    marcadas.add((citaId, estado));
  }
}

Future<void> abrir(WidgetTester tester, AgendaFalsa agenda) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: AgendaScreen(repository: agenda, today: lunes),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('agenda del día', () {
    testWidgets('muestra la cita con su hora, perro, cliente y servicios',
        (tester) async {
      await abrir(tester, AgendaFalsa({lunes: [cita()]}));

      expect(find.text('Lunes 2 de noviembre'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Toby'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Baño'), findsOneWidget);
      expect(find.text(r'$35.000'), findsOneWidget);
    });

    testWidgets('un día sin citas lo dice en vez de quedarse en blanco',
        (tester) async {
      await abrir(tester, AgendaFalsa({}));

      expect(find.textContaining('Ninguna cita'), findsOneWidget);
    });

    testWidgets('las flechas cambian de día y recargan', (tester) async {
      final agenda = AgendaFalsa({
        lunes: [cita(mascota: 'Toby')],
        DateTime(2026, 11, 3): [cita(id: 'c2', mascota: 'Canela')],
      });
      await abrir(tester, agenda);
      expect(find.text('Toby'), findsOneWidget);

      await tester.tap(find.byTooltip('Día siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Martes 3 de noviembre'), findsOneWidget);
      expect(find.text('Canela'), findsOneWidget);
      expect(find.text('Toby'), findsNothing);
    });
  });

  group('marcar asistencia', () {
    testWidgets('marcar cumplida lo guarda y lo refleja', (tester) async {
      final agenda = AgendaFalsa({lunes: [cita()]});
      await abrir(tester, agenda);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cumplida'));
      await tester.pumpAndSettle();

      expect(agenda.marcadas, [('c1', EstadoCita.cumplida)]);
      expect(find.text('CUMPLIDA'), findsOneWidget);
      // Ya marcada, no se vuelve a ofrecer.
      expect(find.widgetWithText(ElevatedButton, 'Cumplida'), findsNothing);
    });

    testWidgets('marcar no asistió también queda registrado', (tester) async {
      final agenda = AgendaFalsa({lunes: [cita()]});
      await abrir(tester, agenda);

      await tester.tap(find.widgetWithText(OutlinedButton, 'No asistió'));
      await tester.pumpAndSettle();

      expect(agenda.marcadas, [('c1', EstadoCita.noAsistio)]);
      expect(find.text('NO ASISTIÓ'), findsOneWidget);
    });

    testWidgets('una cita ya cumplida no ofrece marcarla otra vez',
        (tester) async {
      await abrir(
        tester,
        AgendaFalsa({lunes: [cita(estado: EstadoCita.cumplida)]}),
      );

      expect(find.text('CUMPLIDA'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Cumplida'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'No asistió'), findsNothing);
    });

    testWidgets('marcar una cita no bloquea las demás', (tester) async {
      // Por eso el estado de guardado es un conjunto de ids y no un
      // booleano: con la agenda llena, un toque no debe congelar la lista.
      final agenda = AgendaFalsa({
        lunes: [cita(id: 'c1', hora: 9), cita(id: 'c2', hora: 11)],
      })
        ..bloqueo = Completer<void>();
      await abrir(tester, agenda);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cumplida').first);
      await tester.pump();

      // La primera está guardando; la segunda sigue disponible.
      expect(find.widgetWithText(ElevatedButton, 'Cumplida'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      agenda.bloqueo!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('si falla al guardar, lo dice y no miente sobre el estado',
        (tester) async {
      final agenda = AgendaFalsa({lunes: [cita()]});
      await abrir(tester, agenda);
      agenda.falla = Exception('sin red');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cumplida'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(find.text('RESERVADA'), findsOneWidget);
      expect(find.text('CUMPLIDA'), findsNothing);
    });
  });

  group('cuando la agenda no llega', () {
    testWidgets('lo dice y deja reintentar', (tester) async {
      final agenda = AgendaFalsa({lunes: [cita()]})..falla = Exception('sin red');
      await abrir(tester, agenda);

      expect(find.textContaining('No pudimos traer la agenda'), findsOneWidget);

      agenda.falla = null;
      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Toby'), findsOneWidget);
    });
  });
}
