import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemTimeCalendarPickerMode { light, dark }

enum DesignSystemTimeCalendarPickerPresentation {
  regular,
  compact,
  monthDialog,
}

@immutable
class _TimeCalendarGeometry {
  const _TimeCalendarGeometry({
    required this.dialogInsetPadding,
    required this.compactWidth,
    required this.compactHeight,
    required this.cardWidth,
    required this.cardRadius,
    required this.cardShadowBlur,
    required this.cardShadowOffsetY,
    required this.contentPadding,
    required this.monthDialogPadding,
    required this.headerHeight,
    required this.sectionGap,
    required this.labelDisclosureGap,
    required this.labelTapRadius,
    required this.headerIconClusterWidth,
    required this.headerIconSize,
    required this.headerIconConstraint,
    required this.headerIconSplashRadius,
    required this.weekdayColumnWidth,
    required this.dayCellWidth,
    required this.dayCellHeight,
    required this.selectedDayDiameter,
    required this.selectedDayRadius,
    required this.monthButtonWidth,
    required this.monthButtonHeight,
    required this.monthButtonRadius,
  });

  factory _TimeCalendarGeometry.fromTokens(DsTokens tokens) {
    final cardRadius = tokens.radii.m + (tokens.spacing.step1 / 2);
    final cardWidth =
        (7 * tokens.spacing.step9) +
        (tokens.spacing.step5 * 2) +
        tokens.spacing.step1;

    return _TimeCalendarGeometry(
      dialogInsetPadding: EdgeInsets.all(tokens.spacing.step6),
      compactWidth: 288,
      compactHeight: 256,
      cardWidth: cardWidth,
      cardRadius: cardRadius,
      cardShadowBlur: 60,
      cardShadowOffsetY: 10,
      contentPadding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step4,
      ),
      monthDialogPadding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      headerHeight: tokens.spacing.step9,
      sectionGap: tokens.spacing.step3,
      labelDisclosureGap: tokens.spacing.step2,
      labelTapRadius: tokens.radii.badgesPills,
      headerIconClusterWidth: tokens.spacing.step10 + tokens.spacing.step2,
      headerIconSize: 28,
      headerIconConstraint: tokens.spacing.step9,
      headerIconSplashRadius: tokens.spacing.step6,
      weekdayColumnWidth: tokens.spacing.step9,
      dayCellWidth: tokens.spacing.step9,
      dayCellHeight: tokens.spacing.step9,
      selectedDayDiameter: tokens.spacing.step8,
      selectedDayRadius: tokens.spacing.step6 - tokens.spacing.step1,
      monthButtonWidth: (cardWidth - (tokens.spacing.step5 * 2)) / 4,
      monthButtonHeight: tokens.spacing.step11 - tokens.spacing.step1,
      monthButtonRadius: tokens.radii.l,
    );
  }

  final EdgeInsets dialogInsetPadding;
  final double compactWidth;
  final double compactHeight;
  final double cardWidth;
  final double cardRadius;
  final double cardShadowBlur;
  final double cardShadowOffsetY;
  final EdgeInsets contentPadding;
  final EdgeInsets monthDialogPadding;
  final double headerHeight;
  final double sectionGap;
  final double labelDisclosureGap;
  final double labelTapRadius;
  final double headerIconClusterWidth;
  final double headerIconSize;
  final double headerIconConstraint;
  final double headerIconSplashRadius;
  final double weekdayColumnWidth;
  final double dayCellWidth;
  final double dayCellHeight;
  final double selectedDayDiameter;
  final double selectedDayRadius;
  final double monthButtonWidth;
  final double monthButtonHeight;
  final double monthButtonRadius;
}

class DesignSystemInteractiveTimeCalendarPicker extends StatefulWidget {
  const DesignSystemInteractiveTimeCalendarPicker({
    required this.mode,
    required this.presentation,
    required this.initialSelectedDate,
    required this.currentDate,
    super.key,
  }) : assert(
         presentation != DesignSystemTimeCalendarPickerPresentation.monthDialog,
         'Use DesignSystemTimeCalendarPicker for standalone month dialogs.',
       );

  final DesignSystemTimeCalendarPickerMode mode;
  final DesignSystemTimeCalendarPickerPresentation presentation;
  final DateTime initialSelectedDate;
  final DateTime currentDate;

  @override
  State<DesignSystemInteractiveTimeCalendarPicker> createState() =>
      _DesignSystemInteractiveTimeCalendarPickerState();
}

class _DesignSystemInteractiveTimeCalendarPickerState
    extends State<DesignSystemInteractiveTimeCalendarPicker> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialSelectedDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  Future<void> _showMonthDialog() async {
    final nextMonth = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(
        alpha: widget.mode == DesignSystemTimeCalendarPickerMode.dark
            ? 0.24
            : 0.16,
      ),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: _TimeCalendarGeometry.fromTokens(
          context.designTokens,
        ).dialogInsetPadding,
        child: Center(
          child: DesignSystemTimeCalendarPicker(
            mode: widget.mode,
            presentation:
                DesignSystemTimeCalendarPickerPresentation.monthDialog,
            visibleMonth: _visibleMonth,
            selectedDate: _selectedDate,
            currentDate: _dateOnly(widget.currentDate),
            onMonthPressed: Navigator.of(context).pop,
          ),
        ),
      ),
    );

    if (nextMonth == null || !mounted) {
      return;
    }

    _updateVisibleMonth(nextMonth);
  }

  void _updateVisibleMonth(DateTime nextMonth) {
    setState(() {
      _visibleMonth = DateTime(nextMonth.year, nextMonth.month);
      final clampedDay = math.min(
        _selectedDate.day,
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day,
      );
      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        clampedDay,
      );
    });
  }

  void _changeMonth(int delta) {
    _updateVisibleMonth(
      DateTime(_visibleMonth.year, _visibleMonth.month + delta),
    );
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      _visibleMonth = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesignSystemTimeCalendarPicker(
      mode: widget.mode,
      presentation: widget.presentation,
      visibleMonth: _visibleMonth,
      selectedDate: _selectedDate,
      currentDate: _dateOnly(widget.currentDate),
      onMonthYearPressed: _showMonthDialog,
      onPreviousPressed: () => _changeMonth(-1),
      onNextPressed: () => _changeMonth(1),
      onDayPressed: _selectDay,
    );
  }
}

class DesignSystemTimeCalendarPicker extends StatelessWidget {
  const DesignSystemTimeCalendarPicker({
    required this.mode,
    required this.presentation,
    required this.visibleMonth,
    required this.selectedDate,
    required this.currentDate,
    this.onMonthYearPressed,
    this.onPreviousPressed,
    this.onNextPressed,
    this.onDayPressed,
    this.onMonthPressed,
    super.key,
  });

  final DesignSystemTimeCalendarPickerMode mode;
  final DesignSystemTimeCalendarPickerPresentation presentation;
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime currentDate;
  final VoidCallback? onMonthYearPressed;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;
  final ValueChanged<DateTime>? onDayPressed;
  final ValueChanged<DateTime>? onMonthPressed;

  @override
  Widget build(BuildContext context) {
    final geometry = _TimeCalendarGeometry.fromTokens(context.designTokens);

    switch (presentation) {
      case DesignSystemTimeCalendarPickerPresentation.regular:
        return _MonthCalendarCard(
          mode: mode,
          visibleMonth: visibleMonth,
          selectedDate: selectedDate,
          currentDate: currentDate,
          onMonthYearPressed: onMonthYearPressed,
          onPreviousPressed: onPreviousPressed,
          onNextPressed: onNextPressed,
          onDayPressed: onDayPressed,
        );
      case DesignSystemTimeCalendarPickerPresentation.compact:
        return SizedBox(
          width: geometry.compactWidth,
          height: geometry.compactHeight,
          child: FittedBox(
            alignment: Alignment.topLeft,
            fit: BoxFit.scaleDown,
            child: _MonthCalendarCard(
              mode: mode,
              visibleMonth: visibleMonth,
              selectedDate: selectedDate,
              currentDate: currentDate,
              onMonthYearPressed: onMonthYearPressed,
              onPreviousPressed: onPreviousPressed,
              onNextPressed: onNextPressed,
              onDayPressed: onDayPressed,
            ),
          ),
        );
      case DesignSystemTimeCalendarPickerPresentation.monthDialog:
        return _MonthSelectionDialogCard(
          mode: mode,
          visibleMonth: visibleMonth,
          selectedMonth: selectedDate.month,
          onMonthPressed: onMonthPressed,
        );
    }
  }
}

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
    final palette = _TimeCalendarPalette.fromMode(mode);
    final geometry = _TimeCalendarGeometry.fromTokens(context.designTokens);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final firstDayOfWeek = MaterialLocalizations.of(
      context,
    ).firstDayOfWeekIndex;
    final visibleLabel = DateFormat.yMMMM(localeTag).format(visibleMonth);
    final weeks = _buildMonthGrid(visibleMonth, firstDayOfWeek);

    return _CalendarMaterialCard(
      palette: palette,
      geometry: geometry,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthHeader(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
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

class _MonthSelectionDialogCard extends StatefulWidget {
  const _MonthSelectionDialogCard({
    required this.mode,
    required this.visibleMonth,
    required this.selectedMonth,
    this.onMonthPressed,
  });

  final DesignSystemTimeCalendarPickerMode mode;
  final DateTime visibleMonth;
  final int selectedMonth;
  final ValueChanged<DateTime>? onMonthPressed;

  @override
  State<_MonthSelectionDialogCard> createState() =>
      _MonthSelectionDialogCardState();
}

class _MonthSelectionDialogCardState extends State<_MonthSelectionDialogCard> {
  late int _visibleYear;

  @override
  void initState() {
    super.initState();
    _visibleYear = widget.visibleMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _TimeCalendarPalette.fromMode(widget.mode);
    final geometry = _TimeCalendarGeometry.fromTokens(context.designTokens);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final months = List.generate(
      12,
      (index) =>
          DateFormat.MMM(localeTag).format(DateTime(_visibleYear, index + 1)),
    );

    return _CalendarMaterialCard(
      palette: palette,
      geometry: geometry,
      padding: geometry.monthDialogPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthHeader(
            palette: palette,
            geometry: geometry,
            label: '$_visibleYear',
            showDisclosure: false,
            onPreviousPressed: () => setState(() => _visibleYear -= 1),
            onNextPressed: () => setState(() => _visibleYear += 1),
          ),
          SizedBox(height: context.designTokens.spacing.step4),
          for (var row = 0; row < 3; row++)
            Row(
              children: [
                for (var column = 0; column < 4; column++)
                  _MonthButton(
                    palette: palette,
                    label: months[row * 4 + column],
                    selected:
                        _visibleYear == widget.visibleMonth.year &&
                        row * 4 + column + 1 == widget.selectedMonth,
                    onPressed: () {
                      final nextMonth = DateTime(
                        _visibleYear,
                        row * 4 + column + 1,
                      );
                      widget.onMonthPressed?.call(nextMonth);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CalendarMaterialCard extends StatelessWidget {
  const _CalendarMaterialCard({
    required this.palette,
    required this.geometry,
    required this.child,
    this.padding,
  });

  final _TimeCalendarPalette palette;
  final _TimeCalendarGeometry geometry;
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
            if (palette.surfaceOverlay != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: palette.surfaceOverlay),
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.palette,
    required this.geometry,
    required this.label,
    required this.showDisclosure,
    this.onLabelPressed,
    this.onPreviousPressed,
    this.onNextPressed,
  });

  final _TimeCalendarPalette palette;
  final _TimeCalendarGeometry geometry;
  final String label;
  final bool showDisclosure;
  final VoidCallback? onLabelPressed;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
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
                onPressed: onPreviousPressed,
              ),
              SizedBox(width: context.designTokens.spacing.step1),
              _HeaderIconButton(
                geometry: geometry,
                icon: Icons.chevron_right_rounded,
                color: palette.accent,
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
    this.onPressed,
  });

  final _TimeCalendarGeometry geometry;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
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

  final _TimeCalendarPalette palette;
  final String label;
  final bool isCurrentDay;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final geometry = _TimeCalendarGeometry.fromTokens(context.designTokens);
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
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

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final _TimeCalendarPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final geometry = _TimeCalendarGeometry.fromTokens(context.designTokens);
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: selected ? palette.accent : palette.highEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeCalendarPalette {
  const _TimeCalendarPalette({
    required this.mode,
    required this.surfaceBase,
    required this.surfaceBlurSigma,
    required this.shadow,
    required this.highEmphasis,
    required this.lowEmphasis,
    required this.accent,
    required this.onAccent,
    this.surfaceOverlay,
  });

  factory _TimeCalendarPalette.fromMode(
    DesignSystemTimeCalendarPickerMode mode,
  ) {
    final tokens = switch (mode) {
      DesignSystemTimeCalendarPickerMode.light => dsTokensLight,
      DesignSystemTimeCalendarPickerMode.dark => dsTokensDark,
    };

    return switch (mode) {
      DesignSystemTimeCalendarPickerMode.light => _TimeCalendarPalette(
        mode: mode,
        surfaceBase: tokens.colors.background.level01.withValues(alpha: 0.92),
        surfaceBlurSigma: 24,
        shadow: Colors.black.withValues(alpha: 0.10),
        highEmphasis: tokens.colors.text.highEmphasis,
        lowEmphasis: tokens.colors.text.lowEmphasis,
        accent: tokens.colors.interactive.enabled,
        onAccent: tokens.colors.text.onInteractiveAlert,
      ),
      DesignSystemTimeCalendarPickerMode.dark => _TimeCalendarPalette(
        mode: mode,
        surfaceBase: tokens.colors.background.level01.withValues(alpha: 0.94),
        // The MCP component uses a color-dodge material layer over the dark
        // sidebar. Using the tokenized dark surface highlight keeps the card
        // slightly lighter than the surrounding `background.level02`.
        surfaceOverlay: tokens.colors.surface.enabled,
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
  final Color? surfaceOverlay;
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

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
