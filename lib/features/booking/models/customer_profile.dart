/// Los datos de contacto del cliente.
///
/// Mínimos a propósito: un nombre para saludar y un número al que escribir
/// la tarde anterior. Nada más, porque nada más hace falta para que la
/// estética pueda hacer su trabajo.
class CustomerProfile {
  const CustomerProfile({this.nombre, this.telefono});

  final String? nombre;

  /// En E.164 (`+573001112233`). Ver `normalizarTelefono`.
  final String? telefono;

  /// Si ya se puede reservar sin volver a preguntar.
  ///
  /// El teléfono es el que manda: sin él la estética no puede confirmar ni
  /// avisar, y una cita que no se puede confirmar no sirve de nada.
  bool get completo =>
      (nombre?.trim().isNotEmpty ?? false) &&
      (telefono?.isNotEmpty ?? false);
}
