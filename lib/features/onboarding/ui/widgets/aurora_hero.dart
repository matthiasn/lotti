import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Slow flowing aurora: several large soft colour blooms drift on lissajous
/// paths and blend additively over a dark surface, producing a calm, premium
/// "living gradient". Pure [CustomPainter] (additive radial gradients) so it
/// renders identically in offline goldens — no fragment shader needed.
///
/// Used as the ambient backdrop of the connect page (a different motion from
/// the welcome's neural constellation). Under reduced motion a single static
/// frame is painted.
class AuroraHero extends StatefulWidget {
  const AuroraHero({required this.colors, this.maxAlpha = 0.55, super.key});

  /// Bloom colours (3–4 reads best); each drifts and blends additively.
  final List<Color> colors;

  /// Peak alpha of each bloom centre — lower it to keep the aurora subtle
  /// behind foreground content.
  final double maxAlpha;

  @override
  State<AuroraHero> createState() => _AuroraHeroState();
}

class _AuroraHeroState extends State<AuroraHero>
    with SingleTickerProviderStateMixin {
  static const _loop = Duration(seconds: 22);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _AuroraPainter(
              colors: widget.colors,
              t: _controller.value * _loop.inSeconds,
              maxAlpha: widget.maxAlpha,
            ),
          );
        },
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.colors,
    required this.t,
    required this.maxAlpha,
  });

  final List<Color> colors;
  final double t;
  final double maxAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final diag = size.longestSide;
    for (var i = 0; i < colors.length; i++) {
      // Each bloom drifts on its own slow lissajous orbit.
      final fx = 0.18 + i * 0.05;
      final fy = 0.13 + i * 0.06;
      final phase = i * 1.7;
      final cx = (0.5 + 0.34 * math.cos(t * fx + phase)) * size.width;
      final cy = (0.45 + 0.32 * math.sin(t * fy + phase * 1.3)) * size.height;
      final center = Offset(cx, cy);
      final radius = diag * (0.55 + 0.12 * math.sin(t * 0.1 + phase));

      final shader = RadialGradient(
        colors: [
          colors[i].withValues(alpha: maxAlpha),
          colors[i].withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.maxAlpha != maxAlpha ||
      !listEquals(oldDelegate.colors, colors);
}
