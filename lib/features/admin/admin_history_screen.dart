import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/salon_time.dart';
import '../booking/data/availability_repository.dart';
import 'admin_appointment_form_screen.dart';
import 'data/admin_appointment_repository.dart';
import 'data/customer_directory_repository.dart';
import 'models/agenda_entry.dart';
import 'pestana_recargable.dart';
import 'widgets/estado_cita_chip.dart';

/// Qué tramo del historial se está mirando.
enum _Filtro { todas, pasadas, hoy, futuras }

/// Cómo se ordena la lista.
enum _Orden { fechaDesc, fechaAsc, estado }

/// La pestaña Historial: todas las citas, con filtros y correcciones.
class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({
    super.key,
    required this.appointmentsRepository,
    required this.customersRepository,
    required this.availabilityRepository,
    this.today,
    this.now,
  });

  final AdminAppointmentRepository appointmentsRepository;
  final CustomerDirectoryRepository customersRepository;
  final AvailabilityRepository availabilityRepository;

  /// Se inyectan en los tests. En la app son el reloj de Bogotá.
  final DateTime? today;
  final DateTime? now;

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen>
    implements PestanaRecargable {
  List<AgendaEntry>? _citas;
  Object? _fallo;
  _Filtro _filtro = _Filtro.todas;
  _Orden _orden = _Orden.fechaDesc;
  bool _cancelando = false;

  DateTime get _ahora =>
      widget.now ?? enHoraEstetica(DateTime.now());

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// El filtro y el orden viven en el estado, así que recargar los conserva.
  @override
  Future<void> recargar() => _cargar();

  Future<void> _cargar() async {
    setState(() {
      _citas = null;
      _fallo = null;
    });
    try {
      final citas = await widget.appointmentsRepository.historial();
      if (!mounted) return;
      setState(() => _citas = citas);
    } catch (error) {
      if (!mounted) return;
      setState(() => _fallo = error);
    }
  }

  List<AgendaEntry> get _visibles {
    final ahora = _ahora;
    final dia = DateTime(ahora.year, ahora.month, ahora.day);

    final filtradas = [
      for (final cita in _citas ?? <AgendaEntry>[])
        if (switch (_filtro) {
          _Filtro.todas => true,
          _Filtro.pasadas => cita.empieza.isBefore(ahora),
          _Filtro.hoy => cita.empieza.year == dia.year &&
              cita.empieza.month == dia.month &&
              cita.empieza.day == dia.day,
          _Filtro.futuras => cita.empieza.isAfter(ahora),
        })
          cita,
    ];

    filtradas.sort(switch (_orden) {
      _Orden.fechaDesc => (a, b) => b.empieza.compareTo(a.empieza),
      _Orden.fechaAsc => (a, b) => a.empieza.compareTo(b.empieza),
      _Orden.estado => (a, b) {
          final porEstado = a.estado.index.compareTo(b.estado.index);
          return porEstado != 0
              ? porEstado
              : b.empieza.compareTo(a.empieza);
        },
    });
    return filtradas;
  }

  Future<void> _abrirFormulario({AgendaEntry? cita}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAppointmentFormScreen(
          appointmentsRepository: widget.appointmentsRepository,
          availabilityRepository: widget.availabilityRepository,
          customersRepository: widget.customersRepository,
          cita: cita,
          hoy: widget.today,
        ),
      ),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _cancelar(AgendaEntry cita) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          'La cita de ${cita.clienteNombre ?? 'este cliente'} queda '
          'cancelada y sigue en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _cancelando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await widget.appointmentsRepository.cancelar(cita.id);
      if (!mounted) return;
      setState(() => _cancelando = false);
      await _cargar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelando = false);
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar. Intenta de nuevo.')),
      );
    }
  }

  Future<void> _elegirOrden() async {
    final elegido = await showModalBottomSheet<_Orden>(
      context: context,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ordenar por'),
            ),
            for (final orden in _Orden.values)
              ListTile(
                title: Text(switch (orden) {
                  _Orden.fechaDesc => 'Fecha, más reciente primero',
                  _Orden.fechaAsc => 'Fecha, más antigua primero',
                  _Orden.estado => 'Estado',
                }),
                trailing: orden == _orden ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(contexto).pop(orden),
              ),
          ],
        ),
      ),
    );
    if (elegido != null) setState(() => _orden = elegido);
  }

  /// Sin botón de "Nueva cita": crear vive en Agenda, donde se ve el día.
  /// Aquí se corrige y se cancela.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _filtros(),
          const Divider(height: 1),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _filtros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (final filtro in _Filtro.values)
                  ChoiceChip(
                    label: Text(switch (filtro) {
                      _Filtro.todas => 'Todas',
                      _Filtro.pasadas => 'Pasadas',
                      _Filtro.hoy => 'Hoy',
                      _Filtro.futuras => 'Futuras',
                    }),
                    selected: _filtro == filtro,
                    onSelected: (_) => setState(() => _filtro = filtro),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _elegirOrden,
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_fallo != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No pudimos traer el historial.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_citas == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final citas = _visibles;
    if (citas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          children: [
            const SizedBox(height: 64),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No hay citas en este filtro.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: citas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _TarjetaHistorial(
          cita: citas[i],
          onEditar: () => _abrirFormulario(cita: citas[i]),
          onCancelar: citas[i].estado == EstadoCita.cancelada || _cancelando
              ? null
              : () => _cancelar(citas[i]),
        ),
      ),
    );
  }
}

class _TarjetaHistorial extends StatelessWidget {
  const _TarjetaHistorial({
    required this.cita,
    required this.onEditar,
    required this.onCancelar,
  });

  final AgendaEntry cita;
  final VoidCallback onEditar;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEditar,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
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
                    style: textTheme.titleMedium,
                  ),
                ),
                EstadoCitaChip(estado: cita.estado),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cita.mascotaNombre ?? 'Sin perro registrado',
              style: textTheme.bodyMedium,
            ),
            Text(
              cita.clienteNombre ?? 'Cliente sin nombre',
              style: textTheme.bodySmall,
            ),
            if (cita.clienteTelefono != null)
              Text(cita.clienteTelefono!, style: textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(cita.servicios.join(' · '), style: textTheme.bodyMedium),
            if (cita.notasEstilista != null) ...[
              const SizedBox(height: 8),
              Text(cita.notasEstilista!, style: textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text('TOTAL', style: AppTheme.sectionLabel),
                const SizedBox(width: 8),
                Text(formatCop(cita.totalCop), style: textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                if (onCancelar != null)
                  TextButton.icon(
                    onPressed: onCancelar,
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Eliminar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
