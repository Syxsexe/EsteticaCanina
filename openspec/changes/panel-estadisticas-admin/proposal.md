# Proposal

## Why

La estética hoy solo puede ver la agenda de un día. No tiene forma de consultar
ingresos, citas pasadas, clientes ni observaciones, y no puede crear ni corregir
una cita desde la app. La dueña termina llevando esas cuentas aparte, donde se
desincronizan.

## What Changes

- Nueva pantalla contenedora de administración con cuatro pestañas: Resumen,
  Agenda, Historial y Clientes. La agenda actual se conserva dentro.
- Resumen con citas de hoy y de la semana, ingresos del mes de citas cumplidas,
  porcentaje de no asistencia, clientes nuevos, top 3 de servicios y próximas
  cinco citas.
- Historial de todas las citas con filtros por tiempo (pasadas, hoy, futuras),
  orden por fecha o estado y actualización por deslizamiento.
- Edición de una cita desde el historial: hora, mascota, servicios, estado y
  nota de la estilista. El precio y la duración se recalculan en Postgres.
- "Eliminar" una cita la deja en estado `cancelada`; nunca borra la fila.
- Botón flotante para que el administrador asigne una cita a un cliente ya
  registrado, elegido por nombre o teléfono.
- Lista de clientes ordenada por nombre del tutor, con teléfono, citas y
  observaciones.
- Observaciones creadas solo por administradores, guardadas en una tabla nueva
  que el cliente no puede leer ni escribir.
- Funciones de base `reservar_cita_admin` y `editar_cita_admin`, ambas
  restringidas a administradores y con precio y duración calculados en el
  servidor.

## Capabilities

### New Capabilities

- `admin-analytics`: resumen operativo con métricas de citas e ingresos.
- `admin-appointment-management`: historial, filtros, orden, edición,
  cancelación y creación de citas en nombre de un cliente registrado.
- `admin-customer-directory`: listado de clientes y observaciones exclusivas
  del administrador.

### Modified Capabilities

Ninguna. El proyecto todavía no tiene specs.

## Impact

- `lib/features/admin/`: pantalla contenedora, pestañas, repositorios y modelos
  nuevos. `AgendaScreen` pasa a ser una pestaña y conserva su comportamiento.
- `supabase/migrations/`: una migración con la tabla `observaciones`, sus
  políticas RLS y las dos funciones nuevas.
- `supabase/seed.sql` o documentación de arranque: alta del administrador
  `juanfe20132@gmail.com` y su fila en `public.admins`. La contraseña no se
  versiona.
- Sin dependencias nuevas de Flutter ni de Supabase.
- Las pruebas siguen siendo sin red, con repositorios y fechas inyectados.
