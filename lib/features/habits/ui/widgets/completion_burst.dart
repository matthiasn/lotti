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
    // Sparks accelerate out then ease to a stop; opacity fades over the back
    // half so the burst reads as a quick flash, not a slow drift.
    final eased = Curves.easeOutCubic.transform(progress);
    final reach = size.height * 1.6;
    final fade = (1 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);

    for (var i = 0; i < _count; i++) {
      // Two interleaved rings of sparks, rotated so they don't line up.
      final ring = i.isEven ? 0 : 1;
      final angle =
          (i / _count) * math.pi * 2 + (ring == 0 ? 0.0 : math.pi / _count);
      final speed = 0.62 + ((i * 7) % 5) * 0.1; // 0.62 … 1.02, varied
      final dist = reach * speed * eased;
      final gravity = size.height * 0.22 * progress * progress; // slight fall
      final pos =
          center +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist + gravity);

      final radius = (3.2 - 2.2 * progress) * (ring == 0 ? 1.0 : 0.7);
      if (radius <= 0.3) continue;
      final color = (i % 3 == 0 ? gold : accent).withValues(
        alpha: (fade * (ring == 0 ? 0.95 : 0.7)).clamp(0.0, 1.0),
      );
      canvas.drawCircle(pos, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
