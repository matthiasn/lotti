import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Ring donut for the day's planned load — `prototype/screens/plan.jsx →
/// CapacityDonut`.
///
/// 10 px stroke over a faint background ring. Ring color flips with
/// pressure: `< 90%` teal, `90–100%` warning, `> 100%` error with the
/// over-amount drawn as a second half-alpha arc continuing past the
/// clamped end. Center label shows `{scheduled}h` over an `of {N}h`
/// eyebrow whose color matches the ring when over capacity.
///
/// [neutral] forces the teal ring regardless of ratio — the honest
/// "No plan yet" strip uses this to show tracked hours without a false
/// "Near full" reading.
class CapacityDonut extends StatelessWidget {
  const CapacityDonut({
    required this.scheduledMinutes,
    required this.capacityMinutes,
    this.size = 86,
    this.neutral = false,
    super.key,
  });

  final int scheduledMinutes;
  final int capacityMinutes;
  final double size;

  /// Render the ring in neutral teal regardless of the ratio.
  final bool neutral;

  /// `scheduled / capacity`, `0` when the capacity is unset.
  static double ratioFor(int scheduledMinutes, int capacityMinutes) {
    if (capacityMinutes <= 0) return 0;
    return scheduledMinutes / capacityMinutes;
  }

  /// Compact decimal-hour label, e.g. `5.3h`, `4h`.
  static String formatDecimalHours(int minutes) {
    final hours = minutes / 60;
    final rounded = (hours * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) return '${rounded.round()}h';
    return '${rounded.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ratio = ratioFor(scheduledMinutes, capacityMinutes);
    final over = !neutral && ratio > 1.0;
    final ringColor = neutral || ratio < 0.9
        ? tokens.colors.interactive.enabled
        : ratio <= 1.0
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.alert.error.defaultColor;

    final centerLabel = formatDecimalHours(scheduledMinutes);
    final eyebrow = context.messages.dailyOsNextAgendaCapacityOf(
      formatDecimalHours(capacityMinutes),
    );

    return Semantics(
      label: context.messages.dailyOsNextAgendaSummary(
        formatDecimalHours(scheduledMinutes),
        formatDecimalHours(capacityMinutes),
      ),
      value: '${(ratio * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(
            ratio: ratio,
            color: ringColor,
            trackColor: tokens.colors.background.level03,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  style: calmDisplayStyle(tokens).copyWith(
                    fontSize: size > 100 ? 22 : 18,
                  ),
                ),
                Text(
                  eyebrow.toUpperCase(),
                  style: calmEyebrowStyle(
                    tokens,
                    color: over
                        ? tokens.colors.alert.error.defaultColor
                        : tokens.colors.text.lowEmphasis,
                  ).copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.ratio,
    required this.color,
    required this.trackColor,
  });

  final double ratio;
  final Color color;
  final Color trackColor;

  static const _stroke = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawCircle(center, radius, track);

    final clamped = ratio.clamp(0.0, 1.0);
    if (clamped > 0) {
      final ring = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        clamped * 2 * math.pi,
        false,
        ring,
      );
    }

    // Over-capacity amount continues past the clamped end at half alpha.
    if (ratio > 1.0) {
      final overPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -math.pi / 2 + clamped * 2 * math.pi,
        (ratio - 1).clamp(0.0, 1.0) * 2 * math.pi,
        false,
        overPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.ratio != ratio || old.color != color || old.trackColor != trackColor;
}
