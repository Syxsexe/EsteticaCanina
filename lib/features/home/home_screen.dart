import 'package:flutter/material.dart';

import '../../core/navigation/flow_page_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../booking/service_selection_screen.dart';

/// Pantalla de entrada: presenta la promesa de la app y lleva a la reserva.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLogo(),
                  const SizedBox(height: 32),
                  Text(
                    'Reserva el baño\nde tu perro en\ndos pasos.',
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Elige el servicio, escoge un horario libre y tu cita '
                    'queda confirmada. Sin llamadas y sin esperas.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Step(
                    number: '1',
                    title: 'Elige el servicio',
                    description: 'Baño, corte, uñas, oídos y más.',
                  ),
                  const SizedBox(height: 20),
                  const _Step(
                    number: '2',
                    title: 'Elige día y hora',
                    description: 'Solo ves los espacios libres.',
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      FlowPageRoute<void>(
                        builder: (_) => const ServiceSelectionScreen(),
                      ),
                    ),
                    child: const Text('Reservar cita'),
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

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: textTheme.titleMedium?.copyWith(color: AppColors.primaryDark),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(description, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
