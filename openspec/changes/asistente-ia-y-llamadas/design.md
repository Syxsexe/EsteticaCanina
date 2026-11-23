# Design

## Context

La motivación está en `proposal.md`. El estado actual que condiciona el diseño:

- La reserva normal llama a `reservar_cita_por_celular(nombre, telefono,
  mascota_nombre, empieza, servicios)`, que puede llamar `anon`, valida en la
  base y devuelve el id de la cita.
- `anon` puede leer `servicios`, `horario_atencion` y `cierres`, y ejecutar
  `horarios_ocupados(desde, hasta)`. No puede leer `citas`.
- La rejilla de reservas es de 45 minutos y empieza al abrir cada franja
  (`slotStep` en `lib/features/booking/models/schedule.dart`). El reloj de la
  estética es Bogotá, UTC-5 fijo.
- El proyecto no tiene ningún servidor propio, solo Supabase. Tampoco tiene
  la CLI de Supabase ni Deno instalados. Sí tiene Node 26, que ejecuta
  TypeScript.
- La API `generateContent` de Gemini sigue vigente. Con los modelos Gemini 3,
  la respuesta lleva `thoughtSignature`, y si al reenviar el historial falta,
  la petición falla (`MISSING_THOUGHT_SIGNATURE`).

## Goals / Non-Goals

**Goals:**

- La clave de la IA, solo en el servidor.
- Las reglas de la reserva (precio, duración, solapes y quién es el cliente)
  siguen en Postgres. La IA solo conversa y llama a las herramientas.
- Cambiar de proveedor es reescribir un único archivo.

**Non-Goals:**

- Guardar las conversaciones en la base.
- Límites de uso por IP o por usuario.
- Respuestas por streaming.
- Chat para la administradora.

## Decisions

### Una Edge Function con dos modos

`supabase/functions/asistente/index.ts` recibe `POST {modo, ...}`.

- **`modo: "cliente"`** recibe `{historial}`, el arreglo opaco que devolvió el
  turno anterior más el mensaje nuevo del cliente, y devuelve
  `{historial, texto}`. No exige sesión.
- **`modo: "resumen"`** exige `Authorization: Bearer <jwt>`. Comprueba
  `es_admin()` con un cliente de Supabase creado con ese JWT; si no es admin,
  responde 403 antes de llamar a la IA. Lee las citas de hoy a hoy + 7 con
  `agendaCampos` (el RLS deja verlas a la admin) y las cancelaciones y no
  asistencias de los últimos 7 días, y pide al modelo un parte breve. Devuelve
  `{texto}`.

Se descartaron dos funciones separadas: compartirían el cliente de IA y los
permisos, y en el panel de Supabase cada función es un despliegue más.

### El proveedor en un solo archivo

`modelo.ts` expone esta función:

```ts
conversar({ sistema, historial, herramientas }) => Promise<{ historial, llamadas, texto }>
```

`herramientas` es una lista `{nombre, descripcion, parametros}` en JSON
Schema. `llamadas` es una lista `{nombre, argumentos}`.

La implementación actual usa Gemini, con
`POST https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent`:

- la clave va en la cabecera `x-goog-api-key`, nunca en la URL, para que no
  aparezca en los registros;
- `systemInstruction`, `contents` y `tools: [{functionDeclarations}]`;
- el modelo sale de `GEMINI_MODEL`; por defecto, `gemini-3.8-flash`, que está
  en el plan gratuito.

El `historial` es el arreglo `contents` de Gemini. El servidor lo devuelve a
la app **tal como llegó**, con los `thoughtSignature`, y la app lo reenvía sin
tocarlo. Así no se pierde nada que Gemini exija.

`index.ts` no conoce ese formato salvo para añadir el mensaje del cliente y
los resultados de las herramientas, y lo hace con dos ayudantes que también
exporta `modelo.ts`: `mensajeUsuario(texto)` y
`resultadosHerramientas(resultados)`. Cambiar a Claude es reescribir esas tres
funciones.

### El ciclo de herramientas

En cada turno del cliente:

1. `conversar` devuelve una respuesta.
2. Si hay `llamadas`, se ejecutan todas, se añaden los resultados y se vuelve
   a llamar.
3. El ciclo se repite hasta **4 rondas** como máximo. Al llegar al tope, se
   responde "No pude completar eso; ¿lo intentamos de nuevo?".

Topes de la conversación:

- historial de **40 entradas** como máximo; al pasarlo, el servidor responde
  que se empiece de nuevo;
- mensaje del cliente de **1000 caracteres** como máximo, comprobado en la
  app y también en el servidor.

Herramientas, con parámetros en JSON Schema estricto:

- **`ver_servicios()`**: lee `servicios` activos y devuelve `id`, `nombre`,
  `precio_cop`, `minutos` y `es_extra`.
- **`ver_horarios_libres(fecha, servicios[])`**: suma los minutos de los
  servicios elegidos. Lee `horario_atencion` del día de la semana, `cierres` y
  `horarios_ocupados(fecha, fecha)`. Calcula en `horarios.ts` los comienzos
  libres en la rejilla de 45 minutos de cada franja: la cita entera tiene que
  caber antes del cierre, no pisar ninguna cita ocupada y no empezar antes de
  ahora, en Bogotá. Devuelve `["09:30", "10:15", ...]`, o
  `{cerrado: true}` / `{lleno: true}`.
- **`reservar(nombre, celular, mascota, fecha, hora, servicios[])`**:
  normaliza el celular a `+57` como `normalizarTelefono` de Dart. Llama a
  `reservar_cita_por_celular` con `fecha` + `hora` en hora de Bogotá
  convertida a UTC, y devuelve `{ok, total_cop, minutos}`, sumando los
  servicios leídos de la base, o `{error}` con el mensaje de Postgres (`23P01`
  se traduce a "horario tomado").

El prompt de sistema le exige al modelo:

- escribir en español y de forma breve;
- no inventar precios ni horarios, sino usar siempre las herramientas;
- resumir y pedir confirmación explícita antes de `reservar`;
- recibir "hoy es <fecha de Bogotá>", para que entienda "el jueves".

La fecha va al final del prompt, como mensaje de sistema propio del turno,
para no romper la caché del prompt.

### Permisos de la función

- El cliente de Supabase usa la **anon key** en el modo cliente, así que la
  función no puede hacer nada que la app no pudiera.
- El modo resumen usa **el JWT de quien llama**.
- No se usa la `service_role`.
- `verify_jwt` se desactiva para esta función, porque el modo cliente no
  tiene sesión. El modo resumen comprueba el JWT y `es_admin()` por su
  cuenta.

### Flutter

- `lib/features/assistant/`:
  - `AsistenteRepository` con `enviar(historial, texto)` y `resumen()`, con
    `SampleAsistenteRepository` (respuestas fijas para pruebas y para la app
    sin claves) y `SupabaseAsistenteRepository`
    (`Supabase.instance.client.functions.invoke('asistente', body: ...)`);
  - `AssistantScreen`: lista de burbujas, campo de texto con contador de
    1000, botón enviar e indicador "escribiendo…". Ante un error muestra "El
    asistente no está disponible ahora" y un botón a la reserva normal.
- El historial vive en el estado de la pantalla. Al salir se pierde, que es
  lo esperado.
- **Home:** un botón secundario "Agendar con el asistente", debajo de
  "Reservar cita".
- **Resumen:** un botón "Resumen con IA" arriba, que abre una hoja inferior
  con el texto, un indicador de carga y "Reintentar" si falla.
- **Detalle del cliente:**
  - un `IconButton` de teléfono junto a "Editar contacto", solo si hay
    celular, que llama a
    `launchUrl(Uri(scheme: 'tel', path: telefono))`;
  - si `launchUrl` devuelve `false`, muestra un `SnackBar` con el número.
  - Android 11+ necesita en el manifiesto
    `<queries><intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent></queries>`.

### Despliegue

Hay dos caminos:

- **Sin instalar nada:** en el panel de Supabase, *Edge Functions → Deploy a
  new function → Via Editor*, pegando los tres archivos.
- **Con la CLI:** `npx supabase functions deploy asistente --no-verify-jwt`.

El secreto se crea en *Edge Functions → Secrets* como `GEMINI_API_KEY`. La
clave se obtiene gratis en AI Studio.

## Risks / Trade-offs

- [El plan gratuito usa los datos para entrenar] → El asistente es solo para
  pruebas con datos inventados. Para producción hay que pasar a pago o a
  Claude reescribiendo `modelo.ts`. Queda documentado en `supabase/README.md`
  y en el aviso de la propuesta.
- [Cualquiera puede llamar al modo cliente y gastar la cuota gratuita] → Hay
  topes por conversación. La cuota gratuita tiene sus propios límites, así
  que lo peor es que el asistente quede "no disponible" un rato. Los límites
  por IP quedan para después.
- [El modelo puede equivocarse con los datos] → Nunca decide el precio ni
  valida el horario: todo lo comprueba la base al reservar.
- [La forma de la API de Gemini puede cambiar] → Todo lo que depende de ella
  está en `modelo.ts`.
- [No hay Deno ni CLI para probar la función aquí] → La lógica pura
  (`horarios.ts` y la normalización del celular) se prueba con `node --test`.
  El resto se prueba desplegada, con una llamada `curl` al modo cliente y al
  modo resumen.

## Migration Plan

1. Crear la clave en AI Studio y guardarla en Supabase como `GEMINI_API_KEY`.
2. Desplegar la función `asistente` sin verificación de JWT.
3. Probar por REST el modo cliente con un mensaje, y el modo resumen sin
   sesión, que debe dar 403.
4. Publicar la app. Sin la función desplegada, el asistente y el resumen
   muestran "no disponible" y el resto de la app funciona igual.
5. Rollback: borrar la función en el panel. La app degrada sola.
