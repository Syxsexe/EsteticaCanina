import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/flow_page_route.dart';
import '../../core/startup/app_bootstrap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../home/home_screen.dart';

/// Pantalla de apertura: sostiene la marca mientras [AppBootstrap] termina
/// y entrega el control al [HomeScreen] con un fundido.
///
/// Las dos pantallas comparten el azul de fondo, así que el cruce se lee como
/// un solo movimiento y no como un cambio de pantalla.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.bootstrap});

  /// Qué se espera antes de entrar. Por defecto, [AppBootstrap.run].
  ///
  /// Se inyecta en los tests: con un arranque instantáneo se puede medir el
  /// mínimo en pantalla, que es lo propio de esta pantalla, sin quedar atado
  /// a cuánto tarda en resolver un asset.

  /// Lo que el splash se queda en pantalla aunque el arranque sea
  /// instantáneo. Sin este piso parpadearía en los equipos rápidos.
  static const Duration minimumVisible = Duration(milliseconds: 1500);

  /// Lo que dura la entrada del logotipo y el eslogan.
  static const Duration entrance = Duration(milliseconds: 1100);

  /// Lo que dura el fundido hacia el Home.
  static const Duration fadeToHome = Duration(milliseconds: 450);

  final Future<void> Function(BuildContext context)? bootstrap;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineOffset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.entrance,
    );

    // El logotipo abre solo y el eslogan entra cuando aquel ya está puesto:
    // los intervalos se solapan apenas para que se lea como un gesto.
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );
    _taglineOffset = Tween<Offset>(
      begin: const Offset(0, 0.7),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // El arranque necesita un context ya montado para precargar imágenes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Espera a la vez al arranque y al tiempo mínimo en pantalla: manda el que
  /// termine último, así que un arranque lento nunca se corta y uno rápido no
  /// deja el splash en un parpadeo.
  Future<void> _start() async {
    await Future.wait<void>([
      (widget.bootstrap ?? AppBootstrap.run)(context),
      Future<void>.delayed(SplashScreen.minimumVisible),
    ]);

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(_homeRoute());
  }

  Route<void> _homeRoute() {
    return PageRouteBuilder<void>(
      transitionDuration: SplashScreen.fadeToHome,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => const HomeScreen(),
      // El Home entra con el fundido del splash, pero cuando la reserva lo
      // tapa tiene que apartarse como el resto del flujo. Son dos gestos
      // distintos porque responden a dos animaciones distintas.
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        return FlowExitTransition(
          animation: secondaryAnimation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fondo claro: los iconos del sistema van en oscuro.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.primary,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: const BrandLogo(height: 132),
                ),
              ),
              const SizedBox(height: 26),
              FadeTransition(
                opacity: _taglineOpacity,
                child: SlideTransition(
                  position: _taglineOffset,
                  child: Text(
                     'APP DE RESERVAS',
                    style: AppTheme.sectionLabel.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
