import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/dates.dart';
import 'models/agenda_entry.dart';

// El recordatorio de una cita, listo para que la estética lo mande desde su
// propio WhatsApp o por SMS. No se envía nada solo: se abre la app con el
// texto escrito y la dueña lo revisa y toca enviar.

/// El texto del mensaje. `hoy` es el día en la estética, para decir "hoy" o
/// "mañana" en vez de la fecha.
String mensajeRecordatorio(AgendaEntry cita, DateTime hoy) {
  // En UTC para que un cambio de horario del teléfono no cuente un día de 23 h.
  final dia = DateTime.utc(
    cita.empieza.year,
    cita.empieza.month,
    cita.empieza.day,
  );
  final dias = dia
      .difference(DateTime.utc(hoy.year, hoy.month, hoy.day))
      .inDays;
  final fecha = formatLongDate(dia);
  final cuando = switch (dias) {
    0 => 'hoy',
    1 => 'mañana',
    _ => 'el ${fecha[0].toLowerCase()}${fecha.substring(1)}',
  };

  final nombre = cita.clienteNombre?.trim().split(' ').first;
  final saludo = nombre == null || nombre.isEmpty ? 'Hola' : 'Hola $nombre';
  final deQuien = cita.mascotaNombre == null
      ? 'tu cita'
      : 'la cita de ${cita.mascotaNombre}';
  final servicios = cita.servicios.isEmpty
      ? ''
      : ' (${cita.servicios.join(', ')})';

  return '$saludo, te recordamos $deQuien en Perro Look $cuando a las '
      '${formatHour(cita.inicioEnMinutos)}$servicios. Si no puedes venir, '
      'avísanos por aquí, por favor.';
}

/// `wa.me` abre el chat con ese número y el texto escrito. Pide el número
/// sin `+` ni espacios.
Uri whatsappRecordatorio(String telefono, String mensaje) => Uri.parse(
  'https://wa.me/${telefono.replaceAll(RegExp(r'[^0-9]'), '')}'
  '?text=${Uri.encodeComponent(mensaje)}',
);

/// `encodeComponent` y no `queryParameters`: este pone `+` por los espacios
/// y algunas apps de mensajes los muestran tal cual.
Uri smsRecordatorio(String telefono, String mensaje) =>
    Uri.parse('sms:$telefono?body=${Uri.encodeComponent(mensaje)}');

/// Muestra el mensaje y deja elegir por dónde mandarlo.
Future<void> mostrarRecordatorio(
  BuildContext context,
  AgendaEntry cita,
  DateTime hoy,
) {
  final telefono = cita.clienteTelefono!;
  final mensaje = mensajeRecordatorio(cita, hoy);
  final mensajero = ScaffoldMessenger.of(context);

  Future<void> abrir(BuildContext hoja, Uri uri, String fallo) async {
    Navigator.of(hoja).pop();
    var abierto = false;
    try {
      abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!abierto) mensajero.showSnackBar(SnackBar(content: Text(fallo)));
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (hoja) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recordatorio', style: Theme.of(hoja).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(mensaje, style: Theme.of(hoja).textTheme.bodyMedium),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => abrir(
                hoja,
                whatsappRecordatorio(telefono, mensaje),
                'No se pudo abrir WhatsApp.',
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Enviar por WhatsApp'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => abrir(
                hoja,
                smsRecordatorio(telefono, mensaje),
                'No se pudo abrir los mensajes.',
              ),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Enviar por SMS'),
            ),
          ],
        ),
      ),
    ),
  );
}
