import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

class PerroLookApp extends StatelessWidget {
  const PerroLookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perro Look',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
