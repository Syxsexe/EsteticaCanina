import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Rótulo de sección: versalitas espaciadas y una línea fina que llega hasta
/// el borde.
///
/// Vivía dentro del paso 1. Lo necesita también el paso 2, y un rótulo que se
/// copia es un rótulo que acaba divergiendo, así que pasa a ser del tema.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;

  /// Una nota al otro extremo de la línea, como "Sáb y dom cerrado".
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppTheme.sectionLabel),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AppColors.hairline)),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
