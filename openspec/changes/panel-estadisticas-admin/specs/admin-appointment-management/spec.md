# Spec Delta

## Purpose

Permite a la estética consultar todas sus citas, ordenarlas y filtrarlas, corregir sus datos, cancelarlas y crear citas en nombre de un cliente registrado.

## ADDED Requirements

### Requirement: Historial completo de citas

El historial SHALL mostrar todas las citas de la estética, incluidas pasadas y futuras, con fecha, hora, cliente, mascota, servicios, total y estado.

#### Scenario: Historial con citas de varias fechas

- **WHEN** un administrador abre la pestaña Historial
- **THEN** ve las citas de días pasados, de hoy y de días futuros con su estado

#### Scenario: Historial sin citas

- **WHEN** no existe ninguna cita
- **THEN** el historial muestra un mensaje que lo explica

### Requirement: Filtros por tiempo

El historial SHALL ofrecer los filtros Todas, Pasadas, Hoy y Futuras, comparando el inicio de cada cita con el momento actual y con el día de Bogotá.

#### Scenario: Filtrar citas pasadas

- **WHEN** el administrador elige Pasadas
- **THEN** solo ve citas cuyo inicio ya pasó, sin incluir las de hoy que todavía no empiezan

#### Scenario: Filtrar citas futuras

- **WHEN** el administrador elige Futuras
- **THEN** solo ve citas cuyo inicio es posterior al momento actual

#### Scenario: Filtro Todas

- **WHEN** el administrador elige Todas
- **THEN** vuelve a ver el historial completo

### Requirement: Orden por fecha o estado

El historial SHALL abrir una hoja inferior para ordenar por fecha ascendente, fecha descendente o estado, y SHALL conservar el filtro activo al aplicar el orden.

#### Scenario: Orden por fecha descendente

- **WHEN** el administrador elige fecha descendente
- **THEN** la cita más reciente aparece primero y el filtro activo se mantiene

#### Scenario: Orden por estado

- **WHEN** el administrador elige ordenar por estado
- **THEN** las citas se agrupan por estado en un orden estable y reconocible

### Requirement: Actualización por deslizamiento

El historial SHALL recargar las citas al deslizar hacia abajo y SHALL mostrar un error con opción de reintentar cuando la consulta falla.

#### Scenario: Deslizar para actualizar

- **WHEN** el administrador desliza la lista hacia abajo
- **THEN** las citas se consultan de nuevo y la lista se actualiza

#### Scenario: Fallo al cargar

- **WHEN** la consulta del historial falla
- **THEN** se muestra un mensaje de error con un botón para reintentar

### Requirement: Edición de una cita

El administrador SHALL poder editar la hora, la mascota, los servicios, el estado y la nota de la estilista de una cita. El precio y la duración SHALL recalcularse en el servidor a partir del catálogo de servicios.

#### Scenario: Cambio de servicios

- **WHEN** el administrador cambia los servicios de una cita y guarda
- **THEN** el total y la duración se recalculan y la cita muestra los valores nuevos

#### Scenario: Cambio de hora ocupada

- **WHEN** el administrador mueve una cita a un horario ya ocupado
- **THEN** la operación se rechaza y se le pide elegir otro horario

#### Scenario: Guardado fallido

- **WHEN** el guardado falla por red o por permisos
- **THEN** la cita conserva sus datos anteriores y se muestra un error

### Requirement: Eliminar una cita la cancela

La acción de eliminar SHALL cambiar el estado de la cita a `cancelada` y SHALL conservar la fila y su detalle, sin borrado físico.

#### Scenario: Eliminar una cita

- **WHEN** el administrador confirma eliminar una cita
- **THEN** la cita queda en estado `cancelada` y sigue apareciendo en el historial

#### Scenario: Cita cancelada

- **WHEN** una cita ya está cancelada
- **THEN** no se ofrece eliminarla otra vez y sigue contando para el histórico

### Requirement: Crear cita para un cliente registrado

El botón flotante SHALL permitir crear una cita para un cliente ya registrado, elegido por nombre o teléfono, con mascota opcional, servicios y un horario libre. La cita SHALL quedar a nombre del cliente elegido, no del administrador.

#### Scenario: Creación exitosa

- **WHEN** el administrador elige un cliente, un servicio y un horario libre y confirma
- **THEN** la cita aparece en el historial a nombre de ese cliente con el total calculado

#### Scenario: Cliente sin mascota registrada

- **WHEN** el cliente elegido no tiene mascotas
- **THEN** la cita se puede crear igual con la mascota vacía

#### Scenario: Horario ocupado

- **WHEN** otro usuario toma el horario antes de confirmar
- **THEN** la creación se rechaza y se pide elegir otro horario

#### Scenario: Servicios inválidos

- **WHEN** no hay exactamente un servicio principal activo
- **THEN** la creación se rechaza y se explica el motivo

### Requirement: Acceso exclusivo del administrador

Todas las operaciones del historial SHALL estar restringidas a cuentas administradoras, comprobadas por la base de datos y no solo por la interfaz.

#### Scenario: Cuenta sin permisos

- **WHEN** una cuenta que no está en `admins` intenta leer o modificar citas ajenas
- **THEN** la base rechaza la operación y la interfaz no muestra datos
