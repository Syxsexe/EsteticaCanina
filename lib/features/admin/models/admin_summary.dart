import 'agenda_entry.dart';

/// Un servicio con cuántas veces se pidió en el mes.
class ServiceCount {
  const ServiceCount({required this.name, required this.count});

  final String name;
  final int count;
}

/// Las métricas de un mes, calculadas igual para el mes en curso y para un
/// mes pasado.
class MetricasMes {
  const MetricasMes({
    required this.totalCitas,
    required this.canceladas,
    required this.canceladasPct,
    required this.ingresosCop,
    required this.noAsistenciaPct,
    required this.topServicios,
  });

  /// Las citas no canceladas.
  final int totalCitas;

  /// Las citas canceladas del mes. No entran en ninguna otra métrica.
  final int canceladas;

  /// Porcentaje entero de canceladas sobre todo lo agendado en el mes,
  /// canceladas incluidas. Cero si el mes no tiene citas.
  final int canceladasPct;

  /// La suma de las citas cumplidas.
  final int ingresosCop;

  /// Porcentaje entero de 0 a 100. Cero cuando no hay citas cerradas.
  final int noAsistenciaPct;

  /// Hasta tres, por cantidad y luego por nombre.
  final List<ServiceCount> topServicios;
}

/// Calcula las métricas de [citasDelMes], que ya tienen que estar filtradas
/// al mes: esta función no mira fechas.
MetricasMes metricasDelMes(List<AgendaEntry> citasDelMes) {
  final activas = [
    for (final cita in citasDelMes)
      if (cita.estado != EstadoCita.cancelada) cita,
  ];

  final ingresos = citasDelMes
      .where((c) => c.estado == EstadoCita.cumplida)
      .fold(0, (total, c) => total + c.totalCop);

  final cumplidas =
      citasDelMes.where((c) => c.estado == EstadoCita.cumplida).length;
  final noAsistio =
      citasDelMes.where((c) => c.estado == EstadoCita.noAsistio).length;
  final cerradas = cumplidas + noAsistio;
  final noAsistenciaPct =
      cerradas == 0 ? 0 : ((noAsistio * 100) / cerradas).round();

  final conteo = <String, int>{};
  for (final cita in activas) {
    for (final servicio in cita.servicios) {
      conteo[servicio] = (conteo[servicio] ?? 0) + 1;
    }
  }
  final top = conteo.entries.toList()
    ..sort((a, b) {
      final porCantidad = b.value.compareTo(a.value);
      return porCantidad != 0 ? porCantidad : a.key.compareTo(b.key);
    });

  final canceladas = citasDelMes.length - activas.length;
  final canceladasPct = citasDelMes.isEmpty
      ? 0
      : ((canceladas * 100) / citasDelMes.length).round();

  return MetricasMes(
    totalCitas: activas.length,
    canceladas: canceladas,
    canceladasPct: canceladasPct,
    ingresosCop: ingresos,
    noAsistenciaPct: noAsistenciaPct,
    topServicios: [
      for (final entry in top.take(3))
        ServiceCount(name: entry.key, count: entry.value),
    ],
  );
}

/// Lo que se ve en la pestaña Resumen.
///
/// El cálculo es puro a propósito: la pantalla recibe números ya resueltos y
/// los tests pueden fijar la fecha sin tocar la red ni el reloj.
class AdminSummary {
  const AdminSummary({
    required this.citasHoy,
    required this.citasSemana,
    required this.ingresosMesCop,
    required this.noAsistenciaPct,
    required this.clientesNuevosMes,
    required this.topServicios,
    required this.proximas,
    this.canceladasMes = 0,
    this.canceladasPct = 0,
  });

  final int citasHoy;
  final int citasSemana;
  final int ingresosMesCop;

  /// Porcentaje entero de 0 a 100. Cero cuando no hay citas cerradas.
  final int noAsistenciaPct;

  final int clientesNuevosMes;
  final List<ServiceCount> topServicios;
  final List<AgendaEntry> proximas;

  /// Las citas canceladas del mes y su porcentaje sobre lo agendado.
  final int canceladasMes;
  final int canceladasPct;

  /// Arma el resumen a partir de las citas del mes y de la semana.
  ///
  /// [hoy] es el día de Bogotá. [citas] tiene que incluir el mes en curso y
  /// toda la semana en curso, aunque la semana empiece en el mes anterior o
  /// termine en el siguiente; el repositorio se encarga. Las métricas del mes
  /// se calculan solo con las citas cuyo día cae en el mes de [hoy]: si no,
  /// el 30 de noviembre contaría como ingreso de diciembre.
  factory AdminSummary.fromData({
    required List<AgendaEntry> citas,
    required DateTime hoy,
    required int clientesNuevos,
    required List<AgendaEntry> proximas,
  }) {
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    final lunes = dia.subtract(Duration(days: dia.weekday - 1));
    final domingo = lunes.add(const Duration(days: 7));

    final activas = [
      for (final cita in citas)
        if (cita.estado != EstadoCita.cancelada) cita,
    ];

    final mes = [
      for (final cita in citas)
        if (cita.empieza.year == dia.year && cita.empieza.month == dia.month)
          cita,
    ];
    final citasHoy = activas.where((c) => _mismoDia(c.empieza, dia)).length;
    final citasSemana = activas
        .where(
          (c) =>
              !_pared(c.empieza).isBefore(_pared(lunes)) &&
              _pared(c.empieza).isBefore(_pared(domingo)),
        )
        .length;

    final metricas = metricasDelMes(mes);

    return AdminSummary(
      citasHoy: citasHoy,
      citasSemana: citasSemana,
      ingresosMesCop: metricas.ingresosCop,
      canceladasMes: metricas.canceladas,
      canceladasPct: metricas.canceladasPct,
      noAsistenciaPct: metricas.noAsistenciaPct,
      clientesNuevosMes: clientesNuevos,
      topServicios: metricas.topServicios,
      proximas: proximas.take(5).toList(),
    );
  }

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Compara el reloj de pared de Bogotá sin importar si el [DateTime] llega
  /// marcado como UTC (las filas de Postgres) o como local (los datos de
  /// muestra y los tests). Restar dos instantes con marcas distintas
  /// desplazaría la semana por el desfase del dispositivo.
  static DateTime _pared(DateTime valor) =>
      DateTime.utc(valor.year, valor.month, valor.day, valor.hour, valor.minute);
}
