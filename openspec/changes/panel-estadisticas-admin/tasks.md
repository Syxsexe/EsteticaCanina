# Tasks

## 1. Base de datos

- [x] 1.1 Crear `supabase/migrations/20261116120000_panel_admin.sql` con la tabla `observaciones` (`id`, `cliente_id`, `autor_id`, `texto`, `creada_en`) y verificar que el archivo se aplica sin error en una base limpia.
- [x] 1.2 Añadir RLS y políticas de select, insert, update y delete sobre `observaciones` que exijan `es_admin()`; verificar con una cuenta no administradora que lee cero filas y que el insert es rechazado.
- [x] 1.3 Extraer la validación y escritura compartida a `crear_cita_para(...)` y reescribir `reservar_cita()` para usarla; verificar que reservar como cliente sigue calculando precio, duración y rechazando solapes.
- [x] 1.4 Crear `reservar_cita_admin(p_cliente_id, p_mascota_id, p_empieza, p_servicios)` con comprobación `es_admin()`, cliente existente y mascota del cliente; verificar que una cuenta no administradora recibe rechazo.
- [x] 1.5 Crear `editar_cita_admin(p_cita_id, p_empieza, p_mascota_id, p_servicios, p_estado, p_notas)` que recalcule total y minutos y reemplace `cita_servicios`; verificar que cambiar servicios actualiza el total y que un horario ocupado devuelve `23P01`.
- [x] 1.6 Verificar que una cita se puede cancelar con un update de `estado` a `cancelada` y que no existe política de `delete` sobre `citas`.

## 2. Modelos y repositorios

- [x] 2.1 Crear `lib/features/admin/models/admin_summary.dart` con métricas, top de servicios y próximas citas; verificar con pruebas unitarias de cálculo, incluido el caso de cero citas cerradas.
- [x] 2.2 Crear `lib/features/admin/models/customer_entry.dart` y `admin_observation.dart`; verificar que un perfil sin nombre se representa como cliente sin nombre.
- [x] 2.3 Implementar `AnalyticsRepository` con `SampleAnalyticsRepository` y `SupabaseAnalyticsRepository`; verificar con pruebas que el porcentaje de no asistencia y los ingresos del mes se calculan sobre datos fijos.
- [x] 2.4 Implementar `AdminAppointmentRepository` (historial, editar, cancelar, crear) con sus versiones de muestra y Supabase; verificar que el mapa de error `23P01` se traduce a horario ocupado.
- [x] 2.5 Implementar `CustomerDirectoryRepository` (clientes y CRUD de observaciones) con sus versiones de muestra y Supabase; verificar que la muestra devuelve clientes ordenados por nombre.
- [x] 2.6 Añadir los `default*Repository()` que eligen Supabase o muestra según `AppConfig.hasSupabase`; verificar con una prueba sin credenciales que devuelven la implementación de muestra.

## 3. Contenedor y navegación

- [x] 3.1 Crear `AdminShellScreen` con `NavigationBar` de cuatro destinos e `IndexedStack`; verificar con una prueba de widget que cambiar de destino conserva el estado de la pestaña anterior.
- [x] 3.2 Integrar `AgendaScreen` como pestaña Agenda sin duplicar su carga ni su barra de día; verificar que la agenda del día sigue marcando asistencia.
- [x] 3.3 Cambiar `AdminSignInScreen` para navegar a `AdminShellScreen`; verificar con una prueba que una sesión válida abre el contenedor y que una cuenta sin permisos sigue mostrando el error.
- [x] 3.4 Añadir los botones de salir y el cierre de sesión en el contenedor; verificar que salir vuelve a la pantalla inicial.

## 4. Pestaña Resumen

- [x] 4.1 Construir la tarjeta de KPIs con citas de hoy y semana, ingresos, no asistencia y clientes nuevos; verificar con datos fijos que los cuatro valores coinciden con la prueba del repositorio.
- [x] 4.2 Construir el top 3 de servicios y la lista de próximas cinco citas con sus estados vacíos; verificar que sin datos aparece el mensaje y no una lista vacía.
- [x] 4.3 Añadir actualización por deslizamiento y estado de error con reintento; verificar con un repositorio falso que falla una vez y luego responde.

## 5. Pestaña Historial

- [x] 5.1 Construir la lista del historial con cliente, mascota, servicios, total y estado; verificar con citas pasadas, de hoy y futuras.
- [x] 5.2 Añadir los filtros Todas, Pasadas, Hoy y Futuras usando el reloj de Bogotá; verificar los límites de hoy y de una cita que empieza más tarde hoy.
- [x] 5.3 Añadir la hoja inferior de orden por fecha ascendente, descendente y estado sin perder el filtro activo; verificar con una prueba de widget.
- [x] 5.4 Añadir actualización por deslizamiento y error con reintento; verificar con un repositorio que falla.
- [x] 5.5 Implementar la edición de cita con hora, mascota, servicios, estado y nota; verificar que guardar llama a la función y refresca la fila.
- [x] 5.6 Implementar "Eliminar" como cancelación con confirmación; verificar que la cita queda en `cancelada` y sigue en el historial.
- [x] 5.7 Implementar el FAB de creación: búsqueda de cliente por nombre o teléfono, mascota opcional, servicios, día y hora libres; verificar que la cita aparece a nombre del cliente elegido.
- [x] 5.8 Verificar los errores de horario ocupado y de servicios inválidos con mensajes claros y sin perder el formulario.

## 6. Pestaña Clientes

- [x] 6.1 Construir la lista alfabética de clientes con nombre, teléfono y número de citas, excluyendo administradores; verificar el orden con tres nombres fijos.
- [x] 6.2 Construir el detalle del cliente con datos de contacto y sus citas; verificar que un cliente sin citas muestra el mensaje correspondiente.
- [x] 6.3 Implementar crear, editar y eliminar observaciones con autor y fecha; verificar que la observación aparece y persiste en el repositorio de muestra.
- [x] 6.4 Verificar que la pantalla del cliente no consulta ni muestra observaciones en ningún flujo de cliente.
- [x] 6.5 Añadir actualización por deslizamiento y error con reintento; verificar con un repositorio que falla.

## 7. Documentación y verificación

- [x] 7.1 Actualizar `supabase/README.md` con la migración nueva, la tabla `observaciones`, las funciones de admin y los pasos para crear y autorizar la cuenta `juanfe20132@gmail.com` sin guardar la contraseña.
- [x] 7.2 Generar `base.txt` con el esquema, RLS, funciones y seed actuales más el alta del administrador por correo; verificar que un SQL limpio lo ejecuta en orden sin errores.
- [x] 7.3 Ejecutar `flutter analyze` y corregir todos los avisos nuevos.
- [x] 7.4 Ejecutar `flutter test` y verificar que toda la suite pasa sin red.
- [x] 7.5 Probar el flujo completo en Supabase: login, cuatro pestañas, crear cita, editarla, cancelarla y crear una observación.
