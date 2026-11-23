import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/time/salon_time.dart';
import '../models/admin_summary.dart';
import '../models/agenda_entry.dart';
import '../models/month_summary.dart';
import 'agenda_repository.dart';

/// Las métricas de la pestaña Resumen.
abstract interface class AnalyticsRepository {
  /// El mes en curso, con hoy, la semana y las próximas citas.
  Future<AdminSummary> resumen();

  /// Los meses que se pueden revisar: el primer día de cada uno, del mes en
  /// curso hacia atrás hasta el de la cita más antigua. Incluye los meses
  /// sin citas que queden en medio.
  Future<List<DateTime>> mesesDisponibles();

  /// Las métricas y las citas de un mes ya pasado.
  Future<MonthSummary> resumenDelMes(DateTime mes);
}

/// Los meses de [hoy] hacia atrás hasta el de [primera], ambos incluidos.
/// Sin [primera], o si es posterior a hoy, solo el mes en curso.
List<DateTime> mesesEntre({required DateTime? primera, required DateTime hoy}) {
  final actual = DateTime(hoy.year, hoy.month);
  if (primera == null) return [actual];
  final tope = DateTime(primera.year, primera.month);
  final meses = <DateTime>[];
  for (var mes = actual;
      !mes.isBefore(tope);
      mes = DateTime(mes.year, mes.month - 1)) {
    meses.add(mes);
  }
  return meses.isEmpty ? [actual] : meses;
}

/// Datos de muestra para la app sin credenciales y para los tests.
class SampleAnalyticsRepository implements AnalyticsRepository {
  /// [historico] son las citas de los meses pasados. Sin él, se generan
  /// citas para los dos meses anteriores al actual.
  SampleAnalyticsRepository({DateTime? hoy, this.historico})
      : _hoy = hoy ?? hoyEnLaEstetica();

  final DateTime _hoy;
  final List<AgendaEntry>? historico;

  List<AgendaEntry> get _citasPasadas => historico ?? _historicoDeMuestra();

  List<AgendaEntry> _historicoDeMuestra() {
    final citas = <AgendaEntry>[];
    for (var atras = 1; atras <= 2; atras++) {
      final mes = DateTime(_hoy.year, _hoy.month - atras);
      for (var i = 0; i < 6; i++) {
        citas.add(_cita(
          id: 'muestra-${mes.month}-$i',
          empieza: DateTime(mes.year, mes.month, 3 + i * 4, 9 + i % 3),
          estado: switch (i % 6) {
            4 => EstadoCita.noAsistio,
            5 => EstadoCita.cancelada,
            _ => EstadoCita.cumplida,
          },
          total: i.isEven ? 35000 : 40000,
          servicios: i.isEven ? const ['Baño'] : const ['Corte completo'],
        ));
      }
    }
    return citas;
  }

  @override
  Future<List<DateTime>> mesesDisponibles() async {
    final citas = _citasPasadas;
    DateTime? primera;
    for (final cita in citas) {
      if (primera == null || cita.empieza.isBefore(primera)) {
        primera = cita.empieza;
      }
    }
    return mesesEntre(primera: primera, hoy: _hoy);
  }

  @override
  Future<MonthSummary> resumenDelMes(DateTime mes) async =>
      MonthSummary.fromData(mes: mes, citas: _citasPasadas, clientesNuevos: 1);

  @override
  Future<AdminSummary> resumen() async {
    final dia = DateTime(_hoy.year, _hoy.month, _hoy.day);
    final citas = [
      _cita(
        id: 'muestra-hoy-1',
        empieza: dia.add(const Duration(hours: 9)),
        estado: EstadoCita.cumplida,
        total: 35000,
        servicios: const ['Baño'],
      ),
      _cita(
        id: 'muestra-hoy-2',
        empieza: dia.add(const Duration(hours: 11)),
        estado: EstadoCita.reservada,
        total: 40000,
        servicios: const ['Corte completo'],
      ),
      _cita(
        id: 'muestra-manana',
        empieza: dia.add(const Duration(days: 1, hours: 10)),
        estado: EstadoCita.reservada,
        total: 45000,
        servicios: const ['Visita de cachorro'],
      ),
      _cita(
        id: 'muestra-ausente',
        empieza: dia.subtract(const Duration(days: 2)).add(
              const Duration(hours: 15),
            ),
        estado: EstadoCita.noAsistio,
        total: 35000,
        servicios: const ['Baño'],
      ),
      for (var i = 0; i < 6; i++)
        _cita(
          id: 'muestra-futura-$i',
          empieza: dia.add(Duration(days: 2 + i, hours: 8)),
          estado: EstadoCita.reservada,
          total: 35000,
          servicios: const ['Baño'],
        ),
    ];
    final proximas = [
      for (final cita in citas)
        if (cita.estado == EstadoCita.reservada && cita.empieza.isAfter(dia))
          cita,
    ]..sort((a, b) => a.empieza.compareTo(b.empieza));

    return AdminSummary.fromData(
      citas: citas,
      hoy: dia,
      clientesNuevos: 2,
      proximas: proximas,
    );
  }

  static AgendaEntry _cita({
    required String id,
    required DateTime empieza,
    required EstadoCita estado,
    required int total,
    required List<String> servicios,
  }) =>
      AgendaEntry(
        id: id,
        empieza: empieza,
        minutos: 60,
        estado: estado,
        totalCop: total,
        clienteNombre: 'Ana',
        mascotaNombre: 'Toby',
        servicios: servicios,
        servicioIds: const ['bano'],
      );
}

/// Las métricas contra Postgres.
class SupabaseAnalyticsRepository implements AnalyticsRepository {
  const SupabaseAnalyticsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<AdminSummary> resumen() async {
    final hoy = hoyEnLaEstetica();
    final inicioMes = DateTime(hoy.year, hoy.month, 1);
    final finMes = DateTime(hoy.year, hoy.month + 1, 1);
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
    final domingo = lunes.add(const Duration(days: 7));

    // La semana puede empezar en el mes anterior y terminar en el siguiente.
    final desde = lunes.isBefore(inicioMes) ? lunes : inicioMes;
    final hasta = domingo.isAfter(finMes) ? domingo : finMes;

    final resultados = await Future.wait<dynamic>([
      _db
          .from('citas')
          .select(agendaCampos)
          .gte('empieza', desdeHoraEstetica(desde).toIso8601String())
          .lt('empieza', desdeHoraEstetica(hasta).toIso8601String())
          .order('empieza'),
      _db
          .from('citas')
          .select(agendaCampos)
          .eq('estado', 'reservada')
          .gte('empieza', DateTime.now().toUtc().toIso8601String())
          .order('empieza')
          .limit(5),
      _db.rpc<dynamic>('clientes_nuevos_mes'),
    ]);

    final citas = [
      for (final fila in resultados[0] as List<dynamic>)
        agendaEntryDesdeFila(fila as Map<String, dynamic>),
    ];
    final proximas = [
      for (final fila in resultados[1] as List<dynamic>)
        agendaEntryDesdeFila(fila as Map<String, dynamic>),
    ];
    final nuevos = (resultados[2] as num?)?.toInt() ?? 0;

    return AdminSummary.fromData(
      citas: citas,
      hoy: hoy,
      clientesNuevos: nuevos,
      proximas: proximas,
    );
  }

  @override
  Future<List<DateTime>> mesesDisponibles() async {
    final filas = await _db
        .from('citas')
        .select('empieza')
        .order('empieza')
        .limit(1);
    final primera = filas.isEmpty
        ? null
        : enHoraEstetica(DateTime.parse(filas.first['empieza'] as String));
    return mesesEntre(primera: primera, hoy: hoyEnLaEstetica());
  }

  @override
  Future<MonthSummary> resumenDelMes(DateTime mes) async {
    final inicio = DateTime(mes.year, mes.month);
    final siguiente = DateTime(mes.year, mes.month + 1);

    final resultados = await Future.wait<dynamic>([
      _db
          .from('citas')
          .select(agendaCampos)
          .gte('empieza', desdeHoraEstetica(inicio).toIso8601String())
          .lt('empieza', desdeHoraEstetica(siguiente).toIso8601String())
          .order('empieza'),
      _db.rpc<dynamic>('clientes_nuevos_en', params: {
        // Solo la fecha: la función corta el mes en hora de Bogotá.
        'p_mes': '${inicio.year.toString().padLeft(4, '0')}-'
            '${inicio.month.toString().padLeft(2, '0')}-01',
      }),
    ]);

    return MonthSummary.fromData(
      mes: inicio,
      citas: [
        for (final fila in resultados[0] as List<dynamic>)
          agendaEntryDesdeFila(fila as Map<String, dynamic>),
      ],
      clientesNuevos: (resultados[1] as num?)?.toInt() ?? 0,
    );
  }
}

AnalyticsRepository defaultAnalyticsRepository() {
  if (!AppConfig.hasSupabase) return SampleAnalyticsRepository();
  return SupabaseAnalyticsRepository(Supabase.instance.client);
}
