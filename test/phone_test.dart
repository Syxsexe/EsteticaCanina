import 'package:flutter_test/flutter_test.dart';

import 'package:perro_look/core/format/phone.dart';

void main() {
  group('normalizarTelefono', () {
    test('acepta las formas en que la gente escribe su número', () {
      // Todas son el mismo número.
      for (final entrada in [
        '3001112233',
        '300 111 2233',
        '300-111-2233',
        '+57 300 111 2233',
        '+573001112233',
        '0057 300 111 2233',
        '(300) 1112233',
      ]) {
        expect(
          normalizarTelefono(entrada),
          '+573001112233',
          reason: 'falló con "$entrada"',
        );
      }
    });

    test('rechaza los fijos', () {
      // A un fijo no le llega el recordatorio por mensaje, así que guardarlo
      // sería guardar un número al que nunca se va a escribir.
      expect(normalizarTelefono('6017654321'), isNull);
      expect(normalizarTelefono('7331234'), isNull);
    });

    test('rechaza lo que no es un número colombiano', () {
      expect(normalizarTelefono(''), isNull);
      expect(normalizarTelefono('300111223'), isNull, reason: 'falta un dígito');
      expect(normalizarTelefono('30011122334'), isNull, reason: 'sobra uno');
      expect(normalizarTelefono('+34600111222'), isNull, reason: 'español');
      expect(normalizarTelefono('no soy un número'), isNull);
    });
  });

  group('formatTelefono', () {
    test('agrupa para que se pueda leer', () {
      expect(formatTelefono('+573001112233'), '300 111 2233');
    });

    test('deja intacto lo que no reconoce', () {
      // Mejor enseñar algo raro que esconder un dato que el cliente dio.
      expect(formatTelefono('+34600111222'), '+34600111222');
    });
  });
}
