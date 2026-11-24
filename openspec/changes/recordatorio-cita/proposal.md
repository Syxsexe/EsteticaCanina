# Proposal

## Why

La estética avisa a sus clientes antes de la cita para reducir las no
asistencias, y hoy lo hace a mano: busca el número y escribe el mensaje. La
app ya guarda el celular de cada cliente en el formato que piden WhatsApp y
SMS, pero no ayuda a enviar el aviso.

## What Changes

- Cada cita reservada de la Agenda gana el botón "Recordar".
- Al tocarlo se ve el mensaje ya escrito, con el nombre del cliente, la
  mascota, el día ("hoy", "mañana" o la fecha), la hora y los servicios.
- "Enviar por WhatsApp" abre el chat con ese cliente en el WhatsApp de la
  administradora (enlace `wa.me`); "Enviar por SMS" abre la app de mensajes.
  En los dos casos ella revisa el texto y toca enviar.
- No hay envío automático ni proveedor de mensajería: el aviso sale del número
  de la estética y no cuesta nada.
- Fuera de alcance: envío automático programado (requiere WhatsApp Business
  API o un proveedor de SMS de pago), notificaciones push y marcar qué citas
  ya se recordaron.

## Impact

- `lib/features/admin/recordatorio.dart` (nuevo) y `agenda_screen.dart`.
- `AndroidManifest.xml`: `<queries>` para abrir enlaces `https` y `sms`.
- Sin cambios en la base de datos.
