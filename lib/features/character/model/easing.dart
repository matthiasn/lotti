import 'dart:math' as math;

/// Easing curves used by keyframe channels. Linear is never the right default
/// for character motion — `easeInOut` (slow-in/slow-out) is the animator's
/// staple and the most important single fidelity lever in the plan.
///
/// The `*Back` curves intentionally overshoot the 0..1 range: [easeInBack] dips
/// *below* the start before moving (anticipation — wind up before the action),
/// and [easeOutBack] overshoots the target then settles (follow-through — the
/// little settle that turns a robotic stop into a living one). These two are
/// what let the one-shots (sit/jump) land with weight instead of snapping.
enum Ease {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  easeInBack,
  easeOutBack,
}

extension EaseApply on Ease {
  /// Maps a normalized progress [t] in 0..1 through the curve. Only the input is
  /// clamped; the `*Back` curves deliberately return values slightly outside
  /// 0..1 to produce anticipation / overshoot.
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
      case Ease.easeInBack:
        // Anticipation: pulls back below 0 before driving to 1.
        const c1 = 1.70158;
        const c3 = c1 + 1;
        return c3 * x * x * x - c1 * x * x;
      case Ease.easeOutBack:
        // Follow-through: shoots past 1, then settles back.
        const c1 = 1.70158;
        const c3 = c1 + 1;
        final x1 = x - 1;
        return 1 + c3 * x1 * x1 * x1 + c1 * x1 * x1;
    }
  }
}
