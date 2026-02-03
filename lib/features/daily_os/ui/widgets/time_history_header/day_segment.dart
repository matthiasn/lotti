import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/themes/theme.dart';

/// Fixed width for each day segment in the horizontal list.
const double daySegmentWidth = 56;

/// Individual day segment in the horizontal list.
///
/// Premium design features:
/// - Two-line layout: weekday abbreviation on top, day number below
/// - Selected state: filled primary background with contrasting text
/// - Weekend differentiation: subtle outline border for Sat/Sun
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

  bool get _isWeekend {
    final weekday = daySummary.day.weekday;
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  @override
  Widget build(BuildContext context) {
    final day = daySummary.day;
    final locale = Localizations.localeOf(context).toString();
    final weekdayAbbrev = DateFormat.E(locale).format(day);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        label: DateFormat.yMMMMd(locale).format(day),
        button: true,
        selected: isSelected,
        child: SizedBox(
          width: daySegmentWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _buildDayContent(context, weekdayAbbrev, day.day),
          ),
        ),
      ),
    );
  }

  Widget _buildDayContent(
    BuildContext context,
    String weekdayAbbrev,
    int dayNumber,
  ) {
    // Determine colors based on state
    final Color weekdayColor;
    final Color dayNumberColor;
    final FontWeight dayNumberWeight;

    if (isSelected) {
      weekdayColor = context.colorScheme.onPrimary;
      dayNumberColor = context.colorScheme.onPrimary;
      dayNumberWeight = FontWeight.w700;
    } else if (_isWeekend) {
      weekdayColor = context.colorScheme.onSurfaceVariant;
      dayNumberColor = context.colorScheme.onSurface.withValues(alpha: 0.8);
      dayNumberWeight = FontWeight.w500;
    } else {
      weekdayColor = context.colorScheme.onSurfaceVariant;
      dayNumberColor = context.colorScheme.onSurface;
      dayNumberWeight = FontWeight.w500;
    }

    // Build the text content
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 2),
        Text(
          weekdayAbbrev,
          style: context.textTheme.labelSmall?.copyWith(
            color: weekdayColor,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          dayNumber.toString(),
          style: context.textTheme.titleMedium?.copyWith(
            color: dayNumberColor,
            fontWeight: dayNumberWeight,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
      ],
    );

    // Apply decoration based on state - use Align to prevent expansion
    if (isSelected) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: content,
        ),
      );
    }

    if (_isWeekend) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: content,
        ),
      );
    }

    // Default weekday state: no background
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: content,
      ),
    );
  }
}
