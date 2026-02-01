import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/themes/theme.dart';

/// Fixed width for each day segment in the horizontal list.
const double daySegmentWidth = 56;

/// Individual day segment in the horizontal list.
class DaySegment extends StatelessWidget {
  const DaySegment({
    required this.daySummary,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final DayTimeSummary daySummary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = daySummary.day;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: DateFormat.yMMMMd().format(day),
        button: true,
        selected: isSelected,
        child: Container(
          width: daySegmentWidth,
          decoration: BoxDecoration(
            // Left border as day separator (midnight divider)
            border: Border(
              left: BorderSide(
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(
                      color: context.colorScheme.primary,
                      width: 2,
                    )
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Day number
                Text(
                  day.day.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
