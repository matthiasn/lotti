import 'package:flutter/material.dart';

/// Controller for AnimatedModalItem animations
///
/// This controller exposes the animation state for testing purposes
/// while maintaining encapsulation of the animation logic.
class AnimatedModalItemController extends ChangeNotifier {
  AnimatedModalItemController({
    required TickerProvider vsync,
    Duration hoverDuration = const Duration(milliseconds: 200),
    Duration tapDuration = const Duration(milliseconds: 150),
  }) {
    _hoverAnimationController = AnimationController(
      duration: hoverDuration,
      vsync: vsync,
    );
    _tapAnimationController = AnimationController(
      duration: tapDuration,
      vsync: vsync,
    );
  }

  late final AnimationController _hoverAnimationController;
  late final AnimationController _tapAnimationController;

  /// Animation controller for hover effects (exposed for AnimatedBuilder)
  AnimationController get hoverAnimationController => _hoverAnimationController;

  /// Animation controller for tap effects (exposed for AnimatedBuilder)
  AnimationController get tapAnimationController => _tapAnimationController;

  void startHover() {
    _hoverAnimationController.forward();
  }

  void endHover() {
    _hoverAnimationController.reverse();
  }

  void startTap() {
    _tapAnimationController.forward();
  }

  void endTap() {
    _tapAnimationController.reverse();
  }

  @override
  void dispose() {
    _hoverAnimationController.dispose();
    _tapAnimationController.dispose();
    super.dispose();
  }
}
