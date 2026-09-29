import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema único de la app. Todo el estilo vive aquí para que las pantallas
/// solo usen `Theme.of(context)`.
///
/// La tipografía es Archivo en su versión variable, así que el peso se pide
/// con [FontVariation] además de [FontWeight]: sin la variación el archivo
/// se dibuja siempre en su peso por defecto.
class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Archivo';

  /// Construye un estilo de Archivo con el peso ya instanciado.
  static TextStyle archivo({
    required double size,
    required int weight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  /// Etiqueta en versalitas espaciadas, el recurso que ordena las secciones
  /// en el diseño de Houndsworth.
  static TextStyle get sectionLabel => archivo(
        size: 12,
        weight: 600,
        letterSpacing: 1.6,
        color: AppColors.textSecondary,
      );

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.navy,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: TextTheme(
        // Titular de portada: grande y muy apretado, como el hero del diseño.
        displaySmall: archivo(
          size: 38,
          weight: 800,
          height: 1.02,
          letterSpacing: -1.2,
          color: AppColors.textPrimary,
        ),
        headlineSmall: archivo(
          size: 27,
          weight: 800,
          height: 1.1,
          letterSpacing: -0.6,
          color: AppColors.textPrimary,
        ),
        titleLarge: archivo(
          size: 19,
          weight: 700,
          height: 1.2,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
        titleMedium: archivo(
          size: 16,
          weight: 700,
          color: AppColors.textPrimary,
        ),
        bodyMedium: archivo(
          size: 15,
          weight: 400,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
        bodySmall: archivo(
          size: 13,
          weight: 400,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
        labelSmall: sectionLabel,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: sectionLabel.copyWith(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: archivo(size: 16, weight: 700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.navy, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: archivo(size: 16, weight: 700),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
