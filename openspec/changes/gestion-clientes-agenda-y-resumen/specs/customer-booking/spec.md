# Spec Delta

## Purpose

Define cómo un cliente reserva una cita desde la app y a nombre de quién queda: el cliente se identifica por su celular, no por la sesión abierta en el equipo.

## ADDED Requirements

### Requirement: Paso de identificación en la reserva

Después de elegir los servicios, el día y la hora, la reserva SHALL mostrar un tercer paso que pida el nombre del dueño, el celular y el nombre de la mascota. Los tres datos SHALL ser obligatorios y el celular SHALL validarse como celular colombiano. La cita SHALL guardarse solo al confirmar este paso.

#### Scenario: Datos completos

- **WHEN** el cliente escribe "Ana", "300 111 2233" y "Toby" y confirma
- **THEN** la cita se guarda y se muestra la pantalla de cita confirmada

#### Scenario: Celular inválido

- **WHEN** el cliente escribe un celular que no es colombiano o un número fijo
- **THEN** el paso lo señala y no guarda la cita

#### Scenario: Falta un dato

- **WHEN** el cliente deja vacío el nombre del dueño o el de la mascota
- **THEN** el paso lo señala y no guarda la cita

#### Scenario: Volver al paso anterior

- **WHEN** el cliente vuelve atrás desde el paso 3
- **THEN** vuelve al paso 2 con el día y la hora que había elegido, y no se guarda ninguna cita

### Requirement: La cita queda a nombre del celular

La cita SHALL quedar a nombre del cliente cuyo perfil tiene el celular escrito en el paso 3, sin importar qué sesión haya abierta en el equipo. Si no existe ese cliente, SHALL crearse uno sin cuenta con el nombre y el celular escritos.

#### Scenario: Cliente que vuelve desde otro equipo

- **GIVEN** existe un cliente con el celular +573001112233
- **WHEN** alguien reserva desde otro teléfono con ese mismo celular
- **THEN** la cita queda a nombre de ese cliente y no se crea otro

#### Scenario: Cliente nuevo

- **WHEN** alguien reserva con un celular que no tiene ningún cliente
- **THEN** se crea un cliente sin cuenta con ese nombre y ese celular, y la cita queda a su nombre

#### Scenario: Sesión de administradora abierta en el equipo

- **GIVEN** la administradora dejó su sesión abierta en la tablet de la estética
- **WHEN** un cliente reserva desde esa tablet con su celular
- **THEN** la cita queda a nombre del cliente, no de la administradora

#### Scenario: El nombre escrito no renombra a un cliente existente

- **GIVEN** existe un cliente "Ana" con el celular +573001112233
- **WHEN** alguien reserva con ese celular y escribe el nombre "Otra persona"
- **THEN** la cita queda a nombre de Ana y su nombre no cambia

### Requirement: Mascota de la reserva

La cita SHALL quedar asociada a la mascota del cliente con el nombre escrito en el paso 3, comparando sin distinguir mayúsculas ni espacios de los extremos. Si el cliente no tiene una mascota con ese nombre, SHALL registrarse una.

#### Scenario: Mascota ya registrada

- **GIVEN** el cliente con ese celular tiene una mascota "Toby"
- **WHEN** reserva escribiendo " toby "
- **THEN** la cita queda asociada a Toby y no se crea otra mascota

#### Scenario: Mascota nueva

- **WHEN** el cliente escribe el nombre de una mascota que no tiene registrada
- **THEN** se registra esa mascota a su nombre y la cita queda asociada a ella

### Requirement: Reserva atómica

Crear el cliente, la mascota y la cita SHALL ser una sola operación. Si la cita no se puede crear, SHALL NOT quedar un cliente ni una mascota nuevos.

#### Scenario: Horario tomado

- **WHEN** otra persona toma el horario antes de que el cliente confirme el paso 3
- **THEN** se avisa que la hora ya no está libre, no queda ningún cliente ni mascota nuevos y el cliente vuelve a elegir hora

#### Scenario: Servicios inválidos

- **WHEN** la base rechaza los servicios elegidos
- **THEN** no se crea nada y el cliente ve un mensaje de error

### Requirement: Reserva sin sesión

La reserva SHALL funcionar sin que el cliente inicie sesión ni se cree una cuenta anónima. La base SHALL validar el celular, el nombre y la mascota aunque la app ya los haya validado.

#### Scenario: Equipo sin sesión

- **WHEN** un cliente reserva desde un navegador sin ninguna sesión de Supabase
- **THEN** la cita se crea sin crear ningún usuario en `auth.users`

#### Scenario: Llamada directa con datos inválidos

- **WHEN** alguien llama a la operación de reserva con un celular inválido sin pasar por la app
- **THEN** la base rechaza la reserva y no crea nada
