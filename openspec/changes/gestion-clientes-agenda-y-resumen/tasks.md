# Tasks

## 1. Resumen: métricas acotadas al mes

- [x] 1.1 Renombrar el parámetro `mes` de `AdminSummary.fromData` a `citas`. Calcular los ingresos, la no asistencia y el top de servicios solo con las citas cuyo reloj de Bogotá cae en el mes de `hoy`. Verificar en `test/admin_summary_test.dart` con hoy martes 1 de diciembre de 2026, una cita cumplida de 40000 el 30 de noviembre y otra de 35000 el 1 de diciembre: los ingresos dan 35000 y la semana cuenta 2.
- [x] 1.2 Añadir pruebas para una cita no asistida y un servicio que solo existen en el mes vecino de la misma semana. Verificar que no afectan al porcentaje ni al top.
- [x] 1.3 Ajustar las llamadas de `SampleAnalyticsRepository` y `SupabaseAnalyticsRepository` al nuevo nombre. Verificar que `flutter test test/admin_summary_test.dart` pasa.

## 2. Refresco entre pestañas

- [x] 2.1 Exponer `recargar()` en los `State` de `AdminAnalyticsScreen`, `AgendaScreen` y `AdminHistoryScreen`, sin perder el día de la agenda ni el filtro y el orden del historial. Verificar con una prueba de widget que el Historial conserva el filtro Futuras tras recargar.
- [x] 2.2 En `AdminShellScreen`, llamar a `recargar()` de la pestaña que entra al cambiar de destino, usando `GlobalKey`. Verificar con una prueba que marca una cita como cumplida en Agenda, vuelve a Resumen y ve los ingresos actualizados.
- [x] 2.3 Verificar con una prueba que cancelar en Historial y volver a Agenda muestra la cita cancelada.

## 3. Botón "Nueva cita" en Agenda

- [x] 3.1 Añadir `diaInicial` a `AdminAppointmentFormScreen`. Al crear, abre en ese día o en hoy si ya pasó; al editar, sigue abriendo el día de la cita. Verificar con pruebas para un día futuro, un día pasado y una edición.
- [x] 3.2 Hacer que `AgendaScreen` embebida devuelva un `Scaffold` sin `AppBar` y con un botón flotante "Nueva cita", recibiendo los repositorios de citas, disponibilidad y clientes. El formulario abre con el día visible y la agenda recarga al guardar. Verificar con una prueba de widget que la cita nueva aparece en la agenda.
- [x] 3.3 Pasar los repositorios a la Agenda desde `AdminShellScreen` y quitar el botón flotante de `AdminHistoryScreen`. Mantener la edición desde el historial. Verificar con una prueba que Historial no muestra "Nueva cita".
- [x] 3.4 Mover la prueba `crear una cita usa el cliente elegido` de `test/admin_panel_test.dart` a la pestaña Agenda. Verificar que pasa.

## 4. Cancelación confirmada

- [x] 4.1 En `SupabaseAdminAppointmentRepository.cancelar`, pedir la fila con `.select('id')` y lanzar un error si vuelve vacía. Verificar con una prueba de widget, usando un repositorio falso que lanza ese error, que la cita conserva su estado y se muestra el error.

## 5. Base de datos

- [x] 5.1 Crear `supabase/migrations/20261123120000_gestion_clientes.sql` con las políticas de `update` del administrador sobre `perfiles` y de `insert`/`update` sobre `mascotas`. Verificar en el SQL Editor que una cuenta administradora actualiza un perfil ajeno y una cuenta de cliente no.
- [x] 5.2 En la misma migración, crear `notas_mascota` con RLS y políticas de select, insert y update que exijan `es_admin()`, copiar las `mascotas.notas` no vacías y borrar la columna. Verificar con una cuenta de cliente que `notas_mascota` devuelve cero filas y que el insert es rechazado.
- [ ] 5.3 Actualizar `supabase/reset.sql` para borrar `notas_mascota` y `base.txt` con el esquema resultante. Verificar que `reset.sql`, las migraciones en orden y `seed.sql` se ejecutan sin error en una base limpia.
- [x] 5.4 Documentar en `supabase/README.md` la tabla `notas_mascota`, las políticas nuevas, la eliminación de `mascotas.notas` y el respaldo previo. Verificar que los pasos documentados coinciden con la migración.

## 6. Datos de clientes y mascotas

- [x] 6.1 Crear `PetRecord` y `PetNote` en `lib/features/admin/models/`. Verificar con una prueba unitaria que los campos vacíos se presentan como no registrados.
- [x] 6.2 Añadir a `CustomerDirectoryRepository` los métodos `mascotasDe`, `guardarMascota`, `guardarNotaMascota` y `actualizarContacto`, en sus versiones de muestra y Supabase. Mostrar las fechas con `enHoraEstetica`. Verificar con pruebas sobre la muestra que registrar, editar y anotar una mascota persiste y que el contacto actualizado aparece en `clientes()`.
- [x] 6.3 Añadir `historialDe(clienteId)` a `AdminAppointmentRepository`, en sus versiones de muestra y Supabase con `.eq('cliente_id', ...)`. Verificar con una prueba que solo devuelve citas de ese cliente.

## 7. Pantalla de cliente

- [x] 7.1 En `AdminCustomerDetailScreen`, usar `historialDe` y mostrar la sección Mascotas con nombre, raza, edad, peso y nota interna. Verificar con pruebas de widget para un cliente con mascotas y otro sin ellas.
- [x] 7.2 Añadir el formulario de contacto con nombre obligatorio y teléfono validado con `normalizarTelefono`. Verificar que un teléfono inválido no se guarda y que uno válido actualiza el detalle y la lista.
- [x] 7.3 Añadir el formulario de mascota para crear y editar, sin acción de borrar, que valide nombre, edad entre 0 y 30 y peso mayor que 0. Verificar que los datos fuera de rango no se guardan y que la mascota nueva aparece en el detalle.
- [x] 7.4 Añadir la edición de la nota interna de cada mascota, mostrando autor y fecha. Verificar con una prueba que la nota guardada aparece en la ficha.
- [x] 7.5 Añadir el botón "Nueva cita" en el detalle, que abre el formulario con el cliente preseleccionado y recarga las citas al guardar. Verificar con una prueba que la cita creada aparece en el detalle.

## 8. Verificación integrada

- [x] 8.1 Ejecutar `flutter analyze` y verificar que no hay avisos nuevos.
- [x] 8.2 Ejecutar `flutter test` y verificar que toda la suite pasa sin red.
- [x] 8.3 Probar contra Supabase este flujo: marcar asistencia y ver el Resumen actualizado, crear una cita desde Agenda y desde un cliente, corregir el teléfono, registrar una mascota y escribirle una nota. Después, con la sesión de ese cliente, verificar que no ve la nota y que al reservar se conservan sus datos corregidos.

## 9. Clientes por celular y paso 3

- [x] 9.1 Crear `supabase/migrations/20261124120000_clientes_por_celular.sql`: quitar `perfiles_id_fkey`, dar a `perfiles.id` el `default gen_random_uuid()` y crear `reservar_cita_por_celular`. La función valida, busca o crea el perfil y la mascota, y llama a `crear_cita_para`; lleva `revoke` de `public` y `grant` a `anon, authenticated`. Verificar con la anon key por REST: un celular inválido se rechaza sin crear nada, una reserva válida devuelve el id de la cita, y repetirla con el mismo celular y la misma mascota no crea otro perfil ni otra mascota.
- [x] 9.2 Actualizar `supabase/reset.sql` (borrar la función), `base.txt` (FK, default y función) y `supabase/README.md` (clientes sin cuenta, la función, sus riesgos y el orden de publicación). Verificar que los pasos documentados coinciden con la migración.
- [x] 9.3 Añadir `ClienteReserva` y cambiar `BookingRepository.reservar(booking, cliente)`, en sus versiones de muestra y Supabase, para que llame a `reservar_cita_por_celular` sin `asegurarSesion` y traduzca `23P01` a `SlotTakenException`. Verificar con una prueba sobre la muestra que el cliente llega al repositorio.
- [x] 9.4 Crear el paso 3, `IdentificationScreen`, con nombre, celular y mascota obligatorios, y hacer que `ScheduleSelectionScreen` navegue a él en vez de reservar. Quitar la hoja de contacto y `ProfileRepository` si quedan sin uso. Verificar con pruebas de widget: datos inválidos no reservan; datos válidos llegan a la confirmación; un horario tomado vuelve al paso 2; volver atrás no reserva.
- [x] 9.5 Añadir `crearPorCelular` a `AdminAppointmentRepository`, en sus versiones de muestra y Supabase, y la opción "Cliente nuevo" en `AdminAppointmentFormScreen`, con los tres campos obligatorios. Verificar con pruebas que la muestra reutiliza al cliente si el celular existe, que crea cliente y mascota si no, y que los datos incompletos no guardan.
- [x] 9.6 Actualizar los textos del inicio que dicen "dos pasos" y `AGENTS.md`, que describe el flujo de reserva y la sesión anónima. Verificar que no quedan referencias al flujo de dos pasos.
- [x] 9.7 Ejecutar `flutter analyze` y `flutter test` y verificar que no hay avisos nuevos y que toda la suite pasa sin red.
- [x] 9.8 Probar contra Supabase:
  - reservar desde un navegador sin sesión y comprobar que no se crea ningún usuario en `auth.users`;
  - reservar con la sesión de admin abierta y comprobar que la cita queda a nombre del celular;
  - repetir con el mismo celular y comprobar que no se crea otro cliente;
  - crear un "Cliente nuevo" desde Agenda y comprobar que aparece en Clientes con su mascota;
  - con un horario ocupado, comprobar que no queda ningún cliente huérfano.

## Workflow follow-up

- Archivar `panel-estadisticas-admin` antes de archivar este cambio, porque este modifica sus requisitos.
