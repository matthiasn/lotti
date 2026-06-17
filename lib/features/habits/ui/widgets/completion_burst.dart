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

  static const _count = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    // Kept tighter than the row is tall so sparks read as thrown from the check,
    // not flung across the screen.
    final reach = size.height * 1.25;

    for (var i = 0; i < _count; i++) {
      // Two interleaved rings, rotated so they don't line up.
      final ring = i.isEven ? 0 : 1;
      final angle =
          (i / _count) * math.pi * 2 + (ring == 0 ? 0.0 : math.pi / _count);
      final speed = 0.55 + ((i * 7) % 5) * 0.09;

      // Per-particle lifetime so the tail dies in a staggered spread instead of
      // every spark vanishing on the same frame; a spent spark is dropped
      // entirely so nothing lingers out in dead space.
      final life = 0.55 + ((i * 3) % 4) * 0.11; // 0.55 … 0.88
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      final travel = reach * speed * Curves.easeOutQuart.transform(lt);
      final gravity = size.height * 0.45 * lt * lt; // arcs down as it slows
      final pos =
          center +
          Offset(math.cos(angle) * travel, math.sin(angle) * travel + gravity);

      final opacity = (1 - lt) * (1 - lt); // fast fade so the burst stays crisp
      final radius = (2.4 - 1.6 * lt) * (ring == 0 ? 1.0 : 0.66);
      if (radius <= 0.3) continue;

      // Gold is the rarer, smaller spark — an accent on the accent, not a second
      // colour competing with the brand green.
      final isGold = i % 4 == 0;
      final color = (isGold ? gold : accent).withValues(
        alpha: (opacity * (ring == 0 ? 0.95 : 0.7)).clamp(0.0, 1.0),
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
