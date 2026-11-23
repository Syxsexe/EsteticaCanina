# Spec Delta

## ADDED Requirements

### Requirement: Foto de la mascota en su ficha

Cada mascota SHALL poder tener una sola foto. La ficha de la mascota en el detalle del cliente SHALL mostrar la foto si existe y un marcador sin foto si no.

#### Scenario: Mascota con foto

- **GIVEN** Toby tiene foto
- **WHEN** el administrador abre el detalle de Ana
- **THEN** la ficha de Toby muestra su foto

#### Scenario: Mascota sin foto

- **WHEN** una mascota no tiene foto
- **THEN** su ficha muestra un marcador sin foto y la opción de añadir una

#### Scenario: La foto no carga

- **WHEN** falla la descarga de una foto
- **THEN** la ficha muestra el marcador sin foto y el resto del detalle funciona

### Requirement: Ver la foto ampliada

Al tocar la miniatura de una mascota con foto, la app SHALL abrir la foto a pantalla completa, donde SHALL poder ampliarse con el gesto de pellizcar o con doble toque. Desde esa vista SHALL poder cambiarse o quitarse la foto. Al tocar la miniatura de una mascota sin foto, SHALL abrir directamente la opción de elegir una.

#### Scenario: Abrir la foto

- **GIVEN** Toby tiene foto
- **WHEN** el administrador toca su miniatura
- **THEN** la foto se abre a pantalla completa con el nombre de Toby

#### Scenario: Ampliar con doble toque

- **WHEN** el administrador hace doble toque sobre la foto abierta
- **THEN** la foto se amplía, y otro doble toque la devuelve a su tamaño

#### Scenario: Cambiar desde la foto abierta

- **WHEN** el administrador toca "Cambiar foto" en la vista ampliada y elige otra imagen
- **THEN** la vista se cierra y la ficha muestra la foto nueva

#### Scenario: Mascota sin foto

- **WHEN** el administrador toca la miniatura de una mascota sin foto
- **THEN** se ofrece elegir una foto, sin vista ampliada

### Requirement: Añadir o cambiar la foto

El administrador SHALL poder elegir una imagen del equipo para la foto de una mascota. Antes de guardarla, la app SHALL reducirla a un máximo de 1280 px por lado y convertirla a WebP. Si la mascota ya tenía foto, la nueva SHALL reemplazarla y la anterior SHALL borrarse.

#### Scenario: Añadir una foto JPG

- **WHEN** el administrador elige una foto JPG de 4000 x 3000 para Toby
- **THEN** se guarda una imagen WebP de 1280 x 960 y la ficha la muestra

#### Scenario: Cambiar la foto

- **GIVEN** Toby ya tiene foto
- **WHEN** el administrador elige otra
- **THEN** la ficha muestra la nueva y la anterior deja de existir en el almacenamiento

#### Scenario: Cancelar la elección

- **WHEN** el administrador abre el selector y lo cierra sin elegir
- **THEN** la foto no cambia

#### Scenario: Archivo que no es una imagen legible

- **WHEN** el archivo elegido no se puede leer como imagen
- **THEN** la app avisa que no pudo usar ese archivo y la foto no cambia

#### Scenario: Navegador que no genera WebP

- **WHEN** el administrador elige una foto desde un navegador que no sabe generar WebP
- **THEN** la app avisa que use Chrome, Edge o Firefox, y no sube nada

#### Scenario: Fallo al subir

- **WHEN** la subida falla por red o por permisos
- **THEN** la app muestra un error y la mascota conserva la foto que tenía

### Requirement: Quitar la foto

El administrador SHALL poder quitar la foto de una mascota. Al quitarla, la imagen SHALL borrarse del almacenamiento.

#### Scenario: Quitar la foto

- **GIVEN** Toby tiene foto
- **WHEN** el administrador elige "Quitar foto" y confirma
- **THEN** la ficha muestra el marcador sin foto y la imagen ya no está en el almacenamiento

### Requirement: Solo WebP y solo la administradora

El almacenamiento de fotos SHALL ser privado, SHALL aceptar únicamente archivos `image/webp` y SHALL permitir leer, subir y borrar solo a cuentas administradoras. La comprobación SHALL hacerla Supabase, no solo la app.

#### Scenario: Subir un formato que no es WebP

- **WHEN** alguien intenta guardar directamente un archivo `image/jpeg` en el almacenamiento de fotos
- **THEN** el almacenamiento lo rechaza

#### Scenario: Cuenta sin permisos

- **WHEN** una llamada sin sesión de administradora intenta leer o subir una foto
- **THEN** el almacenamiento la rechaza

### Requirement: Eliminar un cliente borra sus fotos

Al eliminar un cliente, las fotos de sus mascotas SHALL borrarse del almacenamiento.

#### Scenario: Cliente con mascotas con foto

- **GIVEN** Luis tiene dos mascotas con foto
- **WHEN** el administrador elimina a Luis
- **THEN** las dos fotos dejan de existir en el almacenamiento
