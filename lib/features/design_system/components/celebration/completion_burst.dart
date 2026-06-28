import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_burst_painters.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A short burst of particles that fly out of the completed thing and fade — the
/// "magic check" beat. Driven by a one-shot controller resting at `1`: at
/// [progress] near `0` the particles are tight on the origin, by `1` they've
/// flown out and vanished. Motion is index-seeded (no RNG) so it stays
/// deterministic for golden capture.
///
/// [params] carries the variant *and* its tunable look (count, size, reach,
/// cleared centre, plus the variant's physics knobs); switching variant only
/// swaps the painter (see [buildCelebrationBurstPainter]). When omitted it falls
/// back to the default [CelebrationVariant.defaultVariant] look.
///
/// Render it *over* the card inside an [IgnorePointer], in a non-clipping Stack,
/// so particles can leave the row's rounded rect. [origin] is the burst centre
/// in fractional coordinates (default: over the trailing complete button).
class CompletionBurst extends StatelessWidget {
  const CompletionBurst({
    required this.progress,
    this.params,
    this.secondParams,
    this.origin = const Alignment(0.82, 0),
    this.reachOverride,
    super.key,
  });

  final double progress;

  /// The variant and its tunable look. Defaults to the product-default variant's
  /// untouched parameters when null.
  final CelebrationParams? params;

  /// When set, a second particle language is layered over [params] — the
  /// "combine two" surprise mode (see [CombinedBurstPainter]).
  final CelebrationParams? secondParams;

  final Alignment origin;

  /// Absolute reach in pixels. When set it overrides [CelebrationParams.reachFactor]
  /// × height — used when the burst paints in a roomy overlay box (so it isn't
  /// clipped) but the spread must stay sized to a small anchor (a checkbox, a
  /// pill).
  final double? reachOverride;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final resolved =
        params ??
        CelebrationParams.defaultsFor(CelebrationVariant.defaultVariant);
    final primary = buildCelebrationBurstPainter(
      params: resolved,
      progress: progress,
      origin: origin,
      accent: accent,
      reachOverride: reachOverride,
    );
    final second = secondParams;
    return CustomPaint(
      painter: second == null
          ? primary
          : CombinedBurstPainter(
              primary,
              buildCelebrationBurstPainter(
                params: second,
                progress: progress,
                origin: origin,
                accent: accent,
                reachOverride: reachOverride,
              ),
            ),
    );
  }
}
