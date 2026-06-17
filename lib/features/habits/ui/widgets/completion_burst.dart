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
    super.key,
  });

  final double progress;
  final Alignment origin;

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
  });

  final double progress;
  final Alignment origin;
  final Color accent;
  final Color gold;

  // A modest count in a single ring — enough to read as a celebratory spark
  // without the swarming, hectic feel of a dense double ring.
  static const _count = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    // Tight to the check so the sparks read as a small flourish thrown from it,
    // not flung across the screen.
    final reach = size.height * 1.05;

    for (var i = 0; i < _count; i++) {
      // One evenly-spaced ring, offset so it doesn't sit on the axes.
      final angle = (i / _count) * math.pi * 2 + 0.35;
      final speed = 0.6 + ((i * 7) % 5) * 0.07; // 0.60 … 0.88, gentle variation

      // Per-particle lifetime so the tail dies in a staggered spread instead of
      // every spark vanishing on the same frame; a spent spark is dropped
      // entirely so nothing lingers out in dead space.
      final life = 0.6 + ((i * 3) % 4) * 0.1; // 0.6 … 0.9
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      // easeOutCubic eases out more softly than quart — the sparks drift to a
      // stop rather than snapping outward.
      final travel = reach * speed * Curves.easeOutCubic.transform(lt);
      final gravity = size.height * 0.32 * lt * lt; // a gentle downward arc
      final pos =
          center +
          Offset(math.cos(angle) * travel, math.sin(angle) * travel + gravity);

      final opacity = (1 - lt) * (1 - lt); // smooth quadratic fade
      final radius = 2.6 - 1.6 * lt;
      if (radius <= 0.3) continue;

      // Gold is the rarer, smaller spark — an accent on the accent, not a second
      // colour competing with the brand green.
      final isGold = i % 4 == 0;
      final color = (isGold ? gold : accent).withValues(
        alpha: (opacity * 0.9).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        pos,
        isGold ? radius * 0.82 : radius,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
