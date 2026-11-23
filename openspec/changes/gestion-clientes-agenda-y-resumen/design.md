# Design

## Context

La motivación está en `proposal.md`, en la sección Why. Este es el estado actual
que condiciona el diseño:

- `AdminShellScreen` monta las cuatro pestañas en un `IndexedStack`. Cada
  pestaña carga en `initState` y no se entera de lo que cambian las demás.
- `SupabaseAnalyticsRepository.resumen()` pide en una sola consulta las citas
  desde `min(lunes, día 1)` hasta `max(domingo, día 1 del mes siguiente)`.
  `AdminSummary.fromData` recibe esa lista como `mes` y calcula con ella los
  ingresos, la no asistencia y el top de servicios.
- Con `embedded: true`, `AgendaScreen` devuelve un `Column` sin `Scaffold`, así
  que no tiene dónde colocar un botón flotante. Solo recibe `AgendaRepository`.
- `AdminAppointmentFormScreen` ya acepta `cliente:` y `hoy:`. Con `hoy`
  empieza la lista de días, pero en una cita nueva elige siempre el primer día
  con hueco.
- `AdminCustomerDetailScreen` llama a `historial()` y filtra por `clienteId` en
  el teléfono.
- La RLS da al administrador solo `select` sobre `perfiles` y `mascotas`. El
  tutor puede leer y escribir todas las columnas de sus propias mascotas,
  incluida `notas`.
- El flujo de reserva lee el perfil de la base. Solo escribe nombre y teléfono
  cuando el perfil está incompleto (`schedule_selection_screen.dart`, alrededor
  de la línea 263). Por eso una corrección del administrador no se pisa
  mientras el perfil siga completo.
- La app de clientes no lee ni escribe `mascotas.notas`.
- La reserva del cliente tiene dos pasos. `SupabaseBookingRepository.reservar`
  llama a `asegurarSesion`, que hace `signInAnonymously()` si no hay sesión, y
  después a `reservar_cita`, que toma el cliente de `auth.uid()`. Siempre
  envía `p_mascota_id: null`. Si la administradora dejó su sesión abierta en el
  equipo, la cita queda a su nombre.
- `perfiles.id` es una FK a `auth.users` y el trigger `crear_perfil` crea el
  perfil al nacer la cuenta. Por eso no puede existir un cliente sin cuenta.
- Solo la reserva (`BookingRepository`) y la hoja de contacto
  (`ProfileRepository`) usan la sesión anónima. `mi_fidelidad()` existe en la
  base, pero la app no la llama.
- `crear_cita_para` ya no se puede ejecutar directamente: tiene el `execute`
  revocado a `anon` y `authenticated` desde
  `20261123130000_cerrar_crear_cita_para.sql`.

## Goals / Non-Goals

**Goals:**

- Que cada pestaña refleje lo guardado en otra sin que el administrador tenga
  que deslizar.
- Que todos los permisos nuevos del administrador los compruebe Postgres, nunca
  solo la interfaz.
- Que la nota interna sea invisible para el tutor también vía API, no solo en
  la UI.

**Non-Goals:**

- Un sistema global de estado o de eventos, o un paquete de gestión de estado.
- Recargar en tiempo real cambios hechos por otros dispositivos.
- Validar en Postgres el teléfono que edita el administrador desde la ficha.
  Ese teléfono lo valida el formulario. Sí se valida en Postgres el celular
  de `reservar_cita_por_celular`, porque cualquiera puede llamarla.
- Unir un cliente sin cuenta con una cuenta que cree después.
- Recordar los datos del paso 3 entre visitas. Haría falta una dependencia de
  almacenamiento local o una sesión, y la sesión es justo lo que se quita.
- Confirmar el celular por SMS u OTP.
- Corregir la visibilidad de `citas.notas_estilista` para el tutor. El tutor
  hoy puede leerla porque ve todas las columnas de sus citas. Es un hallazgo
  aparte que no forma parte de este cambio.

## Decisions

### Métricas del mes: filtrar en `fromData`, no partir la consulta

`AdminSummary.fromData` sigue recibiendo una sola lista, pero filtra dentro de
ella el subconjunto del mes. Ese subconjunto son las citas cuyo reloj de pared
de Bogotá cae en `[día 1, día 1 del mes siguiente)`. De ahí salen los
ingresos, la no asistencia y el top de servicios. Hoy y la semana siguen
usando la lista completa.

Se renombra el parámetro `mes` a `citas` para que su nombre deje de mentir.

La alternativa era hacer dos consultas, una para el mes y otra para la semana.
Se descartó porque duplica filas en la red y no corrige el error de fondo:
nada impide que alguien vuelva a pasar una lista ampliada.

### Refresco: recargar al entrar a la pestaña

`AdminShellScreen` lleva un contador de versión por pestaña. Al cambiar de
destino, el shell le pide a la pestaña que entra que recargue. Para eso, cada
pantalla de pestaña expone un `State` público con `recargar()` y el shell la
alcanza con una `GlobalKey`.

Las recargas no reinician el estado de la vista:

- Agenda conserva `_dia`.
- Historial conserva el filtro y el orden.
- Resumen muestra el error con reintento si la consulta falla.

Alternativas descartadas:

- **`ChangeNotifier` compartido con un contador de cambios.** Funciona, pero
  añade un objeto que todas las pantallas y todos los tests deben recibir. Para
  cuatro pestañas, recargar al entrar es más simple y cubre todos los
  escenarios de las specs.
- **Quitar el `IndexedStack`.** Rompe la regla del cambio anterior de conservar
  el filtro y el estado al cambiar de pestaña.

El costo es una consulta por cada cambio de pestaña. Con el volumen de una
estética es aceptable.

### Botón flotante dentro de `AgendaScreen`

`AgendaScreen` devuelve un `Scaffold` también cuando va embebida. En ese caso
no lleva `AppBar` y sí lleva `floatingActionButton`. Recibe
`AdminAppointmentRepository`, `AvailabilityRepository` y
`CustomerDirectoryRepository`, todos opcionales. Si faltan, usa los
`default*Repository()` del proyecto.

El botón abre el formulario con un parámetro nuevo, `diaInicial`. Si
`diaInicial` es anterior a `hoyEnLaEstetica()`, el formulario usa hoy. Al
volver con `true`, la agenda llama a `_cargar()` sin mover `_dia`.

Se descartó poner el botón en el `Scaffold` del shell. El shell no sabe qué día
muestra la agenda, y para saberlo haría falta comunicación de ida y vuelta
entre los dos.

`AdminHistoryScreen` pierde el botón flotante, pero conserva
`_abrirFormulario(cita:)` para editar. Ya no necesita
`CustomerDirectoryRepository` para crear, solo para editar.

### Citas del cliente con filtro en el servidor

`AdminAppointmentRepository` gana `historialDe(String clienteId)`. La versión
Supabase usa `.eq('cliente_id', clienteId)` y la de muestra filtra en memoria.
El detalle del cliente usa este método en lugar de `historial()`.

### Cancelar con confirmación de fila

`cancelar()` en Supabase añade `.select('id')` y lanza un error si la lista
vuelve vacía. La interfaz ya muestra un error cuando la llamada falla, así que
no hace falta un cambio de UI.

### Permisos del administrador: políticas RLS

```sql
create policy "la estética edita a los clientes"
  on public.perfiles for update to authenticated
  using (es_admin()) with check (es_admin());

create policy "la estética registra mascotas"
  on public.mascotas for insert to authenticated
  with check (es_admin());

create policy "la estética edita mascotas"
  on public.mascotas for update to authenticated
  using (es_admin()) with check (es_admin());
```

No hay política de `delete` para el administrador sobre `mascotas` ni sobre
`perfiles`.

Se descartaron funciones `security definer` como `editar_cliente_admin`. Su
validación extra sería el formato del teléfono, que no es una regla de
seguridad y ya vive en `normalizarTelefono()`. Las políticas siguen el patrón
de `citas` y `observaciones`.

Los `check` existentes de `mascotas` (edad entre 0 y 30, peso mayor que cero)
siguen vigentes, y el formulario los repite para avisar antes de enviar.

### Notas internas: tabla 1:1 solo para el administrador

```
public.notas_mascota
  mascota_id     uuid primary key references mascotas(id) on delete cascade
  texto          text not null
  autor_id       uuid references auth.users(id)
  actualizada_en timestamptz not null default now()
```

La tabla tiene RLS activo con políticas de `select`, `insert` y `update` que
exigen `es_admin()`. No tiene política de `delete`: vaciar el texto equivale a
borrar la nota.

La escritura es un `upsert` por `mascota_id`. `autor_id` y `actualizada_en` los
fija el cliente Flutter en cada guardado, igual que hoy hace
`observaciones.autor_id`.

Alternativas descartadas:

- **Ocultar `mascotas.notas` con privilegios de columna.** El tutor y el
  administrador comparten el rol `authenticated`, así que revocar
  `select(notas)` se lo quitaría también al administrador.
- **Reutilizar `observaciones` con un `mascota_id` opcional.** Mezcla notas de
  cliente con notas de mascota y obliga a filtrar en todas las consultas
  existentes. Además, el usuario pidió "la nota" de la mascota, no un hilo de
  notas.

La migración ejecuta, en una sola transacción:

1. Crear `notas_mascota` con sus políticas.
2. Copiar a `notas_mascota` las notas existentes con
   `insert ... select id, notas, null, now() from mascotas where nullif(btrim(notas), '') is not null`.
3. `alter table public.mascotas drop column notas`.

### Modelos

- `PetRef` se queda para los selectores, porque solo lleva `id` y `nombre`.
- Se añade `PetRecord` con `id`, `duenoId`, `nombre`, `raza`, `edadAnios`,
  `pesoKg` y una `PetNote?` con `texto`, `autorId` y `actualizadaEn`.
- `CustomerDirectoryRepository` gana estos métodos:
  - `mascotasDe(clienteId)`
  - `guardarMascota(PetRecord)`, que crea la mascota cuando `id` es nulo
  - `guardarNotaMascota(mascotaId, texto)`
  - `actualizarContacto(clienteId, nombre, telefono)`

  La versión Supabase de `mascotasDe` pide
  `mascotas(id, dueno_id, nombre, raza, edad_anios, peso_kg, notas_mascota(texto, autor_id, actualizada_en))`
  en una sola consulta anidada.

### Clientes sin cuenta

Se quita la FK `perfiles_id_fkey` (`perfiles.id -> auth.users`) y `perfiles.id`
pasa a tener `default gen_random_uuid()`.

- El trigger `crear_perfil` sigue insertando `id = new.id`, así que un cliente
  con cuenta conserva su perfil enlazado.
- Las políticas `id = (select auth.uid())` no cambian: un id aleatorio nunca
  coincide con una cuenta, así que un perfil sin cuenta no lo ve ningún
  cliente.
- `citas`, `mascotas`, `observaciones` y `referidos` siguen apuntando a
  `perfiles`, así que no les afecta.

Se descartó una tabla aparte de "clientes de mostrador": `citas.cliente_id`
tendría que apuntar a dos tablas.

### Reserva por celular: una sola función

```
reservar_cita_por_celular(p_nombre, p_telefono, p_mascota_nombre,
                          p_empieza, p_servicios) returns uuid
```

Es `security definer` y se ejecuta con `anon` y `authenticated`. En una sola
transacción hace esto:

1. Valida los datos de entrada:
   - `p_telefono ~ '^\+573[0-9]{9}$'`, el mismo E.164 que produce
     `normalizarTelefono`;
   - el nombre y la mascota no pueden estar vacíos tras `btrim`;
   - límites de longitud razonables.
2. Busca el perfil con ese `telefono`, sin contar las cuentas de `admins`. Si
   hay varios, porque los dejaron las sesiones anónimas de antes, elige el
   más antiguo. Si no hay ninguno, inserta `perfiles(nombre, telefono)`. **No
   actualiza el nombre de un perfil existente**: si lo hiciera, cualquiera
   podría renombrar a un cliente sabiendo su celular.
3. Busca la mascota del perfil por `lower(btrim(nombre))`. Si no existe, la
   inserta.
4. Llama a `crear_cita_para(perfil, mascota, empieza, servicios)`, que
   conserva todas las validaciones de servicios, horario y cierres. Un
   `exclusion_violation` se relanza con el mismo código, `23P01`.

Si cualquier paso falla, la transacción entera se revierte y no quedan
clientes ni mascotas huérfanos.

El panel usa la misma función para "Cliente nuevo". No se crea una
`reservar_cita_cliente_nuevo_admin` aparte. Lo que antes iba a ser "rechazar
si el celular existe" pasa a ser "usar al cliente existente", que es la misma
regla del cliente.

Permisos:

```sql
revoke all on function public.reservar_cita_por_celular(...) from public;
grant execute on function public.reservar_cita_por_celular(...) to anon, authenticated;
```

`reservar_cita` sigue existiendo para cuentas reales, pero la app deja de
llamarla.

Alternativas descartadas:

- **Seguir con la sesión anónima del dispositivo.** No resuelve el problema
  de la sesión de admin compartida ni los clientes duplicados por equipo.
- **Políticas de `insert` sobre `perfiles` y `mascotas` y tres llamadas desde
  la app.** No son atómicas y abrirían esas tablas a inserciones directas.

### Paso 3 en la app

`IdentificationScreen` es el paso 3. `ScheduleSelectionScreen` deja de
reservar: al confirmar el horario, navega al paso 3 con el `Booking`. El paso
3 valida igual que la hoja de contacto, con `normalizarTelefono` y los
campos no vacíos, y llama a `BookingRepository.reservar(booking, cliente)`.

- Con `SlotTakenException`, avisa y vuelve al paso 2, que recarga los
  horarios.
- Al confirmar, `pushAndRemoveUntil` lleva a la confirmación, como ahora.

`BookingRepository.reservar` recibe un `ClienteReserva` con nombre, celular y
mascota. La versión Supabase llama a `reservar_cita_por_celular` sin
`asegurarSesion`.

Desaparecen `pedirDatosDeContacto` (la hoja de contacto) y el uso de
`ProfileRepository` en la reserva. `ProfileRepository` se elimina si nada más
lo usa.

En el panel, `AdminAppointmentRepository` gana `crearPorCelular(nombre,
telefono, mascotaNombre, empieza, servicios)`, que usa la misma función.
`AdminAppointmentFormScreen` añade el botón "Cliente nuevo" junto al buscador,
con los tres campos.

### Fechas y pruebas

`actualizada_en` y `creada_en` se muestran con `enHoraEstetica`, no con
`toLocal()`. Las pruebas siguen sin red: usan repositorios de muestra, fechas
fijas y, para el resumen, un martes 1 de diciembre de 2026 que deja la semana
cruzando dos meses.

## Risks / Trade-offs

- [Este cambio modifica requisitos de capacidades que aún no están archivadas]
  → Archivar `panel-estadisticas-admin` antes que este cambio. `openspec
  validate` ya avisa si el orden es otro.
- [Borrar la columna `mascotas.notas` es irreversible] → La migración copia el
  texto antes de borrarla, todo dentro de la misma transacción. Hacer un
  respaldo antes de aplicarla en una base con datos reales.
- [Quien conozca un celular puede reservar a nombre de esa persona] → No
  puede ver ni cambiar sus datos, y la reserva no renombra el perfil. La
  estética ve la cita en Agenda y puede cancelarla. Confirmar el celular por
  SMS queda fuera de alcance.
- [Spam: `anon` puede crear perfiles y citas sin límite] → Ya era posible con
  las cuentas anónimas. Se mitigaría con límites por IP en Supabase o con un
  captcha, fuera de alcance.
- [Hay perfiles duplicados con el mismo celular, dejados por las sesiones
  anónimas anteriores] → La función elige el más antiguo. Unirlos queda para
  después. Por eso no se pone un índice único en `telefono`: fallaría con los
  datos actuales.
- [Si el administrador cambia el celular de un cliente, ese cliente tiene que
  reservar con el celular nuevo] → Con el antiguo se crearía otro cliente.
  Está documentado en la spec.
- [Borrar una cuenta de `auth.users` ya no borra su perfil] → El perfil queda
  como cliente sin cuenta, con su historial intacto.
- [Un cliente con cuenta de antes y la misma persona reservando por celular
  pueden ser dos perfiles distintos] → Igual que el caso de los duplicados.
- [Recargar en cada cambio de pestaña genera tráfico de red] → Son pocas filas
  por consulta. Si molesta, se puede recargar solo cuando la pestaña lleve
  marcada una versión vieja.
- [Una `GlobalKey` hacia el `State` acopla el shell con las pantallas] → El
  acoplamiento se limita a un método, `recargar()`, y los tests lo cubren
  cambiando de pestaña.
- [El administrador hereda las políticas de cualquier tabla nueva que use
  `es_admin()`] → Es el mismo modelo que el resto del panel. `crear_cita_para`
  ya está cerrada a las llamadas directas, y la función nueva lleva su
  `revoke` y su `grant` explícitos.

## Migration Plan

1. Respaldar `mascotas` desde el SQL Editor de Supabase.
2. Aplicar `supabase/migrations/20261123120000_gestion_clientes.sql` después
   de `20261116120000_panel_admin.sql`.
3. Comprobar con una cuenta de cliente que `select notas from mascotas` falla
   porque la columna ya no existe y que `select * from notas_mascota` devuelve
   cero filas.
4. Actualizar `reset.sql`, `base.txt` y `supabase/README.md`.
5. Rollback: recrear `mascotas.notas`, copiar `notas_mascota.texto` de vuelta y
   borrar las tablas y políticas nuevas. Hacerlo solo si todavía no hay notas
   nuevas que perder.
6. Aplicar `supabase/migrations/20261124120000_clientes_por_celular.sql`.
   Comprobar con la anon key:
   - `rpc/reservar_cita_por_celular` con un celular inválido es rechazada;
   - `rpc/crear_cita_para` sigue en `permission denied`.
7. Publicar la app con el paso 3 después de aplicar esa migración. Con la app
   vieja, la reserva sigue funcionando por la sesión anónima. Con la app
   nueva y la base vieja, la reserva falla porque la función no existe.
8. Rollback de la FK: solo es posible si no se crearon perfiles sin cuenta.
   Hay que borrarlos o asignarlos antes de volver a crear la FK.
