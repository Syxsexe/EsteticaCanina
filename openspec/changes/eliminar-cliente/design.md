# Design

## Context

La motivación está en `proposal.md`. El estado actual que condiciona el diseño:

- `citas.cliente_id` referencia `perfiles` con `on delete restrict`, así que
  no se puede borrar el perfil de un cliente que tenga citas.
- `citas.mascota_id` usa `on delete set null`. `mascotas` cae en cascada al
  borrar el perfil, y `notas_mascota` cae en cascada al borrar la mascota.
- `observaciones.cliente_id` y `referidos` usan `on delete cascade` sobre
  `perfiles`.
- `directorio_clientes()` alimenta la lista de Clientes y la búsqueda del
  formulario de cita.
- `reservar_cita_por_celular` busca el perfil por `telefono`.
- `agendaEntryDesdeFila` es el único punto que convierte filas de citas en
  `AgendaEntry` para Agenda, Historial y Resumen.
- `clientes_nuevos_mes` y `clientes_nuevos_en` cuentan perfiles por
  `creado_en`.

## Goals / Non-Goals

**Goals:**

- Borrar los datos personales sin tocar las cifras históricas.
- Una sola transacción en el servidor, con la comprobación de permisos en
  Postgres.

**Non-Goals:**

- Papelera o deshacer.
- Borrar la cuenta de `auth.users`, que haría falta la `service_role`.

## Decisions

### Anonimizar en vez de borrar el perfil

El perfil se conserva para que las citas sigan apuntando a algo. Lo que se
quita es lo que identifica a la persona.

Se añade `perfiles.eliminado_en timestamptz` (nulo en los perfiles activos).
Al eliminar, se ponen `nombre` y `telefono` a nulo y se fija `eliminado_en`.

- Con `telefono` nulo, `reservar_cita_por_celular` no puede volver a
  encontrarlo, así que la misma persona entra como cliente nueva.
- `creado_en` no cambia, así que `clientes_nuevos_*` de ese mes tampoco.

Se descartó borrar el perfil y dejar `citas.cliente_id` nulo: habría que
volverlo opcional en todo el esquema y en las funciones de reserva.

### Una función que lo hace todo

```
eliminar_cliente_admin(p_cliente_id uuid) returns void
```

Es `security definer` y hace esto, en orden y dentro de una transacción:

1. Rechaza a quien no sea admin con `es_admin()`. Rechaza también que
   `p_cliente_id` esté en `admins`, que no exista o que ya esté eliminado.
2. `update citas set estado = 'cancelada'` en las del cliente con
   `estado = 'reservada'` y `empieza > now()`. Así se libera el horario: la
   restricción `sin_solapes` solo mira citas reservadas y cumplidas.
3. `update citas set notas_estilista = null` en todas sus citas. La nota puede
   tener datos personales.
4. `delete from observaciones where cliente_id = ...`.
5. `delete from mascotas where dueno_id = ...`. `notas_mascota` cae en cascada
   y `citas.mascota_id` queda nulo.
6. `update perfiles set nombre = null, telefono = null, eliminado_en = now()`.

Permisos: `revoke all ... from public, anon` y `grant execute ... to
authenticated`.

Se descartó hacerlo desde el cliente con varias llamadas y políticas de
`delete`: no sería atómico y abriría `delete` sobre tablas que hoy no lo
tienen.

### Listas que ya no lo muestran

`directorio_clientes()` añade `and p.eliminado_en is null`. La lista de
Clientes y la búsqueda del formulario de cita usan esa función, así que no
hace falta tocar Flutter para ocultarlo.

### "Cliente eliminado" en las citas

`agendaCampos` pide también `perfiles(nombre, telefono, eliminado_en)`. En
`agendaEntryDesdeFila`, si `eliminado_en` no es nulo, `clienteNombre` pasa a
ser "Cliente eliminado" y `clienteTelefono` queda nulo. Es el único punto de
conversión, así que Agenda, Historial y Resumen lo heredan.

### Flutter

- `CustomerDirectoryRepository.eliminarCliente(String clienteId)`. La versión
  Supabase llama al RPC. La de muestra quita el cliente, sus mascotas y sus
  observaciones.
- `AdminCustomerDetailScreen` añade en la `AppBar` el icono de borrar, con
  tooltip "Eliminar cliente". Abre un diálogo con el resumen de lo que se
  borra y se conserva, y los botones "Volver" y "Eliminar".
  - Si sale bien, `Navigator.pop(true)`. La lista ya recarga al volver
    (`_abrir` llama a `_cargar`).
  - Si falla, un `SnackBar` y el detalle sigue abierto.

## Risks / Trade-offs

- [Es irreversible] → La confirmación lo dice explícitamente. No hay papelera.
- [Si el cliente tenía cuenta, la cuenta sigue en `auth.users`] → Su perfil
  ya no tiene datos. La reserva usa el celular y no la sesión, así que no
  importa para agendar. Borrar la cuenta queda fuera de alcance.
- [Las citas pasadas pierden la mascota] → Es parte de anonimizar. Los
  totales, servicios y estados se conservan.
- [Un cliente eliminado sigue contando en "clientes nuevos" de su mes] → Es lo
  que se pidió: que las estadísticas no cambien.

## Migration Plan

1. Aplicar `supabase/migrations/20261126120000_eliminar_cliente.sql`.
2. Verificar por REST con la anon key que `rpc/eliminar_cliente_admin`
   responde `permission denied`.
3. Publicar la app. Con la base vieja, el botón falla con un error y no borra
   nada.
4. Rollback: borrar la función, restaurar `directorio_clientes()` y borrar la
   columna. Los clientes ya anonimizados no se pueden recuperar.
