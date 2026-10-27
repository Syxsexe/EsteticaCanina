import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/flow_page_route.dart';
import '../../core/widgets/section_label.dart';
import 'data/service_catalog.dart';
import 'models/service.dart';
import 'schedule_selection_screen.dart';

/// Paso 1 de la reserva: un servicio principal y los extras que se quieran.
class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  BookingSelection _selection = const BookingSelection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final catalogo = ServiceCatalog.todos;

    return Scaffold(
      appBar: AppBar(title: const Text('PASO 01 DE 02')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text('Elige el\nservicio.', style: textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Uno principal, y encima los extras que quieras.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          const SectionLabel('SERVICIO PRINCIPAL'),
          for (final servicio in ServiceCatalog.principales)
            _ServiceRow(
              service: servicio,
              selected: _selection.mainService?.id == servicio.id,
              isRadio: true,
              onTap: () => setState(
                () => _selection = _selection.withMainService(servicio),
              ),
            ),
          const SizedBox(height: 32),
          const SectionLabel('EXTRAS'),
          for (final extra in ServiceCatalog.extras)
            _ServiceRow(
              service: extra,
              selected: _selection.extras.contains(extra.id),
              isRadio: false,
              onTap: () => setState(
                () => _selection = _selection.toggleExtra(extra.id),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _TotalBar(
        total: _selection.totalPrice(catalogo),
        minutes: _selection.totalMinutes(catalogo),
        enabled: _selection.isComplete,
        onContinue: () => Navigator.of(context).push(
          FlowPageRoute<void>(
            builder: (_) => ScheduleSelectionScreen(selection: _selection),
          ),
        ),
      ),
    );
  }
}

/// Una fila del catálogo. La marca de selección cambia de forma según se
/// pueda elegir una sola (círculo) o varias (cuadro).
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.selected,
    required this.isRadio,
    required this.onTap,
  });

  final Service service;
  final bool selected;
  final bool isRadio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Marker(selected: selected, isRadio: isRadio),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(service.name, style: textTheme.titleLarge),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatCop(service.price),
                        style: textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(service.note, style: textTheme.bodySmall),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatDuration(service.minutes),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.selected, required this.isRadio});

  final bool selected;
  final bool isRadio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.navy : Colors.transparent,
        shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isRadio ? null : BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppColors.navy : AppColors.disabled,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}

/// Barra fija con el total y el botón de continuar.
class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.total,
    required this.minutes,
    required this.enabled,
    required this.onContinue,
  });

  final int total;
  final int minutes;
  final bool enabled;
  final VoidCallback onContinue;

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
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL', style: AppTheme.sectionLabel),
                    const SizedBox(height: 2),
                    Text(formatCop(total), style: textTheme.headlineSmall),
                  ],
                ),
                const Spacer(),
                if (minutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'La cita dura ${formatDuration(minutes)}',
                      style: textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: enabled ? onContinue : null,
              child: Text(
                enabled ? 'Continuar' : 'Elige un servicio principal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
