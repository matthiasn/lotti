import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_burst_painters.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A short burst of particles that fly out of the completed thing and fade — the
/// "magic check" beat. Driven by a one-shot controller resting at `1`: at
/// [progress] near `0` the particles are tight on the origin, by `1` they've
/// flown out and vanished. Motion is index-seeded (no RNG) so it stays
/// deterministic for golden capture.
///
/// [variant] picks which particle language the burst speaks (sparks, fireworks,
/// confetti, embers, bubbles); the staging around it is identical, so switching
/// variant only swaps the painter (see [buildCelebrationBurstPainter]).
///
/// Render it *over* the card inside an [IgnorePointer], in a non-clipping Stack,
/// so particles can leave the row's rounded rect. [origin] is the burst centre
/// in fractional coordinates (default: over the trailing complete button).
class CompletionBurst extends StatelessWidget {
  const CompletionBurst({
    required this.progress,
    this.variant = CelebrationVariant.defaultVariant,
    this.origin = const Alignment(0.82, 0),
    this.count = 30,
    this.sizeScale = 1.0,
    this.clearCenter = 0.0,
    this.reachFactor = 2.1,
    this.reachOverride,
    super.key,
  });

  final double progress;

  /// Which particle language the burst speaks.
  final CelebrationVariant variant;

  final Alignment origin;

  /// Number of particles. Higher reads as a denser, richer burst.
  final int count;

  /// How far particles fly, as a multiple of the paint area's height. Lower
  /// keeps the burst a tight ring hugging its anchor; higher gives a wider
  /// spray for a standalone card.
  final double reachFactor;

  /// Absolute reach in pixels. When set it overrides [reachFactor] × height —
  /// used when the burst paints in a roomy overlay box (so it isn't clipped)
  /// but the spread must stay sized to a small anchor (a checkbox, a pill).
  final double? reachOverride;

  /// Multiplier on each particle's head/trail size. Below 1 yields finer
  /// particles — pair a denser [count] with a sub-1 scale so the burst reads
  /// rich, not heavy.
  final double sizeScale;

  /// Fraction of the burst's reach kept clear around [origin] — particles emit
  /// from a ring at this radius rather than the exact centre, so they radiate
  /// *around* the celebrated thing instead of obscuring its label. `0` emits
  /// from the centre.
  final double clearCenter;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    return CustomPaint(
      painter: buildCelebrationBurstPainter(
        variant: variant,
        progress: progress,
        origin: origin,
        accent: tokens.colors.interactive.enabled,
        count: count,
        sizeScale: sizeScale,
        clearCenter: clearCenter,
        reachFactor: reachFactor,
        reachOverride: reachOverride,
      ),
    );
  }
}
