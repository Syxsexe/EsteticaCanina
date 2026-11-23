# Design

## Context

Ver `proposal.md - Why`. El estado actual que condiciona el diseño:

- `AdminSignInScreen` ya valida correo y contraseña y comprueba `es_admin()`
  contra Postgres.
- `AgendaScreen` ya muestra un día, marca asistencia y tiene actualización por
  deslizamiento. Debe conservarse casi tal cual.
- La RLS ya deja al administrador ver todas las citas, perfiles, mascotas y
  detalles de cita, y actualizar citas. No existe política de borrado.
- `reservar_cita()` usa `auth.uid()` como cliente y calcula precio y duración
  desde `servicios`. No sirve para reservar en nombre de otro.
- `citas.cliente_id` es obligatorio y `citas` se escribe solo por función.
- `mascotas.notas` la puede editar el tutor, así que no sirve para
  observaciones privadas.
- El reloj de la estética es Bogotá UTC-5 fijo; `salon_time.dart` es la única
  frontera horaria.

## Goals / Non-Goals

**Goals:**

- Cuatro pestañas con una sola pantalla contenedora y el login existente.
- Métricas y listas calculadas sobre datos reales; sin datos inventados.
- Toda escritura de citas y observaciones validada en Postgres.
- Reutilizar el catálogo, el horario, el formato y el tema existentes.

**Non-Goals:**

- Clientes sin cuenta o creación de cuentas desde el admin.
- Gráficos o librerías de visualización.
- Borrado físico de citas.
- Registro de mascotas desde el flujo de reserva del cliente.
- Cambios en la autenticación por OTP de clientes.

## Decisions

### Contenedor con `NavigationBar` e `IndexedStack`

`AdminShellScreen` usa un `NavigationBar` inferior con cuatro destinos y un
`IndexedStack` para no reconstruir cada pestaña al cambiar. Se descartó
`TabBar` superior porque cuatro secciones no caben cómodas en pantallas
pequeñas y el pulgar llega mejor abajo. `AgendaScreen` se reutiliza sin
`Scaffold` propio o con su `Scaffold` anidado y `AppBar` desactivada.

`AdminSignInScreen` navega a `AdminShellScreen` en vez de a `AgendaScreen`.

### Un repositorio por pestaña

Tres interfaces nuevas, cada una con su implementación de muestra y la de
Supabase, siguiendo el patrón del proyecto:

```
AnalyticsRepository          -> resumen del mes y próximas citas
AdminAppointmentRepository    -> historial, editar, cancelar, crear
CustomerDirectoryRepository   -> clientes y observaciones
```

Cada `default*Repository()` decide entre Supabase y muestra con
`AppConfig.hasSupabase`. Se descartó ampliar `AgendaRepository` con todo: la
agenda del día tiene otra frecuencia de uso y quedaría una interfaz con diez
métodos sin relación.

### Métricas calculadas en Dart, no en SQL

El repositorio pide las citas del mes con su detalle, los perfiles creados en
el mes y las próximas cinco, y agrega en Dart. Con el volumen de una estética
son pocas filas y evita una función SQL grande que hay que probar aparte.
`shortcut: tres consultas por apertura y agregación en el teléfono; pasar a
una función SQL cuando el mes pase de unos miles de citas.`

### Edición y creación en funciones de Postgres

`editar_cita_admin()` recibe cita, hora, mascota, servicios, estado y nota.
Valida `es_admin()`, recalcula precio y minutos desde `servicios`, reemplaza
`cita_servicios` y guarda la cita en una transacción. La restricción
`sin_solapes` sigue siendo la última palabra; su error `23P01` se traduce a un
mensaje de horario ocupado.

`reservar_cita_admin()` recibe `cliente_id` y hace las mismas validaciones que
`reservar_cita()`. Para no duplicar la lógica, la validación y la escritura se
extraen a una función interna `crear_cita_para(cliente, mascota, empieza,
servicios)`; `reservar_cita()` pasa `auth.uid()` y
`reservar_cita_admin()` valida `es_admin()` y pasa el cliente elegido. Los
permisos de ejecución quedan solo en las dos funciones públicas.

Cancelar no necesita función: la política de actualización del administrador
ya permite cambiar `estado` a `cancelada`.

### Observaciones en tabla propia

```
public.observaciones
  id uuid, cliente_id uuid, autor_id uuid, texto text, creada_en timestamptz
```

`cliente_id` referencia `perfiles`, `autor_id` referencia `auth.users`. RLS
activo con políticas de select, insert, update y delete que exigen
`es_admin()`. No se reutiliza `mascotas.notas` porque su política permite al
tutor escribirla. Se descartó una columna nueva en `perfiles`: RLS es por fila,
no por columna, y habría que ocultar la columna con una vista o una función.

La nota por cita sigue siendo `citas.notas_estilista`, que el cliente no puede
escribir porque solo actualiza sus citas para cancelarlas.

### Mascota opcional en la cita creada por el admin

El FAB elige un cliente registrado y, si tiene mascotas, permite elegir una.
Como hoy el flujo de reserva del cliente nunca registra mascota, el campo suele
quedar nulo y la interfaz debe decir "Sin perro registrado" en vez de mostrar
un hueco.

### Fechas y pruebas

Toda comparación de "hoy", "pasada" y "futura" usa `hoyEnLaEstetica()` y el
reloj de Bogotá. Los tests inyectan repositorios falsos, una fecha fija como
`DateTime(2026, 11, 2)` y una sesión de administrador falsa; no tocan la red.

## Risks / Trade-offs

- **Migración no aplicada** → la app falla al abrir las pestañas nuevas. Se
  aplica `supabase/migrations/` en el editor SQL antes de probar y se documenta
  el orden en `supabase/README.md`.
- **Cuenta admin sin confirmar** → el login devuelve credenciales inválidas. Se
  confirma el correo en el panel o se desactiva la confirmación.
- **Precio editado en el cliente** → nunca se envía precio; solo ids de
  servicio, y Postgres calcula. Una prueba verifica que el total cambia al
  cambiar servicios.
- **Solape al editar** → la restricción de exclusión puede rechazar el guardado.
  Se muestra el mismo mensaje que en la reserva del cliente.
- **Cliente creado sin nombre** → aparece como "Cliente sin nombre"; el admin
  no edita perfiles en este alcance.
- **Agregación en el teléfono** → crece con el número de citas del mes. Queda
  anotada la ruta a una función SQL.

## Migration Plan

1. Añadir una migración posterior a `20261103130000_rol_admin.sql` con la tabla
   `observaciones`, sus políticas y las funciones `crear_cita_para`,
   `reservar_cita_admin` y `editar_cita_admin`.
2. Aplicarla en el editor SQL de Supabase, después de las migraciones
   existentes.
3. Crear `juanfe20132@gmail.com` en Authentication > Users, confirmar el correo
   e insertar su id en `public.admins`. La contraseña no se guarda en el repo.
4. Probar con `.\run.ps1` y `flutter test`.
5. Reversión: retirar la navegación nueva y volver a `AgendaScreen`; en la base,
   borrar las funciones nuevas y la tabla `observaciones`. Las citas y perfiles
   no se tocan.
