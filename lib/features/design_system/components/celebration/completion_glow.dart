import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A soft accent glow that **blooms outward and dissipates** — the premium
/// successor to a hard flashing border. Driven by a one-shot controller that
/// rests at `1`: at [value] `0` (the instant of completion) the glow is tight
/// and bright; as it runs to `1` the halo spreads and fades to nothing.
///
/// Render it *behind* the (opaque) card it celebrates so only the halo shows
/// around the edges; the shadow must not be inside a clip, or it gets cut off.
/// The blur/spread are visual-effect dimensions (like a cell size), not layout
/// spacing; the colour and radius come from tokens.
///
/// When [staticGlow] is set (the reduced-motion path) the halo holds a fixed
/// size and only its opacity fades — an acknowledgement with no spatial motion,
/// so it stays safe under "reduce motion" while the glow still happens.
///
/// [intensity] scales the peak opacity (1.0 = full). Dial it down for a glow
/// that should be a soft acknowledgement rather than a celebration in its own
/// right — e.g. a whole-section completion that already has per-item bursts, so
/// a full-strength bloom would read as blinding.
///
/// [color] tints the halo; when null it uses the app accent. A warm celebration
/// variant (embers) passes a warm tone so the bloom matches its particles
/// instead of reading as the cool accent.
class CompletionGlow extends StatelessWidget {
  const CompletionGlow({
    required this.value,
    this.staticGlow = false,
    this.intensity = 1.0,
    this.color,
    super.key,
  });

  /// `0` → bright + tight (just completed); `1` → gone (rest).
  final double value;

  /// Fixed-size halo, opacity-only fade — for reduced motion.
  final bool staticGlow;

  /// Multiplier on the peak opacity (1.0 = full strength).
  final double intensity;

  /// Halo tint; defaults to the app accent when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final alpha = ((1 - value) * 0.55 * intensity).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        boxShadow: [
          BoxShadow(
            color: (color ?? tokens.colors.interactive.enabled).withValues(
              alpha: alpha,
            ),
            blurRadius: staticGlow ? 18 : 8 + 20 * value,
            spreadRadius: staticGlow ? 6 : 1 + 12 * value,
          ),
        ],
      ),
    );
  }
}
