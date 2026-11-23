/// La nota interna de la estética sobre una mascota.
///
/// El tutor no la ve: vive en `notas_mascota`, que no tiene política para
/// clientes.
class PetNote {
  const PetNote({
    required this.texto,
    required this.autorId,
    required this.actualizadaEn,
  });

  final String texto;

  /// Nulo en las notas heredadas de cuando la nota la escribía el tutor.
  final String? autorId;

  /// En el reloj de la estética.
  final DateTime actualizadaEn;
}

/// La ficha completa de una mascota, tal como la ve el panel.
class PetRecord {
  const PetRecord({
    this.id,
    required this.duenoId,
    required this.nombre,
    this.raza,
    this.edadAnios,
    this.pesoKg,
    this.nota,
    this.fotoPath,
  });

  /// Nulo mientras la mascota no se ha guardado todavía.
  final String? id;
  final String duenoId;
  final String nombre;
  final String? raza;
  final int? edadAnios;
  final double? pesoKg;
  final PetNote? nota;

  /// Dónde está su foto en el bucket `fotos-mascotas`, siempre un `.webp`.
  /// Nulo si no tiene.
  final String? fotoPath;

  static const String sinDato = 'No registrado';

  /// Un dato vacío se dice, no se deja como hueco.
  String get razaVisible =>
      raza == null || raza!.trim().isEmpty ? 'Raza: $sinDato' : raza!;

  String get edadVisible => switch (edadAnios) {
        null => 'Edad: $sinDato',
        1 => '1 año',
        final anios => '$anios años',
      };

  String get pesoVisible {
    final peso = pesoKg;
    if (peso == null) return 'Peso: $sinDato';
    // 12.0 se lee "12 kg", 12.5 se lee "12,5 kg".
    final texto = peso == peso.roundToDouble()
        ? peso.toStringAsFixed(0)
        : peso.toStringAsFixed(1).replaceAll('.', ',');
    return '$texto kg';
  }

  PetRecord copyWith({
    String? id,
    String? nombre,
    String? raza,
    int? edadAnios,
    double? pesoKg,
    PetNote? nota,
    String? fotoPath,
  }) =>
      PetRecord(
        id: id ?? this.id,
        duenoId: duenoId,
        nombre: nombre ?? this.nombre,
        raza: raza ?? this.raza,
        edadAnios: edadAnios ?? this.edadAnios,
        pesoKg: pesoKg ?? this.pesoKg,
        nota: nota ?? this.nota,
        fotoPath: fotoPath ?? this.fotoPath,
      );

  /// La misma ficha sin foto. `copyWith` no sirve para poner un nulo.
  PetRecord sinFoto() => PetRecord(
        id: id,
        duenoId: duenoId,
        nombre: nombre,
        raza: raza,
        edadAnios: edadAnios,
        pesoKg: pesoKg,
        nota: nota,
      );
}

/// Qué hay mal en una ficha antes de mandarla. Nulo si se puede guardar.
///
/// Repite los `check` de la tabla `mascotas` para avisar en el formulario
/// en vez de esperar al rechazo de Postgres.
String? validarMascota({
  required String nombre,
  required int? edadAnios,
  required double? pesoKg,
}) {
  if (nombre.trim().isEmpty) return 'Escribe el nombre de la mascota.';
  if (edadAnios != null && (edadAnios < 0 || edadAnios > 30)) {
    return 'La edad va de 0 a 30 años.';
  }
  if (pesoKg != null && pesoKg <= 0) return 'El peso tiene que ser mayor que 0.';
  if (pesoKg != null && pesoKg >= 1000) return 'Revisa el peso.';
  return null;
}
