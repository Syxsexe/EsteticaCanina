# Spec Delta

## MODIFIED Requirements

### Requirement: Crear cita para un cliente registrado

El botón flotante de la pestaña Agenda SHALL permitir crear una cita para un cliente ya registrado, elegido por nombre o teléfono, con mascota opcional, servicios y un horario libre. La cita SHALL quedar a nombre del cliente elegido, no del administrador. La pestaña Historial SHALL NOT ofrecer un botón de creación.

#### Scenario: Creación exitosa

- **WHEN** el administrador elige un cliente, un servicio y un horario libre y confirma
- **THEN** la cita aparece en la agenda y en el historial a nombre de ese cliente con el total calculado

#### Scenario: Cliente sin mascota registrada

- **WHEN** el cliente elegido no tiene mascotas
- **THEN** la cita se puede crear igual con la mascota vacía

#### Scenario: Horario ocupado

- **WHEN** otro usuario toma el horario antes de confirmar
- **THEN** la creación se rechaza y se pide elegir otro horario

#### Scenario: Servicios inválidos

- **WHEN** no hay exactamente un servicio principal activo
- **THEN** la creación se rechaza y se explica el motivo

#### Scenario: Historial sin botón de creación

- **WHEN** el administrador abre la pestaña Historial
- **THEN** no ve el botón "Nueva cita"

## ADDED Requirements

### Requirement: Nueva cita en el día visible de la agenda

Al crear una cita desde la Agenda, el formulario SHALL abrir en el día que la agenda está mostrando. Si ese día ya pasó en Bogotá, SHALL abrir en hoy. Al guardar, la agenda SHALL recargar el día visible.

#### Scenario: Crear en un día futuro

- **GIVEN** la agenda muestra el jueves siguiente
- **WHEN** el administrador toca "Nueva cita"
- **THEN** el formulario muestra ese jueves elegido con sus horarios libres

#### Scenario: Crear desde un día pasado

- **GIVEN** la agenda muestra un día anterior a hoy
- **WHEN** el administrador toca "Nueva cita"
- **THEN** el formulario abre en el día de hoy

#### Scenario: La agenda muestra la cita nueva

- **WHEN** el administrador guarda una cita para el día visible
- **THEN** la cita aparece en la agenda sin deslizar para actualizar

#### Scenario: Cancelar el formulario

- **WHEN** el administrador cierra el formulario sin guardar
- **THEN** la agenda sigue en el mismo día y no crea ninguna cita

### Requirement: Crear cita desde el detalle del cliente

El detalle de un cliente SHALL ofrecer crear una cita con ese cliente ya elegido. Al guardar, la cita SHALL aparecer en las citas de ese cliente.

#### Scenario: Cliente preseleccionado

- **WHEN** el administrador toca "Nueva cita" en el detalle de Ana
- **THEN** el formulario abre con Ana elegida y sus mascotas disponibles

#### Scenario: Cita visible en el detalle

- **WHEN** el administrador guarda esa cita
- **THEN** la cita aparece en la lista de citas del detalle de Ana

### Requirement: Crear cita para un cliente nuevo

El formulario de nueva cita SHALL ofrecer "Cliente nuevo" además de buscar un cliente registrado. "Cliente nuevo" SHALL pedir el nombre del dueño, el celular y el nombre de la mascota, todos obligatorios. La cita SHALL quedar a nombre del cliente con ese celular, siguiendo la misma regla que la reserva del cliente.

#### Scenario: Cliente que llama por teléfono

- **WHEN** el administrador elige "Cliente nuevo", escribe "Marta", "315 222 3344" y "Lola", elige servicio, día y hora y guarda
- **THEN** se crea la cita a nombre de Marta, y Marta aparece en Clientes con su mascota Lola

#### Scenario: El celular ya es de un cliente

- **GIVEN** Ana ya está registrada con el celular +573001112233
- **WHEN** el administrador usa "Cliente nuevo" con ese celular
- **THEN** la cita queda a nombre de Ana y no se crea otro cliente

#### Scenario: Datos incompletos

- **WHEN** el administrador deja vacío el nombre, la mascota o escribe un celular inválido
- **THEN** el formulario lo señala y no guarda

#### Scenario: Horario ocupado con cliente nuevo

- **WHEN** el horario se ocupa antes de guardar
- **THEN** la creación se rechaza, no queda ningún cliente nuevo y el formulario conserva los datos escritos

### Requirement: Pestañas de citas al día con el resto del panel

Las pestañas Agenda e Historial SHALL volver a consultar sus citas cuando el administrador entra a ellas, para reflejar las citas creadas, editadas, canceladas o marcadas en otra pestaña. La Agenda SHALL conservar el día que mostraba y el Historial SHALL conservar su filtro y su orden.

#### Scenario: Cancelación hecha en el historial

- **GIVEN** la agenda de hoy muestra una cita reservada
- **WHEN** el administrador cancela esa cita en Historial y vuelve a Agenda
- **THEN** la agenda muestra la cita como cancelada

#### Scenario: Cita creada en la agenda

- **GIVEN** el Historial tiene activo el filtro Futuras
- **WHEN** el administrador crea una cita futura en Agenda y vuelve a Historial
- **THEN** la cita nueva aparece y el filtro Futuras sigue activo

#### Scenario: Cita creada desde clientes

- **WHEN** el administrador crea una cita desde el detalle de un cliente y vuelve a Agenda en ese día
- **THEN** la agenda muestra la cita nueva

### Requirement: Cancelación confirmada por la base

La cancelación de una cita SHALL considerarse correcta solo si la base devuelve la cita actualizada. Si la base no actualiza ninguna fila, la interfaz SHALL mostrar un error y la cita SHALL conservar su estado anterior.

#### Scenario: Cancelación rechazada sin error de red

- **WHEN** el administrador cancela una cita y la base no actualiza ninguna fila
- **THEN** la interfaz muestra un error y la cita sigue con su estado anterior
