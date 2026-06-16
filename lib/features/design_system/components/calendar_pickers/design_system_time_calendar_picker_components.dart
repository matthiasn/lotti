part of 'design_system_time_calendar_picker.dart';

class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard({
    required this.mode,
    required this.visibleMonth,
    required this.selectedDate,
    required this.currentDate,
    this.onMonthYearPressed,
    this.onPreviousPressed,
    this.onNextPressed,
    this.onDayPressed,
  });

  final DesignSystemTimeCalendarPickerMode mode;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime currentDate;
  final VoidCallback? onMonthYearPressed;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;
  final ValueChanged<DateTime>? onDayPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = TimeCalendarPalette.fromMode(mode);
    final geometry = TimeCalendarGeometry.fromTokens(tokens);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final firstDayOfWeek = MaterialLocalizations.of(
      context,
    ).firstDayOfWeekIndex;
    final visibleLabel = DateFormat.yMMMM(localeTag).format(visibleMonth);
    final weeks = _buildMonthGrid(visibleMonth, firstDayOfWeek);

    return CalendarMaterialCard(
      palette: palette,
      geometry: geometry,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonthHeader(
            palette: palette,
            geometry: geometry,
            label: visibleLabel,
            showDisclosure: true,
            onLabelPressed: onMonthYearPressed,
            onPreviousPressed: onPreviousPressed,
            onNextPressed: onNextPressed,
          ),
          SizedBox(height: geometry.sectionGap),
          Row(
            children: _weekdayLabels(localeTag, firstDayOfWeek).map((label) {
              return SizedBox(
                width: geometry.weekdayColumnWidth,
                child: Center(
                  child: Text(
                    label,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: palette.lowEmphasis,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: geometry.sectionGap),
          for (final week in weeks)
            Row(
              children: [
                for (final day in week)
                  if (day == null)
                    SizedBox(
                      width: geometry.dayCellWidth,
                      height: geometry.dayCellHeight,
                    )
                  else
                    Builder(
                      builder: (context) {
                        final dayDate = DateTime(
                          visibleMonth.year,
                          visibleMonth.month,
                          day,
                        );
                        return _CalendarDayButton(
                          palette: palette,
                          label: '$day',
                          isCurrentDay: _isSameDay(dayDate, currentDate),
                          isSelected: _isSameDay(dayDate, selectedDate),
                          onPressed: onDayPressed == null
                              ? null
                              : () => onDayPressed!(dayDate),
                        );
                      },
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The frosted-glass surface shared by the time-calendar month card and the
/// month-selection dialog.
///
/// Applies the [TimeCalendarPalette]'s blurred translucent fill, rounded
/// corners, and drop shadow at the dimensions from [TimeCalendarGeometry],
/// then pads and renders [child].
class CalendarMaterialCard extends StatelessWidget {
  const CalendarMaterialCard({
    required this.palette,
    required this.geometry,
    required this.child,
    this.padding,
    super.key,
  });

  final TimeCalendarPalette palette;
  final TimeCalendarGeometry geometry;
  final EdgeInsets? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: geometry.cardWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(geometry.cardRadius),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: geometry.cardShadowBlur,
            offset: Offset(0, geometry.cardShadowOffsetY),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(geometry.cardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: palette.surfaceBlurSigma,
                  sigmaY: palette.surfaceBlurSigma,
                ),
                child: ColoredBox(color: palette.surfaceBase),
              ),
            ),
            Padding(
              padding: padding ?? geometry.contentPadding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Header row for the time-calendar card: the month/year [label] (optionally
/// tappable with a disclosure chevron) plus previous/next paging icon buttons.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    required this.palette,
    required this.geometry,
    required this.label,
    required this.showDisclosure,
    this.onLabelPressed,
    this.onPreviousPressed,
    this.onNextPressed,
    super.key,
  });

  final TimeCalendarPalette palette;
  final TimeCalendarGeometry geometry;
  final String label;
  final bool showDisclosure;
  final VoidCallback? onLabelPressed;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final headerStyle = tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: palette.highEmphasis,
    );

    final labelWidget = Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: headerStyle,
          ),
        ),
        if (showDisclosure) ...[
          SizedBox(width: geometry.labelDisclosureGap),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: palette.accent,
          ),
        ],
      ],
    );

    return SizedBox(
      height: geometry.headerHeight,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: onLabelPressed == null
                  ? Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.designTokens.spacing.step3,
                      ),
                      child: labelWidget,
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(
                        geometry.labelTapRadius,
                      ),
                      onTap: onLabelPressed,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: context.designTokens.spacing.step3,
                        ),
                        child: labelWidget,
                      ),
                    ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderIconButton(
                geometry: geometry,
                icon: Icons.chevron_left_rounded,
                color: palette.accent,
                tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
                onPressed: onPreviousPressed,
              ),
              SizedBox(width: context.designTokens.spacing.step1),
              _HeaderIconButton(
                geometry: geometry,
                icon: Icons.chevron_right_rounded,
                color: palette.accent,
                tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                onPressed: onNextPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.geometry,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onPressed,
  });

  final TimeCalendarGeometry geometry;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: geometry.headerIconConstraint,
        height: geometry.headerIconConstraint,
      ),
      splashRadius: geometry.headerIconSplashRadius,
      onPressed: onPressed,
      icon: Icon(icon, size: geometry.headerIconSize, color: color),
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.palette,
    required this.label,
    required this.isCurrentDay,
    required this.isSelected,
    this.onPressed,
  });

  final TimeCalendarPalette palette;
  final String label;
  final bool isCurrentDay;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = TimeCalendarGeometry.fromTokens(tokens);
    final baseStyle = tokens.typography.styles.body.bodyMedium.copyWith(
      color: switch ((isSelected, isCurrentDay, palette.mode)) {
        (true, _, _) => palette.onAccent,
        (_, true, _) => palette.accent,
        _ => palette.highEmphasis,
      },
    );

    return SizedBox(
      width: geometry.dayCellWidth,
      height: geometry.dayCellHeight,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(geometry.selectedDayRadius),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: geometry.dayCellWidth,
                minHeight: geometry.dayCellHeight,
              ),
              child: Center(
                child: Container(
                  width: geometry.selectedDayDiameter,
                  height: geometry.selectedDayDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? palette.accent : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(label, style: baseStyle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single month cell in the month-selection grid, accenting its [label]
/// when [selected].
class MonthButton extends StatelessWidget {
  const MonthButton({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final TimeCalendarPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final geometry = TimeCalendarGeometry.fromTokens(tokens);
    return SizedBox(
      width: geometry.monthButtonWidth,
      height: geometry.monthButtonHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(geometry.monthButtonRadius),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: selected ? palette.accent : palette.highEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolved color set for the time calendar in a given
/// [DesignSystemTimeCalendarPickerMode].
///
/// Built via [TimeCalendarPalette.fromMode], it maps the light/dark token sets
/// to the surface fill, blur sigma, shadow, emphasis text colors, and accent
/// used across the card's sub-components.
class TimeCalendarPalette {
  const TimeCalendarPalette({
    required this.mode,
    required this.surfaceBase,
    required this.surfaceBlurSigma,
    required this.shadow,
    required this.highEmphasis,
    required this.lowEmphasis,
    required this.accent,
    required this.onAccent,
  });

  factory TimeCalendarPalette.fromMode(
    DesignSystemTimeCalendarPickerMode mode,
  ) {
    final tokens = switch (mode) {
      DesignSystemTimeCalendarPickerMode.light => dsTokensLight,
      DesignSystemTimeCalendarPickerMode.dark => dsTokensDark,
    };

    return switch (mode) {
      DesignSystemTimeCalendarPickerMode.light => TimeCalendarPalette(
        mode: mode,
        surfaceBase: tokens.colors.background.level01.withValues(alpha: 0.92),
        surfaceBlurSigma: 24,
        shadow: Colors.black.withValues(alpha: 0.10),
        highEmphasis: tokens.colors.text.highEmphasis,
        lowEmphasis: tokens.colors.text.lowEmphasis,
        accent: tokens.colors.interactive.enabled,
        onAccent: tokens.colors.text.onInteractiveAlert,
      ),
      DesignSystemTimeCalendarPickerMode.dark => TimeCalendarPalette(
        mode: mode,
        // The dark sidebar instance in Figma sits on `background.level02`
        // and uses a lifted material treatment, so the card should read
        // slightly brighter than the shell instead of falling back to the
        // raw `background.level01` token.
        surfaceBase: Color.alphaBlend(
          tokens.colors.surface.enabled,
          tokens.colors.background.level02,
        ),
        surfaceBlurSigma: 24,
        shadow: Colors.black.withValues(alpha: 0.10),
        highEmphasis: tokens.colors.text.highEmphasis,
        lowEmphasis: tokens.colors.text.lowEmphasis,
        accent: tokens.colors.interactive.enabled,
        onAccent: tokens.colors.text.onInteractiveAlert,
      ),
    };
  }

  final DesignSystemTimeCalendarPickerMode mode;
  final Color surfaceBase;
  final double surfaceBlurSigma;
  final Color shadow;
  final Color highEmphasis;
  final Color lowEmphasis;
  final Color accent;
  final Color onAccent;
}

List<List<int?>> _buildMonthGrid(DateTime month, int firstDayOfWeekIndex) {
  final firstDay = DateTime(month.year, month.month);
  final daysInMonth = _daysInMonth(month);
  final offset = (firstDay.weekday % 7 - firstDayOfWeekIndex + 7) % 7;
  final cells = <int?>[
    ...List<int?>.filled(offset, null),
    ...List<int?>.generate(daysInMonth, (index) => index + 1),
  ];

  while (cells.length % 7 != 0) {
    cells.add(null);
  }

  return [
    for (var index = 0; index < cells.length; index += 7)
      cells.sublist(index, index + 7),
  ];
}

List<String> _weekdayLabels(String localeTag, int firstDayOfWeekIndex) {
  final sunday = DateTime(2025, 4, 6);

  return List.generate(7, (index) {
    final dayIndex = (firstDayOfWeekIndex + index) % 7;
    final label = DateFormat.E(
      localeTag,
    ).format(sunday.add(Duration(days: dayIndex)));
    return label.substring(0, math.min(3, label.length)).toUpperCase();
  });
}

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
