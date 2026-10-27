import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/flow_page_route.dart';
import '../../core/widgets/section_label.dart';
import 'data/availability_repository.dart';
import 'data/service_catalog.dart';
import 'booking_confirmed_screen.dart';
import 'models/booking.dart';
import 'models/schedule.dart';
import 'models/service.dart';

/// Paso 2 de la reserva: el día y la hora.
///
/// La duración que trae el paso 1 manda. Esta pantalla no ofrece horas
/// sueltas sino comienzos en los que la cita entera termina antes de cerrar
/// y sin pisar otra, que es la diferencia entre una agenda y una lista de
/// horas bonitas.
class ScheduleSelectionScreen extends StatefulWidget {
  const ScheduleSelectionScreen({
    super.key,
    required this.selection,
    this.today,
    this.repository,
  });

  /// Lo elegido en el paso 1.
  ///
  /// Viaja por el constructor: el flujo es lineal y tres pantallas no
  /// justifican un contenedor de estado. Si algún día se ramifica, subirlo a
  /// uno es mecánico.
  final BookingSelection selection;

  /// Desde qué día se ofrece agenda. Se inyecta en los tests; en la app es
  /// hoy.
  final DateTime? today;

  /// De dónde sale la agenda.
  ///
  /// Nulo significa "la que toque": Postgres si hay credenciales, la de
  /// muestra si no. Se pasa explícito en los tests, que así no dependen ni
  /// de la red ni de lo que haya hoy en la base.
  final AvailabilityRepository? repository;

  @override
  State<ScheduleSelectionScreen> createState() =>
      _ScheduleSelectionScreenState();
}

class _ScheduleSelectionScreenState extends State<ScheduleSelectionScreen> {
  late final int _minutes;

  /// Los días, una vez cargados. Nulo mientras se esperan.
  List<DaySchedule>? _days;

  /// Por qué no se pudieron cargar. Nulo si no ha fallado nada.
  Object? _fallo;

  /// El día que se está mirando. Nulo hasta que llega la agenda.
  DaySchedule? _day;

  /// El comienzo elegido, en minutos desde medianoche. Nulo mientras no se
  /// haya tocado ninguna hora.
  int? _start;

  @override
  void initState() {
    super.initState();
    _minutes = widget.selection.totalMinutes(ServiceCatalog.todos);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _days = null;
      _fallo = null;
      _day = null;
      _start = null;
    });

    try {
      final repositorio = widget.repository ?? defaultAvailabilityRepository();
      final days = await repositorio.daysFrom(
        widget.today ?? DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _days = days;
        // Abrir en un día que sirva le ahorra al cliente el primer rebote.
        // Si no hay ninguno en dos semanas, se abre en el primero y la
        // pantalla lo dice con todas las letras.
        _day = days.firstWhere(
          (day) => day.hasRoomFor(_minutes),
          orElse: () => days.first,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _fallo = error);
    }
  }

  void _elegirDia(DaySchedule day) {
    setState(() {
      _day = day;
      // La hora elegida pertenecía al día anterior: conservarla sería
      // ofrecer un hueco que aquí puede estar tomado.
      _start = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PASO 02 DE 02')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text('Elige día\ny hora.', style: textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Tu cita dura ${formatDuration(_minutes)}. Solo te dejamos '
            'empezar donde quepa entera.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          // El titular y la duración no dependen de la red, así que se
          // quedan quietos. Solo la agenda cambia de estado, y así la
          // pantalla no parpadea entera mientras carga.
          ..._agenda(),
        ],
      ),
      bottomNavigationBar: _ConfirmBar(
        total: widget.selection.totalPrice(ServiceCatalog.todos),
        date: _day?.date,
        start: _start,
        onConfirm: _start == null ? null : _confirmar,
      ),
    );
  }

  /// La agenda, o lo que haya en su lugar mientras llega o si no llega.
  List<Widget> _agenda() {
    if (_fallo != null) {
      return [
        _Aviso(
          'No pudimos traer los horarios. Revisa tu conexión.',
          onRetry: _cargar,
        ),
      ];
    }

    final days = _days;
    final day = _day;
    if (days == null || day == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      SectionLabel(
        formatMonth(day.date).toUpperCase(),
        trailing: 'Sáb y dom cerrado',
      ),
      const SizedBox(height: 12),
      _DayStrip(
        days: days,
        selected: day,
        minutes: _minutes,
        onSelect: _elegirDia,
      ),
      const SizedBox(height: 28),
      ..._horarios(day),
    ];
  }

  /// Las franjas del día elegido, o el motivo por el que no hay ninguna.
  List<Widget> _horarios(DaySchedule day) {
    if (day.isClosed) {
      return [_Aviso('La estética no abre el ${formatLongDate(day.date)}.')];
    }
    if (!day.hasRoomFor(_minutes)) {
      return [
        _Aviso(
          'Ningún hueco de ese día aguanta una cita de '
          '${formatDuration(_minutes)}. Prueba con otro.',
        ),
      ];
    }

    // Las franjas son las que traiga el día, no dos fijas. Con la agenda de
    // muestra siempre son mañana y tarde, pero cuando vengan de la base la
    // dueña puede cambiarlas y la pantalla no tiene por qué enterarse.
    return [
      for (final (i, window) in day.windows.indexed) ...[
        if (i > 0) const SizedBox(height: 24),
        _Franja(
          titulo: _nombreFranja(window),
          slots: day.slotsIn(window, _minutes),
          selected: _start,
          onSelect: (start) => setState(() => _start = start),
        ),
      ],
    ];
  }

  /// Cómo se llama una franja, deducido de a qué hora empieza.
  ///
  /// Se deduce en vez de venir escrito en la base: un rótulo guardado junto
  /// al horario es un rótulo que alguien acaba dejando en "MAÑANA" para una
  /// franja de las seis de la tarde.
  String _nombreFranja(TimeWindow window) {
    if (window.start < 12 * 60) return 'MAÑANA';
    if (window.start < 18 * 60) return 'TARDE';
    return 'NOCHE';
  }

  void _confirmar() {
    final booking = Booking(
      selection: widget.selection,
      date: _day!.date,
      startMinutes: _start!,
    );

    // `pushAndRemoveUntil` en vez de `push`: la confirmación es terminal y
    // los dos pasos salen de la pila. Si se pudiera volver atrás desde ella,
    // lo único que se conseguiría es reservar la misma hora dos veces.
    Navigator.of(context).pushAndRemoveUntil(
      FlowPageRoute<void>(
        builder: (_) => BookingConfirmedScreen(booking: booking),
      ),
      (route) => route.isFirst,
    );
  }
}

/// La tira horizontal de días.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.minutes,
    required this.onSelect,
  });

  final List<DaySchedule> days;
  final DaySchedule selected;
  final int minutes;
  final ValueChanged<DaySchedule> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = days[i];
          return _DayChip(
            day: day,
            selected: day.date == selected.date,
            // Un día cerrado y uno lleno se tocan igual de poco, así que se
            // pintan igual: lo que importa es que no se pueden elegir.
            enabled: day.hasRoomFor(minutes),
            onTap: () => onSelect(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DaySchedule day;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = selected
        ? Colors.white
        : enabled
            ? AppColors.textPrimary
            : AppColors.disabled;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatWeekdayShort(day.date),
              style: textTheme.bodySmall?.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.date.day}',
              style: textTheme.titleLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una franja del día con sus horas.
class _Franja extends StatelessWidget {
  const _Franja({
    required this.titulo,
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final String titulo;
  final List<SlotOption> slots;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(titulo),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in slots)
              _TimeChip(
                slot: slot,
                selected: slot.start == selected,
                onTap: () => onSelect(slot.start),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final SlotOption slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Tres estados, tres tratamientos. El tachado queda solo para lo que ya
    // está tomado: eso es información sobre la agenda. Lo que no cabe se
    // apaga sin tachar, porque cambiaría si el cliente volviera atrás y
    // quitara un extra.
    final tomado = slot.status == SlotStatus.taken;
    final disponible = slot.isFree;

    return InkWell(
      onTap: disponible ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
          ),
        ),
        child: Text(
          formatHour(slot.start),
          style: textTheme.titleMedium?.copyWith(
            color: selected
                ? Colors.white
                : disponible
                    ? AppColors.textPrimary
                    : AppColors.disabled,
            decoration: tomado ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.disabled,
          ),
        ),
      ),
    );
  }
}

/// Una línea de explicación cuando el día elegido no ofrece nada.
class _Aviso extends StatelessWidget {
  const _Aviso(this.text, {this.onRetry});

  final String text;

  /// Si se pasa, el aviso ofrece volver a intentarlo. Un día cerrado no lo
  /// necesita —reintentar no lo va a abrir—; un fallo de red sí.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra fija con lo que se lleva elegido y el botón de reservar.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.total,
    required this.date,
    required this.start,
    required this.onConfirm,
  });

  final int total;

  /// El día elegido, o nulo mientras la agenda no haya llegado.
  final DateTime? date;

  final int? start;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TU CITA', style: AppTheme.sectionLabel),
                      const SizedBox(height: 2),
                      Text(
                        switch ((date, start)) {
                          (null, _) => 'Buscando horarios…',
                          (final d?, null) => formatLongDate(d),
                          (final d?, final h?) =>
                            '${formatLongDate(d)}, ${formatHour(h)}',
                        },
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatCop(total), style: textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConfirm,
                child: Text(
                  onConfirm == null ? 'Elige una hora' : 'Reservar cita',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
