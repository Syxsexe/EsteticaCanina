/// Una mascota del cliente, con lo justo para elegirla en una cita.
class PetRef {
  const PetRef({required this.id, required this.nombre});

  final String id;
  final String nombre;
}

/// Un cliente del directorio.
class CustomerEntry {
  const CustomerEntry({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.citas,
    this.mascotas = const [],
  });

  final String id;
  final String? nombre;
  final String? telefono;
  final int citas;
  final List<PetRef> mascotas;

  /// Con cuentas anónimas el nombre puede faltar. Decirlo es mejor que
  /// dejar un hueco en la lista.
  String get nombreVisible =>
      nombre == null || nombre!.trim().isEmpty ? 'Cliente sin nombre' : nombre!;

  String get telefonoVisible => telefono ?? 'Sin teléfono';
}
