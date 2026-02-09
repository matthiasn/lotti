import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/themes/theme.dart';

/// A continuous tap-bar with 10 visual tick marks.
///
/// Tapping stores the exact horizontal position as 0.0-1.0.
/// No snapping — a tap between tick 3 and 4 stores ~0.35.
class RatingTapBar extends StatelessWidget {
  const RatingTapBar({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double? value;
  final ValueChanged<double> onChanged;

  static const int _tickCount = 10;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onTapDown: (details) {
            final normalized =
                (details.localPosition.dx / width).clamp(0.0, 1.0);
            onChanged(normalized);
            HapticFeedback.selectionClick();
          },
          onHorizontalDragUpdate: (details) {
            final normalized =
                (details.localPosition.dx / width).clamp(0.0, 1.0);
            onChanged(normalized);
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: CustomPaint(
              size: Size(width, 40),
              painter: _TapBarPainter(
                value: value,
                tickCount: _tickCount,
                activeColor: colorScheme.primary,
                inactiveColor:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                fillColor: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TapBarPainter extends CustomPainter {
  _TapBarPainter({
    required this.value,
    required this.tickCount,
    required this.activeColor,
    required this.inactiveColor,
    required this.fillColor,
  });

  final double? value;
  final int tickCount;
  final Color activeColor;
  final Color inactiveColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final tickSpacing = size.width / tickCount;

    // Draw fill up to value
    if (value != null) {
      final fillWidth = value! * size.width;
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillWidth, size.height),
          const Radius.circular(8),
        ),
        fillPaint,
      );
    }

    // Draw tick marks
    final tickPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < tickCount; i++) {
      final x = i * tickSpacing;
      final isActive = value != null && (i / tickCount) <= value!;
      tickPaint.color = isActive ? activeColor : inactiveColor;
      canvas.drawLine(
        Offset(x, size.height * 0.25),
        Offset(x, size.height * 0.75),
        tickPaint,
      );
    }

    // Draw value indicator
    if (value != null) {
      final indicatorX = value! * size.width;
      final indicatorPaint = Paint()..color = activeColor;
      canvas.drawCircle(
        Offset(indicatorX, size.height / 2),
        6,
        indicatorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TapBarPainter oldDelegate) =>
      value != oldDelegate.value ||
      activeColor != oldDelegate.activeColor ||
      inactiveColor != oldDelegate.inactiveColor ||
      fillColor != oldDelegate.fillColor;
}

/// A segmented button input for categorical rating questions.
///
/// Renders each option as a [SegmentedButton] segment. When an option
/// is selected, [onChanged] is called with its normalized value.
class RatingSegmentedInput extends StatelessWidget {
  const RatingSegmentedInput({
    required this.label,
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<({String label, double value})> segments;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        SegmentedButton<double>(
          segments: [
            for (final segment in segments)
              ButtonSegment(
                value: segment.value,
                label: Text(segment.label),
              ),
          ],
          selected: value != null ? {value!} : {},
          onSelectionChanged: (selected) {
            if (selected.isEmpty) {
              onChanged(null);
            } else {
              onChanged(selected.first);
              HapticFeedback.selectionClick();
            }
          },
          emptySelectionAllowed: true,
        ),
      ],
    );
  }
}
