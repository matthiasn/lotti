import 'dart:math' as math;

/// Easing curves used by keyframe channels. Linear is never the right default
/// for character motion — `easeInOut` (slow-in/slow-out) is the animator's
/// staple and the most important single fidelity lever in the plan.
enum Ease {
  linear,
  easeIn,
  easeOut,
  easeInOut,
}

extension EaseApply on Ease {
  /// Maps a normalized progress [t] in 0..1 through the curve.
  double apply(double t) {
    final x = t.clamp(0.0, 1.0);
    switch (this) {
      case Ease.linear:
        return x;
      case Ease.easeIn:
        return x * x;
      case Ease.easeOut:
        return 1 - (1 - x) * (1 - x);
      case Ease.easeInOut:
        // Cosine ease — smooth and cheap.
        return 0.5 - 0.5 * math.cos(math.pi * x);
    }
  }
}
