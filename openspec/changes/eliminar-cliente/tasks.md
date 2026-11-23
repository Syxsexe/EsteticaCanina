# Tasks

## 1. Base de datos

- [x] 1.1 Crear `supabase/migrations/20261126120000_eliminar_cliente.sql` con `perfiles.eliminado_en`, `eliminar_cliente_admin(p_cliente_id)` según el diseño (comprobaciones, cancelar futuras, limpiar notas, borrar observaciones y mascotas, anonimizar el perfil) y `directorio_clientes()` excluyendo eliminados, con `revoke` de `public` y `anon` y `grant` a `authenticated`. Verificar por REST con la anon key que la función responde `permission denied`.
- [x] 1.2 Actualizar `supabase/reset.sql`, `base.txt` y `supabase/README.md`. Verificar que lo documentado coincide con la migración.

## 2. Datos en la app

- [x] 2.1 Pedir `eliminado_en` en `agendaCampos` y mostrar "Cliente eliminado" desde `agendaEntryDesdeFila`. Verificar con una prueba unitaria que una fila con `eliminado_en` da ese nombre y ningún teléfono.
- [x] 2.2 Añadir `eliminarCliente(clienteId)` a `CustomerDirectoryRepository`, con la versión Supabase llamando al RPC y la de muestra quitando cliente, mascotas y observaciones. Verificar con una prueba sobre la muestra que el cliente desaparece de `clientes()` y de la búsqueda.

## 3. Pantalla

- [x] 3.1 Añadir "Eliminar cliente" al detalle, con confirmación que explique qué se borra y qué se conserva, cierre del detalle al confirmar y `SnackBar` si falla. Verificar con pruebas de widget: confirmar lo quita de la lista; "Volver" no cambia nada; un fallo deja el detalle abierto con el error.

## 4. Verificación integrada

- [x] 4.1 Ejecutar `flutter analyze` y `flutter test` y verificar que no hay avisos nuevos y que toda la suite pasa sin red.
- [ ] 4.2 Probar contra Supabase con un cliente de prueba que tenga una cita pasada cumplida, una futura reservada, una mascota con nota y una observación. Al eliminarlo:
  - desaparece de Clientes;
  - la cita pasada sale como "Cliente eliminado" y los ingresos de su mes no cambian;
  - la futura queda cancelada y su hora libre;
  - reservar con su celular crea un cliente nuevo.

## Workflow follow-up

- Archivar después de `panel-estadisticas-admin` y `gestion-clientes-agenda-y-resumen`.
