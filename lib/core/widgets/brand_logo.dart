import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Logotipo de Perro Look: el badge blanco con borde navy de la identidad.
///
/// Dibuja [assetPath] cuando el archivo está en el proyecto y, si falta, cae
/// en el lockup tipográfico para que ninguna pantalla quede vacía. Cambiar el
/// logotipo por el definitivo es, entonces, dejar el PNG en su sitio: ninguna
/// pantalla necesita tocarse.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 38});

  /// Dónde vive el logotipo. La carpeta ya está declarada en `pubspec.yaml`,
  /// así que basta con copiar el archivo y correr `flutter pub get`.
  static const String assetPath = 'assets/images/logo.png';

  /// Alto del logotipo sin contar el marco. El resto de medidas sale de aquí,
  /// de modo que el badge crece entero y no por partes.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.37,
        vertical: height * 0.26,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(height * 0.37),
        border: Border.all(color: AppColors.navy, width: 1.5),
      ),
      child: Image.asset(
        assetPath,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _Wordmark(height: height),
      ),
    );
  }
}

/// El nombre de la estética compuesto con tipografía, para cuando todavía no
/// hay archivo de logotipo.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perro Look',
          style: AppTheme.archivo(
            size: height * 0.42,
            weight: 700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Estética canina',
          style: AppTheme.archivo(
            size: height * 0.29,
            weight: 400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
