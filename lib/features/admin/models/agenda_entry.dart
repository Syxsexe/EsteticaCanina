/// En qué ha quedado una cita.
///
/// Los nombres de la base van en snake_case y los de Dart en camelCase, así
/// que la correspondencia se declara una vez aquí en vez de repartirse en
/// comparaciones de cadenas por toda la app.
enum EstadoCita {
  reservada('reservada'),
  cumplida('cumplida'),
  cancelada('cancelada'),
  noAsistio('no_asistio');

  const EstadoCita(this.enBase);

  /// Cómo se escribe en la columna `citas.estado`.
  final String enBase;

  /// Un estado que no se reconoce es un error, no algo que redondear.
  ///
  /// Dar por defecto `reservada` sería peor que fallar: la pantalla
  /// ofrecería marcar asistencia sobre una cita que a lo mejor está
  /// cancelada.
  static EstadoCita desde(String valor) => EstadoCita.values.firstWhere(
        (estado) => estado.enBase == valor,
        orElse: () => throw ArgumentError('Estado de cita desconocido: $valor'),
      );

  String get rotulo => switch (this) {
        EstadoCita.reservada => 'Reservada',
        EstadoCita.cumplida => 'Cumplida',
        EstadoCita.cancelada => 'Cancelada',
        EstadoCita.noAsistio => 'No asistió',
      };

  /// Solo una cita reservada admite que se marque qué pasó con ella.
  bool get admiteAsistencia => this == EstadoCita.reservada;
}

/// Una cita vista desde el lado de la estética.
///
/// Trae lo que el cliente nunca ve de una cita ajena: de quién es, con qué
/// perro y con qué teléfono. Es un modelo distinto al del cliente a
/// propósito — la diferencia de permisos se nota en el tipo, no solo en las
/// políticas.
class AgendaEntry {
  const AgendaEntry({
    required this.id,
    required this.empieza,
    required this.minutos,
    required this.estado,
    required this.totalCop,
    this.clienteNombre,
    this.clienteTelefono,
    this.mascotaNombre,
    this.servicios = const [],
    this.notasEstilista,
  });

  final String id;
  final DateTime empieza;
  final int minutos;
  final EstadoCita estado;
  final int totalCop;

  /// Nulo mientras el cliente no haya dado su nombre: con cuentas anónimas
  /// es lo normal.
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? mascotaNombre;

  /// Los nombres de los servicios, no sus identificadores.
  final List<String> servicios;

  final String? notasEstilista;

  DateTime get termina => empieza.add(Duration(minutes: minutos));

  /// Minutos desde medianoche, para pintar la hora con el mismo formato que
  /// el resto de la app.
  int get inicioEnMinutos => empieza.hour * 60 + empieza.minute;

  AgendaEntry copyWith({EstadoCita? estado}) => AgendaEntry(
        id: id,
        empieza: empieza,
        minutos: minutos,
        estado: estado ?? this.estado,
        totalCop: totalCop,
        clienteNombre: clienteNombre,
        clienteTelefono: clienteTelefono,
        mascotaNombre: mascotaNombre,
        servicios: servicios,
        notasEstilista: notasEstilista,
      );
}
