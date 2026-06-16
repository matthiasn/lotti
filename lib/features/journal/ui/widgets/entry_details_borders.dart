import 'dart:async';

import 'package:flutter/material.dart';

class _GlowBorderPainter extends CustomPainter {
  _GlowBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.glowSigma,
    required this.devicePixelRatio,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double glowSigma;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // Align to device pixels for crisp corners/edges
    final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final alignedWidth = (size.width * dpr).round() / dpr;
    final alignedHeight = (size.height * dpr).round() / dpr;

    // Choose nearest whole-physical-pixel thickness to requested width (min 1px)
    final requestedPx = strokeWidth * dpr;
    final ringPx = requestedPx < 1 ? 1.0 : requestedPx.roundToDouble();
    final ringLogical = ringPx / dpr;

    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, alignedWidth, alignedHeight),
      Radius.circular(radius),
    );
    final inner = outer.deflate(ringLogical);

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        glowSigma != oldDelegate.glowSigma;
  }
}

/// A rounded-rectangle border that pulses (fades 0.4↔1.0) for a fixed number
/// of loops after `startDelay`, then fades to zero and stops.
///
/// Used as the temporary scroll-to highlight around an entry card (in the
/// entry's category color). Edges are device-pixel-aligned for crisp corners
/// and the whole thing is wrapped in a [RepaintBoundary]. Contrast with
/// [TimerBorder], the persistent border for the actively-recording entry.
class PulsingBorder extends StatefulWidget {
  const PulsingBorder({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.duration,
    required this.loopCount,
    required this.startDelay,
    super.key,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final Duration duration;
  final int loopCount; // run this many loops, then stop
  final Duration startDelay;

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _startDelayTimer;

  late final Animation<double> _opacity = () {
    const low = 0.4;
    const high = 1.0;
    // Build N loops (low->high->low), but end last loop by fading to 0
    final n = widget.loopCount.clamp(1, 10);
    final items = <TweenSequenceItem<double>>[];
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      // The very first up-tween starts fully transparent so the border stays
      // hidden during the `startDelay` window (controller value 0.0) and only
      // becomes visible once `_controller.forward()` runs.
      final upTween = Tween<double>(
        begin: i == 0 ? 0.0 : low,
        end: high,
      ).chain(CurveTween(curve: Curves.easeInOutSine));
      final downCurve = isLast ? Curves.easeOutCubic : Curves.easeInOutSine;
      final downEnd = isLast ? 0.0 : low;
      final downTween = Tween<double>(
        begin: high,
        end: downEnd,
      ).chain(CurveTween(curve: downCurve));

      items
        ..add(TweenSequenceItem(tween: upTween, weight: 50))
        ..add(TweenSequenceItem(tween: downTween, weight: 50));
    }
    final sequence = TweenSequence<double>(items);
    return _controller.drive(sequence);
  }();

  @override
  void initState() {
    super.initState();
    // Start the finite animation sequence once.
    _startDelayTimer = Timer(widget.startDelay, () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _startDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr =
        MediaQuery.maybeOf(context)?.devicePixelRatio ??
        View.of(context).devicePixelRatio;
    // Derive a slight tint shift based on current opacity to increase visibility
    const low = 0.4;
    final p = ((_opacity.value - low) / (1 - low)).clamp(0.0, 1.0);
    final tinted = Color.lerp(widget.color, Colors.white, 0.15 * p)!;

    return FadeTransition(
      opacity: _opacity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GlowBorderPainter(
            color: tinted,
            radius: widget.radius,
            strokeWidth: widget.strokeWidth,
            glowSigma: 0, // sharp edges; no blur
            devicePixelRatio: dpr,
          ),
        ),
      ),
    );
  }
}

/// A static rounded-rectangle stroke painted around the entry card that is
/// actively recording a timer. Unlike [PulsingBorder] it does not animate — it
/// stays drawn (in the error color) for as long as the entry is the running
/// timer.
class TimerBorder extends StatelessWidget {
  const TimerBorder({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    super.key,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimerBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TimerBorderPainter extends CustomPainter {
  const _TimerBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _TimerBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
