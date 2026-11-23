# Tasks

## 1. Base de datos

- [x] 1.1 Crear `supabase/migrations/20261125120000_clientes_nuevos_por_mes.sql` con `clientes_nuevos_en(p_mes date)`: `security definer`, corte en `America/Bogota`, sin contar `admins`, cero para quien no sea admin, `revoke` de `public` y `anon` y `grant` a `authenticated`. Verificar por REST con la anon key que responde `permission denied`.
- [x] 1.2 Actualizar `supabase/reset.sql`, `base.txt` y `supabase/README.md` con la función nueva. Verificar que lo documentado coincide con la migración.

## 2. Modelo

- [x] 2.1 Extraer de `AdminSummary.fromData` el cálculo de ingresos, no asistencia y top a `metricasDelMes(...)`, sin cambiar resultados. Verificar que `flutter test test/admin_summary_test.dart` sigue pasando.
- [x] 2.2 Crear `MonthSummary` con `fromData(mes:, citas:, clientesNuevos:)`: total de no canceladas, métricas compartidas y citas ordenadas incluidas las canceladas. Verificar con pruebas unitarias el caso de octubre de la spec (4 citas, 105000, 25 %), un mes vacío y la cita del 31 de octubre a las 20:00 de Bogotá.

## 3. Repositorio

- [x] 3.1 Añadir `mesesDisponibles()` y `resumenDelMes(mes)` a `AnalyticsRepository`, con la muestra generando tres meses y la versión Supabase consultando la cita más antigua, el rango del mes y `clientes_nuevos_en`. Verificar con pruebas sobre la muestra que los meses van del actual hacia atrás, incluyen meses vacíos intermedios y que sin citas solo está el mes en curso.

## 4. Pantalla

- [x] 4.1 Añadir el desplegable de meses al Resumen, que abre en el mes en curso y conserva la vista actual para ese mes. Verificar con una prueba de widget que el desplegable lista los meses del repositorio.
- [x] 4.2 Construir la vista de mes pasado: métricas, top de servicios y lista de citas con fecha, hora, cliente, mascota, servicios, total y estado, ocultando hoy, semana y próximas. Verificar con una prueba de widget que al elegir un mes pasado aparecen sus citas y desaparecen las secciones del presente, y que un mes vacío lo indica.
- [x] 4.3 Hacer que deslizar, `recargar()` y "Reintentar" consulten el mes elegido, y que si falla `mesesDisponibles` quede solo el mes en curso. Verificar con un repositorio falso que falla una vez que el reintento consulta el mismo mes.

- [x] 4.4 Añadir a `metricasDelMes` las canceladas y su porcentaje sobre el total agendado, y mostrarlas en la tarjeta "Canceladas" del mes en curso y del mes pasado. Verificar:
  - con pruebas unitarias: octubre da 1 y 20 %, y un mes vacío da 0 y 0 %;
  - con pruebas de widget: la tarjeta aparece en las dos vistas.

## 5. Verificación integrada

- [x] 5.1 Ejecutar `flutter analyze` y `flutter test` y verificar que no hay avisos nuevos y que toda la suite pasa sin red.
- [ ] 5.2 Probar contra Supabase: el desplegable lista los meses desde la primera cita real; las métricas y citas de un mes pasado coinciden con una consulta en el SQL Editor; y el mes en curso se ve igual que antes.

## Workflow follow-up

- Archivar en orden: `panel-estadisticas-admin`, `gestion-clientes-agenda-y-resumen` y luego este cambio.
