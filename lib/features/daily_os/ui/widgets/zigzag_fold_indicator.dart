import 'package:flutter/material.dart';

/// A CustomPainter that draws a zigzag pattern along the left edge.
///
/// This creates a visual "torn paper" effect that signals hidden/compressed
/// content in the timeline.
class ZigzagFoldPainter extends CustomPainter {
  const ZigzagFoldPainter({
    required this.color,
    this.zigzagWidth = 6,
    this.zigzagHeight = 4,
    this.strokeWidth = 1.5,
  });

  /// The color of the zigzag line.
  final Color color;

  /// Width of each zigzag peak (horizontal distance).
  final double zigzagWidth;

  /// Height of each zigzag peak (vertical distance).
  final double zigzagHeight;

  /// Width of the stroke.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    var y = 0.0;
    var goingRight = true;

    // Start at top-left
    path.moveTo(0, 0);

    while (y < size.height) {
      final nextY = (y + zigzagHeight).clamp(0.0, size.height);
      final x = goingRight ? zigzagWidth : 0.0;
      path.lineTo(x, nextY);
      y = nextY;
      goingRight = !goingRight;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ZigzagFoldPainter oldDelegate) {
    return color != oldDelegate.color ||
        zigzagWidth != oldDelegate.zigzagWidth ||
        zigzagHeight != oldDelegate.zigzagHeight ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

/// A widget that displays a zigzag fold indicator.
///
/// This is typically placed on the left edge of a compressed timeline region
/// to indicate that time has been folded/compressed.
class ZigzagFoldIndicator extends StatelessWidget {
  const ZigzagFoldIndicator({
    required this.color,
    this.width = 10,
    this.zigzagWidth = 6,
    this.zigzagHeight = 4,
    super.key,
  });

  /// The color of the zigzag pattern.
  final Color color;

  /// Total width of the indicator widget.
  final double width;

  /// Width of each zigzag peak.
  final double zigzagWidth;

  /// Height of each zigzag peak.
  final double zigzagHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CustomPaint(
        painter: ZigzagFoldPainter(
          color: color,
          zigzagWidth: zigzagWidth,
          zigzagHeight: zigzagHeight,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
