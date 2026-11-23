# Proposal

## Why

Desde el panel no hay forma de quitar a un cliente: alguien que pidió que
borraran sus datos, un registro de prueba o un cliente duplicado se quedan para
siempre en Clientes. Borrarlo de verdad no es posible sin romper el historial,
porque las citas apuntan al cliente y los ingresos de meses pasados dependen de
ellas.

## What Changes

- El detalle de un cliente gana la acción "Eliminar cliente", con una
  confirmación que explica qué se borra y qué se conserva.
- Eliminar **anonimiza** al cliente, en una sola operación:
  - desaparece de la lista de Clientes y de la búsqueda del formulario de
    cita;
  - se borran su nombre, su celular, sus mascotas con sus notas internas y
    sus observaciones;
  - sus citas pasadas se conservan con sus importes y estados, a nombre de
    "Cliente eliminado" y sin mascota ni nota de la estilista;
  - sus citas futuras que sigan reservadas se cancelan y liberan el horario.
- Si esa persona vuelve a reservar con el mismo celular, entra como cliente
  nuevo: no se recupera nada de lo borrado.
- Ingresos, % de no asistencia, top de servicios y clientes nuevos de los meses
  pasados no cambian.
- Fuera de alcance: deshacer una eliminación, eliminar varios clientes a la
  vez, borrar la cuenta de `auth.users` que tuviera el cliente y eliminar
  cuentas administradoras.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `admin-customer-directory`: eliminar un cliente anonimizándolo. La
  capacidad nace en `panel-estadisticas-admin` y la amplía
  `gestion-clientes-agenda-y-resumen`; ninguno está archivado todavía. Este
  cambio se archiva después de ellos.

## Impact

- `supabase/migrations/`: una migración con la columna
  `perfiles.eliminado_en`, la función `eliminar_cliente_admin` y
  `directorio_clientes` excluyendo a los eliminados. También se actualizan
  `reset.sql`, `base.txt` y `supabase/README.md`.
- `lib/features/admin/data/customer_directory_repository.dart`: el método
  `eliminarCliente`, en sus versiones de muestra y Supabase.
- `lib/features/admin/data/agenda_repository.dart`: las citas de un cliente
  eliminado se muestran como "Cliente eliminado" en Agenda, Historial y
  Resumen.
- `lib/features/admin/admin_customer_detail_screen.dart`: la acción y su
  confirmación.
- Pruebas sin red para la acción, la confirmación y la desaparición del
  cliente de la lista.
- Sin dependencias nuevas.
