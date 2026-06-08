import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/utils/first_day_of_week.dart';

/// Compact month calendar for the desktop navigation sidebar — the
/// `CalendarWidget` from the Daily OS design handoff (sidebar spec):
/// month header with chevrons, weekday initials, day grid with today
/// highlighted in teal and small dots under days that have a plan.
///
/// Purely presentational: the host owns the visible [month], the
/// [markedDays] set, and what tapping a day does.
class SidebarMonthCalendar extends StatelessWidget {
  const SidebarMonthCalendar({
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
    this.selectedDay,
    this.markedDays = const <DateTime>{},
    this.today,
    this.firstDayOfWeekIndex,
    super.key,
  });

  /// Any date inside the month to display.
  final DateTime month;

  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  /// Called with the local midnight of the tapped day.
  final ValueChanged<DateTime> onDaySelected;

  /// Day shown with a selection ring (when it differs from today).
  final DateTime? selectedDay;

  /// Days that carry a small dot (e.g. days with a Daily OS plan).
  /// Compared by local calendar day.
  final Set<DateTime> markedDays;

  /// Injectable "today" for deterministic tests. Defaults to
  /// `clock.now()`.
  final DateTime? today;

  /// Explicit first column of the grid (Flutter convention:
  /// `0 = Sunday` … `6 = Saturday`). When null, falls back to the app
  /// locale's `MaterialLocalizations.firstDayOfWeekIndex`.
  ///
  /// The Daily OS host derives this from the device region (US starts on
  /// Sunday, most of Europe on Monday), resolved natively since macOS hides
  /// the region from Flutter's locale APIs.
  final int? firstDayOfWeekIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final materialLocalizations = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = today ?? clock.now();
    final todayDay = DateTime(now.year, now.month, now.day);
    final selected = selectedDay == null
        ? null
        : DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day);
    final marked = {
      for (final day in markedDays) DateTime(day.year, day.month, day.day),
    };

    final firstDayOfWeekIndex =
        this.firstDayOfWeekIndex ?? materialLocalizations.firstDayOfWeekIndex;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDayOffset = leadingBlankDayCount(
      year: month.year,
      month: month.month,
      firstDayOfWeekIndex: firstDayOfWeekIndex,
    );
    final narrowWeekdays = materialLocalizations.narrowWeekdays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM(locale).format(month),
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _MonthNavButton(
              icon: Icons.chevron_left_rounded,
              tooltip: materialLocalizations.previousMonthTooltip,
              onPressed: onPreviousMonth,
            ),
            SizedBox(width: tokens.spacing.step1),
            _MonthNavButton(
              icon: Icons.chevron_right_rounded,
              tooltip: materialLocalizations.nextMonthTooltip,
              onPressed: onNextMonth,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 7; i++)
              Center(
                child: Text(
                  narrowWeekdays[(firstDayOfWeekIndex + i) % 7],
                  style: calmEyebrowStyle(tokens),
                ),
              ),
            for (var i = 0; i < firstDayOffset; i++) const SizedBox.shrink(),
            for (final cellDay in [
              for (var day = 1; day <= daysInMonth; day++)
                DateTime(month.year, month.month, day),
            ])
              _DayCell(
                day: cellDay,
                isToday: cellDay == todayDay,
                isSelected: cellDay == selected,
                isMarked: marked.contains(cellDay),
                onTap: onDaySelected,
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          onTap: onPressed,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(
              icon,
              size: 16,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isMarked,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isMarked;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final numberColor = isToday
        ? tokens.colors.text.onInteractiveAlert
        : tokens.colors.text.mediumEmphasis;

    return Semantics(
      button: true,
      selected: isSelected || isToday,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onTap(day),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isToday)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: teal,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 24),
              )
            else if (isSelected)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.surface.selected,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 24),
              ),
            Text(
              '${day.day}',
              style: tokens.typography.styles.others.caption.copyWith(
                color: numberColor,
                fontWeight: isToday
                    ? tokens.typography.weight.semiBold
                    : tokens.typography.weight.regular,
              ),
            ),
            if (isMarked)
              Positioned(
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isToday
                        ? tokens.colors.text.onInteractiveAlert
                        : teal,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: tokens.spacing.step1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
