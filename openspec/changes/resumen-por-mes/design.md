# Design

## Context

La motivación está en `proposal.md`. El estado actual que condiciona el diseño:

- `AdminAnalyticsScreen` recibe un `AnalyticsRepository` con un solo método,
  `resumen()`, que devuelve un `AdminSummary` del mes en curso. Implementa
  `PestanaRecargable`: el panel la recarga al entrar.
- `SupabaseAnalyticsRepository.resumen()` hace tres consultas: las citas del
  mes ampliado con la semana, las próximas cinco y el RPC
  `clientes_nuevos_mes()`.
- `AdminSummary.fromData` ya separa las citas del mes de las de la semana
  comparando año y mes del reloj de pared de Bogotá. Las filas de Postgres
  llegan ya convertidas con `enHoraEstetica`.
- `clientes_nuevos_mes()` es `security definer`, devuelve cero a quien no sea
  admin y calcula el corte de mes con `America/Bogota`. No recibe ningún mes.
- El administrador puede leer todas las citas por RLS (`es_admin()`).

## Goals / Non-Goals

**Goals:**

- Que un mes pasado se pueda revisar con las mismas métricas que el actual,
  calculadas igual.
- Una consulta por mes, sin bajar el historial completo.

**Non-Goals:**

- Comparar meses entre sí, gráficos o tendencias.
- Elegir rangos que no sean un mes natural completo.
- Guardar el mes elegido entre sesiones de la app.

## Decisions

### Un modelo propio para el mes cerrado

`MonthSummary` (`models/month_summary.dart`) tiene estos campos:

- `mes`, el primer día del mes;
- `totalCitas`, las no canceladas;
- `ingresosCop`, `noAsistenciaPct`, `clientesNuevos` y `topServicios`;
- `citas`, todas las del mes ordenadas por inicio, incluidas las canceladas.

Se arma con `MonthSummary.fromData(mes:, citas:, clientesNuevos:)`, que es
puro y se puede probar con fechas fijas.

Las métricas del mes se calculan igual que en `AdminSummary`. Para no
duplicar el cálculo, se extrae a una función compartida `metricasDelMes(...)`
que devuelve ingresos, porcentaje y top, y que usan los dos modelos.

Se descartó reutilizar `AdminSummary` con campos que quedan sin sentido
(`citasHoy`, `proximas`): la pantalla tendría que saber qué campos ignorar.

### El repositorio gana dos métodos

```
Future<List<DateTime>> mesesDisponibles();   // primer día de cada mes, del actual hacia atrás
Future<MonthSummary> resumenDelMes(DateTime mes);
```

- **`mesesDisponibles`** pide la cita más antigua con `order('empieza')` y
  `limit(1)`, la convierte con `enHoraEstetica` y genera todos los meses entre
  esa y el mes de `hoyEnLaEstetica()`, incluidos los que no tuvieron citas. Sin
  citas, devuelve solo el mes en curso.
- **`resumenDelMes`** pide en paralelo las citas en `[desdeHoraEstetica(día
  1), desdeHoraEstetica(día 1 del mes siguiente))` y el RPC nuevo de clientes
  nuevos.

`resumen()` no cambia, y la vista del mes en curso sigue usándolo.

### Función nueva de clientes nuevos por mes

```sql
clientes_nuevos_en(p_mes date) returns int
```

Cuenta los perfiles creados en `[p_mes, p_mes + 1 mes)` del reloj de Bogotá,
excluyendo a las cuentas de `admins`. Es `security definer`, `stable`, y
devuelve cero si no es admin, igual que la actual. Se crea con un nombre
nuevo en vez de sobrecargar `clientes_nuevos_mes`, porque PostgREST resuelve
mal las sobrecargas cuando los parámetros pueden faltar. La función actual se
queda para la vista del mes en curso.

Permisos explícitos: `revoke all ... from public, anon` y `grant execute ...
to authenticated`.

### Pantalla

El título de fecha se convierte en un `DropdownButton<DateTime>` con los meses
en formato "Noviembre 2026". El mes en curso lleva "(este mes)".

- **Mes en curso:** el contenido actual sin cambios.
- **Mes pasado:**
  - fila de métricas con "Citas del mes", "Ingresos", "No asistió" y
    "Clientes nuevos";
  - servicios más pedidos;
  - "CITAS DE <MES>": una tarjeta por cita con fecha, hora, cliente, mascota,
    servicios, total y la etiqueta de estado. La etiqueta reutiliza los
    colores de la agenda.

El estado de la pantalla guarda `_mes` y `_meses`. `_cargar()` consulta según
`_mes`, de modo que `recargar()` del panel y el deslizamiento conservan el mes
elegido. La lista de meses se pide una vez al abrir y se vuelve a pedir en
cada `recargar()`, porque puede aparecer un mes nuevo si cambia el día.

Si `mesesDisponibles` falla, el desplegable muestra solo el mes en curso y el
resumen actual sigue funcionando. La lista de meses es un extra, no un
requisito para ver el presente.

### Muestra y pruebas

`SampleAnalyticsRepository` genera citas para el mes en curso y los dos
anteriores, con estados variados, para que la app sin credenciales enseñe el
desplegable.

Las pruebas usan fechas fijas e incluyen estos casos:

- una cita del 31 de octubre a las 20:00 de Bogotá marcada como UTC;
- un mes vacío entre dos meses con citas;
- una prueba de widget que cambia de mes y comprueba que desaparecen las
  secciones del presente.

## Risks / Trade-offs

- [Un mes con muchas citas trae muchas filas] → Es una estética con una
  estilista: unas pocas centenas al mes. Si crece, se pagina la lista.
- [La consulta de la cita más antigua recorre `citas` por `empieza`] → Ya
  existe el índice `citas_por_fecha`.
- [`AdminSummary` y `MonthSummary` comparten cálculo] → Se extrae a
  `metricasDelMes` y se prueba una vez.
- [Este cambio y `gestion-clientes-agenda-y-resumen` tocan la misma
  capacidad sin archivar] → Archivar en orden: `panel-estadisticas-admin`,
  `gestion-clientes-agenda-y-resumen` y después este.

## Migration Plan

1. Aplicar `supabase/migrations/20261125120000_clientes_nuevos_por_mes.sql`
   en el SQL Editor.
2. Verificar por REST con la anon key que `rpc/clientes_nuevos_en` devuelve
   `permission denied`.
3. Publicar la app. Si la app nueva corre contra una base sin la función, la
   vista de un mes pasado muestra el error con reintento; el mes en curso no
   se ve afectado.
4. Rollback: `drop function public.clientes_nuevos_en(date)`.
