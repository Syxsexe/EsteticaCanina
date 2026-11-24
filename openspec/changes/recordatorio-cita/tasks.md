## 1. Recordatorio

- [x] 1.1 `recordatorio.dart`: texto del mensaje (hoy, mañana o fecha; sin nombre o sin mascota), enlaces `wa.me` y `sms:` con el texto codificado, y la hoja con los dos botones.
- [x] 1.2 Botón "Recordar" en las citas reservadas con celular de la Agenda.
- [x] 1.3 `<queries>` de Android para `https` y `sms`.

## 2. Verificación

- [x] 2.1 Pruebas en `test/recordatorio_test.dart` (mensaje, enlaces y botón solo en citas reservadas). `flutter analyze` sin avisos nuevos y suite completa en verde.
- [ ] 2.2 Probar en el Redmi: "Enviar por WhatsApp" abre el chat con el texto, y "Enviar por SMS" la app de mensajes.
