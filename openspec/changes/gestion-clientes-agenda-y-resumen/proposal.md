# Proposal

## Why

El panel de administración ya tiene sus cuatro pestañas, pero tres partes no
sirven todavía para el trabajo diario. El Resumen mezcla días de otro mes en
los ingresos cuando la semana cruza de un mes a otro, y no refleja lo que se
marca en Agenda hasta que se desliza para refrescar. La cita nueva se crea
desde Historial, aunque la estética piensa en días de agenda. Clientes es de
solo lectura, salvo las observaciones: no se puede corregir un teléfono, dar
de alta una mascota ni dejar una nota interna sobre ella.

Además, la cita del cliente queda a nombre de la sesión que haya abierta en el
equipo. Si la administradora dejó su sesión abierta, la cita queda a su nombre,
y la misma persona aparece como un cliente distinto en cada teléfono o
navegador. Por la misma razón, la estética no puede agendar a quien llama o
llega al local sin haber usado nunca la app.

## What Changes

- Resumen: los ingresos, el porcentaje de no asistencia y el top de servicios
  se calculan solo con las citas del mes en curso, aunque la semana empiece en
  el mes anterior o termine en el siguiente.
- Resumen, Agenda e Historial se vuelven a consultar cuando el administrador
  entra a la pestaña o cuando otra pestaña guarda un cambio en una cita.
- El botón flotante "Nueva cita" pasa de Historial a Agenda. El formulario
  abre en el día que muestra la agenda, o en hoy si ese día ya pasó. Al
  guardar, la agenda se recarga. Historial queda sin botón de creación.
- Clientes identificados por celular, con o sin cuenta en la app:
  - la reserva del cliente gana un paso 3, "¿Quién eres?", que pide el nombre
    del dueño, el celular y el nombre de la mascota, y reemplaza a la hoja de
    contacto. La cita queda a nombre del cliente con ese celular, nunca a
    nombre de la sesión abierta en el equipo;
  - si no existe un cliente con ese celular, se crea sin cuenta. Si la
    mascota no existe con ese nombre, se registra. Todo ocurre en la misma
    operación que crea la cita;
  - el formulario "Nueva cita" del panel ofrece "Cliente nuevo" con los mismos
    datos y usa la misma operación. Si el celular ya existe, la cita va a ese
    cliente.
  - el administrador edita el nombre y el teléfono del cliente;
  - ve la ficha completa de cada mascota: nombre, raza, edad y peso;
  - crea mascotas para un cliente y edita las existentes, pero no las borra;
  - crea una cita desde el detalle del cliente, con ese cliente ya elegido;
  - las citas del detalle se piden filtradas por cliente, no se baja todo el
    historial para filtrarlo en el teléfono.
- Notas internas de mascota: solo el administrador las lee y las escribe. El
  tutor no puede verlas.
- **BREAKING (base de datos)**: se elimina la columna `mascotas.notas`. Su
  contenido actual se copia a una tabla nueva, accesible solo para el
  administrador. La app de clientes no usa esa columna.
- **BREAKING (base de datos)**: `perfiles.id` deja de referenciar a
  `auth.users`. Un perfil puede existir sin cuenta.
- **BREAKING (app de clientes)**: la reserva ya no crea una sesión anónima ni
  recuerda los datos del cliente. El paso 3 se llena en cada reserva.
- Fuera de alcance:
  - borrar mascotas y borrar clientes;
  - unir un cliente sin cuenta con una cuenta que cree después;
  - recordar los datos del paso 3 entre visitas;
  - confirmar el celular por SMS.

## Capabilities

### New Capabilities

- `customer-booking`: la reserva del cliente desde la app. Este cambio añade
  el paso de identificación por celular y define a nombre de quién queda la
  cita.

### Modified Capabilities

Las tres capacidades nacen en el cambio `panel-estadisticas-admin`, que todavía
no está archivado. Este cambio debe archivarse después de ese.

- `admin-analytics`: el resumen se actualiza al volver a la pestaña o tras un
  cambio guardado en otra pestaña; las métricas del mes no incluyen días de
  otro mes.
- `admin-appointment-management`: la creación de citas pasa del Historial a la
  Agenda y al detalle del cliente; se puede agendar a un cliente nuevo por
  celular; las pestañas de citas se actualizan tras cambios hechos en otra.
- `admin-customer-directory`: edición del contacto del cliente, ficha de
  mascotas con alta y edición, y notas internas de mascota.

## Impact

- `lib/features/admin/`: `AdminShellScreen`, `AgendaScreen`,
  `AdminHistoryScreen`, `AdminAppointmentFormScreen`,
  `AdminCustomerDetailScreen`, modelos de cliente y mascota, y los
  repositorios `AnalyticsRepository`, `AdminAppointmentRepository` y
  `CustomerDirectoryRepository`, en sus versiones de muestra y Supabase.
- `lib/features/admin/models/admin_summary.dart`: separa las citas del mes de
  las de la semana.
- `supabase/migrations/`: una migración nueva con las políticas de escritura
  del administrador sobre `perfiles` y `mascotas`, la tabla de notas internas
  y la eliminación de `mascotas.notas`. Otra migración quita la FK de
  `perfiles` a `auth.users` y crea `reservar_cita_por_celular`. También se
  actualizan `reset.sql`, `supabase/README.md` y `base.txt`.
- `lib/features/booking/`: un paso 3 nuevo en el flujo de reserva.
  `BookingRepository` reserva por celular. Desaparecen la hoja de contacto y el
  uso de `ProfileRepository` y de `asegurarSesion` en la reserva.
- `lib/features/admin/admin_appointment_form_screen.dart`: la opción "Cliente
  nuevo".
- Pruebas sin red para el resumen con semanas que cruzan meses, el botón en
  Agenda, la edición de clientes y mascotas, las notas internas, el paso 3 y
  el cliente nuevo del panel.
- Sin dependencias nuevas.
