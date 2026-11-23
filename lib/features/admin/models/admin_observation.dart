/// Una observación escrita por la estética.
///
/// El cliente no la ve: la tabla `observaciones` no tiene política para él.
class AdminObservation {
  const AdminObservation({
    required this.id,
    required this.clienteId,
    required this.autorId,
    required this.texto,
    required this.creadaEn,
  });

  final String id;
  final String clienteId;
  final String autorId;
  final String texto;
  final DateTime creadaEn;
}
