// ignore_for_file: cascade_invocations

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class AnalogVuMeter extends StatefulWidget {
  const AnalogVuMeter({
    required this.decibels,
    required this.size,
    required this.colorScheme,
    super.key,
  });

  final double decibels;
  final double size;
  final ColorScheme colorScheme;

  @override
  State<AnalogVuMeter> createState() => _AnalogVuMeterState();
}

class _AnalogVuMeterState extends State<AnalogVuMeter>
    with TickerProviderStateMixin {
  late AnimationController _needleController;
  late AnimationController _peakController;
  late AnimationController _clipController;
  late Animation<double> _needleAnimation;
  late Animation<double> _peakAnimation;
  late Animation<double> _clipAnimation;

  double _currentValue = 0;
  double _peakValue = 0;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _peakController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _clipController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _needleAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _needleController,
      curve: Curves.easeOutCubic,
    ));

    _peakAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _peakController,
      curve: Curves.easeInOutCubic,
    ));

    _clipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _clipController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(AnalogVuMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decibels != widget.decibels) {
      _updateNeedle(widget.decibels);
    }
  }

  void _updateNeedle(double decibels) {
    final normalizedValue = _normalizeDecibels(decibels);

    _needleAnimation = Tween<double>(
      begin: _currentValue,
      end: normalizedValue,
    ).animate(CurvedAnimation(
      parent: _needleController,
      curve: Curves.easeOutCubic,
    ));

    _needleController.forward(from: 0);
    _currentValue = normalizedValue;

    // Check for clipping (>0.9 of scale is considered hot)
    if (normalizedValue > 0.9) {
      _clipController.forward(from: 0);
      // Hardware VU meters typically hold the clip LED for 150-200ms
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _clipController.reverse();
        }
      });
    }

    // Update peak if current value exceeds it
    if (normalizedValue > _peakValue) {
      _peakValue = normalizedValue;

      _peakAnimation = Tween<double>(
        begin: _peakValue,
        end: _peakValue,
      ).animate(_peakController);

      // Start decay after hold time - peak should fall back to current level, not zero
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _peakAnimation = Tween<double>(
            begin: _peakValue,
            end: _currentValue, // Fall back to current level, not zero
          ).animate(CurvedAnimation(
            parent: _peakController,
            curve: Curves.easeInQuad,
          ));
          _peakController.forward(from: 0).then((_) {
            if (mounted) {
              setState(() {
                _peakValue = _currentValue;
              });
            }
          });
        }
      });
    }
  }

  double _normalizeDecibels(double decibels) {
    // VU meters typically show -20 to +3 dB range
    // Map input decibels (0-160) to VU scale (-20 to +3)
    // 0 dB on VU scale should be at ~60% position

    // Convert to dB scale where 130 input = 0 VU
    final vuDb = (decibels - 130) / 4; // Rough mapping

    // Map VU dB to 0-1 scale position
    if (vuDb <= -20) return 0;
    if (vuDb <= -10) return 0.15 * (vuDb + 20) / 10;
    if (vuDb <= -7) return 0.15 + 0.10 * (vuDb + 10) / 3;
    if (vuDb <= -5) return 0.25 + 0.10 * (vuDb + 7) / 2;
    if (vuDb <= -3) return 0.35 + 0.10 * (vuDb + 5) / 2;
    if (vuDb <= 0) return 0.45 + 0.15 * (vuDb + 3) / 3;
    if (vuDb <= 3) return 0.60 + 0.20 * vuDb / 3;
    return 1; // +3 dB and above
  }

  @override
  void dispose() {
    _needleController.dispose();
    _peakController.dispose();
    _clipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 0.5,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_needleAnimation, _peakAnimation, _clipAnimation]),
        builder: (context, child) {
          return CustomPaint(
            painter: AnalogVuMeterPainter(
              value: _needleAnimation.value,
              peakValue: _peakAnimation.value,
              clipValue: _clipAnimation.value,
              colorScheme: Theme.of(context).colorScheme,
              isDarkMode: Theme.of(context).brightness == Brightness.dark,
            ),
          );
        },
      ),
    );
  }
}

class AnalogVuMeterPainter extends CustomPainter {
  AnalogVuMeterPainter({
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

  @override
  void paint(Canvas canvas, Size size) {
    // Define internal coordinate system
    const double internalWidth = 350;
    const double internalHeight = 175;

    // Calculate scale factor to fit the actual size
    final scaleX = size.width / internalWidth;
    final scaleY = size.height / internalHeight;
    final scale = math.min(scaleX, scaleY);

    // Save canvas state and apply scaling
    canvas.save();
    canvas.scale(scale, scale);

    // Now work in fixed coordinate space
    const internalSize = Size(internalWidth, internalHeight);

    // Draw scale markings and labels
    _drawScale(canvas, internalSize);

    // Draw VU text
    _drawVuText(canvas, internalSize);

    // Needle pivot at bottom center of meter face - moved down slightly
    const needlePivot = Offset(internalWidth / 2, internalHeight * 0.8);

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
    final pivot = Offset(size.width / 2, size.height * 0.8);
    final radius = size.width * 0.275; // Medium size arc

    // Get theme colors
    final mainColor = isDarkMode ? Colors.grey[300]! : Colors.black;
    final redColor = isDarkMode ? Colors.redAccent : Colors.red;
    
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
    final scalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = mainColor;

    // Draw the main arc
    final arcRect = Rect.fromCircle(center: pivot, radius: radius);
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepAngle,
      false,
      scalePaint,
    );

    // Draw red zone arc
    final redZonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = redColor.withValues(alpha: 0.2);

    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: radius - 5),
      _startAngle + _sweepAngle * 0.6,
      _sweepAngle * 0.4,
      false,
      redZonePaint,
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
        pivot.dx + cos * radius,
        pivot.dy + sin * radius,
      );
      final tickLength = isMajor ? 12 : 8;
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
          style: TextStyle(
            color: isRed ? redColor : mainColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

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
            pivot.dx + minorCos * radius,
            pivot.dy + minorSin * radius,
          );
          final minorInner = Offset(
            pivot.dx + minorCos * (radius - 5),
            pivot.dy + minorSin * (radius - 5),
          );

          canvas.drawLine(
            minorInner,
            minorOuter,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = (isInRedZone ? redColor : mainColor)
                  .withValues(alpha: 0.5),
          );
        }
      }
    }
  }

  void _drawVuText(Canvas canvas, Size size) {
    final mainColor = isDarkMode ? Colors.grey[300]! : Colors.black;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'VU',
        style: TextStyle(
          color: mainColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    // Position VU text in the center of the meter face - adjusted for new pivot
    textPainter.paint(
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
    final mainColor = isDarkMode ? Colors.grey[300]! : Colors.black;
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
      ..color = (isDarkMode ? Colors.black : Colors.black).withValues(alpha: 0.3)
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
    final mainColor = isDarkMode ? Colors.grey[300]! : Colors.black;
    final highlightColor = isDarkMode ? Colors.grey[500]! : Colors.grey[600]!;
    
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..style = PaintingStyle.fill
        ..color = mainColor,
    );

    // Small highlight
    canvas.drawCircle(
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
      canvas.drawCircle(
        ledCenter,
        ledRadius * 3,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.red.withValues(alpha: 0.2 * clipValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      // Medium glow
      canvas.drawCircle(
        ledCenter,
        ledRadius * 2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.redAccent.withValues(alpha: 0.4 * clipValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // LED itself lit up - very bright
      canvas.drawCircle(
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
      );

      // Bright white center
      canvas.drawCircle(
        Offset(ledCenter.dx - 1, ledCenter.dy - 1),
        ledRadius * 0.4,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.9 * clipValue),
      );
    }

    // LED rim - more prominent
    final mainColor = isDarkMode ? Colors.grey[300]! : Colors.black;
    canvas.drawCircle(
      ledCenter,
      ledRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = isDarkMode ? const Color(0xFF9A9A9A) : const Color(0xFF6A6A6A),
    );

    // PEAK label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PEAK',
        style: TextStyle(
          color: mainColor,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
          ledCenter.dx - textPainter.width / 2, ledCenter.dy + ledRadius + 3),
    );
  }

  @override
  bool shouldRepaint(AnalogVuMeterPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.peakValue != peakValue ||
        oldDelegate.clipValue != clipValue ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
