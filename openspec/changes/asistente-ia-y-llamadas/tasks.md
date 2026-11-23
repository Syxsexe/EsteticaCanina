# Tasks

## 1. Llamar al cliente

- [x] 1.1 Declarar `url_launcher` en `pubspec.yaml` y añadir al `AndroidManifest.xml` la consulta del intent `DIAL` con esquema `tel`. Verificar que `flutter pub get` resuelve y que el APK compila.
- [x] 1.2 Añadir en el detalle del cliente el botón "Llamar", visible solo si hay celular, que abre `tel:` y, si no puede, muestra el número en un `SnackBar`. Verificar con pruebas de widget que el botón aparece con celular y no sin él.

## 2. Edge Function

- [x] 2.1 Crear `supabase/functions/asistente/horarios.ts`: comienzos libres en la rejilla de 45 minutos, cupo hasta el cierre, sin solapes y sin horas pasadas en Bogotá, más la normalización del celular. Verificar con `node --test`:
  - un día con una cita ocupada;
  - un servicio de 2 h al final de la franja;
  - un día cerrado;
  - hoy con horas ya pasadas;
  - celulares válidos e inválidos.
- [x] 2.2 Crear `modelo.ts` con `conversar`, `mensajeUsuario` y `resultadosHerramientas` para Gemini `generateContent`: clave en la cabecera, modelo por `GEMINI_MODEL` y el historial devuelto tal cual. Verificar con la llamada real del grupo 4.
- [x] 2.3 Crear `index.ts`:
  - el modo cliente, con las herramientas `ver_servicios`, `ver_horarios_libres` y `reservar`, el ciclo de hasta 4 rondas, los topes de historial y de mensaje, y el prompt de sistema con la fecha de Bogotá;
  - el modo resumen, con la comprobación de `es_admin()` y su 403;
  - CORS para web.

  Verificar con la llamada real del grupo 4.

## 3. App

- [x] 3.1 Crear `AsistenteRepository` con sus versiones de muestra y Supabase (`functions.invoke`). Verificar con una prueba sobre la muestra que devuelve historial y texto.
- [x] 3.2 Crear `AssistantScreen` (burbujas, contador de 1000, indicador "escribiendo…", error con acceso a la reserva normal) y la entrada "Agendar con el asistente" en el inicio. Verificar con pruebas de widget:
  - enviar muestra la respuesta;
  - más de 1000 caracteres no se envía;
  - un error muestra la salida a la reserva normal.
- [x] 3.3 Añadir "Resumen con IA" en la pestaña Resumen, con una hoja inferior, carga y "Reintentar". Verificar con una prueba de widget que muestra el texto, y el error y su reintento.

## 4. Despliegue y documentación

- [x] 4.1 Documentar en `supabase/README.md` y `AGENTS.md`:
  - cómo desplegar la función (panel o `npx supabase`, sin verificación de JWT);
  - el secreto `GEMINI_API_KEY`;
  - el aviso de datos del plan gratuito;
  - cómo cambiar de proveedor.

  Verificar que los pasos coinciden con el código.
- [x] 4.2 Ejecutar `flutter analyze` y `flutter test` y verificar que no hay avisos nuevos y que la suite pasa sin red.
- [x] 4.3 Con la función desplegada y la clave puesta, probar por REST:
  - el modo cliente con "¿cuánto cuesta un baño?", que debe responder con el precio real;
  - el modo resumen sin sesión, que debe dar 403.

  Probar en la app:
  - una reserva completa con datos inventados;
  - el resumen como admin;
  - la llamada en Android.

## 5. Ajustes tras la primera prueba

- [x] 5.1 Decir que la estética está en Pasto, no en Bogotá. Verificado preguntando al asistente desplegado.
- [x] 5.2 Botón "Reintentar" en el chat, que reenvía el mensaje fallido sin salir. Verificado con una prueba de widget.
- [x] 5.3 Resumen con citas agrupadas por día y fechas en palabras, sin año, y texto plano. Verificado que las fechas de 2024 a 2030 no existen en la base (`horarios_ocupados` entre 2024 y 2031 solo devuelve noviembre y diciembre de 2026).
- [x] 5.4 Límite de 90 días: crear `20261128120000_limite_agenda.sql` (`crear_cita_para`), la herramienta del asistente y `base.txt`. Verificar por REST, tras aplicar la migración, que una reserva a más de 90 días es rechazada; en el asistente ya se verificó que no ofrece la fecha.

## 6. Seguridad ante inyección

- [x] 6.1 SQL: revisado que no hay SQL dinámico (`execute` con datos) ni filtros PostgREST armados con texto, y que toda función `security definer` fija `search_path`. Sin cambios.
- [x] 6.2 Historial: `historialValido` en `modelo.ts` (roles `user`/`model`, solo las partes que produce el servidor) y tope de 200 KB; servicios por llamada, máximo 10. Verificado en vivo: rol `system` y `fileData` dan 400, y una conversación de dos turnos con herramientas sigue funcionando.
- [x] 6.3 Prompts: el asistente declina cambiar de papel o mostrar sus instrucciones (verificado en vivo). En el resumen, los nombres pasan por `textoSeguro` y van dentro de `<datos>`, marcados como registros. Pruebas: `horarios.test.ts` (10) y `modelo.test.ts` (2).

## Workflow follow-up

- Archivar después de `panel-estadisticas-admin`, `gestion-clientes-agenda-y-resumen`, `resumen-por-mes`, `eliminar-cliente` y `foto-mascota`.
