import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/colors.dart';

/// A short burst of accent sparks that fly out of the completed check and fade
/// — the "magic check" beat. Driven by a one-shot controller resting at `1`:
/// at [progress] near `0` the sparks are tight on the origin, by `1` they've
/// flown out and vanished. Particle motion is index-seeded (no RNG) so it stays
/// deterministic for golden capture.
///
/// Render it *over* the card inside an [IgnorePointer], in a non-clipping Stack,
/// so sparks can leave the row's rounded rect. [origin] is the burst centre in
/// fractional coordinates (default: over the trailing complete button).
class CompletionBurst extends StatelessWidget {
  const CompletionBurst({
    required this.progress,
    this.origin = const Alignment(0.82, 0),
    this.count = 30,
    this.sizeScale = 1.0,
    this.clearCenter = 0.0,
    this.reachFactor = 2.1,
    this.reachOverride,
    super.key,
  });

  final double progress;
  final Alignment origin;

  /// Number of sparks. Higher reads as a denser, richer burst.
  final int count;

  /// How far the sparks fly, as a multiple of the paint area's height. Lower
  /// keeps the burst a tight ring hugging its anchor (so it doesn't splash into
  /// adjacent text or off-screen); higher gives a wider spray for a standalone
  /// card.
  final double reachFactor;

  /// Absolute reach in pixels. When set it overrides [reachFactor] × height —
  /// used when the burst paints in a roomy overlay box (so it isn't clipped)
  /// but the spread must stay sized to a small anchor (a checkbox, a pill).
  final double? reachOverride;

  /// Multiplier on each spark's head/trail size. Below 1 yields finer sparks —
  /// pair a denser [count] with a sub-1 scale so the burst reads rich, not
  /// heavy.
  final double sizeScale;

  /// Fraction of the burst's reach kept clear around [origin] — sparks emit
  /// from a ring at this radius rather than the exact centre, so they radiate
  /// *around* the thing being celebrated (a status pill, a progress ring)
  /// instead of obscuring its label. `0` emits from the centre (the default,
  /// e.g. over a complete button with no text under it).
  final double clearCenter;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    return CustomPaint(
      painter: _BurstPainter(
        progress: progress,
        origin: origin,
        accent: tokens.colors.interactive.enabled,
        gold: starredGold,
        count: count,
        sizeScale: sizeScale,
        clearCenter: clearCenter,
        reachFactor: reachFactor,
        reachOverride: reachOverride,
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.origin,
    required this.accent,
    required this.gold,
    required this.count,
    required this.sizeScale,
    required this.clearCenter,
    required this.reachFactor,
    required this.reachOverride,
  });

  final double progress;
  final Alignment origin;
  final Color accent;
  final Color gold;

  // A full spread of sparks — enough to feel like a real burst, drawn as
  // trailed "comets" with varied size, speed and lifetime so it reads rich and
  // alive rather than a sparse handful of identical dots.
  final int count;
  final double sizeScale;
  final double clearCenter;
  final double reachFactor;
  final double? reachOverride;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    final reach = reachOverride ?? (size.height * reachFactor);
    final clearRadius = reach * clearCenter;

    for (var i = 0; i < count; i++) {
      // An even radial spread with a small per-spark jitter so it reads organic,
      // not mechanical.
      final angle = (i / count) * math.pi * 2 + (((i * 13) % 7) - 3) * 0.05;
      // Varied speed → some sparks shoot far, some stay close (a sense of depth)
      final speed = 0.5 + ((i * 7) % 9) / 9 * 0.8; // 0.5 … 1.3
      // Varied lifetime → the tail dies in a long staggered spread, not all at
      // once; a spent spark is dropped so nothing lingers in dead space.
      final life = 0.7 + ((i * 5) % 5) / 5 * 0.3; // 0.7 … 1.0
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      // A quick initial pop blended with a steady linear component, so the
      // sparks keep *drifting* outward through their life instead of snapping to
      // a stop right after the burst.
      final ease = 0.5 * Curves.easeOutCubic.transform(lt) + 0.5 * lt;
      final dist = clearRadius + reach * speed * ease;
      final gravity = size.height * 0.16 * lt * lt; // a faint floaty droop
      final dir = Offset(math.cos(angle), math.sin(angle));
      final head = center + dir * dist + Offset(0, gravity);

      // Two depth tiers so the burst layers instead of reading uniform: a
      // third of the sparks are brighter, larger "lead" motes in front, the
      // rest dimmer and smaller behind them.
      final isLead = i % 3 == 0;
      final tierScale = isLead ? 1.25 : 0.82;
      final tierAlpha = isLead ? 1.0 : 0.72;
      // A big comet head that fades slowly (1 - lt², concave) so the burst
      // lingers long enough to watch, with a tapered trail behind it that's long
      // while the spark is fast and shrinks as it drifts.
      final opacity = ((1 - lt * lt) * tierAlpha).clamp(0.0, 1.0);
      final headR =
          (2.6 + ((i * 3) % 4) / 3 * 2.6) * (1 - 0.32 * lt) * sizeScale * tierScale;
      if (headR <= 0.3) continue;
      final isGold = i % 5 == 0;
      final base = isGold ? gold : accent;

      final trailLen = reach * speed * 0.2 * (1 - ease);
      // Stop the trail at the clear-centre ring so it never streaks back over
      // the celebrated label.
      final tailDist = (dist - trailLen).clamp(clearRadius, dist);
      final tail = center + dir * tailDist + Offset(0, gravity);
      canvas
        // A faint halo so each spark reads as a glowing mote, not a flat dot.
        ..drawCircle(
          head,
          headR * 2.2,
          Paint()
            ..color = base.withValues(alpha: (opacity * 0.18).clamp(0.0, 1.0)),
        )
        ..drawLine(
          tail,
          head,
          Paint()
            ..color = base.withValues(alpha: (opacity * 0.4).clamp(0.0, 1.0))
            ..strokeWidth = headR * 0.9
            ..strokeCap = StrokeCap.round,
        )
        ..drawCircle(
          head,
          headR,
          Paint()
            ..color = base.withValues(alpha: (opacity * 0.95).clamp(0.0, 1.0)),
        );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.accent != accent ||
      oldDelegate.gold != gold ||
      oldDelegate.count != count ||
      oldDelegate.sizeScale != sizeScale ||
      oldDelegate.clearCenter != clearCenter ||
      oldDelegate.reachFactor != reachFactor ||
      oldDelegate.reachOverride != reachOverride;
}
