import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class AnalogVuMeter extends StatefulWidget {
  const AnalogVuMeter({
    super.key,
    required this.decibels,
    required this.size,
  });

  final double decibels;
  final double size;

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
  double _peakHoldTime = 0;
  bool _isClipping = false;

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
      _isClipping = true;
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
      _peakHoldTime = DateTime.now().millisecondsSinceEpoch.toDouble();
      
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
    // Normalize decibels to 0-1 range for meter display
    // Assuming input range is roughly 0-160 dB
    final clampedDb = decibels.clamp(0, 160);
    return clampedDb / 160;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size * 0.8,
          height: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_needleAnimation, _peakAnimation, _clipAnimation]),
            builder: (context, child) {
              return CustomPaint(
                painter: AnalogVuMeterPainter(
                  value: _needleAnimation.value,
                  peakValue: _peakAnimation.value,
                  clipValue: _clipAnimation.value,
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnalogVuMeterPainter extends CustomPainter {
  AnalogVuMeterPainter({
    required this.value,
    required this.peakValue,
    required this.clipValue,
    required this.isDarkMode,
  });

  final double value;
  final double peakValue;
  final double clipValue;
  final bool isDarkMode;

  // Vertical orientation: -150 degrees (pointing down-left) to -30 degrees (pointing down-right)
  static const double _startAngle = -150 * math.pi / 180;
  static const double _sweepAngle = 120 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width * 0.45;

    // Draw meter background
    _drawMeterBackground(canvas, center, radius, size);
    
    // Draw scale markings
    _drawScale(canvas, center, radius);
    
    // Draw peak indicator
    if (peakValue > 0) {
      _drawPeakIndicator(canvas, center, radius);
    }
    
    // Draw needle
    _drawNeedle(canvas, center, radius * 0.9);
    
    // Draw center pivot
    _drawCenterPivot(canvas, center);
    
    // Draw clip LED
    _drawClipIndicator(canvas, size);
  }

  void _drawMeterBackground(Canvas canvas, Offset center, double radius, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFF2A2A2A),
          isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFF1A1A1A),
        ],
        [0.0, 1.0],
      );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.1),
      _startAngle - 0.1,
      _sweepAngle + 0.2,
      true,
      paint,
    );

    // Draw outer rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFF4A4A4A);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.1),
      _startAngle - 0.1,
      _sweepAngle + 0.2,
      false,
      rimPaint,
    );
  }

  void _drawScale(Canvas canvas, Offset center, double radius) {
    final majorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    final minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = isDarkMode ? Colors.grey[600]! : Colors.grey[400]!;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw major scale markings and labels
    const divisions = 10;
    for (int i = 0; i <= divisions; i++) {
      final angle = _startAngle + (i / divisions) * _sweepAngle;
      final cos = math.cos(angle);
      final sin = math.sin(angle);

      // Major tick marks
      final innerPoint = Offset(
        center.dx + cos * radius * 0.85,
        center.dy + sin * radius * 0.85,
      );
      final outerPoint = Offset(
        center.dx + cos * radius * 0.95,
        center.dy + sin * radius * 0.95,
      );

      canvas.drawLine(innerPoint, outerPoint, majorPaint);

      // Labels
      String label;
      if (i <= 2) {
        label = '${-20 + i * 10}';
      } else if (i <= 7) {
        label = '${(i - 2) * 10}';
      } else if (i == 8) {
        label = '60\n80';
      } else if (i == 9) {
        label = '80\n10%';
      } else {
        label = '1\n3\n+';
      }

      final labelOffset = Offset(
        center.dx + cos * radius * 0.7,
        center.dy + sin * radius * 0.7,
      );

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          fontSize: label.contains('\n') ? 8 : 10,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );

      // Minor tick marks
      if (i < divisions) {
        for (int j = 1; j < 5; j++) {
          final minorAngle = angle + (j / 5) * (_sweepAngle / divisions);
          final minorCos = math.cos(minorAngle);
          final minorSin = math.sin(minorAngle);

          final minorInner = Offset(
            center.dx + minorCos * radius * 0.9,
            center.dy + minorSin * radius * 0.9,
          );
          final minorOuter = Offset(
            center.dx + minorCos * radius * 0.95,
            center.dy + minorSin * radius * 0.95,
          );

          canvas.drawLine(minorInner, minorOuter, minorPaint);
        }
      }
    }

    // Draw red zone
    final redZonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08
      ..color = Colors.red.withOpacity(0.3);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.91),
      _startAngle + _sweepAngle * 0.75,
      _sweepAngle * 0.25,
      false,
      redZonePaint,
    );
  }

  void _drawPeakIndicator(Canvas canvas, Offset center, double radius) {
    final peakAngle = _startAngle + peakValue * _sweepAngle;
    final cos = math.cos(peakAngle);
    final sin = math.sin(peakAngle);

    final peakPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.orange.withOpacity(0.8);

    final peakStart = Offset(
      center.dx + cos * radius * 0.82,
      center.dy + sin * radius * 0.82,
    );
    final peakEnd = Offset(
      center.dx + cos * radius * 0.88,
      center.dy + sin * radius * 0.88,
    );

    canvas.drawLine(
      peakStart,
      peakEnd,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.orange,
    );
  }

  void _drawNeedle(Canvas canvas, Offset center, double needleLength) {
    final needleAngle = _startAngle + value * _sweepAngle;
    final cos = math.cos(needleAngle);
    final sin = math.sin(needleAngle);

    final needleEnd = Offset(
      center.dx + cos * needleLength,
      center.dy + sin * needleLength,
    );

    // Draw needle shadow
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawLine(
      Offset(center.dx + 2, center.dy + 2),
      Offset(needleEnd.dx + 2, needleEnd.dy + 2),
      shadowPaint,
    );

    // Draw main needle
    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = isDarkMode ? Colors.white : Colors.black;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw needle tip
    final tipPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    canvas.drawCircle(needleEnd, 4, tipPaint);
  }

  void _drawCenterPivot(Canvas canvas, Offset center) {
    // Outer circle
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFF3A3A3A),
    );

    // Inner circle
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.radial(
          center,
          8,
          [
            isDarkMode ? Colors.grey[700]! : Colors.grey[600]!,
            isDarkMode ? Colors.grey[900]! : Colors.grey[800]!,
          ],
          [0.0, 1.0],
        ),
    );

    // Highlight
    canvas.drawCircle(
      Offset(center.dx - 2, center.dy - 2),
      3,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(0.3),
    );
  }

  void _drawClipIndicator(Canvas canvas, Size size) {
    // Position the LED in the top right corner of the meter
    final ledCenter = Offset(size.width * 0.85, size.height * 0.15);
    final ledRadius = 8.0;
    
    // Background (dark LED)
    canvas.drawCircle(
      ledCenter,
      ledRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFF3A3A3A),
    );
    
    // LED glow when clipping
    if (clipValue > 0) {
      // Outer glow
      canvas.drawCircle(
        ledCenter,
        ledRadius * 2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.red.withOpacity(0.2 * clipValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      
      // LED itself
      canvas.drawCircle(
        ledCenter,
        ledRadius,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.radial(
            ledCenter,
            ledRadius,
            [
              Colors.red.shade300.withOpacity(clipValue),
              Colors.red.withOpacity(clipValue),
            ],
            [0.0, 1.0],
          ),
      );
      
      // Bright center
      canvas.drawCircle(
        Offset(ledCenter.dx - 2, ledCenter.dy - 2),
        ledRadius * 0.3,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(0.8 * clipValue),
      );
    }
    
    // LED border
    canvas.drawCircle(
      ledCenter,
      ledRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = isDarkMode ? Colors.grey[800]! : Colors.grey[700]!,
    );
    
    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PEAK',
        style: TextStyle(
          color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
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
      Offset(ledCenter.dx - textPainter.width / 2, ledCenter.dy + ledRadius + 4),
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