import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/agenda_entry.dart';

/// La etiqueta del estado de una cita, igual en Agenda, Historial y Resumen.
class EstadoCitaChip extends StatelessWidget {
  const EstadoCitaChip({super.key, required this.estado});

  final EstadoCita estado;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = switch (estado) {
      EstadoCita.reservada => (AppColors.primarySoft, AppColors.primaryDark),
      EstadoCita.cumplida => (AppColors.navy, Colors.white),
      EstadoCita.cancelada => (AppColors.hairline, AppColors.textSecondary),
      EstadoCita.noAsistio => (AppColors.hairline, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.rotulo.toUpperCase(),
        style: AppTheme.archivo(size: 11, weight: 700, color: texto),
      ),
    );
  }
}
