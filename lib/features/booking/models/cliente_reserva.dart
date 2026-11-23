/// Quién reserva: lo que se escribe en el paso 3.
///
/// La cita queda a nombre del cliente con este celular, no de la sesión que
/// haya abierta en el equipo. Si no existe, la base lo crea; si existe, no
/// le cambia el nombre.
class ClienteReserva {
  const ClienteReserva({
    required this.nombre,
    required this.telefono,
    required this.mascota,
  });

  final String nombre;

  /// Ya normalizado a E.164 (`+573001112233`) con `normalizarTelefono`.
  final String telefono;

  /// El nombre de la mascota. Si el cliente no tiene una con ese nombre, se
  /// registra.
  final String mascota;
}
