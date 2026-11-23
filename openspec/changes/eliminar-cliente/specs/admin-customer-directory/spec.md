# Spec Delta

## ADDED Requirements

### Requirement: Eliminar un cliente

El detalle de un cliente SHALL ofrecer la acción "Eliminar cliente". Antes de eliminar, SHALL pedir confirmación explicando qué se borra y qué se conserva. Al confirmar, el cliente SHALL dejar de aparecer en la lista de Clientes y en la búsqueda del formulario de cita.

#### Scenario: Confirmar la eliminación

- **WHEN** el administrador toca "Eliminar cliente" en el detalle de Luis y confirma
- **THEN** vuelve a la lista de Clientes y Luis ya no aparece

#### Scenario: Cancelar la confirmación

- **WHEN** el administrador toca "Eliminar cliente" y luego "Volver"
- **THEN** el cliente sigue intacto y el detalle sigue abierto

#### Scenario: Fallo al eliminar

- **WHEN** la base rechaza la eliminación o falla la red
- **THEN** se muestra un error y el cliente conserva todos sus datos

### Requirement: Eliminar anonimiza los datos personales

Eliminar un cliente SHALL borrar su nombre, su celular, sus mascotas con sus notas internas y sus observaciones, y SHALL quitar la mascota y la nota de la estilista de sus citas. Todo SHALL ocurrir en una sola operación: si algo falla, no se borra nada.

#### Scenario: Datos borrados

- **GIVEN** Luis tiene una mascota con nota interna y dos observaciones
- **WHEN** el administrador lo elimina
- **THEN** no queda su nombre, su celular, su mascota, la nota ni las observaciones

#### Scenario: Volver a reservar con el mismo celular

- **GIVEN** Luis fue eliminado
- **WHEN** alguien reserva con el celular que tenía Luis
- **THEN** se crea un cliente nuevo, sin las mascotas ni el historial de Luis

### Requirement: Las citas pasadas se conservan

Las citas pasadas de un cliente eliminado SHALL conservarse con su fecha, servicios, total y estado, y SHALL mostrarse a nombre de "Cliente eliminado" en Agenda, Historial y Resumen. Los ingresos, el porcentaje de no asistencia, el top de servicios y los clientes nuevos de cualquier mes SHALL NOT cambiar al eliminar un cliente.

#### Scenario: Ingresos intactos

- **GIVEN** octubre tiene ingresos de 105000, 35000 de ellos de Luis
- **WHEN** el administrador elimina a Luis
- **THEN** el Resumen de octubre sigue mostrando 105000

#### Scenario: Cita pasada en el historial

- **WHEN** el administrador abre el Historial después de eliminar a Luis
- **THEN** las citas que eran de Luis aparecen a nombre de "Cliente eliminado"

### Requirement: Las citas futuras se cancelan

Al eliminar un cliente, sus citas futuras en estado `reservada` SHALL pasar a `cancelada`, de modo que su horario quede libre para otros.

#### Scenario: Horario liberado

- **GIVEN** Luis tiene una cita reservada el próximo martes a las 09:00
- **WHEN** el administrador lo elimina
- **THEN** esa cita queda cancelada y las 09:00 del martes vuelven a estar libres en la reserva

### Requirement: Solo la administradora elimina clientes

La eliminación SHALL estar restringida a cuentas administradoras y comprobada por la base. Una cuenta administradora SHALL NOT poder eliminarse con esta acción.

#### Scenario: Cuenta sin permisos

- **WHEN** una llamada sin sesión de administradora intenta eliminar un cliente
- **THEN** la base la rechaza y no cambia nada

#### Scenario: Intentar eliminar a una administradora

- **WHEN** se intenta eliminar un perfil que está en `admins`
- **THEN** la base lo rechaza
