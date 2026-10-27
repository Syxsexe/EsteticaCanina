import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_label.dart';
import 'data/availability_catalog.dart';
import 'data/service_catalog.dart';
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

  @override
  State<ScheduleSelectionScreen> createState() =>
      _ScheduleSelectionScreenState();
}

class _ScheduleSelectionScreenState extends State<ScheduleSelectionScreen> {
  late final List<DaySchedule> _days;
  late final int _minutes;
  late DaySchedule _day;

  /// El comienzo elegido, en minutos desde medianoche. Nulo mientras no se
  /// haya tocado ninguna hora.
  int? _start;

  @override
  void initState() {
    super.initState();
    _minutes = widget.selection.totalMinutes(ServiceCatalog.todos);
    _days = AvailabilityCatalog.nextDays(widget.today ?? DateTime.now());
    // Abrir en un día que sirva le ahorra al cliente el primer rebote. Si no
    // hay ninguno en dos semanas, se abre en el primero y la pantalla lo
    // dice con todas las letras.
    _day = _days.firstWhere(
      (day) => day.hasRoomFor(_minutes),
      orElse: () => _days.first,
    );
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
          SectionLabel(
            formatMonth(_day.date).toUpperCase(),
            trailing: 'Sáb y dom cerrado',
          ),
          const SizedBox(height: 12),
          _DayStrip(
            days: _days,
            selected: _day,
            minutes: _minutes,
            onSelect: _elegirDia,
          ),
          const SizedBox(height: 28),
          ..._horarios(),
        ],
      ),
      bottomNavigationBar: _ConfirmBar(
        total: widget.selection.totalPrice(ServiceCatalog.todos),
        date: _day.date,
        start: _start,
        onConfirm: _start == null ? null : _confirmar,
      ),
    );
  }

  /// Las franjas del día elegido, o el motivo por el que no hay ninguna.
  List<Widget> _horarios() {
    if (_day.isClosed) {
      return [_Aviso('La estética no abre el ${formatLongDate(_day.date)}.')];
    }
    if (!_day.hasRoomFor(_minutes)) {
      return [
        _Aviso(
          'Ningún hueco de ese día aguanta una cita de '
          '${formatDuration(_minutes)}. Prueba con otro.',
        ),
      ];
    }

    return [
      _Franja(
        titulo: 'MAÑANA',
        slots: _day.slotsIn(AvailabilityCatalog.morning, _minutes),
        selected: _start,
        onSelect: (start) => setState(() => _start = start),
      ),
      const SizedBox(height: 24),
      _Franja(
        titulo: 'TARDE',
        slots: _day.slotsIn(AvailabilityCatalog.afternoon, _minutes),
        selected: _start,
        onSelect: (start) => setState(() => _start = start),
      ),
    ];
  }

  void _confirmar() {
    final servicio = widget.selection.mainService?.name ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$servicio · ${formatLongDate(_day.date)} a las '
          '${formatHour(_start!)}. La confirmación llega en la siguiente '
          'tanda.',
        ),
      ),
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
  const _Aviso(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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
  final DateTime date;
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
                        start == null
                            ? formatLongDate(date)
                            : '${formatLongDate(date)}, ${formatHour(start!)}',
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
