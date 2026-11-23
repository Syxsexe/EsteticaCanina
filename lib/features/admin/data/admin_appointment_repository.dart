import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/time/salon_time.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/data/service_catalog.dart';
import '../models/agenda_entry.dart';
import 'agenda_repository.dart';
import 'customer_directory_repository.dart';

/// La base rechazó la cita por una regla del negocio: servicios inválidos,
/// día cerrado, fuera del horario... [motivo] es el texto de la base, que
/// ya está escrito para mostrarse tal cual.
class CitaRechazadaException implements Exception {
  const CitaRechazadaException(this.motivo);

  final String motivo;

  @override
  String toString() => motivo;
}

/// La base no actualizó la cita: no existe o la cuenta no tiene permiso.
class CitaNoActualizadaException implements Exception {
  const CitaNoActualizadaException();

  @override
  String toString() => 'La cita no se actualizó en la base.';
}

/// Las citas vistas desde el panel: historial, edición y creación.
abstract interface class AdminAppointmentRepository {
  /// Todas las citas, de la más reciente a la más antigua.
  Future<List<AgendaEntry>> historial();

  /// Las citas de un cliente, de la más reciente a la más antigua. Se
  /// filtran en la base: el detalle de un cliente no baja la estética entera.
  Future<List<AgendaEntry>> historialDe(String clienteId);

  Future<void> editar({
    required String citaId,
    required DateTime empieza,
    required String? mascotaId,
    required List<String> servicios,
    required EstadoCita estado,
    required String? notas,
  });

  Future<void> cancelar(String citaId);

  Future<String> crear({
    required String clienteId,
    required String? mascotaId,
    required DateTime empieza,
    required List<String> servicios,
  });

  /// Crea la cita a nombre del cliente con ese celular, con la misma regla
  /// que la reserva de la app: si no existe, se crea sin cuenta; si existe,
  /// se usa y no se le cambia el nombre. La mascota se busca por nombre y se
  /// registra si falta. Todo en una sola operación.
  Future<String> crearPorCelular({
    required String nombre,
    required String telefono,
    required String mascotaNombre,
    required DateTime empieza,
    required List<String> servicios,
  });
}

/// Las citas de muestra, en memoria.
class SampleAdminAppointmentRepository implements AdminAppointmentRepository {
  /// [directorio] es el directorio de muestra donde `crearPorCelular` busca
  /// o registra al cliente y a la mascota. Sin él, inventa un id por celular.
  SampleAdminAppointmentRepository({
    DateTime? hoy,
    this.directorio,
  }) : _hoy = hoy ?? hoyEnLaEstetica() {
    final dia = DateTime(_hoy.year, _hoy.month, _hoy.day);
    _citas = [
      AgendaEntry(
        id: 'muestra-1',
        clienteId: 'cliente-ana',
        empieza: dia.subtract(const Duration(days: 1)).add(
              const Duration(hours: 10),
            ),
        minutos: 60,
        estado: EstadoCita.cumplida,
        totalCop: 35000,
        clienteNombre: 'Ana',
        clienteTelefono: '+573001112233',
        mascotaId: 'mascota-toby',
        mascotaNombre: 'Toby',
        servicios: const ['Baño'],
        servicioIds: const ['bano'],
        notasEstilista: 'Se porta bien con el secador.',
      ),
      AgendaEntry(
        id: 'muestra-2',
        clienteId: 'cliente-luis',
        empieza: dia.add(const Duration(hours: 14, minutes: 30)),
        minutos: 120,
        estado: EstadoCita.reservada,
        totalCop: 40000,
        clienteNombre: 'Luis',
        clienteTelefono: '+573004445566',
        mascotaNombre: 'Canela',
        servicios: const ['Corte completo'],
        servicioIds: const ['corte_completo'],
      ),
    ];
  }

  final DateTime _hoy;
  final SampleCustomerDirectoryRepository? directorio;
  late List<AgendaEntry> _citas;
  int _secuencia = 0;

  @override
  Future<List<AgendaEntry>> historial() async {
    final copia = List<AgendaEntry>.from(_citas)
      ..sort((a, b) => b.empieza.compareTo(a.empieza));
    return copia;
  }

  @override
  Future<List<AgendaEntry>> historialDe(String clienteId) async => [
        for (final cita in await historial())
          if (cita.clienteId == clienteId) cita,
      ];

  @override
  Future<void> editar({
    required String citaId,
    required DateTime empieza,
    required String? mascotaId,
    required List<String> servicios,
    required EstadoCita estado,
    required String? notas,
  }) async {
    final indice = _citas.indexWhere((c) => c.id == citaId);
    if (indice < 0) throw StateError('Cita desconocida: $citaId');

    final elegidos = [
      for (final s in ServiceCatalog.todos)
        if (servicios.contains(s.id)) s,
    ];
    final minutos = elegidos.fold(0, (total, s) => total + s.minutes);
    final total = elegidos.fold(0, (suma, s) => suma + s.price);

    _citas[indice] = _citas[indice].copyWith(
      empieza: empieza,
      minutos: minutos,
      totalCop: total,
      estado: estado,
      mascotaId: mascotaId,
      servicios: [for (final s in elegidos) s.name],
      servicioIds: servicios,
      notasEstilista: notas,
    );
  }

  @override
  Future<void> cancelar(String citaId) async {
    final indice = _citas.indexWhere((c) => c.id == citaId);
    if (indice < 0) throw StateError('Cita desconocida: $citaId');
    _citas[indice] = _citas[indice].copyWith(estado: EstadoCita.cancelada);
  }

  @override
  Future<String> crear({
    required String clienteId,
    required String? mascotaId,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    final elegidos = [
      for (final s in ServiceCatalog.todos)
        if (servicios.contains(s.id)) s,
    ];
    final id = 'muestra-nueva-${_secuencia++}';
    _citas.add(
      AgendaEntry(
        id: id,
        clienteId: clienteId,
        empieza: empieza,
        minutos: elegidos.fold(0, (total, s) => total + s.minutes),
        estado: EstadoCita.reservada,
        totalCop: elegidos.fold(0, (total, s) => total + s.price),
        mascotaId: mascotaId,
        servicios: [for (final s in elegidos) s.name],
        servicioIds: servicios,
      ),
    );
    return id;
  }

  @override
  Future<String> crearPorCelular({
    required String nombre,
    required String telefono,
    required String mascotaNombre,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    final directorio = this.directorio;
    final (clienteId, mascotaId) = directorio == null
        ? ('cliente-$telefono', null)
        : await directorio.registrarPorCelular(
            nombre: nombre,
            telefono: telefono,
            mascota: mascotaNombre,
          );
    return crear(
      clienteId: clienteId,
      mascotaId: mascotaId,
      empieza: empieza,
      servicios: servicios,
    );
  }
}

/// Las citas contra Postgres.
class SupabaseAdminAppointmentRepository
    implements AdminAppointmentRepository {
  const SupabaseAdminAppointmentRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<AgendaEntry>> historial() async {
    final filas = await _db
        .from('citas')
        .select(agendaCampos)
        .order('empieza', ascending: false);
    return [for (final fila in filas) agendaEntryDesdeFila(fila)];
  }

  @override
  Future<List<AgendaEntry>> historialDe(String clienteId) async {
    final filas = await _db
        .from('citas')
        .select(agendaCampos)
        .eq('cliente_id', clienteId)
        .order('empieza', ascending: false);
    return [for (final fila in filas) agendaEntryDesdeFila(fila)];
  }

  @override
  Future<void> editar({
    required String citaId,
    required DateTime empieza,
    required String? mascotaId,
    required List<String> servicios,
    required EstadoCita estado,
    required String? notas,
  }) async {
    try {
      await _db.rpc<dynamic>('editar_cita_admin', params: {
        'p_cita_id': citaId,
        'p_empieza': empieza.toUtc().toIso8601String(),
        'p_mascota_id': mascotaId,
        'p_servicios': servicios,
        'p_estado': estado.enBase,
        'p_notas': notas,
      });
    } on PostgrestException catch (error) {
      throw _traducir(error);
    }
  }

  /// Se pide la fila de vuelta porque un `update` que el RLS no deja pasar,
  /// o con un id que no existe, no da error en PostgREST: actualiza cero
  /// filas y calla. Sin esto la pantalla diría "cancelada" sin serlo.
  @override
  Future<void> cancelar(String citaId) async {
    final filas = await _db
        .from('citas')
        .update({'estado': EstadoCita.cancelada.enBase})
        .eq('id', citaId)
        .select('id');
    if (filas.isEmpty) throw const CitaNoActualizadaException();
  }

  @override
  Future<String> crear({
    required String clienteId,
    required String? mascotaId,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    try {
      final id = await _db.rpc<dynamic>('reservar_cita_admin', params: {
        'p_cliente_id': clienteId,
        'p_mascota_id': mascotaId,
        'p_empieza': empieza.toUtc().toIso8601String(),
        'p_servicios': servicios,
      });
      return id.toString();
    } on PostgrestException catch (error) {
      throw _traducir(error);
    }
  }

  @override
  Future<String> crearPorCelular({
    required String nombre,
    required String telefono,
    required String mascotaNombre,
    required DateTime empieza,
    required List<String> servicios,
  }) async {
    // La misma función que usa la reserva de la app: la regla de quién es
    // el cliente vive en un solo sitio.
    try {
      final id = await _db.rpc<dynamic>('reservar_cita_por_celular', params: {
        'p_nombre': nombre,
        'p_telefono': telefono,
        'p_mascota_nombre': mascotaNombre,
        'p_empieza': empieza.toUtc().toIso8601String(),
        'p_servicios': servicios,
      });
      return id.toString();
    } on PostgrestException catch (error) {
      throw _traducir(error);
    }
  }

  static const String _choque = '23P01';

  /// Los rechazos de regla que las funciones lanzan con `raise exception`
  /// (código `P0001`) o por datos inválidos (`22023`). Su mensaje ya está
  /// escrito para la estética: "La cita necesita exactamente un servicio
  /// principal", "Ese día la estética está cerrada"...
  static const Set<String> _reglas = {'P0001', '22023'};

  static Object _traducir(PostgrestException error) {
    if (error.code == _choque) return const SlotTakenException();
    if (_reglas.contains(error.code)) return CitaRechazadaException(error.message);
    return error;
  }
}

AdminAppointmentRepository defaultAdminAppointmentRepository() {
  if (!AppConfig.hasSupabase) return SampleAdminAppointmentRepository();
  return SupabaseAdminAppointmentRepository(Supabase.instance.client);
}
