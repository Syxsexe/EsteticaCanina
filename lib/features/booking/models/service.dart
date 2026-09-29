/// Un servicio del catálogo.
///
/// La reserva se arma en dos niveles: un [Service] principal, que define el
/// precio base y la duración de la cita, y cualquier número de extras que se
/// suman encima.
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.note,
    required this.price,
    required this.minutes,
  });

  final String id;

  /// Nombre corto, el que se lee en la lista.
  final String name;

  /// Una línea que explica qué incluye.
  final String note;

  /// Precio en pesos colombianos.
  final int price;

  /// Cuánto ocupa de la agenda. Los extras suman sobre el principal.
  final int minutes;
}

/// Lo que el usuario lleva elegido mientras arma la cita.
class BookingSelection {
  const BookingSelection({this.mainService, this.extras = const {}});

  final Service? mainService;
  final Set<String> extras;

  bool get isComplete => mainService != null;

  BookingSelection withMainService(Service service) =>
      BookingSelection(mainService: service, extras: extras);

  BookingSelection toggleExtra(String id) {
    final next = Set<String>.from(extras);
    if (!next.remove(id)) next.add(id);
    return BookingSelection(mainService: mainService, extras: next);
  }

  int totalPrice(List<Service> catalog) {
    var total = mainService?.price ?? 0;
    for (final service in catalog) {
      if (extras.contains(service.id)) total += service.price;
    }
    return total;
  }

  int totalMinutes(List<Service> catalog) {
    var total = mainService?.minutes ?? 0;
    for (final service in catalog) {
      if (extras.contains(service.id)) total += service.minutes;
    }
    return total;
  }
}
