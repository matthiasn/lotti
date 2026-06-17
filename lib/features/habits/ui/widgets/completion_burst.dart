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

  // A generous spread of sparks — enough to feel like a real burst, drawn as
  // trailed "comets" with varied size, speed and lifetime so it reads rich and
  // alive rather than a sparse handful of identical dots.
  static const _count = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    final reach = size.height * 1.5;

    for (var i = 0; i < _count; i++) {
      // An even radial spread with a small per-spark jitter so it reads organic,
      // not mechanical.
      final angle = (i / _count) * math.pi * 2 + (((i * 13) % 7) - 3) * 0.06;
      // Varied speed → some sparks shoot far, some stay close (a sense of depth)
      final speed = 0.45 + ((i * 7) % 9) / 9 * 0.7; // 0.45 … 1.15
      // Varied lifetime → the tail dies in a long staggered spread, not all at
      // once; a spent spark is dropped so nothing lingers in dead space.
      final life = 0.62 + ((i * 5) % 5) / 5 * 0.36; // 0.62 … 0.98
      final lt = (progress / life).clamp(0.0, 1.0);
      if (lt >= 1) continue;

      final ease = Curves.easeOutCubic.transform(lt);
      final dist = reach * speed * ease;
      final gravity = size.height * 0.32 * lt * lt; // a gentle downward arc
      final dir = Offset(math.cos(angle), math.sin(angle));
      final head = center + dir * dist + Offset(0, gravity);

      // A comet head that fades slowly (1 - lt², concave) so the burst lingers
      // long enough to watch, and a tapered trail behind it that's long while
      // the spark is fast and shrinks as it slows.
      final opacity = (1 - lt * lt).clamp(0.0, 1.0);
      final headR = (1.7 + ((i * 3) % 4) / 3 * 1.9) * (1 - 0.4 * lt);
      if (headR <= 0.3) continue;
      final isGold = i % 5 == 0;
      final base = isGold ? gold : accent;

      final trailLen = reach * speed * 0.18 * (1 - ease);
      final tail = head - dir * trailLen;
      canvas
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
      oldDelegate.progress != progress;
}
