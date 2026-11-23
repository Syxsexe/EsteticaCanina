# Spec Delta

## MODIFIED Requirements

### Requirement: Detalle del cliente

Al elegir un cliente, el directorio SHALL mostrar sus datos de contacto, sus mascotas con su ficha, sus citas y sus observaciones.

#### Scenario: Abrir un cliente

- **WHEN** el administrador toca un cliente de la lista
- **THEN** ve su nombre, teléfono, mascotas, citas y observaciones

#### Scenario: Cliente sin citas

- **WHEN** el cliente no tiene citas
- **THEN** el detalle lo indica y sigue mostrando sus datos de contacto

#### Scenario: Cliente sin mascotas

- **WHEN** el cliente no tiene mascotas registradas
- **THEN** el detalle lo indica y ofrece registrar una

#### Scenario: Solo las citas del cliente

- **WHEN** el administrador abre el detalle de Ana
- **THEN** la lista de citas muestra solo citas a nombre de Ana

## ADDED Requirements

### Requirement: Edición del contacto del cliente

El administrador SHALL poder editar el nombre y el teléfono de un cliente registrado, con o sin cuenta en la app. El teléfono SHALL validarse con el mismo formato que usa el flujo de reserva. Ninguna cuenta que no sea administradora SHALL poder editar el perfil de otro cliente.

#### Scenario: Corregir el teléfono

- **WHEN** el administrador cambia el teléfono de Ana y guarda
- **THEN** el detalle y la lista muestran el teléfono nuevo

#### Scenario: Teléfono inválido

- **WHEN** el administrador escribe un teléfono con formato inválido
- **THEN** el formulario lo señala y no guarda

#### Scenario: La reserva no pisa la corrección

- **GIVEN** el administrador corrigió el nombre y el teléfono de Ana
- **WHEN** Ana vuelve a reservar desde la app de clientes con su celular corregido, aunque escriba su nombre de otra forma
- **THEN** la cita queda a nombre de Ana y el perfil conserva los datos corregidos por el administrador

#### Scenario: Cuenta sin permisos

- **WHEN** una cuenta que no es administradora intenta actualizar el perfil de otro cliente
- **THEN** la base rechaza la escritura

### Requirement: Ficha de mascota

El detalle del cliente SHALL mostrar de cada mascota su nombre, raza, edad en años y peso en kilos. Los campos sin dato SHALL mostrarse como no registrados, sin dejar un hueco.

#### Scenario: Mascota con ficha completa

- **WHEN** Toby tiene raza Beagle, 4 años y 12 kg
- **THEN** el detalle muestra Toby con esos tres datos

#### Scenario: Mascota sin raza

- **WHEN** una mascota no tiene raza registrada
- **THEN** el detalle indica que la raza no está registrada

### Requirement: Alta y edición de mascotas por el administrador

El administrador SHALL poder registrar una mascota para un cliente registrado y editar el nombre, la raza, la edad y el peso de sus mascotas. El nombre SHALL ser obligatorio, la edad SHALL estar entre 0 y 30 años y el peso SHALL ser mayor que cero. El panel SHALL NOT ofrecer borrar mascotas.

#### Scenario: Registrar una mascota

- **WHEN** el administrador registra a Canela para Luis y guarda
- **THEN** Canela aparece en el detalle de Luis y se puede elegir en una cita nueva para él

#### Scenario: Editar una mascota

- **WHEN** el administrador cambia el peso de Toby a 13 kg
- **THEN** el detalle muestra 13 kg

#### Scenario: Datos fuera de rango

- **WHEN** el administrador escribe una edad de 40 años o un peso de 0 kg
- **THEN** el formulario lo señala y no guarda

#### Scenario: Sin opción de borrar

- **WHEN** el administrador abre la ficha de una mascota
- **THEN** no hay ninguna acción para borrarla

#### Scenario: Cuenta sin permisos

- **WHEN** una cuenta que no es administradora intenta registrar una mascota a nombre de otro cliente
- **THEN** la base rechaza la escritura

### Requirement: Notas internas de mascota

Cada mascota SHALL tener una nota interna que solo las cuentas administradoras pueden leer y escribir. El tutor de la mascota SHALL NOT poder leer ni escribir esa nota desde ninguna consulta. La nota SHALL guardar quién la editó por última vez y cuándo.

#### Scenario: Escribir la nota

- **WHEN** el administrador escribe "se incomoda con el secador cerca de las orejas" en la nota de Toby y guarda
- **THEN** la ficha de Toby muestra la nota con su autor y su fecha

#### Scenario: El tutor consulta su mascota

- **WHEN** el tutor de Toby consulta sus mascotas con su sesión de cliente
- **THEN** la base no le devuelve la nota interna

#### Scenario: El tutor intenta escribir la nota

- **WHEN** una cuenta que no es administradora intenta crear o cambiar una nota interna
- **THEN** la base rechaza la escritura

#### Scenario: Notas existentes del tutor

- **GIVEN** una mascota tenía texto en la nota que antes escribía el tutor
- **WHEN** se aplica el cambio en la base
- **THEN** ese texto queda como nota interna de la mascota y el tutor deja de verlo
