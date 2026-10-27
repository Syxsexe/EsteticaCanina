import 'package:flutter/material.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'data/service_catalog.dart';
import 'models/booking.dart';
import 'models/service.dart';

/// El final del flujo: la cita quedó hecha.
///
/// Es una pantalla terminal. Se llega con `pushAndRemoveUntil`, así que los
/// dos pasos quedan fuera de la pila y el botón atrás lleva al inicio, no de
/// vuelta a la hora que se acaba de reservar. Volver allí solo serviría para
/// reservar dos veces.
class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final catalogo = ServiceCatalog.todos;
    final servicios = booking.selection.chosenServices(catalogo);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                children: [
                  const Center(child: _Check()),
                  const SizedBox(height: 24),
                  Text(
                    '¡Cita confirmada!',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 28),
                  _Resumen(booking: booking, servicios: servicios),
                  const SizedBox(height: 20),
                  Text(
                    'Te avisamos por mensaje la tarde anterior. '
                    'Pagas después de la cita.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: OutlinedButton(
                // Vacía lo que quede del flujo y deja el inicio a la vista.
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El visto bueno, que entra con un golpe de escala.
///
/// Usa [TweenAnimationBuilder] y no un controlador porque la animación se
/// dispara sola al construirse y no vuelve a ocurrir: no hay estado que
/// mantener ni ticker que liberar.
class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, valor, child) => Transform.scale(scale: valor, child: child),
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 42, color: Colors.white),
      ),
    );
  }
}

/// La tarjeta con el detalle de la cita.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.booking, required this.servicios});

  final Booking booking;
  final List<Service> servicios;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final catalogo = ServiceCatalog.todos;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Dato(
            etiqueta: 'DÍA',
            valor: formatLongDate(booking.date),
          ),
          const SizedBox(height: 16),
          _Dato(
            etiqueta: 'HORA',
            valor: '${formatHour(booking.startMinutes)} · '
                '${formatDuration(booking.minutes(catalogo))}',
          ),
          const SizedBox(height: 16),
          _Dato(
            etiqueta: servicios.length > 1 ? 'SERVICIOS' : 'SERVICIO',
            valor: [for (final s in servicios) s.name].join('\n'),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.hairline),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL', style: AppTheme.sectionLabel),
              const Spacer(),
              Text(
                formatCop(booking.price(catalogo)),
                style: textTheme.headlineSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTheme.sectionLabel),
        const SizedBox(height: 4),
        Text(valor, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
