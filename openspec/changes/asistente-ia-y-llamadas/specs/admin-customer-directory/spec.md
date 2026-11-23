# Spec Delta

## ADDED Requirements

### Requirement: Llamar al cliente

El detalle de un cliente con celular SHALL ofrecer un botón "Llamar" que abre el marcador del teléfono con ese número listo para marcar. Sin celular, el botón SHALL NOT aparecer.

#### Scenario: Llamar desde el detalle

- **WHEN** la administradora toca "Llamar" en el detalle de Ana
- **THEN** se abre el marcador del teléfono con +573001112233, sin marcarlo solo

#### Scenario: Equipo sin marcador

- **WHEN** el equipo no puede abrir el marcador (por ejemplo, un navegador de escritorio)
- **THEN** la app muestra el número para copiarlo
