import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../models/agenda_entry.dart';

/// La agenda desde el lado de la estética.
///
/// Todo lo que hay aquí exige ser administradora. No se comprueba en el
/// cliente: las políticas de Postgres devuelven una lista vacía a quien no
/// lo sea, y rechazan sus escrituras. La pantalla solo necesita saber
/// pedirlo.
abstract interface class AgendaRepository {
  /// Las citas de un día, en orden de hora.
  Future<List<AgendaEntry>> citasDe(DateTime dia);

  /// Deja constancia de qué pasó con una cita.
  Future<void> marcar(String citaId, EstadoCita estado);
}

/// Dos citas de muestra, para ver la pantalla sin backend y para los tests.
class SampleAgendaRepository implements AgendaRepository {
  SampleAgendaRepository();

  final Map<String, EstadoCita> _marcadas = {};

  @override
  Future<List<AgendaEntry>> citasDe(DateTime dia) async {
    final base = DateTime(dia.year, dia.month, dia.day);
    if (base.weekday >= DateTime.saturday) return [];

    return [
      AgendaEntry(
        id: 'muestra-1',
        empieza: base.add(const Duration(hours: 8)),
        minutos: 60,
        estado: _marcadas['muestra-1'] ?? EstadoCita.reservada,
        totalCop: 45000,
        clienteNombre: 'Ana',
        clienteTelefono: '+573001112233',
        mascotaNombre: 'Toby',
        servicios: const ['Baño', 'Corte de uñas'],
      ),
      AgendaEntry(
        id: 'muestra-2',
        empieza: base.add(const Duration(hours: 14, minutes: 30)),
        minutos: 120,
        estado: _marcadas['muestra-2'] ?? EstadoCita.reservada,
        totalCop: 40000,
        clienteNombre: 'Luis',
        clienteTelefono: '+573004445566',
        mascotaNombre: 'Canela',
        servicios: const ['Corte completo'],
        notasEstilista: 'Se incomoda con el secador cerca de las orejas.',
      ),
    ];
  }

  @override
  Future<void> marcar(String citaId, EstadoCita estado) async {
    _marcadas[citaId] = estado;
  }
}

/// La agenda real.
class SupabaseAgendaRepository implements AgendaRepository {
  const SupabaseAgendaRepository(this._db);

  final SupabaseClient _db;

  /// Lo que se pide de cada cita.
  ///
  /// PostgREST permite anidar: de la cita cuelgan el perfil, la mascota y
  /// los servicios, y de cada servicio su nombre. Todo en una consulta, y
  /// con el RLS aplicado en cada nivel — a quien no sea administradora
  /// esto le devuelve una lista vacía.
  static const String _campos = 'id, empieza, minutos, estado, total_cop, '
      'notas_estilista, perfiles(nombre, telefono), mascotas(nombre), '
      'cita_servicios(servicios(nombre))';

  @override
  Future<List<AgendaEntry>> citasDe(DateTime dia) async {
    final desde = DateTime(dia.year, dia.month, dia.day);
    final hasta = DateTime(dia.year, dia.month, dia.day + 1);

    final filas = await _db
        .from('citas')
        .select(_campos)
        .gte('empieza', desde.toUtc().toIso8601String())
        .lt('empieza', hasta.toUtc().toIso8601String())
        .order('empieza');

    return [for (final fila in filas) _desdeFila(fila)];
  }

  @override
  Future<void> marcar(String citaId, EstadoCita estado) async {
    await _db
        .from('citas')
        .update({'estado': estado.enBase}).eq('id', citaId);
  }

  static AgendaEntry _desdeFila(Map<String, dynamic> fila) {
    final perfil = fila['perfiles'] as Map<String, dynamic>?;
    final mascota = fila['mascotas'] as Map<String, dynamic>?;
    final servicios = (fila['cita_servicios'] as List<dynamic>? ?? const [])
        .map((e) => (e as Map<String, dynamic>)['servicios'])
        .whereType<Map<String, dynamic>>()
        .map((s) => s['nombre'] as String)
        .toList();

    return AgendaEntry(
      id: fila['id'] as String,
      // Postgres manda el instante absoluto; la agenda se lee en la hora
      // de la estética, que es la del dispositivo.
      empieza: DateTime.parse(fila['empieza'] as String).toLocal(),
      minutos: fila['minutos'] as int,
      estado: EstadoCita.desde(fila['estado'] as String),
      totalCop: fila['total_cop'] as int,
      clienteNombre: perfil?['nombre'] as String?,
      clienteTelefono: perfil?['telefono'] as String?,
      mascotaNombre: mascota?['nombre'] as String?,
      servicios: servicios,
      notasEstilista: fila['notas_estilista'] as String?,
    );
  }
}

/// La agenda que usa la app: Postgres si hay credenciales, muestra si no.
AgendaRepository defaultAgendaRepository() {
  if (!AppConfig.hasSupabase) return SampleAgendaRepository();
  return SupabaseAgendaRepository(Supabase.instance.client);
}
