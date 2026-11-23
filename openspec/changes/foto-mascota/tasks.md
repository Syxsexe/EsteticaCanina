# Tasks

## 1. Base de datos y almacenamiento

- [x] 1.1 Crear `supabase/migrations/20261127120000_foto_mascota.sql` con:
  - la columna `mascotas.foto_path`;
  - el bucket privado `fotos-mascotas`, que solo admita `image/webp` y 2 MB;
  - políticas `select`, `insert`, `update` y `delete` en `storage.objects` para ese bucket con `es_admin()`.

  Verificar por REST con la anon key que subir al bucket es rechazado y que listarlo no devuelve objetos.
- [x] 1.2 Actualizar `supabase/reset.sql`, `base.txt` y `supabase/README.md` (bucket, políticas y cómo vaciarlo al reiniciar). Verificar que lo documentado coincide con la migración.

## 2. Dependencias y conversión

- [x] 2.1 Añadir `image_picker` y `flutter_image_compress` con `flutter pub add`, y el script de web si el README del paquete lo exige. Verificar que `flutter pub get` resuelve y que la app compila para web.
- [x] 2.2 Crear `FotoMascotaService` con su implementación real (`elegir`, `aWebp` con cálculo del tamaño destino y comprobación de la cabecera WebP) y las excepciones `ArchivoNoLegibleException` y `WebpNoDisponibleException`. Verificar con pruebas unitarias:
  - la función pura de tamaño destino: 4000 x 3000 da 1280 x 960, 800 x 600 se queda igual, y en vertical 3000 x 4000 da 960 x 1280;
  - la detección de la cabecera WebP.

## 3. Repositorio

- [x] 3.1 Añadir `fotoPath` a `PetRecord` y pedir `foto_path` en `mascotasDe`. Añadir `guardarFotoMascota`, `quitarFotoMascota` y `fotoDe` en sus versiones de muestra y Supabase, con el orden subir, apuntar y borrar la anterior. Verificar con pruebas sobre la muestra que cambiar la foto deja solo la nueva y que quitarla la borra.
- [x] 3.2 Hacer que `eliminarCliente` en Supabase borre las fotos de sus mascotas después del RPC, y la muestra igual. Verificar con una prueba sobre la muestra que no queda ninguna foto del cliente.

## 4. Pantalla

- [x] 4.1 Añadir a `_FichaMascota` la miniatura (o el marcador) con la hoja "Elegir/Cambiar foto" y "Quitar foto". Mostrar progreso y los tres mensajes de error, guardar los bytes descargados por ruta e inyectar `FotoMascotaService` en el detalle. Verificar con pruebas de widget y un servicio falso:
  - añadir una foto la muestra;
  - cancelar no cambia nada;
  - un archivo ilegible avisa;
  - el navegador sin WebP avisa;
  - quitar la foto vuelve al marcador.

- [x] 4.2 Al tocar la miniatura con foto, abrir una vista a pantalla completa con `InteractiveViewer` (pellizcar y doble toque para ampliar) y los botones "Cambiar foto" y "Quitar foto". Sin foto, ofrecer elegir una. Verificar con pruebas de widget:
  - tocar abre la vista con el nombre;
  - el doble toque amplía y vuelve;
  - "Cambiar foto" desde la vista guarda la nueva;
  - "Quitar foto" desde la vista vuelve a la huella.

## 5. Verificación integrada

- [x] 5.1 Ejecutar `flutter analyze` y `flutter test` y verificar que no hay avisos nuevos y que toda la suite pasa sin red.
- [ ] 5.2 Probar contra Supabase en Android y en Chrome:
  - subir una foto JPG grande y comprobar en el panel de Storage que se guardó un `.webp` de 1280 px como máximo;
  - cambiarla y comprobar que la anterior desapareció;
  - quitarla;
  - eliminar un cliente con foto y comprobar que su foto se borró.

## Workflow follow-up

- Archivar después de `panel-estadisticas-admin`, `gestion-clientes-agenda-y-resumen` y `eliminar-cliente`.
