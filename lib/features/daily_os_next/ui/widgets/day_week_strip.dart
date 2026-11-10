import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kMinFlingVelocity;
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The seven days of [selected]'s week, as the day page's primary day
/// control.
///
/// The week starts on the locale's first day
/// ([MaterialLocalizations.firstDayOfWeekIndex]). Each cell is the weekday's
/// initial over the day number; the selected day is a `surface.selected`
/// pill with `interactive.enabled` text, and today — when it is not the
/// selected day — carries a small teal dot under its number. A tap selects a
/// day; a horizontal fling pages a week (keeping the weekday), and with
/// [showWeekChevrons] the strip carries a chevron at each end that does the
/// same for a mouse. Days with a plan show nothing extra: the strip is
/// navigation, not a heat-map.
///
/// Presentation only: the host owns the selected day.
class DayWeekStrip extends StatelessWidget {
  const DayWeekStrip({
    required this.selected,
    required this.today,
    required this.onSelect,
    this.showWeekChevrons = false,
    super.key,
  });

  /// The day the page shows. Only its date counts.
  final DateTime selected;

  /// The current day, for the today dot. Only its date counts.
  final DateTime today;

  /// Called with the day the user picked: a tapped cell, or [selected]
  /// moved a week by a fling or a chevron.
  final ValueChanged<DateTime> onSelect;

  /// Whether to put a previous/next-week chevron at the strip's ends —
  /// for wide layouts, where a fling is awkward with a mouse.
  final bool showWeekChevrons;

  /// The seven days of the week holding [day], starting on the weekday
  /// [firstDayOfWeekIndex] names (0 is Sunday, as in
  /// [MaterialLocalizations.firstDayOfWeekIndex]). Built with the
  /// `DateTime` constructor so the days stay midnight-aligned across a DST
  /// change.
  @visibleForTesting
  static List<DateTime> weekOf(DateTime day, int firstDayOfWeekIndex) {
    // DateTime.weekday is 1 (Monday) to 7 (Sunday); `% 7` maps Sunday to 0
    // like the Material index, and Dart's `%` is never negative.
    final offset = (day.weekday % 7 - firstDayOfWeekIndex) % 7;
    return [
      for (var i = 0; i < 7; i++)
        DateTime(day.year, day.month, day.day - offset + i),
    ];
  }

  void _shiftWeek(int weeks) => onSelect(
    DateTime(selected.year, selected.month, selected.day + 7 * weeks),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    final days = weekOf(selected, material.firstDayOfWeekIndex);
    final strip = LayoutBuilder(
      builder: (context, constraints) {
        // Cells share the width on a phone and stop growing on a wide pane,
        // where seven stretched cells would scatter the week across it.
        final cellWidth = math.min(
          constraints.maxWidth / days.length,
          TapTargets.minimum + tokens.spacing.step3,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final day in days)
              SizedBox(
                width: cellWidth,
                child: _DayCell(
                  key: ValueKey('daily_os_week_strip_${day.toIso8601String()}'),
                  day: day,
                  selected: DateUtils.isSameDay(day, selected),
                  today: DateUtils.isSameDay(day, today),
                  onTap: () => onSelect(day),
                ),
              ),
          ],
        );
      },
    );
    return GestureDetector(
      // A fling, not any drag, so a slow pan that ends on a cell still
      // reads as a tap and the strip does not jump a week by accident.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < kMinFlingVelocity) return;
        _shiftWeek(velocity < 0 ? 1 : -1);
      },
      child: showWeekChevrons
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('daily_os_week_strip_previous'),
                  icon: const Icon(LottiIcons.chevronLeft),
                  tooltip: messages.dailyOsNextWeekStripPreviousWeek,
                  onPressed: () => _shiftWeek(-1),
                ),
                Flexible(child: strip),
                IconButton(
                  key: const Key('daily_os_week_strip_next'),
                  icon: const Icon(LottiIcons.chevronRight),
                  tooltip: messages.dailyOsNextWeekStripNextWeek,
                  onPressed: () => _shiftWeek(1),
                ),
              ],
            )
          : strip,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
    super.key,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final material = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    // The selected day leads; the rest of the week stays a step quieter.
    final ink = selected
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final dotSize = tokens.spacing.step2;
    return Semantics(
      button: true,
      selected: selected,
      label: context.messages.dailyOsNextWeekStripSelectDay(
        DateFormat.MMMMEEEEd(locale).format(day),
      ),
      // The cell's own words stand in for its two Texts; the tap is restated
      // here because excluding the subtree's semantics drops the InkWell's.
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? tokens.colors.surface.selected : null,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TapTargets.minimum),
              // step1: the 48 pt minimum already gives the cell its height,
              // so the strip spends no more of a phone's screen than that.
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      material.narrowWeekdays[day.weekday % 7],
                      maxLines: 1,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: selected
                            ? tokens.colors.interactive.enabled
                            : tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      '${day.day}',
                      maxLines: 1,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: ink,
                            fontFeatures: dayFigures,
                          ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    // The dot's slot is always there, so today's cell is no
                    // taller than its neighbours.
                    SizedBox.square(
                      dimension: dotSize,
                      child: today && !selected
                          ? DecoratedBox(
                              key: const Key('daily_os_week_strip_today_dot'),
                              decoration: BoxDecoration(
                                color: tokens.colors.interactive.enabled,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
