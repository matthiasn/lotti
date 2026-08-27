import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A row of small bars, one per day, with the last day accented — the
/// compact "how has this signal been going" strip in the completion sheet.
///
/// A `null` value is a day without data and draws as a hairline stub so the
/// strip keeps its rhythm; the accented last bar uses the enabled surface
/// when today has nothing yet. No axes, no labels: the numbers live in the
/// row's caption.
class SignalSparkline extends StatelessWidget {
  const SignalSparkline({required this.values, super.key});

  /// Oldest first; the last entry is today.
  final List<num?> values;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: values.last?.toString(),
      child: SizedBox(
        height: tokens.spacing.step8,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            history: tokens.colors.surface.active,
            today: tokens.colors.interactive.enabled,
            empty: tokens.colors.surface.enabled,
            gap: tokens.spacing.step1,
            radius: tokens.radii.xs,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.history,
    required this.today,
    required this.empty,
    required this.gap,
    required this.radius,
  });

  final List<num?> values;
  final Color history;
  final Color today;
  final Color empty;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.whereType<num>().fold<num>(0, (m, v) => v > m ? v : m);
    final barWidth = (size.width - gap * (values.length - 1)) / values.length;
    final stub = size.height * 0.08;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final isToday = i == values.length - 1;
      final height = value == null || max == 0
          ? stub
          : stub + (size.height - stub) * (value / max);
      final paint = Paint()
        ..color = isToday
            ? (value == null ? empty : today)
            : (value == null ? empty : history);
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(radius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values ||
      old.history != history ||
      old.today != today ||
      old.empty != empty;
}
