import 'dart:math' as math;

import 'package:lotti/features/character/model/easing.dart';

/// A signed easing curve: maps normalized segment progress `t` in 0..1 to an
/// eased output that MAY leave 0..1 on purpose — dipping below 0 for
/// *anticipation* (a wind-up against the move) and rising above 1 for
/// *overshoot* (a follow-through past the target before it settles). The
/// endpoints are always exact (`f(0) == 0`, `f(1) == 1`), so the keyframe values
/// the curve interpolates between are still hit precisely on the beat.
typedef EaseCurve = double Function(double t);

/// Laban-Effort *dynamics* for a dance accent: the "how" of a beat gesture,
/// kept separate from the "what" (which bone moves where, authored as the
/// keyframe values). Each factor is a signed dial in -1..1 whose extremes are
/// the opposing Effort Elements:
///
/// - [weight]: Light (-1) .. Strong (+1) — a Strong accent winds up before it
///   drives (anticipation) and arrives harder.
/// - [time]: Sustained (-1) .. Sudden (+1) — a Sudden accent snaps late
///   (accelerates into the peak); a Sustained one eases in early and
///   decelerates.
/// - [flow]: Bound (-1) .. Free (+1) — a Free accent overshoots the target and
///   settles back (follow-through); a Bound one arrives and holds without
///   overshoot.
///
/// Effort *Space* (direct/indirect) is deliberately omitted: the computational
/// Laban-Movement-Analysis literature found it the least reliable of the four
/// factors, so only Weight/Time/Flow are exposed. [neutral] (all zero)
/// reproduces a plain `easeInOut` exactly, so layering dynamics onto an existing
/// accent is opt-in and regression-free.
///
/// Const-constructible so it can live in `const` choreography data; the curve it
/// implies is built at clip-assembly time by [dynamicsCurve].
class DanceDynamics {
  const DanceDynamics({this.weight = 0, this.time = 0, this.flow = 0});

  /// Light (-1) .. Strong (+1).
  final double weight;

  /// Sustained (-1) .. Sudden (+1).
  final double time;

  /// Bound (-1) .. Free (+1).
  final double flow;

  /// The do-nothing dynamics: maps to `easeInOut`, with no anticipation,
  /// overshoot, or snap. Used as the regression-safe default.
  static const DanceDynamics neutral = DanceDynamics();

  bool get isNeutral => weight == 0 && time == 0 && flow == 0;
}

/// Peak anticipation depth — the fraction of the value range the curve dips
/// below the start — at full Strong [DanceDynamics.weight]. ~0.30 reads as a
/// clear wind-up without looking broken.
const double _kAnticipationScale = 0.30;

/// Peak overshoot height — the fraction past the target the curve rises — at
/// full Free [DanceDynamics.flow].
const double _kOvershootScale = 0.30;

/// Normaliser for the early/late shaping bumps: `1 / max(x·(1-x)³)`, whose
/// maximum sits at `x = 0.25` (= 0.10546875). Multiplying the bumps by this
/// makes [_kAnticipationScale]/[_kOvershootScale] read directly as each bump's
/// peak contribution.
const double _kBumpNorm = 9.481481481481482;

/// Builds the [EaseCurve] for [d] using the EMOTE recipe adapted to a single
/// inter-keyframe segment:
///
/// - the inflection point `tᵢ = 0.5 + 0.4·max(strong, sudden) − 0.4·max(light,
///   sustained)` (clamped to 0.15..0.85) skews where the curve is steepest —
///   late for a Sudden/Strong snap, early for a Light/Sustained settle —
///   realised as a power time-warp that maps `tᵢ → 0.5` of an `easeInOut`;
/// - a Strong [DanceDynamics.weight] subtracts an early bump so the curve dips
///   below 0 (anticipation wind-up);
/// - a Free [DanceDynamics.flow] adds a late bump so the curve rises above 1
///   (overshoot / follow-through) before returning to exactly 1.
///
/// Pure and deterministic; the endpoints are exact. [DanceDynamics.neutral]
/// returns `easeInOut` unchanged.
EaseCurve dynamicsCurve(DanceDynamics d) {
  if (d.isNeutral) return (t) => Ease.easeInOut.apply(t);

  final strong = math.max(d.weight, 0);
  final light = math.max(-d.weight, 0);
  final sudden = math.max(d.time, 0);
  final sustained = math.max(-d.time, 0);
  final free = math.max(d.flow, 0);

  final inflection =
      (0.5 + 0.4 * math.max(strong, sudden) - 0.4 * math.max(light, sustained))
          .clamp(0.15, 0.85);
  final anticipation = _kAnticipationScale * strong;
  final overshoot = _kOvershootScale * free;
  // Power warp that sends `inflection → 0.5`, so the easeInOut's steepest point
  // lands at the inflection. gamma == 1 (the identity) when inflection == 0.5.
  final gamma = math.log(0.5) / math.log(inflection);

  return (t) {
    final x = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    final warped = math.pow(x, gamma).toDouble();
    final base = 0.5 - 0.5 * math.cos(math.pi * warped);
    final early = anticipation * _kBumpNorm * x * math.pow(1 - x, 3).toDouble();
    final late = overshoot * _kBumpNorm * math.pow(x, 3).toDouble() * (1 - x);
    return base - early + late;
  };
}
