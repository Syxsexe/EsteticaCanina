import 'admin_summary.dart';
import 'agenda_entry.dart';

/// El resumen de un mes ya pasado: sus métricas y todas sus citas.
///
/// No tiene "hoy", "semana" ni "próximas": en un mes cerrado no significan
/// nada. Las métricas salen de [metricasDelMes], igual que las del mes en
/// curso, para que un mismo mes dé los mismos números en las dos vistas.
class MonthSummary {
  const MonthSummary({
    required this.mes,
    required this.totalCitas,
    required this.canceladas,
    required this.canceladasPct,
    required this.ingresosCop,
    required this.noAsistenciaPct,
    required this.clientesNuevos,
    required this.topServicios,
    required this.citas,
  });

  /// El primer día del mes.
  final DateTime mes;

  /// Las citas no canceladas.
  final int totalCitas;

  /// Las canceladas y su porcentaje sobre todo lo agendado en el mes.
  final int canceladas;
  final int canceladasPct;

  final int ingresosCop;
  final int noAsistenciaPct;
  final int clientesNuevos;
  final List<ServiceCount> topServicios;

  /// Todas las citas del mes, canceladas incluidas, en orden de inicio.
  final List<AgendaEntry> citas;

  /// Arma el resumen de [mes] con las [citas] recibidas.
  ///
  /// Se queda solo con las que caen en ese mes según el reloj de pared de
  /// Bogotá: las filas de Postgres ya llegan convertidas, así que la cita
  /// del 31 de octubre a las 20:00 es de octubre aunque en UTC sea noviembre.
  factory MonthSummary.fromData({
    required DateTime mes,
    required List<AgendaEntry> citas,
    required int clientesNuevos,
  }) {
    final delMes = [
      for (final cita in citas)
        if (cita.empieza.year == mes.year && cita.empieza.month == mes.month)
          cita,
    ]..sort((a, b) => a.empieza.compareTo(b.empieza));

    final metricas = metricasDelMes(delMes);

    return MonthSummary(
      mes: DateTime(mes.year, mes.month),
      totalCitas: metricas.totalCitas,
      canceladas: metricas.canceladas,
      canceladasPct: metricas.canceladasPct,
      ingresosCop: metricas.ingresosCop,
      noAsistenciaPct: metricas.noAsistenciaPct,
      clientesNuevos: clientesNuevos,
      topServicios: metricas.topServicios,
      citas: delMes,
    );
  }
}
