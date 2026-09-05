import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/first_day_of_week.dart';
import 'package:material_ui/material_ui.dart';

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
    this.reserveFullMonthHeight = false,
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

  /// Pads the day grid out to a constant [_maxWeekRows] rows, so the calendar
  /// occupies the same height in every month.
  ///
  /// A month needs between four and six week rows depending on its length and
  /// which weekday it starts on — February 2026 fits in five, March 2026 needs
  /// six. Left to size itself the calendar therefore grows and shrinks as you
  /// page through months, which moves everything below it and makes the
  /// chevrons jump out from under the pointer.
  ///
  /// Off by default: a host that simply stacks the calendar (the navigation
  /// sidebar) can absorb the reflow, and reserving a row it rarely needs would
  /// cost it real estate. Hosts that present the calendar as a card turn it on.
  final bool reserveFullMonthHeight;

  /// The most week rows any month can occupy: 31 days starting on the last
  /// column spills into a sixth week.
  static const _maxWeekRows = 6;

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
    // Blank cells after the last day, so every month fills the same number of
    // week rows. Never negative: the widest month (offset 6 + 31 days = 37)
    // still fits inside the 42 cells six rows provide.
    final trailingBlankDayCount = reserveFullMonthHeight
        ? _maxWeekRows * DateTime.daysPerWeek - firstDayOffset - daysInMonth
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  DateFormat.yMMMM(locale).format(month),
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _MonthNavButton(
              icon: LottiIcons.chevronLeft,
              tooltip: materialLocalizations.previousMonthTooltip,
              onPressed: onPreviousMonth,
            ),
            SizedBox(width: tokens.spacing.step1),
            _MonthNavButton(
              icon: LottiIcons.chevronRight,
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
            for (var i = 0; i < trailingBlankDayCount; i++)
              const SizedBox.shrink(),
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
      container: true,
      button: true,
      selected: isSelected,
      label: _semanticLabel(context),
      onTap: () => onTap(day),
      child: ExcludeSemantics(
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
                    child: SizedBox.square(dimension: tokens.spacing.step2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel(BuildContext context) {
    final labels = [MaterialLocalizations.of(context).formatFullDate(day)];
    if (isToday) labels.add(context.messages.calendarTodayLabel);
    if (isMarked) labels.add(context.messages.calendarHasPlanLabel);
    return labels.join(', ');
  }
}
