import 'package:flutter/material.dart';

/// Dashed rounded-rectangle border around [child] — the design system's
/// "provisional / placeholder" surface treatment.
///
/// Single home for the dashed-RRect painter previously re-implemented
/// privately by `DsPill`'s muted variant, the file-upload drop zone, and
/// the Daily OS Next drafted/hint surfaces. The default `[4, 3]` dash
/// rhythm reads as "ghost" without looking dotty at pill radii.
class DsDashedBorder extends StatelessWidget {
  const DsDashedBorder({
    required this.child,
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dashLength = 4,
    this.dashGap = 3,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        dashGap: dashGap,
      ),
      child: child,
    );
  }
}

/// Paints a dashed border along an RRect inset by half the stroke width so
/// the stroke stays inside the painted bounds.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dashLength = 4,
    this.dashGap = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.dashGap != dashGap;
}
