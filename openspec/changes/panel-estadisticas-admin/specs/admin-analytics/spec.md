# Spec Delta

## Purpose

Entrega a la estética un resumen operativo de su actividad: volumen de citas, ingresos, ausencias, clientes nuevos y servicios más pedidos.

## ADDED Requirements

### Requirement: Citas de hoy y de la semana

El resumen SHALL mostrar cuántas citas hay hoy y cuántas en la semana en curso, contando solo las que no están canceladas y usando el día de Bogotá.

#### Scenario: Conteo de hoy y semana

- **WHEN** un administrador abre la pestaña Resumen
- **THEN** ve el número de citas de hoy y de la semana en curso, sin incluir canceladas

#### Scenario: Semana sin citas

- **WHEN** no hay citas registradas en la semana
- **THEN** ambos conteos muestran cero, no un error

### Requirement: Ingresos del mes

El resumen SHALL mostrar la suma de `total_cop` de las citas con estado `cumplida` cuyo inicio cae en el mes en curso de Bogotá.

#### Scenario: Suma de citas cumplidas

- **WHEN** el mes tiene dos citas cumplidas de 40000 y 35000 y una reservada
- **THEN** los ingresos del mes muestran 75000

#### Scenario: Mes sin citas cumplidas

- **WHEN** ninguna cita del mes está cumplida
- **THEN** los ingresos del mes muestran cero

### Requirement: Porcentaje de no asistencia

El resumen SHALL calcular el porcentaje de citas `no_asistio` sobre el total de citas `cumplida` más `no_asistio` del mes en curso, y SHALL mostrar cero cuando ese total sea cero.

#### Scenario: Cálculo del porcentaje

- **WHEN** el mes tiene tres citas cumplidas y una no asistida
- **THEN** el porcentaje de no asistencia muestra 25 por ciento

#### Scenario: Sin citas cerradas

- **WHEN** el mes no tiene citas cumplidas ni no asistidas
- **THEN** el porcentaje muestra cero sin dividir por cero

### Requirement: Clientes nuevos del mes

El resumen SHALL mostrar cuántos perfiles de cliente se crearon en el mes en curso, excluyendo las cuentas administradoras.

#### Scenario: Conteo de clientes nuevos

- **WHEN** se crearon dos perfiles de cliente y ningún administrador en el mes
- **THEN** el resumen muestra dos clientes nuevos

### Requirement: Servicios más pedidos

El resumen SHALL mostrar hasta tres servicios con más citas en el mes en curso, contando solo citas no canceladas, y SHALL mostrar un mensaje vacío cuando no haya datos.

#### Scenario: Top de servicios con datos

- **WHEN** el baño aparece en cinco citas y el corte en tres
- **THEN** el baño aparece primero y el corte segundo

#### Scenario: Top de servicios sin datos

- **WHEN** el mes no tiene citas
- **THEN** el resumen indica que todavía no hay servicios registrados

### Requirement: Próximas cinco citas

El resumen SHALL listar hasta cinco citas en estado `reservada` que empiecen en el momento actual o después, en orden ascendente por hora.

#### Scenario: Lista de próximas citas

- **WHEN** hay ocho citas reservadas futuras
- **THEN** solo se muestran las cinco más cercanas en el tiempo

#### Scenario: Sin citas futuras

- **WHEN** no hay citas reservadas futuras
- **THEN** el resumen lo indica sin mostrar una lista vacía sin explicación

### Requirement: Actualización y fallos del resumen

El resumen SHALL actualizarse al deslizar hacia abajo y SHALL mostrar un mensaje con opción de reintentar cuando la consulta falla, sin sustituir datos reales por datos inventados.

#### Scenario: Fallo de consulta

- **WHEN** la consulta de métricas falla
- **THEN** la pantalla muestra un error y un botón para reintentar

#### Scenario: Actualización manual

- **WHEN** el administrador desliza hacia abajo
- **THEN** las métricas se vuelven a consultar y se muestran los valores nuevos
