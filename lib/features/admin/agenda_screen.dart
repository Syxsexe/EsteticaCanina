import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/time/salon_time.dart';
import '../../core/theme/app_theme.dart';
import '../booking/data/availability_repository.dart';
import 'admin_appointment_form_screen.dart';
import 'data/admin_appointment_repository.dart';
import 'data/admin_session.dart';
import 'data/agenda_repository.dart';
import 'data/customer_directory_repository.dart';
import 'models/agenda_entry.dart';
import 'pestana_recargable.dart';
import 'widgets/estado_cita_chip.dart';

/// La agenda del día, para la estética.
///
/// Es la pantalla que se abre quince veces al día, así que manda lo
/// práctico: quién viene, a qué hora, con qué perro, y un toque para dejar
/// constancia de qué pasó.
///
/// Marcar asistencia no es una floritura: mientras nadie lo haga, ninguna
/// cita pasa de `reservada`, `mi_fidelidad()` devuelve cero visitas para
/// siempre y las analíticas son una suma de ceros.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({
    super.key,
    this.repository,
    this.session,
    this.today,
    this.embedded = false,
    this.appointmentsRepository,
    this.availabilityRepository,
    this.customersRepository,
  });

  final AgendaRepository? repository;
  final AdminSession? session;

  /// Lo que necesita el formulario de "Nueva cita". Si faltan, se usan los
  /// de siempre, y solo al tocar el botón: los tests que no crean citas no
  /// tienen por qué montarlos.
  final AdminAppointmentRepository? appointmentsRepository;
  final AvailabilityRepository? availabilityRepository;
  final CustomerDirectoryRepository? customersRepository;

  /// Qué día se abre. Se inyecta en los tests; en la app es hoy.
  final DateTime? today;

  /// Cuando vive dentro del panel, no pinta su propia barra ni su salida.
  final bool embedded;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen>
    implements PestanaRecargable {
  late final AgendaRepository _repositorio;
  late DateTime _dia;

  List<AgendaEntry>? _citas;
  Object? _fallo;

  /// Los ids que se están guardando ahora mismo. Se guarda el conjunto y no
  /// un booleano para que marcar una cita no bloquee las demás.
  final Set<String> _guardando = {};

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repository ?? defaultAgendaRepository();
    final hoy = widget.today ?? hoyEnLaEstetica();
    _dia = DateTime(hoy.year, hoy.month, hoy.day);
    _cargar();
  }

  /// Vuelve a pedir el día que se está viendo, sin moverlo.
  @override
  Future<void> recargar() => _cargar();

  Future<void> _cargar() async {
    setState(() {
      _citas = null;
      _fallo = null;
    });
    try {
      final citas = await _repositorio.citasDe(_dia);
      if (!mounted) return;
      setState(() => _citas = citas);
    } catch (error) {
      if (!mounted) return;
      setState(() => _fallo = error);
    }
  }

  void _moverDia(int dias) {
    setState(() => _dia = DateTime(_dia.year, _dia.month, _dia.day + dias));
    _cargar();
  }

  Future<void> _marcar(AgendaEntry cita, EstadoCita estado) async {
    setState(() => _guardando.add(cita.id));
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await _repositorio.marcar(cita.id, estado);
      if (!mounted) return;
      // Se actualiza en sitio en vez de recargar el día entero: la lista no
      // salta y no se pierde el desplazamiento a media jornada.
      setState(() {
        _guardando.remove(cita.id);
        _citas = [
          for (final c in _citas!)
            if (c.id == cita.id) c.copyWith(estado: estado) else c,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando.remove(cita.id));
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  /// Abre el formulario en el día que se está viendo. Si ese día ya pasó,
  /// el formulario abre en hoy. Al guardar se recarga el mismo día.
  Future<void> _nuevaCita() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAppointmentFormScreen(
          appointmentsRepository: widget.appointmentsRepository ??
              defaultAdminAppointmentRepository(),
          availabilityRepository: widget.availabilityRepository ??
              defaultAvailabilityRepository(),
          customersRepository: widget.customersRepository ??
              defaultCustomerDirectoryRepository(),
          hoy: widget.today,
          diaInicial: _dia,
        ),
      ),
    );
    if (guardado == true && mounted) await _cargar();
  }

  Future<void> _salir() async {
    final sesion = widget.session ?? defaultAdminSession();
    await sesion.salir();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final cuerpo = Column(
      children: [
        _BarraDeDia(
          dia: _dia,
          onAnterior: () => _moverDia(-1),
          onSiguiente: () => _moverDia(1),
        ),
        const Divider(height: 1),
        Expanded(child: _cuerpo()),
      ],
    );

    final botonNuevaCita = FloatingActionButton.extended(
      onPressed: _nuevaCita,
      icon: const Icon(Icons.add),
      label: const Text('Nueva cita'),
    );

    // Embebida no pinta barra ni salida —eso lo pone el panel—, pero sí su
    // propio Scaffold: es lo que le da sitio al botón flotante.
    if (widget.embedded) {
      return Scaffold(body: cuerpo, floatingActionButton: botonNuevaCita);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AGENDA'),
        actions: [
          IconButton(
            onPressed: _salir,
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: cuerpo,
      floatingActionButton: botonNuevaCita,
    );
  }

  Widget _cuerpo() {
    if (_fallo != null) {
      return _Centrado(
        texto: 'No pudimos traer la agenda.',
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    final citas = _citas;
    if (citas == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (citas.isEmpty) {
      return _Centrado(
        texto: _dia.weekday >= DateTime.saturday
            ? 'Sábado y domingo no se abre.'
            : 'Ninguna cita este día.',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        // Abajo deja sitio al botón flotante para que no tape la última cita.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: citas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _Tarjeta(
          cita: citas[i],
          guardando: _guardando.contains(citas[i].id),
          onMarcar: (estado) => _marcar(citas[i], estado),
        ),
      ),
    );
  }
}

/// La cabecera con el día y las flechas para moverse.
class _BarraDeDia extends StatelessWidget {
  const _BarraDeDia({
    required this.dia,
    required this.onAnterior,
    required this.onSiguiente,
  });

  final DateTime dia;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Día anterior',
          ),
          Expanded(
            child: Text(
              formatLongDate(dia),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onSiguiente,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Día siguiente',
          ),
        ],
      ),
    );
  }
}

/// Una cita de la agenda.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.cita,
    required this.guardando,
    required this.onMarcar,
  });

  final AgendaEntry cita;
  final bool guardando;
  final ValueChanged<EstadoCita> onMarcar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatHour(cita.inicioEnMinutos),
                style: textTheme.titleLarge,
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  formatDuration(cita.minutos),
                  style: textTheme.bodySmall,
                ),
              ),
              const Spacer(),
              EstadoCitaChip(estado: cita.estado),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            // Con cuentas anónimas todavía no hay nombre, y decirlo es mejor
            // que dejar un hueco en blanco.
            cita.mascotaNombre ?? 'Sin perro registrado',
            style: textTheme.titleMedium,
          ),
          Text(
            cita.clienteNombre ?? 'Cliente sin nombre',
            style: textTheme.bodySmall,
          ),
          if (cita.clienteTelefono != null)
            Text(cita.clienteTelefono!, style: textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(cita.servicios.join(' · '), style: textTheme.bodyMedium),
          if (cita.notasEstilista != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(cita.notasEstilista!, style: textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('TOTAL', style: AppTheme.sectionLabel),
              const SizedBox(width: 8),
              Text(formatCop(cita.totalCop), style: textTheme.titleMedium),
            ],
          ),
          if (cita.estado.admiteAsistencia) ...[
            const SizedBox(height: 14),
            if (guardando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onMarcar(EstadoCita.cumplida),
                      child: const Text('Cumplida'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onMarcar(EstadoCita.noAsistio),
                      child: const Text('No asistió'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Centrado extends StatelessWidget {
  const _Centrado({required this.texto, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (accion != null) ...[const SizedBox(height: 12), accion!],
          ],
        ),
      ),
    );
  }
}
