# Spec Delta

## ADDED Requirements

### Requirement: Elegir el mes del resumen

El resumen SHALL ofrecer un menú desplegable de meses. Las opciones SHALL ir desde el mes en curso de Bogotá hasta el mes de la cita más antigua registrada, del más reciente al más antiguo. Al abrir la pestaña, el mes elegido SHALL ser el mes en curso.

#### Scenario: Meses desde la primera cita

- **GIVEN** hoy es 23 de noviembre de 2026 y la cita más antigua es del 14 de agosto de 2026
- **WHEN** el administrador abre el desplegable
- **THEN** ve noviembre, octubre, septiembre y agosto de 2026, en ese orden

#### Scenario: Sin citas registradas

- **WHEN** no existe ninguna cita
- **THEN** el desplegable ofrece solo el mes en curso

#### Scenario: Mes sin citas entre otros meses

- **GIVEN** hubo citas en agosto y en octubre, pero ninguna en septiembre
- **WHEN** el administrador abre el desplegable
- **THEN** septiembre aparece igualmente entre octubre y agosto

### Requirement: Resumen del mes en curso

Con el mes en curso elegido, el resumen SHALL mostrar lo mismo que hasta ahora: citas de hoy, citas de la semana, ingresos del mes, porcentaje de no asistencia, clientes nuevos, servicios más pedidos y próximas citas.

#### Scenario: Volver al mes en curso

- **GIVEN** el administrador está viendo octubre
- **WHEN** elige el mes en curso en el desplegable
- **THEN** vuelven a aparecer las citas de hoy, de la semana y las próximas citas

### Requirement: Resumen de un mes pasado

Con un mes pasado elegido, el resumen SHALL mostrar las métricas de ese mes: total de citas no canceladas, ingresos de las citas cumplidas, porcentaje de no asistencia, clientes nuevos y hasta tres servicios más pedidos. SHALL NOT mostrar citas de hoy, citas de la semana ni próximas citas.

#### Scenario: Métricas de octubre

- **GIVEN** octubre tuvo tres citas cumplidas de 35000, una no asistida y una cancelada
- **WHEN** el administrador elige octubre
- **THEN** ve 4 citas, ingresos de 105000, 25 % de no asistencia y el top de servicios de octubre

#### Scenario: Secciones del presente ocultas

- **WHEN** el administrador elige un mes pasado
- **THEN** no aparecen "Citas hoy", "Citas semana" ni "Próximas citas"

#### Scenario: Clientes nuevos de ese mes

- **GIVEN** en octubre se registraron dos clientes y en noviembre uno
- **WHEN** el administrador elige octubre
- **THEN** los clientes nuevos muestran 2

#### Scenario: Corte de mes en hora de Bogotá

- **GIVEN** una cita empieza el 31 de octubre a las 20:00 de Bogotá, que ya es 1 de noviembre en UTC
- **WHEN** el administrador elige octubre
- **THEN** esa cita cuenta en octubre y no en noviembre

### Requirement: Citas canceladas del mes

El resumen SHALL mostrar cuántas citas del mes se cancelaron y qué porcentaje son del total agendado en ese mes, canceladas incluidas. SHALL mostrarse tanto en el mes en curso como en un mes pasado, y SHALL mostrar cero cuando el mes no tenga citas. Las canceladas SHALL seguir fuera de las demás métricas.

#### Scenario: Canceladas de octubre

- **GIVEN** octubre tuvo cinco citas agendadas y una de ellas se canceló
- **WHEN** el administrador elige octubre
- **THEN** "Canceladas" muestra 1 y 20 %, y "Citas del mes" sigue mostrando 4

#### Scenario: Canceladas del mes en curso

- **GIVEN** en el mes en curso hay diez citas agendadas y dos canceladas
- **WHEN** el administrador abre el Resumen
- **THEN** "Canceladas" muestra 2 y 20 %

#### Scenario: Mes sin citas

- **WHEN** el mes elegido no tiene citas
- **THEN** "Canceladas" muestra 0 y 0 %, sin dividir por cero

### Requirement: Citas de un mes pasado

Con un mes pasado elegido, el resumen SHALL listar todas las citas de ese mes en orden de fecha y hora, incluidas las canceladas. Cada cita SHALL mostrar fecha, hora, cliente, mascota, servicios, total y estado.

#### Scenario: Lista del mes

- **WHEN** el administrador elige octubre
- **THEN** ve todas las citas de octubre, de la más temprana a la más tardía, cada una con su estado

#### Scenario: Mes sin citas

- **WHEN** el administrador elige un mes que no tuvo citas
- **THEN** las métricas muestran cero y la lista indica que ese mes no hubo citas

### Requirement: El mes elegido se conserva

Al deslizar para actualizar o al volver a la pestaña Resumen, el resumen SHALL volver a consultar los datos del mismo mes elegido. Si la consulta falla, SHALL mostrar un error con opción de reintentar y conservar el mes elegido.

#### Scenario: Actualizar un mes pasado

- **GIVEN** el administrador está viendo octubre
- **WHEN** desliza para actualizar
- **THEN** se vuelven a consultar los datos de octubre y el desplegable sigue en octubre

#### Scenario: Fallo al consultar un mes

- **WHEN** falla la consulta de un mes pasado
- **THEN** se muestra un error con "Reintentar" y, al reintentar, se consulta ese mismo mes
