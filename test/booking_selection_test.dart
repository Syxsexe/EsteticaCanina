import 'package:flutter_test/flutter_test.dart';
import 'package:perro_look/core/format/money.dart';
import 'package:perro_look/features/booking/data/service_catalog.dart';
import 'package:perro_look/features/booking/models/service.dart';

void main() {
  final catalogo = ServiceCatalog.todos;

  group('BookingSelection', () {
    test('sin servicio principal la reserva no esta completa', () {
      const seleccion = BookingSelection();
      expect(seleccion.isComplete, isFalse);
      expect(seleccion.totalPrice(catalogo), 0);
      expect(seleccion.totalMinutes(catalogo), 0);
    });

    test('los extras suman sobre el precio y la duracion del principal', () {
      final corte = ServiceCatalog.principales
          .firstWhere((s) => s.id == 'corte_completo');
      final unas = ServiceCatalog.extras.firstWhere((s) => s.id == 'unas');

      final seleccion =
          const BookingSelection().withMainService(corte).toggleExtra(unas.id);

      expect(seleccion.isComplete, isTrue);
      expect(seleccion.totalPrice(catalogo), corte.price + unas.price);
      expect(seleccion.totalMinutes(catalogo), corte.minutes + unas.minutes);
    });

    test('marcar dos veces el mismo extra lo quita', () {
      final seleccion = const BookingSelection().toggleExtra('unas');
      expect(seleccion.extras, contains('unas'));
      expect(seleccion.toggleExtra('unas').extras, isEmpty);
    });

    test('cambiar de servicio principal conserva los extras marcados', () {
      final bano = ServiceCatalog.principales.firstWhere((s) => s.id == 'bano');
      final raza =
          ServiceCatalog.principales.firstWhere((s) => s.id == 'corte_raza');

      final seleccion = const BookingSelection()
          .withMainService(bano)
          .toggleExtra('oidos')
          .withMainService(raza);

      expect(seleccion.mainService?.id, 'corte_raza');
      expect(seleccion.extras, contains('oidos'));
    });
  });

  group('formato', () {
    test('formatCop separa los miles con punto', () {
      expect(formatCop(0), r'$0');
      expect(formatCop(8000), r'$8.000');
      expect(formatCop(63000), r'$63.000');
      expect(formatCop(1250000), r'$1.250.000');
    });

    test('formatDuration pasa a horas cuando corresponde', () {
      expect(formatDuration(45), '45 min');
      expect(formatDuration(60), '1 h');
      expect(formatDuration(100), '1 h 40');
    });
  });
}
