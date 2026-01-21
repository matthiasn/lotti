import 'package:flutter/material.dart';

/// Animation constants and curves for gamified interactions.
/// These create playful, satisfying feedback that makes the app feel alive.
class GameyAnimations {
  GameyAnimations._();

  // ============================================================================
  // DURATIONS
  // ============================================================================

  /// Fast feedback (button presses, quick interactions)
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal transitions (most UI changes)
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow, deliberate animations (reveals, important moments)
  static const Duration slow = Duration(milliseconds: 500);

  /// Celebration animations (confetti, achievements)
  static const Duration celebration = Duration(milliseconds: 800);

  /// Long celebrations (major achievements)
  static const Duration celebrationLong = Duration(milliseconds: 1200);

  /// Shimmer loop duration
  static const Duration shimmer = Duration(milliseconds: 2000);

  /// Pulse loop duration
  static const Duration pulse = Duration(milliseconds: 1500);

  /// Wiggle attention-grab duration
  static const Duration wiggle = Duration(milliseconds: 500);

  // ============================================================================
  // CURVES
  // ============================================================================

  /// Bouncy elastic curve for playful interactions
  static const Curve bounce = Curves.elasticOut;

  /// Smooth deceleration for natural feeling
  static const Curve smooth = Curves.easeOutCubic;

  /// Sharp, responsive curve for quick feedback
  static const Curve sharp = Curves.easeOutQuart;

  /// Playful overshoot for fun interactions
  static const Curve playful = Curves.easeOutBack;

  /// Snappy curve for UI transitions
  static const Curve snappy = Curves.easeOutExpo;

  /// Ease in-out for symmetrical animations
  static const Curve symmetrical = Curves.easeInOut;

  /// Slow start for reveal animations
  static const Curve reveal = Curves.easeOutCirc;

  // ============================================================================
  // SCALE VALUES
  // ============================================================================

  /// Tap scale - noticeable squeeze effect
  static const double tapScale = 0.92;

  /// Hover scale - subtle enlarge on hover
  static const double hoverScale = 0.97;

  /// Hover scale up - for items that grow on hover
  static const double hoverScaleUp = 1.03;

  /// Pulse maximum scale (breathing effect)
  static const double pulseScaleMax = 1.08;

  /// Pulse minimum scale
  static const double pulseScaleMin = 0.98;

  /// Celebration scale (achievement unlock)
  static const double celebrationScale = 1.2;

  /// Icon tap scale (for icon buttons)
  static const double iconTapScale = 0.85;

  /// Wiggle scale for attention
  static const double wiggleScale = 1.05;

  // ============================================================================
  // ROTATION VALUES (in radians)
  // ============================================================================

  /// Wiggle rotation amount
  static const double wiggleRotation = 0.05;

  /// Shake rotation for errors
  static const double shakeRotation = 0.1;

  // ============================================================================
  // OPACITY VALUES
  // ============================================================================

  /// Tap opacity feedback
  static const double tapOpacity = 0.85;

  /// Disabled opacity
  static const double disabledOpacity = 0.5;

  /// Hover highlight opacity
  static const double hoverHighlightOpacity = 0.08;

  // ============================================================================
  // OFFSET VALUES
  // ============================================================================

  /// Slide in distance
  static const double slideInDistance = 24;

  /// Float/hover distance
  static const double floatDistance = 4;

  /// Bounce distance
  static const double bounceDistance = 8;

  // ============================================================================
  // STAGGER DELAYS
  // ============================================================================

  /// Delay between staggered list items
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// Delay between staggered grid items
  static const Duration staggerDelayGrid = Duration(milliseconds: 75);

  /// Delay for sequential reveal
  static const Duration revealDelay = Duration(milliseconds: 100);

  // ============================================================================
  // ANIMATION HELPERS
  // ============================================================================

  /// Creates a staggered delay for list items
  static Duration staggeredDelay(int index, {Duration base = staggerDelay}) {
    return base * index;
  }

  /// Creates animation interval for staggered animations
  static Interval staggeredInterval(
    int index, {
    int totalItems = 10,
    double overlap = 0.3,
  }) {
    final itemDuration = 1.0 / (totalItems + (totalItems - 1) * (1 - overlap));
    final start = index * itemDuration * (1 - overlap);
    final end = (start + itemDuration).clamp(0.0, 1.0);
    return Interval(start.clamp(0.0, 1.0), end, curve: smooth);
  }

  // ============================================================================
  // TWEEN FACTORIES
  // ============================================================================

  /// Creates a tap scale tween
  static Tween<double> tapScaleTween() {
    return Tween<double>(begin: 1, end: tapScale);
  }

  /// Creates a pulse scale tween
  static Tween<double> pulseScaleTween() {
    return Tween<double>(begin: pulseScaleMin, end: pulseScaleMax);
  }

  /// Creates a celebration scale tween
  static Tween<double> celebrationScaleTween() {
    return Tween<double>(begin: 0, end: celebrationScale);
  }

  /// Creates a fade in tween
  static Tween<double> fadeInTween() {
    return Tween<double>(begin: 0, end: 1);
  }

  /// Creates a slide up offset tween
  static Tween<Offset> slideUpTween() {
    return Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    );
  }

  /// Creates a slide in from right tween
  static Tween<Offset> slideRightTween() {
    return Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    );
  }
}

/// Mixin for adding pulse animation to a StatefulWidget
mixin GameyPulseAnimationMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Animation<double> get pulseAnimation => _pulseAnimation;

  void initPulseAnimation({
    Duration duration = GameyAnimations.pulse,
    double minScale = GameyAnimations.pulseScaleMin,
    double maxScale = GameyAnimations.pulseScaleMax,
  }) {
    _pulseController = AnimationController(
      vsync: this,
      duration: duration,
    );

    _pulseAnimation = Tween<double>(
      begin: minScale,
      end: maxScale,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: GameyAnimations.symmetrical,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  void disposePulseAnimation() {
    _pulseController.dispose();
  }
}

/// Mixin for adding wiggle animation to a StatefulWidget
mixin GameyWiggleAnimationMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  Animation<double> get wiggleAnimation => _wiggleAnimation;

  void initWiggleAnimation({
    Duration duration = GameyAnimations.wiggle,
    double rotation = GameyAnimations.wiggleRotation,
  }) {
    _wiggleController = AnimationController(
      vsync: this,
      duration: duration,
    );

    _wiggleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: rotation), weight: 1),
      TweenSequenceItem(tween: Tween(begin: rotation, end: -rotation), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -rotation, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _wiggleController,
        curve: GameyAnimations.bounce,
      ),
    );
  }

  void triggerWiggle() {
    _wiggleController
      ..reset()
      ..forward();
  }

  void disposeWiggleAnimation() {
    _wiggleController.dispose();
  }
}
