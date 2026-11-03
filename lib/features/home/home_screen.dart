import 'package:flutter/material.dart';

import '../../core/navigation/flow_page_route.dart';
import '../admin/admin_sign_in_screen.dart';
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
        // El `Spacer` de abajo empuja la tarjeta al borde inferior, pero en
        // una pantalla baja —o con el texto ampliado por accesibilidad— no
        // hay sitio y la columna se desborda. Esto deja que se desplace
        // cuando no cabe y que siga llenando la pantalla cuando sí: el
        // `IntrinsicHeight` es lo que permite usar `Spacer` dentro de algo
        // desplazable, que de otro modo tiene altura infinita.
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: IntrinsicHeight(
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
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
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
                          // Discreto a propósito: el cliente no tiene por qué
                          // encontrarse con una puerta que no es suya, pero
                          // esconderla del todo obligaría a la dueña a recordar un
                          // truco.
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                FlowPageRoute<void>(
                                  builder: (_) => const AdminSignInScreen(),
                                ),
                              ),
                              child: Text(
                                'Soy la estética',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.primaryDark,
            ),
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
