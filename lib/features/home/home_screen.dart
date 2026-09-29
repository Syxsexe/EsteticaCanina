import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
                  const _Logo(),
                  const SizedBox(height: 32),
                  Text(
                    'Reserva el bano\nde tu perro en\ndos pasos.',
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
                    description: 'Bano, corte, unas, oidos y mas.',
                  ),
                  const SizedBox(height: 20),
                  const _Step(
                    number: '2',
                    title: 'Elige dia y hora',
                    description: 'Solo ves los espacios libres.',
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('La reserva llega en el siguiente paso.'),
                        ),
                      );
                    },
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perro Look',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Estetica canina',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
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
