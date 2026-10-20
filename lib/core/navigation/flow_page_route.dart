/// Eje compartido horizontal de Material, escrito a mano para no sumar una
/// dependencia por unas pocas líneas.
///
/// El flujo de reserva es un asistente: el movimiento tiene que decir si se
/// avanza o se retrocede. Al abrir un paso, la pantalla nueva llega desde la
/// derecha y la anterior se va a la izquierda; al volver, Flutter corre la
/// misma animación hacia atrás y el gesto se invierte solo.
library;

import 'package:flutter/material.dart';

/// Cuánto se desplaza cada pantalla, en píxeles.
///
/// El eje compartido mueve poco a propósito: el fundido hace el grueso del
/// trabajo y el deslizamiento solo marca la dirección. Son píxeles y no una
/// fracción del ancho para que en una ventana de escritorio el gesto no se
/// convierta en un viaje.
const double _shift = 30;

/// Lo que tarda un paso en entrar o en salir.
const Duration flowTransitionDuration = Duration(milliseconds: 300);

/// Los dos fundidos no se solapan: el de salida ocupa el primer tercio y el
/// de entrada los dos últimos, así que nunca se ven dos pantallas a media
/// opacidad una encima de la otra.
const Interval _exitFadeWindow = Interval(0, 0.3);
const Interval _enterFadeWindow = Interval(0.3, 1);

/// Ruta de los pasos de la reserva.
///
/// Compone las dos mitades de la transición, de modo que una pantalla abierta
/// con esta ruta sabe tanto entrar como apartarse cuando la siguiente la tapa.
class FlowPageRoute<T> extends PageRouteBuilder<T> {
  FlowPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: flowTransitionDuration,
          reverseTransitionDuration: flowTransitionDuration,
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return FlowExitTransition(
              animation: secondaryAnimation,
              child: FlowEnterTransition(animation: animation, child: child),
            );
          },
        );
}

/// La mitad de entrada: la pantalla llega desde la derecha mientras aparece.
///
/// Se puede usar suelta, pero lo normal es dejar que [FlowPageRoute] la ponga.
class FlowEnterTransition extends StatelessWidget {
  const FlowEnterTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Translate(
      offset: Tween<double>(begin: _shift, end: 0)
          .chain(CurveTween(curve: Curves.easeInOutCubicEmphasized))
          .animate(animation),
      child: FadeTransition(
        opacity: CurveTween(curve: _enterFadeWindow).animate(animation),
        child: child,
      ),
    );
  }
}

/// La mitad de salida: la pantalla se aparta a la izquierda y se desvanece
/// cuando otra la cubre.
///
/// Va atada a la `secondaryAnimation` de la ruta, no a la suya. Por eso el
/// Home puede usarla aunque entre con el fundido del splash: una cosa es cómo
/// aparece una pantalla y otra cómo se retira.
class FlowExitTransition extends StatelessWidget {
  const FlowExitTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Translate(
      offset: Tween<double>(begin: 0, end: -_shift)
          .chain(CurveTween(curve: Curves.easeInOutCubicEmphasized))
          .animate(animation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: _exitFadeWindow))
            .animate(animation),
        child: child,
      ),
    );
  }
}

/// Desplaza a su hijo en horizontal por un número de píxeles animado.
///
/// `SlideTransition` no sirve aquí porque mide en fracciones del tamaño del
/// hijo, y el desplazamiento de este eje es una medida fija.
class _Translate extends StatelessWidget {
  const _Translate({required this.offset, required this.child});

  final Animation<double> offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: offset,
      child: child,
      builder: (_, child) => Transform.translate(
        offset: Offset(offset.value, 0),
        child: child,
      ),
    );
  }
}
