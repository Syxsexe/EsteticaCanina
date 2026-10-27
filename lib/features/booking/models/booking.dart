import 'service.dart';

/// Una cita cerrada: qué se eligió y cuándo.
///
/// Es lo que sale del paso 2 y entra en la confirmación. Cuando haya
/// backend, es también lo que se le pasa a `reservar_cita`: por eso guarda
/// la hora como minutos desde medianoche y el día aparte, que es como
/// razona el resto del flujo, y deja la conversión a un instante concreto
/// en un solo sitio ([startsAt]).
class Booking {
  const Booking({
    required this.selection,
    required this.date,
    required this.startMinutes,
  });

  /// Los servicios, tal como quedaron en el paso 1.
  final BookingSelection selection;

  /// El día de la cita, a medianoche.
  final DateTime date;

  /// A qué hora empieza, en minutos desde medianoche.
  final int startMinutes;

  /// Cuánto ocupa de la agenda, sumando extras.
  int minutes(List<Service> catalog) => selection.totalMinutes(catalog);

  /// Lo que se paga al terminar.
  int price(List<Service> catalog) => selection.totalPrice(catalog);

  /// El instante en que empieza, en hora local.
  DateTime get startsAt => DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: startMinutes));

  /// El instante en que termina.
  DateTime endsAt(List<Service> catalog) =>
      startsAt.add(Duration(minutes: minutes(catalog)));
}
