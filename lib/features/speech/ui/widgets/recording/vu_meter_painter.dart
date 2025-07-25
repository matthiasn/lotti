import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VuMeterPainter extends CustomPainter {
  VuMeterPainter({
    required this.value,
    required this.peakValue,
    required this.clipValue,
    required this.isDarkMode,
    required this.colorScheme,
  });

  final double value;
  final double peakValue;
  final double clipValue;
  final bool isDarkMode;
  final ColorScheme colorScheme;

  // Needle sweeps from about 200 degrees (lower left) to 340 degrees (lower right)
  static const double _startAngle = 200 * math.pi / 180;
  static const double _sweepAngle = 140 * math.pi / 180;
  static const _needlePositionVertical = 0.90;

  @override
  void paint(Canvas canvas, Size size) {
    // Define internal coordinate system
    const double internalWidth = 350;
    const double internalHeight = 140;

    // Calculate scale factor to fit the actual size
    final scaleX = size.width / internalWidth;
    final scaleY = size.height / internalHeight;
    final scale = math.min(scaleX, scaleY);

    // Save canvas state and apply scaling
    canvas
      ..save()
      ..scale(scale, scale);

    // Now work in fixed coordinate space
    const internalSize = Size(internalWidth, internalHeight);

    // Draw scale markings and labels
    _drawScale(canvas, internalSize);

    // Draw VU text
    _drawVuText(canvas, internalSize);

    // Needle pivot at bottom center of meter face - moved down slightly
    const needlePivot =
        Offset(internalWidth / 2, internalHeight * _needlePositionVertical);

    // Draw peak indicator line
    if (peakValue > 0) {
      _drawPeakIndicator(canvas, needlePivot, internalSize);
    }

    // Draw needle
    _drawNeedle(canvas, needlePivot, internalSize);

    // Draw center pivot
    _drawCenterPivot(canvas, needlePivot);

    // Draw clip LED on the right
    _drawClipIndicator(canvas, internalSize);

    // Restore canvas state
    canvas.restore();
  }

  void _drawScale(Canvas canvas, Size size) {
    // Needle pivot at bottom center of meter face - moved down slightly
    final pivot = Offset(size.width / 2, size.height * _needlePositionVertical);
    final radius = size.width * 0.275; // Medium size arc

    // Get theme colors with better contrast
    final mainColor =
        isDarkMode ? colorScheme.primaryFixedDim : colorScheme.onSurface;
    const redColor = Colors.red;

    // Scale positions and labels matching real VU meter
    final scaleMarks = [
      {'pos': 0.0, 'label': '-20', 'major': true},
      {'pos': 0.15, 'label': '-10', 'major': true},
      {'pos': 0.25, 'label': '-7', 'major': true},
      {'pos': 0.35, 'label': '-5', 'major': true},
      {'pos': 0.45, 'label': '-3', 'major': true},
      {'pos': 0.6, 'label': '0', 'major': true, 'red': true},
      {'pos': 0.8, 'label': '3', 'major': true, 'red': true},
      {'pos': 1.0, 'label': '+', 'major': true, 'red': true},
    ];

    // Draw arc scale with thicker line
    final arcRect = Rect.fromCircle(center: pivot, radius: radius);

    // Draw non-red portion of arc (from -20 to 0)
    final normalScalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = mainColor;

    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepAngle * 0.6, // Only up to 0 dB mark
      false,
      normalScalePaint,
    );

    // Draw red portion of arc (from 0 to +3)
    final redScalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = redColor;

    canvas.drawArc(
      arcRect,
      _startAngle + _sweepAngle * 0.595,
      _sweepAngle * 0.41,
      false,
      redScalePaint,
    );

    // Draw tick marks and labels along the arc
    for (var i = 0; i < scaleMarks.length; i++) {
      final mark = scaleMarks[i];
      final position = mark['pos']! as double;
      final angle = _startAngle + position * _sweepAngle;
      final isRed = mark['red'] == true;
      final isMajor = mark['major'] == true;

      // Calculate tick positions
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final outerPoint = Offset(
        pivot.dx + cos * (radius + 1), // Extended by 2px to cover the arc
        pivot.dy + sin * (radius + 1),
      );
      final tickLength = isMajor ? 13 : 9;
      final innerPoint = Offset(
        pivot.dx + cos * (radius - tickLength),
        pivot.dy + sin * (radius - tickLength),
      );

      // Draw tick mark
      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMajor ? 3 : 2
        ..color = isRed ? redColor : mainColor;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Draw label with proper alignment
      final isLeftSide = position < 0.5;
      final labelRadius = radius + 10; // Consistent distance from arc
      final labelPoint = Offset(
        pivot.dx + cos * labelRadius,
        pivot.dy + sin * labelRadius,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: mark['label']! as String,
          style: GoogleFonts.inconsolata(
            color: isRed ? redColor : mainColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Adjust x position based on side
      double labelX;
      if (isLeftSide) {
        // Right-align labels on the left side
        labelX = labelPoint.dx - textPainter.width;
      } else {
        // Left-align labels on the right side
        labelX = labelPoint.dx;
      }

      textPainter.paint(
        canvas,
        Offset(labelX, labelPoint.dy - textPainter.height / 2),
      );

      // Draw minor ticks between major marks
      if (i < scaleMarks.length - 1) {
        final nextPos = scaleMarks[i + 1]['pos']! as double;
        final currentPos = position;
        const numMinorTicks = 4;

        for (var j = 1; j < numMinorTicks; j++) {
          final minorPos =
              currentPos + (nextPos - currentPos) * j / numMinorTicks;
          final minorAngle = _startAngle + minorPos * _sweepAngle;
          final minorCos = math.cos(minorAngle);
          final minorSin = math.sin(minorAngle);
          final isInRedZone = minorPos >= 0.6;

          final minorOuter = Offset(
            pivot.dx + minorCos * (radius + 1),
            pivot.dy + minorSin * (radius + 1),
          );
          final minorInner = Offset(
            pivot.dx + minorCos * (radius - 7),
            pivot.dy + minorSin * (radius - 7),
          );

          canvas.drawLine(
            minorInner,
            minorOuter,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color =
                  (isInRedZone ? redColor : mainColor).withValues(alpha: 0.5),
          );
        }
      }
    }
  }

  void _drawVuText(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'VU',
        style: GoogleFonts.inconsolata(
          fontSize: 24,
          fontWeight: FontWeight.w300,
          color:
              isDarkMode ? colorScheme.primaryFixedDim : colorScheme.onSurface,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter
      ..layout()
      // Position VU text in the center of the meter face - adjusted for new pivot
      ..paint(
        canvas,
        Offset(
          size.width / 2 - textPainter.width / 2,
          size.height * 0.53 - textPainter.height / 2,
        ),
      );
  }

  void _drawPeakIndicator(Canvas canvas, Offset pivot, Size size) {
    final peakColor = isDarkMode ? Colors.orangeAccent : Colors.orange;
    final radius = size.width * 0.275;
    final peakAngle = _startAngle + peakValue * _sweepAngle;
    final cos = math.cos(peakAngle);
    final sin = math.sin(peakAngle);

    // Draw peak indicator line along the arc
    final peakOuter = Offset(
      pivot.dx + cos * (radius + 5),
      pivot.dy + sin * (radius + 5),
    );
    final peakInner = Offset(
      pivot.dx + cos * (radius - 10),
      pivot.dy + sin * (radius - 10),
    );

    final peakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = peakColor;

    canvas.drawLine(peakInner, peakOuter, peakPaint);
  }

  void _drawNeedle(Canvas canvas, Offset pivot, Size size) {
    final mainColor = isDarkMode ? colorScheme.primary : colorScheme.onSurface;
    final radius = size.width * 0.275;
    final needleAngle = _startAngle + value * _sweepAngle;
    final needleLength = radius * 1.1; // Longer needle that extends past arc

    final needleEnd = Offset(
      pivot.dx + math.cos(needleAngle) * needleLength,
      pivot.dy + math.sin(needleAngle) * needleLength,
    );

    // Draw more prominent needle shadow
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawLine(
      Offset(pivot.dx + 2, pivot.dy + 2),
      Offset(needleEnd.dx + 2, needleEnd.dy + 2),
      shadowPaint,
    );

    // Draw main needle
    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = mainColor;

    canvas.drawLine(pivot, needleEnd, needlePaint);
  }

  void _drawCenterPivot(Canvas canvas, Offset center) {
    final mainColor = isDarkMode ? colorScheme.primary : colorScheme.onSurface;
    final highlightColor = isDarkMode
        ? colorScheme.primary.withValues(alpha: 0.3)
        : colorScheme.onSurfaceVariant;

    canvas
      ..drawCircle(
        center,
        6,
        Paint()
          ..style = PaintingStyle.fill
          ..color = mainColor,
      )
      // Small highlight
      ..drawCircle(
        Offset(center.dx - 1, center.dy - 1),
        2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = highlightColor,
      );
  }

  void _drawClipIndicator(Canvas canvas, Size size) {
    // Position the LED on the right side of the meter face, near the + mark
    final ledCenter = Offset(size.width * 0.82, size.height * 0.35);
    const ledRadius = 6.0;

    // LED background - darker when off
    canvas.drawCircle(
      ledCenter,
      ledRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF4B0000), // Very dark red when off
    );

    // LED glow when clipping
    if (clipValue > 0) {
      // Large outer glow
      canvas
        ..drawCircle(
          ledCenter,
          ledRadius * 3,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.red.withValues(alpha: 0.2 * clipValue)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        )

        // Medium glow
        ..drawCircle(
          ledCenter,
          ledRadius * 2,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.redAccent.withValues(alpha: 0.4 * clipValue)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        )

        // LED itself lit up - very bright
        ..drawCircle(
          ledCenter,
          ledRadius,
          Paint()
            ..style = PaintingStyle.fill
            ..shader = ui.Gradient.radial(
              ledCenter,
              ledRadius,
              [
                Colors.white.withValues(alpha: clipValue * 0.8),
                Colors.redAccent.withValues(alpha: clipValue),
                Colors.red.withValues(alpha: clipValue),
              ],
              [0.0, 0.3, 1.0],
            ),
        )

        // Bright white center
        ..drawCircle(
          Offset(ledCenter.dx - 1, ledCenter.dy - 1),
          ledRadius * 0.4,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.white.withValues(alpha: 0.9 * clipValue),
        );
    }

    // LED rim - more prominent
    canvas.drawCircle(
      ledCenter,
      ledRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = isDarkMode
            ? colorScheme.primary.withValues(alpha: 0.7)
            : colorScheme.onSurfaceVariant,
    );

    // PEAK label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PEAK',
        style: GoogleFonts.inconsolata(
          color: isDarkMode
              ? colorScheme.primary.withValues(alpha: 0.8)
              : colorScheme.onSurface,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
          ledCenter.dx - textPainter.width / 2, ledCenter.dy + ledRadius + 3),
    );
  }

  @override
  bool shouldRepaint(VuMeterPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.peakValue != peakValue ||
        oldDelegate.clipValue != clipValue ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
