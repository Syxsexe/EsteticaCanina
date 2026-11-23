# Proposal

## Why

La estética reconoce a los perros por la cara, no por el nombre. La ficha de
la mascota en el panel solo tiene texto, así que, cuando llegan dos "Toby",
la estilista no tiene cómo saber cuál es cuál antes de verlos.

## What Changes

- En el detalle del cliente, cada mascota puede tener **una foto**. La
  administradora puede añadirla, cambiarla o quitarla.
- La foto se elige de la galería o de los archivos del equipo, en cualquier
  formato que el equipo sepa leer: JPG, PNG, HEIC, GIF (se usa el primer
  cuadro), WebP, etc.
- Antes de subirla, la app la reduce a un máximo de 1280 px por lado y la
  convierte a **WebP**. Lo que se guarda y lo que se muestra es siempre WebP.
- Las fotos van a un bucket **privado** de Supabase Storage que solo acepta
  `image/webp` y solo la administradora puede leer o escribir.
- Plataformas: Android y navegador web.
  - En web, la conversión depende del navegador. Si el navegador no sabe
    generar WebP (Safari), la app avisa y no sube nada.
- Eliminar un cliente también borra las fotos de sus mascotas.
- **Dependencias nuevas**: `image_picker` y `flutter_image_compress`.
- Fuera de alcance:
  - varias fotos por mascota;
  - recortar o editar la foto;
  - tomar la foto con la cámara desde web;
  - que el cliente vea la foto;
  - iOS.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `admin-customer-directory`: foto de la mascota en su ficha, y borrado de
  fotos al eliminar un cliente. La capacidad nace en
  `panel-estadisticas-admin` y la amplían `gestion-clientes-agenda-y-resumen`
  y `eliminar-cliente`, ninguno archivado. Este cambio se archiva después.

## Impact

- `pubspec.yaml`: `image_picker` y `flutter_image_compress`.
- `web/index.html`: el script que necesita `flutter_image_compress` en web,
  si su versión lo exige.
- `supabase/migrations/`: una migración con la columna `mascotas.foto_path`,
  el bucket `fotos-mascotas` y sus políticas de Storage. También se
  actualizan `reset.sql`, `base.txt` y `supabase/README.md`.
- `lib/features/admin/`:
  - el modelo `PetRecord`;
  - `CustomerDirectoryRepository` (subir, leer y quitar la foto);
  - un servicio de selección y conversión de imagen;
  - la ficha de mascota en `AdminCustomerDetailScreen`;
  - el flujo de eliminar cliente.
- Pruebas sin red y sin plugins, con el selector y el conversor sustituidos
  por falsos.
