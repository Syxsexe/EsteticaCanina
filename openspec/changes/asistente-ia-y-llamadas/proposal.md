# Proposal

## Why

Reservar exige recorrer tres pantallas, y hay clientes que prefieren escribir
"quiero bañar a Toby el jueves por la tarde" y que alguien les responda. La
administradora, por su parte, tiene que leer Resumen, Agenda e Historial para
saber cómo va el día, y para llamar a un cliente tiene que copiar su número a
mano.

## What Changes

- **Asistente de reservas para clientes.** Desde el inicio, el cliente puede
  agendar conversando:
  - el asistente pregunta lo que falta: servicio, día, hora, nombre, celular y
    mascota;
  - consulta los servicios y los horarios libres reales;
  - crea la cita con la misma regla de la reserva normal
    (`reservar_cita_por_celular`), así que el precio, la duración, los
    solapes y quién es el cliente los decide la base, no la IA.
- **"Resumen con IA" para la administradora.** Un botón en la pestaña Resumen
  escribe un parte corto de hoy y los próximos días: quién viene, huecos
  libres, cancelaciones, no asistencias y clientes nuevos. Es una sola
  llamada por toque, sin chat. Solo funciona con una sesión de
  administradora.
- **Llamar al cliente.** En el detalle del cliente hay un botón que abre el
  marcador del teléfono con su celular.
- **Proveedor de IA: Gemini, plan gratuito, para empezar.** La llamada al
  modelo vive en **un solo archivo** de la Edge Function. Pasar a Claude u
  otro proveedor es reescribir ese archivo, sin tocar la app ni las
  herramientas.
- La clave del proveedor es un **secreto de Supabase** (`GEMINI_API_KEY`) y
  nunca viaja en la app.
- **Aviso de datos:** en el plan gratuito de Gemini, Google usa lo enviado
  para mejorar sus productos. Mientras sea así, el asistente es **solo para
  pruebas con datos inventados**. Para clientes reales hay que pasar a un
  plan de pago o a otro proveedor (Ley 1581).
- **Dependencias nuevas:** `url_launcher`, para la llamada. Ya llegaba de
  forma transitiva y ahora se declara directamente.
- Fuera de alcance:
  - chat para la administradora;
  - notificaciones push;
  - que el asistente cancele o modifique citas;
  - memoria entre conversaciones;
  - voz;
  - límites de uso por cliente, más allá de topes por conversación.

## Capabilities

### New Capabilities

- `asistente-reservas`: el asistente conversacional que ayuda al cliente a
  agendar una cita.

### Modified Capabilities

- `admin-analytics`: el resumen escrito por IA, bajo demanda.
- `admin-customer-directory`: llamar al cliente desde su detalle.

Las dos capacidades nacen en cambios todavía sin archivar. Este cambio se
archiva después de ellos.

## Impact

- `supabase/functions/asistente/`: una Edge Function nueva en Deno.
  - `index.ts`: rutas, herramientas y permisos.
  - `modelo.ts`: lo único que conoce al proveedor de IA.
  - `horarios.ts`: cálculo de horarios libres, con su prueba.
- `lib/features/assistant/`: la pantalla del chat y `AsistenteRepository`, en
  sus versiones de muestra y Supabase.
- `lib/features/home/home_screen.dart`: la entrada "Agendar con el
  asistente".
- `lib/features/admin/admin_analytics_screen.dart`: el botón "Resumen con IA".
- `lib/features/admin/admin_customer_detail_screen.dart`: el botón de llamar.
- `android/app/src/main/AndroidManifest.xml`: la consulta del intent `tel`,
  que Android 11+ exige.
- `pubspec.yaml`: `url_launcher`.
- `supabase/README.md` y `AGENTS.md`: cómo desplegar la función y configurar
  el secreto.
- No hay migraciones: se reutilizan `reservar_cita_por_celular`,
  `horarios_ocupados` y las políticas de admin.
