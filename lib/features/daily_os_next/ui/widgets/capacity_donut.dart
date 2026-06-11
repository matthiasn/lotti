import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One category slice of the capacity ring.
@immutable
class CapacityDonutSegment {
  const CapacityDonutSegment({required this.color, required this.minutes});

  final Color color;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is CapacityDonutSegment &&
      other.color == color &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(color, minutes);
}

/// Ring donut for the day's planned load.
///
/// 5 px stroke over a faint background track. When [segments] are given
/// the ring is the stacked category mix matching the legend dots beside it
/// (the gray remainder = free capacity); otherwise a single teal arc. The
/// center shows the *remaining* capacity ("45m" over a LEFT eyebrow) —
/// pressure wording lives in the stat card's overline, so the ring stays
/// calm until the day is genuinely over capacity (error color + OVER
/// eyebrow, with the over-amount drawn as a half-alpha arc continuing
/// past the clamped end).
///
/// [neutral] keeps the calm treatment regardless of ratio — the honest
/// "No plan yet" strip uses this to show tracked hours without a false
/// pressure reading.
class CapacityDonut extends StatelessWidget {
  const CapacityDonut({
    required this.scheduledMinutes,
    required this.capacityMinutes,
    this.size = 86,
    this.neutral = false,
    this.segments = const [],
    super.key,
  });

  final int scheduledMinutes;
  final int capacityMinutes;
  final double size;

  /// Render the ring in the calm treatment regardless of the ratio.
  final bool neutral;

  /// Optional per-category slices (color + minutes) that stack into the
  /// ring so it matches the category legend. Falls back to a single teal
  /// arc when empty.
  final List<CapacityDonutSegment> segments;

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
    final overColor = tokens.colors.alert.error.defaultColor;

    final remaining = capacityMinutes - scheduledMinutes;
    final centerLabel = formatMinutesCompact(remaining.abs());
    final eyebrow = over
        ? context.messages.dailyOsNextAgendaDonutOver
        : context.messages.dailyOsNextAgendaDonutLeft;

    return Semantics(
      label: context.messages.dailyOsNextAgendaSummary(
        formatMinutesCompact(scheduledMinutes),
        formatMinutesCompact(capacityMinutes),
      ),
      value: '${(ratio * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(
            ratio: ratio,
            color: over ? overColor : tokens.colors.interactive.enabled,
            trackColor: tokens.colors.background.level03,
            // Over capacity the stacked ring would silently clip its last
            // slices; fall back to the explicit over state (error ring +
            // half-alpha over-arc) instead of lying by omission.
            segmentSweeps: [
              if (capacityMinutes > 0 && !over)
                for (final segment in segments)
                  (
                    color: segment.color,
                    sweep: (segment.minutes / capacityMinutes).clamp(0.0, 1.0),
                  ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  style: calmDisplayStyle(tokens).copyWith(
                    fontSize: size > 100 ? 22 : 18,
                    color: over ? overColor : tokens.colors.text.highEmphasis,
                  ),
                ),
                Text(
                  eyebrow.toUpperCase(),
                  style: calmEyebrowStyle(
                    tokens,
                    color: over ? overColor : tokens.colors.text.lowEmphasis,
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
    required this.segmentSweeps,
  });

  final double ratio;
  final Color color;
  final Color trackColor;
  final List<({Color color, double sweep})> segmentSweeps;

  static const _stroke = 5.0;

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
    if (segmentSweeps.isNotEmpty) {
      // Stacked category arcs, butt-capped so the slices tile cleanly into
      // one ring that mirrors the legend.
      var startAngle = -math.pi / 2;
      for (final segment in segmentSweeps) {
        final sweep = segment.sweep * 2 * math.pi;
        if (sweep <= 0) continue;
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke;
        canvas.drawArc(rect, startAngle, sweep, false, paint);
        startAngle += sweep;
      }
    } else if (clamped > 0) {
      final ring = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      // A full 2π arc with a round cap renders unreliably on some
      // backends (overlapping start/end points) — draw a circle instead.
      if (clamped >= 1.0) {
        canvas.drawCircle(center, radius, ring);
      } else {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          clamped * 2 * math.pi,
          false,
          ring,
        );
      }
    }

    // Over-capacity amount continues past the clamped end at half alpha.
    if (ratio > 1.0) {
      final overPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      final overSweep = (ratio - 1).clamp(0.0, 1.0);
      if (overSweep >= 1.0) {
        canvas.drawCircle(center, radius, overPaint);
      } else {
        canvas.drawArc(
          rect,
          -math.pi / 2 + clamped * 2 * math.pi,
          overSweep * 2 * math.pi,
          false,
          overPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.ratio != ratio ||
      old.color != color ||
      old.trackColor != trackColor ||
      !listEquals(old.segmentSweeps, segmentSweeps);
}
