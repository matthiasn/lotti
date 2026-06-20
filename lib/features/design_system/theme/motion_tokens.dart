/// Motion design tokens for the app.
///
/// Hand-authored rather than generated: the design-token generator only emits
/// lerp-able `color` / `double` / `string` scalars on a `ThemeExtension`, and
/// `Duration` / `Curve` are brightness-invariant (identical in light and dark)
/// and don't lerp meaningfully through that machinery. Motion is also not a
/// Figma *variable* in this repo's export, so there is no upstream source of
/// truth to import. A small, named `const` set is the honest representation and
/// the single source of truth for animation timing across the app.
///
/// Durations follow the Material 3 duration scale; curves follow the M3
/// easing family (standard / emphasized-decelerate / emphasized-accelerate).
library;

import 'package:flutter/animation.dart';

/// The Material-3 duration scale (subset in active use).
///
/// Pick by *distance*: short on-screen moves (a single row collapsing,
/// neighbours reflowing a few logical px) belong at the short end; only
/// large/complex transitions reach [long2]. Nothing on-screen should exceed
/// ~500ms — a longer value reads as a hang, not as grace.
abstract final class MotionDurations {
  /// 100ms — micro fades, value cross-fades (count badge).
  static const Duration short2 = Duration(milliseconds: 100);

  /// 150ms — the in-place "resolve" acknowledgement beat.
  static const Duration short3 = Duration(milliseconds: 150);

  /// 200ms — small enters/exits.
  static const Duration short4 = Duration(milliseconds: 200);

  /// 250ms — a single row collapsing/expanding.
  static const Duration medium1 = Duration(milliseconds: 250);

  /// 300ms — list reflow, one row entering.
  static const Duration medium2 = Duration(milliseconds: 300);

  /// 400ms — larger coordinated moves.
  static const Duration medium4 = Duration(milliseconds: 400);

  /// 500ms — the longest on-screen transition (e.g. the one-shot swipe nudge).
  static const Duration long2 = Duration(milliseconds: 500);
}

/// The Material-3 easing family.
///
/// Rule of thumb: **entering / settling** elements *decelerate* into rest
/// (long soft tail, no hard stop); **exiting** elements *accelerate* away;
/// supporting motion uses [standard].
abstract final class MotionCurves {
  /// Symmetric emphasized / standard easing for supporting motion.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Entering and settling elements — fast off the line, long gentle tail so
  /// the motion *arrives* at rest instead of stopping. This is the curve the
  /// user actually watches when a gap closes, so the soft landing matters most.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Exiting elements — eases in, accelerates away.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
}

/// The one shared "resolve → collapse" choreography for an accepted/rejected
/// AI proposal row, so the row, the checklist hold above it, the pending-count
/// badge, and the residual scroll stabiliser all read a single timeline.
///
/// The two beats **overlap**: the collapse begins while the resolve beat is in
/// its tail, so contact → rest stays crisp (~[total]) instead of the two
/// durations summing. Within the collapse the content opacity leads the height
/// (the row is visually gone before the gap finishes closing) so the gap reads
/// as space *healing* rather than a thing deflating.
abstract final class ProposalMotion {
  /// The in-place acknowledgement beat: a filled check / dismiss badge + a
  /// plain-language word firm in, a restrained wash settles, a light haptic
  /// fires — all with no layout change, so the row the finger is on never moves
  /// out from under it. Held long enough that low-vision / slower-reading users
  /// can register *what* happened before the row leaves.
  static const Duration resolveHold = MotionDurations.short4; // 200ms

  /// Height collapse + fade. The collapsing height *is* the reflow: neighbours
  /// slide up on this same tween (no snap, no FLIP bookkeeping).
  static const Duration collapse = MotionDurations.medium1; // 250ms

  /// Where in the resolve beat the collapse joins (0–1). High, so the badge is
  /// fully shown and dwells before the row starts to leave.
  static const double collapseStart = 0.9;

  /// The collapse / reflow is what the user watches — decelerate into stillness.
  static const Curve collapseCurve = MotionCurves.emphasizedDecelerate;

  /// Total perceived contact → rest, accounting for the beat overlap.
  static const Duration total = Duration(milliseconds: 440);

  /// Per-row stagger for the confirm-all sweep (clamp the index, see usage).
  static const Duration staggerStep = Duration(milliseconds: 55);

  /// The one-shot swipe-affordance nudge (single directional peek, out + back).
  static const Duration nudge = MotionDurations.long2; // 500ms
}
