# Spec Delta

## MODIFIED Requirements

### Requirement: Ingresos del mes

El resumen SHALL mostrar la suma de `total_cop` de las citas con estado `cumplida` cuyo inicio cae en el mes en curso de Bogotá.

#### Scenario: Suma de citas cumplidas

- **WHEN** el mes tiene dos citas cumplidas de 40000 y 35000 y una reservada
- **THEN** los ingresos del mes muestran 75000

#### Scenario: Mes sin citas cumplidas

- **WHEN** ninguna cita del mes está cumplida
- **THEN** los ingresos del mes muestran cero

#### Scenario: Semana que empieza en el mes anterior

- **GIVEN** hoy es martes 1 de diciembre en Bogotá y la semana en curso empieza el lunes 30 de noviembre
- **WHEN** hay una cita cumplida de 40000 el 30 de noviembre y otra de 35000 el 1 de diciembre
- **THEN** los ingresos del mes muestran 35000
- **AND** las citas de la semana cuentan las dos

### Requirement: Porcentaje de no asistencia

El resumen SHALL calcular el porcentaje de citas `no_asistio` sobre el total de citas `cumplida` más `no_asistio` del mes en curso, y SHALL mostrar cero cuando ese total sea cero.

#### Scenario: Cálculo del porcentaje

- **WHEN** el mes tiene tres citas cumplidas y una no asistida
- **THEN** el porcentaje de no asistencia muestra 25 por ciento

#### Scenario: Sin citas cerradas

- **WHEN** el mes no tiene citas cumplidas ni no asistidas
- **THEN** el porcentaje muestra cero sin dividir por cero

#### Scenario: Ausencia en otro mes de la misma semana

- **GIVEN** la semana en curso empieza en el mes anterior
- **WHEN** hay una cita no asistida en un día de la semana que pertenece al mes anterior
- **THEN** esa cita no cuenta para el porcentaje del mes en curso

### Requirement: Servicios más pedidos

El resumen SHALL mostrar hasta tres servicios con más citas en el mes en curso, contando solo citas no canceladas, y SHALL mostrar un mensaje vacío cuando no haya datos.

#### Scenario: Top de servicios con datos

- **WHEN** el baño aparece en cinco citas y el corte en tres
- **THEN** el baño aparece primero y el corte segundo

#### Scenario: Top de servicios sin datos

- **WHEN** el mes no tiene citas
- **THEN** el resumen indica que todavía no hay servicios registrados

#### Scenario: Servicio pedido solo en otro mes

- **GIVEN** la semana en curso termina en el mes siguiente
- **WHEN** un servicio solo aparece en citas del mes siguiente
- **THEN** ese servicio no aparece en el top del mes en curso

## ADDED Requirements

### Requirement: Resumen al día con el resto del panel

El resumen SHALL volver a consultar sus métricas cuando el administrador entra a la pestaña Resumen, para reflejar los cambios hechos en otras pestañas sin tener que deslizar para actualizar.

#### Scenario: Asistencia marcada en la agenda

- **GIVEN** el resumen muestra ingresos del mes de 35000
- **WHEN** el administrador marca como cumplida una cita de 40000 en la pestaña Agenda y vuelve a Resumen
- **THEN** los ingresos del mes muestran 75000

#### Scenario: Fallo al volver a la pestaña

- **WHEN** el administrador vuelve a Resumen y la consulta falla
- **THEN** se muestra el error con opción de reintentar, sin conservar como válidos números que pueden estar desactualizados
