# Spec Delta

## ADDED Requirements

### Requirement: Recordar la cita al cliente

La Agenda SHALL ofrecer "Recordar" en cada cita reservada cuyo cliente tenga
celular. El recordatorio SHALL mostrar un mensaje ya escrito y dejar enviarlo
por WhatsApp o por SMS desde el teléfono de la administradora, sin enviarlo
solo.

#### Scenario: Recordar una cita de mañana

- **GIVEN** Ana tiene cita mañana a las 09:00 para Toby, con baño
- **WHEN** la administradora toca "Recordar"
- **THEN** ve "Hola Ana, te recordamos la cita de Toby en Perro Look mañana a las 09:00 (Baño)…" y los botones "Enviar por WhatsApp" y "Enviar por SMS"

#### Scenario: Enviar por WhatsApp

- **WHEN** toca "Enviar por WhatsApp"
- **THEN** se abre WhatsApp en el chat con el celular del cliente y el mensaje escrito, listo para enviar

#### Scenario: Cita que ya no está en pie

- **WHEN** la cita está cumplida, cancelada o marcada como no asistió
- **THEN** no aparece "Recordar"

#### Scenario: No se puede abrir la app

- **WHEN** el teléfono no puede abrir WhatsApp o la app de mensajes
- **THEN** la administradora ve un aviso de que no se pudo abrir
