# Proposal

## Why

El Resumen solo muestra el mes en curso. Cuando el mes termina, sus ingresos,
ausencias y servicios más pedidos desaparecen de la pantalla. La dueña no
puede comparar ni revisar cómo le fue, salvo filtrando el Historial cita por
cita y sumando a mano.

## What Changes

- El Resumen gana un menú desplegable de meses. Las opciones van desde el mes
  en curso hasta el mes de la cita más antigua registrada.
- Con el mes en curso elegido, el Resumen se ve igual que hoy: citas de hoy y
  de la semana, ingresos, % de no asistencia, clientes nuevos, top 3 de
  servicios y próximas cinco citas.
- Con un mes pasado elegido, el Resumen muestra:
  - las métricas de ese mes: total de citas no canceladas, ingresos de las
    citas cumplidas, % de no asistencia, clientes nuevos de ese mes y top 3
    de servicios;
  - la lista de todas las citas de ese mes, con fecha, hora, cliente,
    mascota, servicios, total y estado.

  Se ocultan "citas hoy", "citas semana" y "próximas citas", que no aplican a
  un mes cerrado.
- El mes elegido se conserva al deslizar para actualizar y al volver a la
  pestaña.
- Todos los cortes de mes usan el reloj de Bogotá.
- En la base, una función nueva cuenta los clientes nuevos de un mes dado. La
  actual, `clientes_nuevos_mes()`, solo sabe calcular el mes en curso.
- Fuera de alcance: comparar meses entre sí, gráficos, exportar a archivo y
  elegir rangos que no sean un mes completo.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `admin-analytics`: el resumen se puede consultar por mes, incluidos los
  meses pasados con su lista de citas. La capacidad nace en
  `panel-estadisticas-admin`, que todavía no está archivado. Este cambio debe
  archivarse después de ese y de `gestion-clientes-agenda-y-resumen`.

## Impact

- `lib/features/admin/admin_analytics_screen.dart`: el desplegable y la vista
  de mes pasado.
- `lib/features/admin/data/analytics_repository.dart`: los meses disponibles
  y el resumen de un mes, en sus versiones de muestra y Supabase.
- `lib/features/admin/models/`: el modelo del resumen de un mes cerrado.
- `supabase/migrations/`: una migración con la función de clientes nuevos por
  mes. También se actualizan `reset.sql`, `base.txt` y `supabase/README.md`.
- Pruebas sin red para la lista de meses, las métricas de un mes pasado y el
  cambio de vista.
- Sin dependencias nuevas.
