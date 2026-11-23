import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/salon_time.dart';
import '../assistant/data/asistente_repository.dart';
import 'data/analytics_repository.dart';
import 'models/admin_summary.dart';
import 'models/month_summary.dart';
import 'pestana_recargable.dart';
import 'widgets/estado_cita_chip.dart';

/// La pestaña Resumen: cómo va la estética de un vistazo.
///
/// Un desplegable elige el mes. El mes en curso muestra hoy, la semana y lo
/// que viene; un mes pasado muestra sus métricas y todas sus citas.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({
    super.key,
    required this.repository,
    this.hoy,
    this.asistenteRepository,
  });

  final AnalyticsRepository repository;

  /// Se inyecta en los tests; en la app es hoy en Bogotá.
  final DateTime? hoy;

  /// Quién escribe el "Resumen con IA". Se inyecta en las pruebas.
  final AsistenteRepository? asistenteRepository;

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    implements PestanaRecargable {
  /// El primer día del mes en curso, en Bogotá.
  late final DateTime _actual;

  /// El mes que se está viendo. Se conserva al recargar y al reintentar.
  late DateTime _mes;

  /// Las opciones del desplegable. Solo el mes en curso hasta que llegan, o
  /// si no se pudieron traer: la lista es un extra, el presente no depende
  /// de ella.
  late List<DateTime> _meses;

  AdminSummary? _resumen;
  MonthSummary? _delMes;
  Object? _fallo;

  bool get _esMesActual => _mes == _actual;

  @override
  void initState() {
    super.initState();
    final hoy = widget.hoy ?? hoyEnLaEstetica();
    _actual = DateTime(hoy.year, hoy.month);
    _mes = _actual;
    _meses = [_actual];
    _cargar();
  }

  @override
  Future<void> recargar() => _cargar();

  void _elegirMes(DateTime? mes) {
    if (mes == null || mes == _mes) return;
    setState(() => _mes = mes);
    _cargar();
  }

  Future<void> _cargar() async {
    final mes = _mes;
    setState(() {
      _resumen = null;
      _delMes = null;
      _fallo = null;
    });

    // La lista de meses se vuelve a pedir en cada carga: si cambió el día,
    // puede haber un mes nuevo. Si falla, queda el mes en curso.
    final meses = widget.repository.mesesDisponibles().then(
          (lista) => lista.isEmpty ? [_actual] : lista,
          onError: (Object _) => [_actual],
        );

    try {
      if (mes == _actual) {
        final resumen = await widget.repository.resumen();
        final lista = await meses;
        if (!mounted || mes != _mes) return;
        setState(() {
          _resumen = resumen;
          _meses = lista;
        });
      } else {
        final delMes = await widget.repository.resumenDelMes(mes);
        final lista = await meses;
        if (!mounted || mes != _mes) return;
        setState(() {
          _delMes = delMes;
          _meses = lista.contains(mes) ? lista : [...lista, mes];
        });
      }
    } catch (error) {
      if (!mounted || mes != _mes) return;
      setState(() => _fallo = error);
    }
  }

  /// El desplegable de meses, arriba de todo.
  Widget _selectorDeMes() {
    return DropdownButton<DateTime>(
      key: const Key('selector-mes'),
      value: _meses.contains(_mes) ? _mes : null,
      isExpanded: true,
      onChanged: _elegirMes,
      items: [
        for (final mes in _meses)
          DropdownMenuItem(
            value: mes,
            child: Text(
              '${formatMonth(mes)} ${mes.year}'
              '${mes == _actual ? ' (este mes)' : ''}',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fallo != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _selectorDeMes(),
              const SizedBox(height: 16),
              const Text(
                'No pudimos traer las estadísticas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_esMesActual) {
      final resumen = _resumen;
      if (resumen == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _vistaMesActual(resumen);
    }

    final delMes = _delMes;
    if (delMes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _vistaMesPasado(delMes);
  }

  Widget _vistaMesActual(AdminSummary resumen) {
    final hoy = widget.hoy ?? hoyEnLaEstetica();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _selectorDeMes(),
          const SizedBox(height: 8),
          Text(formatLongDate(hoy), style: Theme.of(context).textTheme.titleMedium),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _HojaResumenIa(
                  repository: widget.asistenteRepository ??
                      defaultAsistenteRepository(),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Resumen con IA'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  etiqueta: 'Citas hoy',
                  valor: '${resumen.citasHoy}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  etiqueta: 'Citas semana',
                  valor: '${resumen.citasSemana}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  etiqueta: 'Ingresos del mes',
                  valor: formatCop(resumen.ingresosMesCop),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  etiqueta: 'No asistió',
                  valor: '${resumen.noAsistenciaPct} %',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  etiqueta: 'Clientes nuevos este mes',
                  valor: '${resumen.clientesNuevosMes}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  etiqueta: 'Canceladas',
                  valor: '${resumen.canceladasMes} · '
                      '${resumen.canceladasPct} %',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('SERVICIOS MÁS PEDIDOS', style: AppTheme.sectionLabel),
          const SizedBox(height: 8),
          if (resumen.topServicios.isEmpty)
            _Vacio(texto: 'Todavía no hay servicios en el mes.')
          else
            for (final servicio in resumen.topServicios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        servicio.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${servicio.count}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 24),
          Text('PRÓXIMAS CITAS', style: AppTheme.sectionLabel),
          const SizedBox(height: 8),
          if (resumen.proximas.isEmpty)
            _Vacio(texto: 'No hay citas reservadas por delante.')
          else
            for (final cita in resumen.proximas)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        formatHour(cita.inicioEnMinutos),
                        style: AppTheme.archivo(size: 15, weight: 700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatLongDate(cita.empieza)} · '
                              '${cita.mascotaNombre ?? 'Sin perro registrado'}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              cita.clienteNombre ?? 'Cliente sin nombre',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCop(cita.totalCop),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

extension on _AdminAnalyticsScreenState {
  /// Un mes ya pasado: sus métricas y todas sus citas. Sin hoy, semana ni
  /// próximas, que en un mes cerrado no significan nada.
  Widget _vistaMesPasado(MonthSummary mes) {
    final textTheme = Theme.of(context).textTheme;
    final nombreMes = formatMonth(mes.mes);

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _selectorDeMes(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  etiqueta: 'Citas del mes',
                  valor: '${mes.totalCitas}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  etiqueta: 'Ingresos',
                  valor: formatCop(mes.ingresosCop),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  etiqueta: 'No asistió',
                  valor: '${mes.noAsistenciaPct} %',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Kpi(
                  etiqueta: 'Canceladas',
                  valor: '${mes.canceladas} · ${mes.canceladasPct} %',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Kpi(
            etiqueta: 'Clientes nuevos',
            valor: '${mes.clientesNuevos}',
          ),
          const SizedBox(height: 24),
          Text('SERVICIOS MÁS PEDIDOS', style: AppTheme.sectionLabel),
          const SizedBox(height: 8),
          if (mes.topServicios.isEmpty)
            const _Vacio(texto: 'Ese mes no hubo servicios.')
          else
            for (final servicio in mes.topServicios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(servicio.name, style: textTheme.bodyMedium),
                    ),
                    Text('${servicio.count}', style: textTheme.titleMedium),
                  ],
                ),
              ),
          const SizedBox(height: 24),
          Text(
            'CITAS DE ${nombreMes.toUpperCase()}',
            style: AppTheme.sectionLabel,
          ),
          const SizedBox(height: 8),
          if (mes.citas.isEmpty)
            _Vacio(texto: 'En $nombreMes no hubo citas.')
          else
            for (final cita in mes.citas)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${formatLongDate(cita.empieza)} · '
                              '${formatHour(cita.inicioEnMinutos)}',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          EstadoCitaChip(estado: cita.estado),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cita.clienteNombre ?? 'Cliente sin nombre'} · '
                        '${cita.mascotaNombre ?? 'Sin perro registrado'}',
                        style: textTheme.bodySmall,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cita.servicios.join(' · '),
                              style: textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            formatCop(cita.totalCop),
                            style: textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta.toUpperCase(), style: AppTheme.sectionLabel),
          const SizedBox(height: 6),
          Text(valor, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

/// El parte escrito por IA: se pide al abrir la hoja y se puede reintentar.
class _HojaResumenIa extends StatefulWidget {
  const _HojaResumenIa({required this.repository});

  final AsistenteRepository repository;

  @override
  State<_HojaResumenIa> createState() => _HojaResumenIaState();
}

class _HojaResumenIaState extends State<_HojaResumenIa> {
  String? _texto;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _pedir();
  }

  Future<void> _pedir() async {
    setState(() {
      _texto = null;
      _fallo = false;
    });
    try {
      final texto = await widget.repository.resumen();
      if (mounted) setState(() => _texto = texto);
    } catch (_) {
      if (mounted) setState(() => _fallo = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RESUMEN CON IA', style: AppTheme.sectionLabel),
              const SizedBox(height: 12),
              if (_fallo) ...[
                Text(
                  'El asistente no está disponible ahora.',
                  style: textTheme.bodyMedium,
                ),
                TextButton(onPressed: _pedir, child: const Text('Reintentar')),
              ] else if (_texto == null)
                const Center(child: CircularProgressIndicator())
              else
                Text(
                  _texto!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
