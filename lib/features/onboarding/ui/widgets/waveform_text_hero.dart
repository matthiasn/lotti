import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Looping "voice becomes a task" hero that is NOT the literal mic-input orb: a
/// luminous waveform ripples and swells while a task title types in beneath it,
/// then the wave calms as the text resolves, holds, and the loop restarts.
///
/// Reduced motion: a calm static wave plus the full resolved title.
class WaveformTextHero extends StatefulWidget {
  const WaveformTextHero({
    required this.waveColor,
    required this.textColor,
    this.phrase = 'Plan my week',
    super.key,
  });

  final Color waveColor;
  final Color textColor;
  final String phrase;

  @override
  State<WaveformTextHero> createState() => _WaveformTextHeroState();
}

class _WaveformTextHeroState extends State<WaveformTextHero>
    with SingleTickerProviderStateMixin {
  static const _loop = Duration(seconds: 5);

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

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 1.0 : _controller.value;
        // Amplitude is high while "speaking", settles as the text resolves.
        final envelope = reduceMotion
            ? 0.18
            : (1 - _seg(t, 0.45, 0.8)) * 0.85 + 0.15;
        final reveal = reduceMotion ? 1.0 : _seg(t, 0.1, 0.5);
        final shown = (widget.phrase.length * reveal).round();
        final textOpacity = reduceMotion ? 1.0 : 1 - _seg(t, 0.9, 1);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                width: 260,
                child: CustomPaint(
                  painter: _WavePainter(
                    color: widget.waveColor,
                    t: reduceMotion ? 0 : t * _loop.inSeconds,
                    envelope: envelope,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: textOpacity,
                child: Text(
                  widget.phrase.substring(
                    0,
                    shown.clamp(0, widget.phrase.length),
                  ),
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color, required this.t, required this.envelope});

  final Color color;
  final double t;
  final double envelope;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final path = Path();
    const samples = 64;
    for (var i = 0; i <= samples; i++) {
      final x = size.width * i / samples;
      // Two stacked sines give an organic, speech-like ripple.
      final base = math.sin(i / samples * math.pi * 4 + t * 3);
      final detail = math.sin(i / samples * math.pi * 9 - t * 2) * 0.4;
      // Taper amplitude toward the edges so the wave reads as contained.
      final taper = math.sin(i / samples * math.pi);
      final y = mid + (base + detail) * (size.height * 0.32) * envelope * taper;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.envelope != envelope ||
      oldDelegate.color != color;
}
