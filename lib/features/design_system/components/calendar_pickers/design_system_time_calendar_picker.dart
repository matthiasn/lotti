import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DesignSystemTimeCalendarPickerMode { light, dark }

enum DesignSystemTimeCalendarPickerPresentation {
  regular,
  compact,
  monthDialog,
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
        insetPadding: const EdgeInsets.all(24),
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
          width: 288,
          height: 256,
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
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final visibleLabel = DateFormat.yMMMM(localeTag).format(visibleMonth);
    final weeks = _buildMonthGrid(visibleMonth);

    return _CalendarMaterialCard(
      palette: palette,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthHeader(
            palette: palette,
            label: visibleLabel,
            showDisclosure: true,
            onLabelPressed: onMonthYearPressed,
            onPreviousPressed: onPreviousPressed,
            onNextPressed: onNextPressed,
          ),
          const SizedBox(height: 8),
          Row(
            children: _weekdayLabels(localeTag).map((label) {
              return SizedBox(
                width: 48,
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
          const SizedBox(height: 8),
          for (final week in weeks)
            Row(
              children: [
                for (final day in week)
                  if (day == null)
                    const SizedBox(width: 48, height: 44)
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
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final months = List.generate(
      12,
      (index) =>
          DateFormat.MMM(localeTag).format(DateTime(_visibleYear, index + 1)),
    );

    return _CalendarMaterialCard(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthHeader(
            palette: palette,
            label: '$_visibleYear',
            showDisclosure: false,
            onPreviousPressed: () => setState(() => _visibleYear -= 1),
            onNextPressed: () => setState(() => _visibleYear += 1),
          ),
          const SizedBox(height: 12),
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
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final _TimeCalendarPalette palette;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 370,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 60,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
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
              padding: padding,
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
    required this.label,
    required this.showDisclosure,
    this.onLabelPressed,
    this.onPreviousPressed,
    this.onNextPressed,
  });

  final _TimeCalendarPalette palette;
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
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: palette.accent,
          ),
        ],
      ],
    );

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: onLabelPressed == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: labelWidget,
                    )
                  : InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onLabelPressed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: labelWidget,
                      ),
                    ),
            ),
          ),
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                color: palette.accent,
                onPressed: onPreviousPressed,
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
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
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      splashRadius: 16,
      onPressed: onPressed,
      icon: Icon(icon, size: 28, color: color),
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
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: switch ((isSelected, isCurrentDay, palette.mode)) {
        (true, _, DesignSystemTimeCalendarPickerMode.light) => Colors.white,
        (true, _, DesignSystemTimeCalendarPickerMode.dark) => const Color(
          0xFF0E0E0E,
        ),
        (_, true, _) => palette.accent,
        _ => palette.highEmphasis,
      },
    );

    return SizedBox(
      width: 48,
      height: 44,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPressed,
            child: Container(
              width: 40,
              height: 40,
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
    return SizedBox(
      width: 84.5,
      height: 78,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
    this.surfaceOverlay,
  });

  factory _TimeCalendarPalette.fromMode(
    DesignSystemTimeCalendarPickerMode mode,
  ) {
    return switch (mode) {
      DesignSystemTimeCalendarPickerMode.light => _TimeCalendarPalette(
        mode: mode,
        surfaceBase: Colors.white.withValues(alpha: 0.92),
        surfaceOverlay: Colors.white.withValues(alpha: 0.08),
        surfaceBlurSigma: 24,
        shadow: Colors.black.withValues(alpha: 0.10),
        highEmphasis: Colors.black.withValues(alpha: 0.88),
        lowEmphasis: Colors.black.withValues(alpha: 0.32),
        accent: const Color(0xFF2BA184),
      ),
      DesignSystemTimeCalendarPickerMode.dark => _TimeCalendarPalette(
        mode: mode,
        surfaceBase: const Color(0xFF202020).withValues(alpha: 0.92),
        surfaceOverlay: Colors.white.withValues(alpha: 0.02),
        surfaceBlurSigma: 24,
        shadow: Colors.black.withValues(alpha: 0.10),
        highEmphasis: Colors.white.withValues(alpha: 0.88),
        lowEmphasis: Colors.white.withValues(alpha: 0.32),
        accent: const Color(0xFF5ED4B7),
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
}

List<List<int?>> _buildMonthGrid(DateTime month) {
  final firstDay = DateTime(month.year, month.month);
  final daysInMonth = _daysInMonth(month);
  final offset = firstDay.weekday % 7;
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

List<String> _weekdayLabels(String localeTag) {
  final sunday = DateTime(2025, 4, 6);

  return List.generate(7, (index) {
    final label = DateFormat.E(
      localeTag,
    ).format(sunday.add(Duration(days: index)));
    return label.substring(0, math.min(3, label.length)).toUpperCase();
  });
}

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
