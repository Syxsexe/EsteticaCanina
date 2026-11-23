# Design

## Context

La motivación está en `proposal.md`. El estado actual que condiciona el diseño:

- `PetRecord` y `CustomerDirectoryRepository` ya cargan la ficha de cada
  mascota (`mascotasDe`) y la guardan (`guardarMascota`).
  `AdminCustomerDetailScreen` la pinta con `_FichaMascota`.
- La app no usa Supabase Storage ni ningún paquete de imágenes. Las pruebas
  corren sin red y sin plugins nativos.
- El tutor puede leer las filas de sus mascotas (RLS por fila). Un dato en
  `mascotas` es visible para él; un objeto en un bucket privado no lo es.
- Supabase no deja borrar objetos de Storage con un `delete` sobre
  `storage.objects` desde SQL: hay que usar la API de Storage. Por eso
  `eliminar_cliente_admin` no puede borrar las fotos por sí sola.
- El paquete `image` de Dart lee WebP pero no lo escribe.
  `flutter_image_compress` sí lo escribe: en Android con el códec nativo, y en
  web con el `canvas` del navegador. Safari no genera WebP con `canvas`.

## Goals / Non-Goals

**Goals:**

- Que en el almacenamiento solo haya WebP, garantizado por Supabase y no solo
  por la app.
- Fotos privadas, solo para la administradora.
- Pruebas que no dependan de plugins.

**Non-Goals:**

- Varias fotos, recorte, edición o cámara en web.
- Mostrar la foto al cliente.
- iOS.

## Decisions

### Almacenamiento: bucket privado que solo acepta WebP

La migración crea el bucket insertando en `storage.buckets`:

- `id = 'fotos-mascotas'`;
- `public = false`;
- `allowed_mime_types = '{image/webp}'`;
- `file_size_limit = 2097152`, es decir, 2 MB. Una foto de 1280 px en WebP
  pesa entre 100 y 300 KB.

Las políticas sobre `storage.objects` para ese bucket (`select`, `insert`,
`update` y `delete`) exigen `public.es_admin()`.

Con esto, aunque alguien salte la app, Supabase rechaza cualquier archivo que
no sea `image/webp` y a cualquier cuenta que no sea administradora.

### Dónde se apunta la foto: `mascotas.foto_path`

Es una columna de texto nula. Guarda la ruta del objeto,
`<mascota_id>/<marca de tiempo>.webp`.

- El tutor podría leer la ruta, pero no el objeto: el bucket es privado.
- Se descartó una tabla aparte como `notas_mascota`, porque la ruta no
  revela nada.
- El nombre cambia con cada foto nueva, así que nunca se sirve una imagen
  vieja desde una caché.

### Conversión en la app, detrás de una interfaz

`FotoMascotaService` (`lib/features/admin/data/foto_mascota_service.dart`)
tiene dos métodos:

- `Future<Uint8List?> elegir()` abre el selector de `image_picker` (galería
  en Android, diálogo de archivos en web) y devuelve los bytes originales, o
  nulo si se cancela.
- `Future<Uint8List> aWebp(Uint8List original)` hace la conversión en tres
  pasos:
  1. Lee las dimensiones con `ui.instantiateImageCodec`. Si no puede, lanza
     `ArchivoNoLegibleException`.
  2. Calcula el tamaño destino, con el lado mayor a 1280 px como máximo y sin
     agrandar nunca. Se pasa ese tamaño como `minWidth` y `minHeight` a
     `FlutterImageCompress.compressWithList(format: CompressFormat.webp,
     quality: 80)`. Así se evita la semántica de "mínimo" del paquete, que
     con 1280 x 1280 dejaría 1707 x 1280.
  3. Comprueba que el resultado empiece por `RIFF....WEBP`. Si no, lanza
     `WebpNoDisponibleException`. Es lo que pasa en Safari, que devuelve PNG
     o JPEG.

`defaultFotoMascotaService()` devuelve la implementación real. Las pruebas
inyectan una falsa que devuelve bytes fijos y puede lanzar las dos
excepciones.

Se descartó convertir en una Edge Function: el usuario eligió conversión en
la app.

### Repositorio

`CustomerDirectoryRepository` gana tres métodos.

- **`guardarFotoMascota(PetRecord mascota, Uint8List webp)`**:
  1. Sube la foto a `fotos-mascotas/<id>/<ms>.webp` con
     `contentType: 'image/webp'`.
  2. Actualiza `mascotas.foto_path`. Si este paso falla, borra el objeto
     recién subido.
  3. Borra la foto anterior. Si este borrado falla, solo deja un archivo
     huérfano, no un dato incoherente.
  4. Devuelve la mascota actualizada.
- **`quitarFotoMascota(PetRecord mascota)`**: pone `foto_path` a nulo y
  después borra el objeto.
- **`fotoDe(String path)`**: devuelve un `Future<Uint8List>` descargado con
  `storage.from(...).download(path)`.

`mascotasDe` pide también `foto_path`, y `PetRecord` gana `fotoPath`.

La versión de muestra guarda los bytes en un mapa en memoria.

Se descargan los bytes en vez de usar una URL firmada para no depender de
CORS ni de la caducidad, y porque `Image.memory` se prueba sin red.

### Pantalla

`_FichaMascota` muestra a la izquierda una miniatura de 64 x 64. Si la foto
no existe o falla, muestra un marcador con la huella. Al tocarla se abre una
hoja con estas opciones:

- **"Elegir foto"** (o "Cambiar foto"):
  1. Llama a `elegir()`, después a `aWebp()` y después a
     `guardarFotoMascota()`.
  2. Mientras tanto, la miniatura muestra un indicador de progreso.
  3. Los errores se muestran con `SnackBar`:
     - `ArchivoNoLegibleException`: "No pudimos usar ese archivo como
       imagen."
     - `WebpNoDisponibleException`: "Este navegador no puede convertir
       fotos. Usa Chrome, Edge o Firefox."
     - Cualquier otro: "No se pudo guardar la foto."
- **"Quitar foto"**, solo si hay foto: pide confirmación y llama a
  `quitarFotoMascota()`.

Las fotos descargadas se guardan en un mapa `path -> bytes` del estado, para
no volver a pedirlas en cada recarga del detalle.

`AdminCustomerDetailScreen` recibe `FotoMascotaService?` para poder
inyectarlo en las pruebas.

### Eliminar cliente

Antes de llamar a `eliminar_cliente_admin`, la versión Supabase de
`eliminarCliente` lee los `foto_path` de las mascotas del cliente. Si el RPC
sale bien, borra esos objetos con `storage.remove(paths)`.

- Si el RPC falla, no se borra ninguna foto.
- Si el borrado de fotos falla, el cliente ya está anonimizado y quedan
  archivos huérfanos, que no son visibles para nadie salvo la admin.

### Web

`flutter_image_compress` en web puede necesitar un `<script>` en
`web/index.html`. Se añade solo si el README de la versión instalada lo pide.
`image_picker` en web no necesita configuración. En Android 13 o superior usa
el selector de fotos del sistema y no pide permisos.

## Risks / Trade-offs

- [Safari no convierte] → Se detecta por los bytes y se avisa. La admin usa
  Android o Chrome.
- [HEIC en web] → Solo Safari lo decodifica, así que en Chrome sale
  "No pudimos usar ese archivo". En Android sí funciona.
- [Fotos huérfanas si falla un borrado] → No exponen datos: el bucket es
  privado. Se pueden limpiar desde el panel de Supabase.
- [Dos dependencias nuevas con plugins nativos] → Son paquetes muy usados y
  mantenidos. Las pruebas no dependen de ellos gracias a la interfaz.
- [GIF animado] → Se guarda solo el primer cuadro.

## Migration Plan

1. Aplicar `supabase/migrations/20261127120000_foto_mascota.sql`, que crea la
   columna, el bucket y las políticas.
2. Verificar por REST con la anon key:
   - subir un objeto a `fotos-mascotas` es rechazado;
   - listar el bucket no devuelve nada.
3. `flutter pub get` y compilar para Android y web.
4. Rollback: borrar las políticas, vaciar el bucket desde el panel, borrar el
   bucket y la columna.
