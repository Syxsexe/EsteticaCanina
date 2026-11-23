# Spec Delta

## Purpose

Da a la estética un directorio de sus clientes con datos de contacto, historial de citas y observaciones privadas que solo el administrador puede gestionar.

## ADDED Requirements

### Requirement: Lista de clientes por nombre del tutor

El directorio SHALL listar los perfiles de cliente ordenados alfabéticamente por nombre del tutor, mostrando nombre, teléfono y número de citas. Las cuentas administradoras SHALL quedar fuera de la lista.

#### Scenario: Orden alfabético

- **WHEN** existen clientes Ana, Luis y Camila
- **THEN** la lista aparece Camila, Luis, Ana

#### Scenario: Cliente sin nombre

- **WHEN** un perfil todavía no tiene nombre
- **THEN** aparece como cliente sin nombre y conserva su teléfono si lo tiene

#### Scenario: Sin clientes

- **WHEN** no hay perfiles de cliente
- **THEN** el directorio muestra un mensaje que lo explica

### Requirement: Detalle del cliente

Al elegir un cliente, el directorio SHALL mostrar sus datos de contacto, sus citas y sus observaciones.

#### Scenario: Abrir un cliente

- **WHEN** el administrador toca un cliente de la lista
- **THEN** ve su nombre, teléfono, citas y observaciones

#### Scenario: Cliente sin citas

- **WHEN** el cliente no tiene citas
- **THEN** el detalle lo indica y sigue mostrando sus datos de contacto

### Requirement: Observaciones exclusivas del administrador

Las observaciones SHALL crearse, leerse, editarse y eliminarse solo por cuentas administradoras. Cada observación SHALL guardar su autor y su fecha. Ningún cliente SHALL poder leer ni escribir observaciones.

#### Scenario: Crear una observación

- **WHEN** un administrador escribe una observación sobre un cliente y guarda
- **THEN** la observación aparece en el detalle del cliente con autor y fecha

#### Scenario: Editar una observación

- **WHEN** un administrador cambia el texto de una observación
- **THEN** el detalle muestra el texto nuevo y conserva la fecha de creación

#### Scenario: Cliente intenta leer observaciones

- **WHEN** el tutor de ese cliente consulta sus datos desde la app de clientes
- **THEN** la base no le devuelve ninguna observación

#### Scenario: Cuenta sin permisos intenta escribir

- **WHEN** una cuenta que no es administradora intenta crear una observación
- **THEN** la base rechaza la escritura

### Requirement: Actualización del directorio

El directorio y el detalle SHALL actualizarse al deslizar hacia abajo y SHALL mostrar un error con opción de reintentar cuando la consulta falla.

#### Scenario: Fallo al cargar clientes

- **WHEN** la consulta de perfiles falla
- **THEN** se muestra un mensaje de error con un botón para reintentar

#### Scenario: Actualización manual

- **WHEN** el administrador desliza la lista hacia abajo
- **THEN** los clientes y sus conteos se consultan de nuevo
