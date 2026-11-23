import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/time/salon_time.dart';
import '../models/admin_observation.dart';
import '../models/customer_entry.dart';
import '../models/pet_record.dart';

/// El directorio de clientes, sus mascotas y las notas privadas.
///
/// Solo clientes que ya tienen cuenta: aquí no se crea ninguno.
abstract interface class CustomerDirectoryRepository {
  /// Clientes ordenados por nombre, filtrados por [busqueda] si viene.
  Future<List<CustomerEntry>> clientes({String busqueda = ''});

  /// Corrige el nombre y el teléfono. El teléfono llega ya normalizado.
  Future<void> actualizarContacto({
    required String clienteId,
    required String nombre,
    required String telefono,
  });

  /// Las mascotas de un cliente con su ficha y su nota interna.
  Future<List<PetRecord>> mascotasDe(String clienteId);

  /// Registra la mascota si no tiene `id`; si lo tiene, la corrige.
  Future<PetRecord> guardarMascota(PetRecord mascota);

  /// Guarda [webp] como la foto de [mascota], reemplazando la anterior, y
  /// devuelve la ficha con la ruta nueva. [webp] ya tiene que ser WebP.
  Future<PetRecord> guardarFotoMascota(PetRecord mascota, Uint8List webp);

  /// Quita la foto de [mascota] y la borra del almacenamiento.
  Future<PetRecord> quitarFotoMascota(PetRecord mascota);

  /// Los bytes de la foto guardada en [path].
  Future<Uint8List> fotoDe(String path);

  /// Escribe la nota interna de una mascota. Un texto vacío la deja sin nota.
  Future<PetNote> guardarNotaMascota({
    required String mascotaId,
    required String texto,
  });

  /// Elimina al cliente anonimizándolo: desaparece del directorio, se
  /// borran sus datos, mascotas y observaciones, se cancelan sus citas
  /// futuras y las pasadas quedan como "Cliente eliminado". No se deshace.
  Future<void> eliminarCliente(String clienteId);

  Future<List<AdminObservation>> observaciones(String clienteId);

  Future<AdminObservation> guardarObservacion({
    String? id,
    required String clienteId,
    required String texto,
  });

  Future<void> eliminarObservacion(String id);
}

/// La base no tocó la fila: no existe o la cuenta no tiene permiso.
class FilaNoActualizadaException implements Exception {
  const FilaNoActualizadaException();

  @override
  String toString() => 'La base no actualizó ninguna fila.';
}

/// El directorio de muestra.
class SampleCustomerDirectoryRepository implements CustomerDirectoryRepository {
  SampleCustomerDirectoryRepository({
    List<CustomerEntry>? clientes,
    List<PetRecord>? mascotas,
    List<AdminObservation>? observaciones,
  })  : _clientes = List.of(clientes ?? _porDefecto()),
        _mascotas = List.of(
          mascotas ??
              (clientes == null
                  ? _mascotasPorDefecto()
                  : _mascotasDeLosClientes(clientes)),
        ),
        _observaciones = observaciones ??
            [
              AdminObservation(
                id: 'obs-1',
                clienteId: 'cliente-ana',
                autorId: 'admin',
                texto: 'Prefiere que la llamen antes de las 10.',
                creadaEn: DateTime(2026, 11, 1, 9),
              ),
            ];

  final List<CustomerEntry> _clientes;
  final List<PetRecord> _mascotas;
  final List<AdminObservation> _observaciones;
  int _secuencia = 0;

  /// El bucket de muestra: ruta -> bytes. Público para que las pruebas
  /// comprueben qué quedó guardado.
  final Map<String, Uint8List> fotos = {};

  static List<CustomerEntry> _porDefecto() => const [
        CustomerEntry(
          id: 'cliente-ana',
          nombre: 'Ana',
          telefono: '+573001112233',
          citas: 1,
        ),
        CustomerEntry(
          id: 'cliente-camila',
          nombre: 'Camila',
          telefono: '+573007778899',
          citas: 0,
        ),
        CustomerEntry(
          id: 'cliente-luis',
          nombre: 'Luis',
          telefono: '+573004445566',
          citas: 1,
        ),
      ];

  static List<PetRecord> _mascotasPorDefecto() => [
        PetRecord(
          id: 'mascota-toby',
          duenoId: 'cliente-ana',
          nombre: 'Toby',
          raza: 'Beagle',
          edadAnios: 4,
          pesoKg: 12,
          nota: PetNote(
            texto: 'Se incomoda con el secador cerca de las orejas.',
            autorId: 'admin',
            actualizadaEn: DateTime(2026, 10, 20, 15),
          ),
        ),
        const PetRecord(
          id: 'mascota-canela',
          duenoId: 'cliente-luis',
          nombre: 'Canela',
        ),
      ];

  /// Cuando un test pasa sus propios clientes con mascotas, esas mascotas
  /// también existen con su ficha mínima.
  static List<PetRecord> _mascotasDeLosClientes(List<CustomerEntry> clientes) =>
      [
        for (final cliente in clientes)
          for (final mascota in cliente.mascotas)
            PetRecord(
              id: mascota.id,
              duenoId: cliente.id,
              nombre: mascota.nombre,
            ),
      ];

  @override
  Future<List<CustomerEntry>> clientes({String busqueda = ''}) async {
    final texto = busqueda.trim().toLowerCase();
    final encontrados = [
      for (final cliente in _clientes)
        if (texto.isEmpty ||
            cliente.nombreVisible.toLowerCase().contains(texto) ||
            cliente.telefonoVisible.contains(texto))
          CustomerEntry(
            id: cliente.id,
            nombre: cliente.nombre,
            telefono: cliente.telefono,
            citas: cliente.citas,
            mascotas: [
              for (final mascota in _mascotas)
                if (mascota.duenoId == cliente.id)
                  PetRef(id: mascota.id!, nombre: mascota.nombre),
            ],
          ),
    ]..sort((a, b) => a.nombreVisible.compareTo(b.nombreVisible));
    return encontrados;
  }

  @override
  Future<void> actualizarContacto({
    required String clienteId,
    required String nombre,
    required String telefono,
  }) async {
    final indice = _clientes.indexWhere((c) => c.id == clienteId);
    if (indice < 0) throw const FilaNoActualizadaException();
    final actual = _clientes[indice];
    _clientes[indice] = CustomerEntry(
      id: actual.id,
      nombre: nombre,
      telefono: telefono,
      citas: actual.citas,
      mascotas: actual.mascotas,
    );
  }

  @override
  Future<List<PetRecord>> mascotasDe(String clienteId) async => [
        for (final mascota in _mascotas)
          if (mascota.duenoId == clienteId) mascota,
      ]..sort((a, b) => a.nombre.compareTo(b.nombre));

  @override
  Future<PetRecord> guardarMascota(PetRecord mascota) async {
    final id = mascota.id;
    if (id == null) {
      final nueva = PetRecord(
        id: 'mascota-muestra-${_secuencia++}',
        duenoId: mascota.duenoId,
        nombre: mascota.nombre,
        raza: mascota.raza,
        edadAnios: mascota.edadAnios,
        pesoKg: mascota.pesoKg,
      );
      _mascotas.add(nueva);
      return nueva;
    }

    final indice = _mascotas.indexWhere((m) => m.id == id);
    if (indice < 0) throw const FilaNoActualizadaException();
    // La nota no viaja con la ficha: se conserva la que hubiera.
    final editada = PetRecord(
      id: id,
      duenoId: _mascotas[indice].duenoId,
      nombre: mascota.nombre,
      raza: mascota.raza,
      edadAnios: mascota.edadAnios,
      pesoKg: mascota.pesoKg,
      nota: _mascotas[indice].nota,
      fotoPath: _mascotas[indice].fotoPath,
    );
    _mascotas[indice] = editada;
    return editada;
  }

  @override
  Future<PetNote> guardarNotaMascota({
    required String mascotaId,
    required String texto,
  }) async {
    final indice = _mascotas.indexWhere((m) => m.id == mascotaId);
    if (indice < 0) throw const FilaNoActualizadaException();
    final nota = PetNote(
      texto: texto,
      autorId: 'admin',
      actualizadaEn: enHoraEstetica(DateTime.now()),
    );
    _mascotas[indice] = _mascotas[indice].copyWith(nota: nota);
    return nota;
  }

  @override
  Future<PetRecord> guardarFotoMascota(PetRecord mascota, Uint8List webp) async {
    final indice = _mascotas.indexWhere((m) => m.id == mascota.id);
    if (indice < 0) throw const FilaNoActualizadaException();
    final anterior = _mascotas[indice].fotoPath;
    final ruta = '${mascota.id}/${_secuencia++}.webp';
    fotos[ruta] = webp;
    final conFoto = _mascotas[indice].copyWith(fotoPath: ruta);
    _mascotas[indice] = conFoto;
    if (anterior != null) fotos.remove(anterior);
    return conFoto;
  }

  @override
  Future<PetRecord> quitarFotoMascota(PetRecord mascota) async {
    final indice = _mascotas.indexWhere((m) => m.id == mascota.id);
    if (indice < 0) throw const FilaNoActualizadaException();
    final anterior = _mascotas[indice].fotoPath;
    final sinFoto = _mascotas[indice].sinFoto();
    _mascotas[indice] = sinFoto;
    if (anterior != null) fotos.remove(anterior);
    return sinFoto;
  }

  @override
  Future<Uint8List> fotoDe(String path) async {
    final bytes = fotos[path];
    if (bytes == null) throw StateError('Foto desconocida: $path');
    return bytes;
  }

  @override
  Future<void> eliminarCliente(String clienteId) async {
    final indice = _clientes.indexWhere((c) => c.id == clienteId);
    if (indice < 0) throw const FilaNoActualizadaException();
    _clientes.removeAt(indice);
    for (final mascota in _mascotas) {
      if (mascota.duenoId == clienteId && mascota.fotoPath != null) {
        fotos.remove(mascota.fotoPath);
      }
    }
    _mascotas.removeWhere((m) => m.duenoId == clienteId);
    _observaciones.removeWhere((o) => o.clienteId == clienteId);
  }

  /// La versión de muestra de lo que hace `reservar_cita_por_celular` antes
  /// de crear la cita: el cliente con ese celular (o uno nuevo, sin tocar el
  /// nombre del existente) y su mascota con ese nombre (o una nueva).
  Future<(String clienteId, String mascotaId)> registrarPorCelular({
    required String nombre,
    required String telefono,
    required String mascota,
  }) async {
    var indice = _clientes.indexWhere((c) => c.telefono == telefono);
    if (indice < 0) {
      _clientes.add(CustomerEntry(
        id: 'cliente-muestra-${_secuencia++}',
        nombre: nombre.trim(),
        telefono: telefono,
        citas: 0,
      ));
      indice = _clientes.length - 1;
    }
    final cliente = _clientes[indice];
    _clientes[indice] = CustomerEntry(
      id: cliente.id,
      nombre: cliente.nombre,
      telefono: cliente.telefono,
      citas: cliente.citas + 1,
      mascotas: cliente.mascotas,
    );

    final buscada = mascota.trim().toLowerCase();
    final existente = _mascotas.where(
      (m) => m.duenoId == cliente.id && m.nombre.trim().toLowerCase() == buscada,
    );
    if (existente.isNotEmpty) return (cliente.id, existente.first.id!);

    final nueva = await guardarMascota(
      PetRecord(duenoId: cliente.id, nombre: mascota.trim()),
    );
    return (cliente.id, nueva.id!);
  }

  @override
  Future<List<AdminObservation>> observaciones(String clienteId) async => [
        for (final obs in _observaciones)
          if (obs.clienteId == clienteId) obs,
      ]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));

  @override
  Future<AdminObservation> guardarObservacion({
    String? id,
    required String clienteId,
    required String texto,
  }) async {
    if (id != null) {
      final indice = _observaciones.indexWhere((o) => o.id == id);
      if (indice < 0) throw StateError('Observación desconocida: $id');
      final actual = _observaciones[indice];
      final editada = AdminObservation(
        id: actual.id,
        clienteId: actual.clienteId,
        autorId: actual.autorId,
        texto: texto,
        creadaEn: actual.creadaEn,
      );
      _observaciones[indice] = editada;
      return editada;
    }

    final nueva = AdminObservation(
      id: 'obs-muestra-${_secuencia++}',
      clienteId: clienteId,
      autorId: 'admin',
      texto: texto,
      creadaEn: DateTime.now(),
    );
    _observaciones.add(nueva);
    return nueva;
  }

  @override
  Future<void> eliminarObservacion(String id) async {
    _observaciones.removeWhere((o) => o.id == id);
  }
}

/// El directorio contra Postgres.
class SupabaseCustomerDirectoryRepository
    implements CustomerDirectoryRepository {
  const SupabaseCustomerDirectoryRepository(this._db);

  final SupabaseClient _db;

  /// La ficha y su nota en una sola consulta. `notas_mascota` tiene la
  /// mascota como clave primaria, así que PostgREST la anida como objeto.
  static const String _camposMascota =
      'id, dueno_id, nombre, raza, edad_anios, peso_kg, foto_path, '
      'notas_mascota(texto, autor_id, actualizada_en)';

  @override
  Future<List<CustomerEntry>> clientes({String busqueda = ''}) async {
    final resultados = await Future.wait([
      _db.rpc<dynamic>('directorio_clientes'),
      _db.from('mascotas').select('id, dueno_id, nombre'),
    ]);

    final mascotasPorDueno = <String, List<PetRef>>{};
    for (final fila in resultados[1] as List<dynamic>) {
      final mapa = fila as Map<String, dynamic>;
      final dueno = mapa['dueno_id'] as String;
      mascotasPorDueno.putIfAbsent(dueno, () => []).add(
            PetRef(id: mapa['id'] as String, nombre: mapa['nombre'] as String),
          );
    }

    final texto = busqueda.trim().toLowerCase();
    final encontrados = <CustomerEntry>[];
    for (final fila in resultados[0] as List<dynamic>) {
      final mapa = fila as Map<String, dynamic>;
      final cliente = CustomerEntry(
        id: mapa['id'] as String,
        nombre: mapa['nombre'] as String?,
        telefono: mapa['telefono'] as String?,
        citas: (mapa['citas'] as num?)?.toInt() ?? 0,
        mascotas: mascotasPorDueno[mapa['id']] ?? const [],
      );
      if (texto.isEmpty ||
          cliente.nombreVisible.toLowerCase().contains(texto) ||
          cliente.telefonoVisible.contains(texto)) {
        encontrados.add(cliente);
      }
    }
    return encontrados;
  }

  /// Se pide la fila de vuelta: un `update` que el RLS no deja pasar no da
  /// error en PostgREST, solo actualiza cero filas.
  @override
  Future<void> actualizarContacto({
    required String clienteId,
    required String nombre,
    required String telefono,
  }) async {
    final filas = await _db
        .from('perfiles')
        .update({'nombre': nombre, 'telefono': telefono})
        .eq('id', clienteId)
        .select('id');
    if (filas.isEmpty) throw const FilaNoActualizadaException();
  }

  @override
  Future<List<PetRecord>> mascotasDe(String clienteId) async {
    final filas = await _db
        .from('mascotas')
        .select(_camposMascota)
        .eq('dueno_id', clienteId)
        .order('nombre');
    return [for (final fila in filas) _mascotaDesdeFila(fila)];
  }

  @override
  Future<PetRecord> guardarMascota(PetRecord mascota) async {
    final datos = {
      'nombre': mascota.nombre,
      'raza': mascota.raza,
      'edad_anios': mascota.edadAnios,
      'peso_kg': mascota.pesoKg,
    };

    final id = mascota.id;
    final List<Map<String, dynamic>> filas;
    if (id == null) {
      filas = await _db
          .from('mascotas')
          .insert({...datos, 'dueno_id': mascota.duenoId})
          .select(_camposMascota);
    } else {
      filas = await _db
          .from('mascotas')
          .update(datos)
          .eq('id', id)
          .select(_camposMascota);
    }
    if (filas.isEmpty) throw const FilaNoActualizadaException();
    return _mascotaDesdeFila(filas.first);
  }

  @override
  Future<PetNote> guardarNotaMascota({
    required String mascotaId,
    required String texto,
  }) async {
    final fila = await _db
        .from('notas_mascota')
        .upsert({
          'mascota_id': mascotaId,
          'texto': texto,
          'autor_id': _db.auth.currentUser!.id,
          'actualizada_en': DateTime.now().toUtc().toIso8601String(),
        })
        .select('texto, autor_id, actualizada_en')
        .single();
    return _notaDesdeFila(fila);
  }

  @override
  Future<List<AdminObservation>> observaciones(String clienteId) async {
    final filas = await _db
        .from('observaciones')
        .select()
        .eq('cliente_id', clienteId)
        .order('creada_en', ascending: false);
    return [for (final fila in filas) _desdeFila(fila)];
  }

  @override
  Future<AdminObservation> guardarObservacion({
    String? id,
    required String clienteId,
    required String texto,
  }) async {
    if (id != null) {
      final fila = await _db
          .from('observaciones')
          .update({'texto': texto})
          .eq('id', id)
          .select()
          .single();
      return _desdeFila(fila);
    }

    final fila = await _db.from('observaciones').insert({
      'cliente_id': clienteId,
      'autor_id': _db.auth.currentUser!.id,
      'texto': texto,
    }).select().single();
    return _desdeFila(fila);
  }

  @override
  Future<void> eliminarObservacion(String id) async {
    await _db.from('observaciones').delete().eq('id', id);
  }

  static const String _bucket = 'fotos-mascotas';

  /// Subir, apuntar y borrar la anterior, en ese orden. Si falla apuntar,
  /// se borra lo subido; si falla borrar la anterior, solo queda un archivo
  /// huérfano, no un dato incoherente.
  @override
  Future<PetRecord> guardarFotoMascota(PetRecord mascota, Uint8List webp) async {
    final id = mascota.id!;
    final ruta = '$id/${DateTime.now().millisecondsSinceEpoch}.webp';
    final almacen = _db.storage.from(_bucket);

    await almacen.uploadBinary(
      ruta,
      webp,
      fileOptions: const FileOptions(contentType: 'image/webp'),
    );

    final List<Map<String, dynamic>> filas;
    try {
      filas = await _db
          .from('mascotas')
          .update({'foto_path': ruta})
          .eq('id', id)
          .select(_camposMascota);
      if (filas.isEmpty) throw const FilaNoActualizadaException();
    } catch (_) {
      await _borrarSinFallar([ruta]);
      rethrow;
    }

    final anterior = mascota.fotoPath;
    if (anterior != null && anterior != ruta) await _borrarSinFallar([anterior]);
    return _mascotaDesdeFila(filas.first);
  }

  @override
  Future<PetRecord> quitarFotoMascota(PetRecord mascota) async {
    final filas = await _db
        .from('mascotas')
        .update({'foto_path': null})
        .eq('id', mascota.id!)
        .select(_camposMascota);
    if (filas.isEmpty) throw const FilaNoActualizadaException();
    final anterior = mascota.fotoPath;
    if (anterior != null) await _borrarSinFallar([anterior]);
    return _mascotaDesdeFila(filas.first);
  }

  /// Se descargan los bytes en vez de usar una URL firmada: no depende de
  /// CORS ni de que la URL caduque, y se pinta con `Image.memory`.
  @override
  Future<Uint8List> fotoDe(String path) =>
      _db.storage.from(_bucket).download(path);

  /// Borrar fotos nunca tumba la operación principal: un fallo aquí deja
  /// un archivo huérfano, privado, que se puede quitar desde el panel.
  Future<void> _borrarSinFallar(List<String> rutas) async {
    if (rutas.isEmpty) return;
    try {
      await _db.storage.from(_bucket).remove(rutas);
    } catch (_) {}
  }

  /// Todo lo de la base ocurre en `eliminar_cliente_admin`, en una
  /// transacción. Las fotos no se pueden borrar desde SQL: se leen sus rutas
  /// antes y se borran después, solo si la eliminación salió bien.
  @override
  Future<void> eliminarCliente(String clienteId) async {
    final filas = await _db
        .from('mascotas')
        .select('foto_path')
        .eq('dueno_id', clienteId)
        .not('foto_path', 'is', null);
    final rutas = [
      for (final fila in filas) fila['foto_path'] as String,
    ];

    await _db.rpc<dynamic>(
      'eliminar_cliente_admin',
      params: {'p_cliente_id': clienteId},
    );

    await _borrarSinFallar(rutas);
  }

  static PetRecord _mascotaDesdeFila(Map<String, dynamic> fila) {
    // Uno a uno llega como objeto; por si PostgREST lo devuelve como lista,
    // se acepta también la primera fila.
    final crudo = fila['notas_mascota'];
    final nota = switch (crudo) {
      final Map<String, dynamic> mapa => mapa,
      final List<dynamic> lista when lista.isNotEmpty =>
        lista.first as Map<String, dynamic>,
      _ => null,
    };

    return PetRecord(
      id: fila['id'] as String,
      duenoId: fila['dueno_id'] as String,
      nombre: fila['nombre'] as String,
      raza: fila['raza'] as String?,
      edadAnios: (fila['edad_anios'] as num?)?.toInt(),
      pesoKg: (fila['peso_kg'] as num?)?.toDouble(),
      nota: nota == null ? null : _notaDesdeFila(nota),
      fotoPath: fila['foto_path'] as String?,
    );
  }

  static PetNote _notaDesdeFila(Map<String, dynamic> fila) => PetNote(
        texto: fila['texto'] as String,
        autorId: fila['autor_id'] as String?,
        actualizadaEn:
            enHoraEstetica(DateTime.parse(fila['actualizada_en'] as String)),
      );

  static AdminObservation _desdeFila(Map<String, dynamic> fila) =>
      AdminObservation(
        id: fila['id'] as String,
        clienteId: fila['cliente_id'] as String,
        autorId: fila['autor_id'] as String,
        texto: fila['texto'] as String,
        // El reloj de la estética, no el del dispositivo.
        creadaEn: enHoraEstetica(DateTime.parse(fila['creada_en'] as String)),
      );
}

CustomerDirectoryRepository defaultCustomerDirectoryRepository() {
  if (!AppConfig.hasSupabase) return SampleCustomerDirectoryRepository();
  return SupabaseCustomerDirectoryRepository(Supabase.instance.client);
}
