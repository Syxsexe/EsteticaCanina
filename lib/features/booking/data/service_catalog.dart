import '../models/service.dart';

/// Catálogo de la estética.
///
/// OJO: los precios y las duraciones son de muestra. Ni el póster ni el
/// diseño de Houndsworth traen cifras reales, así que hay que reemplazarlos
/// por los de Perro Look antes de mostrar esto a un cliente.
class ServiceCatalog {
  const ServiceCatalog._();

  /// Se elige uno solo. Define el precio base y el largo de la cita.
  static const List<Service> principales = [
    Service(
      id: 'bano',
      name: 'Baño',
      note: 'Agua caliente, cepillado y secado.',
      price: 35000,
      minutes: 45,
    ),
    Service(
      id: 'corte_completo',
      name: 'Corte completo',
      note: 'Baño más corte de todo el manto.',
      price: 55000,
      minutes: 90,
    ),
    Service(
      id: 'corte_raza',
      name: 'Corte de raza',
      note: 'Corte acorde al estándar de la raza.',
      price: 70000,
      minutes: 105,
    ),
    Service(
      id: 'cachorro',
      name: 'Visita de cachorro',
      note: 'Primera vez, con calma y sin máquina.',
      price: 30000,
      minutes: 40,
    ),
  ];

  /// Se marcan los que se quieran, encima del principal.
  static const List<Service> extras = [
    Service(
      id: 'unas',
      name: 'Corte de uñas',
      note: 'Incluye limado.',
      price: 8000,
      minutes: 10,
    ),
    Service(
      id: 'oidos',
      name: 'Limpieza de oídos',
      note: 'Revisión y limpieza suave.',
      price: 8000,
      minutes: 10,
    ),
    Service(
      id: 'dientes',
      name: 'Limpieza de dientes',
      note: 'Cepillado con pasta canina.',
      price: 12000,
      minutes: 15,
    ),
    Service(
      id: 'deslanado',
      name: 'Deslanado',
      note: 'Retira el pelo muerto del manto doble.',
      price: 25000,
      minutes: 30,
    ),
    Service(
      id: 'masaje',
      name: 'Masaje anti estrés',
      note: 'Durante el baño, para perros nerviosos.',
      price: 10000,
      minutes: 15,
    ),
    Service(
      id: 'perfume',
      name: 'Adorno y perfume',
      note: 'Moño o pañoleta y perfume canino.',
      price: 6000,
      minutes: 5,
    ),
  ];

  static List<Service> get todos => [...principales, ...extras];
}
