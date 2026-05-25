import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// SVG-style donut showing how much of the day's capacity is
/// scheduled. Color flips with pressure:
/// - `< 90%` → teal (comfortable)
/// - `90–100%` → warning amber (near full)
/// - `> 100%` → error red (over capacity); a 0.5-alpha second ring
///   visually exceeds the full circle.
class CapacityDonut extends StatelessWidget {
  const CapacityDonut({
    required this.scheduledMinutes,
    required this.capacityMinutes,
    this.diameter = 86,
    super.key,
  });

  final int scheduledMinutes;
  final int capacityMinutes;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ratio = capacityMinutes == 0
        ? 0.0
        : scheduledMinutes / capacityMinutes;
    final teal = tokens.colors.interactive.enabled;
    final warning = tokens.colors.alert.warning.defaultColor;
    final error = tokens.colors.alert.error.defaultColor;
    final color = ratio < 0.9
        ? teal
        : ratio <= 1.0
        ? warning
        : error;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _DonutPainter(
          ratio: ratio,
          color: color,
          backgroundColor: tokens.colors.background.level03,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatHours(scheduledMinutes),
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: color,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              Text(
                context.messages.dailyOsNextAgendaCapacityOf(
                  _formatHours(capacityMinutes),
                ),
                style: tokens.typography.styles.others.overline.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m}m';
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.ratio,
    required this.color,
    required this.backgroundColor,
  });

  final double ratio;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final track = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final clamped = ratio.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      clamped * 2 * math.pi,
      false,
      fill,
    );

    // Over-amount draws as a partially overlapping second ring at
    // 0.5 alpha so over-capacity is unmistakable.
    if (ratio > 1.0) {
      final over = (ratio - 1.0).clamp(0.0, 1.0);
      final overPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        over * 2 * math.pi,
        false,
        overPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.ratio != ratio ||
      old.color != color ||
      old.backgroundColor != backgroundColor;
}
