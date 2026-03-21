import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemCalendarPickerWidgetbookComponent({
  @visibleForTesting DateTime? initialDate,
}) {
  return WidgetbookComponent(
    name: 'Calendar picker',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) =>
            _CalendarPickerOverviewPage(initialDate: initialDate),
      ),
    ],
  );
}

class _CalendarPickerOverviewPage extends StatelessWidget {
  const _CalendarPickerOverviewPage({this.initialDate});

  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _CalendarSection(
            title: context.messages.designSystemDateCardsTitle,
            child: const _DateCardStates(),
          ),
          const SizedBox(height: 32),
          _CalendarSection(
            title: context.messages.designSystemCalendarViewsTitle,
            child: _InteractiveCalendarViews(initialDate: initialDate),
          ),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _DateCardStates extends StatelessWidget {
  const _DateCardStates();

  @override
  Widget build(BuildContext context) {
    final labels = _weeklyLabels(context);

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _DateCardStateColumn(
          label: context.messages.designSystemDefaultLabel,
          child: DesignSystemCalendarDateCard(
            weekdayLabel: labels[0],
            dayLabel: '15',
            selected: false,
            onPressed: _noop,
          ),
        ),
        _DateCardStateColumn(
          label: context.messages.designSystemHoverLabel,
          child: DesignSystemCalendarDateCard(
            weekdayLabel: labels[0],
            dayLabel: '15',
            selected: false,
            forcedState: DesignSystemCalendarDateCardVisualState.hover,
            onPressed: _noop,
          ),
        ),
        _DateCardStateColumn(
          label: context.messages.designSystemSelectedLabel,
          child: DesignSystemCalendarDateCard(
            weekdayLabel: labels[0],
            dayLabel: '15',
            selected: true,
            onPressed: _noop,
          ),
        ),
      ],
    );
  }
}

class _DateCardStateColumn extends StatelessWidget {
  const _DateCardStateColumn({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _InteractiveCalendarViews extends StatefulWidget {
  const _InteractiveCalendarViews({this.initialDate});

  final DateTime? initialDate;

  @override
  State<_InteractiveCalendarViews> createState() =>
      _InteractiveCalendarViewsState();
}

class _InteractiveCalendarViewsState extends State<_InteractiveCalendarViews> {
  late final DateTime _today;
  late DateTime _visibleMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _today = widget.initialDate ?? DateTime.now();
    _visibleMonth = DateTime(_today.year, _today.month);
  }

  void _onDayPressed(DateTime date) {
    setState(() {
      if (_rangeStart == null) {
        _rangeStart = date;
        _rangeEnd = null;
      } else if (_rangeEnd == null) {
        if (_isSameDay(date, _rangeStart!)) {
          _rangeStart = null;
        } else if (date.isBefore(_rangeStart!)) {
          _rangeEnd = _rangeStart;
          _rangeStart = date;
        } else {
          _rangeEnd = date;
        }
      } else {
        _rangeStart = date;
        _rangeEnd = null;
      }
    });
  }

  void _onMonthPressed(int year, int month) {
    setState(() {
      _visibleMonth = DateTime(year, month);
    });
  }

  void _onTodayPressed() {
    setState(() {
      _visibleMonth = DateTime(_today.year, _today.month);
      _rangeStart = DateTime(_today.year, _today.month, _today.day);
      _rangeEnd = null;
    });
  }

  bool _isDateSelected(DateTime date) {
    if (_rangeStart == null) return false;
    if (_rangeEnd == null) return _isSameDay(date, _rangeStart!);

    final start = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
    final end = _rangeStart!.isBefore(_rangeEnd!) ? _rangeEnd! : _rangeStart!;

    return !date.isBefore(start) && !date.isAfter(end);
  }

  DesignSystemCalendarDayCellSelectionPosition _selectionPosition(
    DateTime date,
  ) {
    if (_rangeEnd == null) {
      return DesignSystemCalendarDayCellSelectionPosition.standalone;
    }

    final start = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
    final end = _rangeStart!.isBefore(_rangeEnd!) ? _rangeEnd! : _rangeStart!;

    if (_isSameDay(date, start)) {
      return DesignSystemCalendarDayCellSelectionPosition.start;
    }
    if (_isSameDay(date, end)) {
      return DesignSystemCalendarDayCellSelectionPosition.end;
    }
    return DesignSystemCalendarDayCellSelectionPosition.middle;
  }

  List<List<DesignSystemCalendarDayCellData?>> _buildWeeks() {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = (DateTime(year, month).weekday - 1) % 7;

    final cells = <DesignSystemCalendarDayCellData?>[];

    for (var i = 0; i < firstWeekday; i++) {
      cells.add(null);
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final isToday = _isSameDay(date, _today);
      final isSelected = _isDateSelected(date);

      final DesignSystemCalendarDayCellType type;
      var position = DesignSystemCalendarDayCellSelectionPosition.start;

      if (isSelected) {
        type = DesignSystemCalendarDayCellType.selected;
        position = _selectionPosition(date);
      } else if (isToday) {
        type = DesignSystemCalendarDayCellType.today;
      } else {
        type = DesignSystemCalendarDayCellType.activeMonth;
      }

      cells.add(
        DesignSystemCalendarDayCellData(
          label: '$day',
          type: type,
          selectionPosition: position,
          onPressed: () => _onDayPressed(date),
        ),
      );
    }

    final weeks = <List<DesignSystemCalendarDayCellData?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = (i + 7 > cells.length) ? cells.length : i + 7;
      final week = List<DesignSystemCalendarDayCellData?>.from(
        cells.sublist(i, end),
      );
      while (week.length < 7) {
        week.add(null);
      }
      weeks.add(week);
    }

    return weeks;
  }

  List<DesignSystemCalendarMonthRailSection> _buildMonthSections(
    BuildContext context,
  ) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final months = <DateTime>[];

    for (var i = -6; i <= 6; i++) {
      months.add(DateTime(_today.year, _today.month + i));
    }

    final grouped = <int, List<DateTime>>{};
    for (final m in months) {
      grouped.putIfAbsent(m.year, () => []).add(m);
    }

    return grouped.entries.map((entry) {
      return DesignSystemCalendarMonthRailSection(
        yearLabel: '${entry.key}',
        items: entry.value.map((m) {
          return DesignSystemCalendarMonthRailItem(
            label: DateFormat.MMM(localeTag).format(m),
            selected:
                m.year == _visibleMonth.year && m.month == _visibleMonth.month,
            onPressed: () => _onMonthPressed(m.year, m.month),
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat.yMMMM(localeTag).format(_visibleMonth);

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _CalendarPreviewColumn(
          title: context.messages.designSystemCalendarPickerLabel,
          child: DesignSystemCalendarPicker(
            monthSections: _buildMonthSections(context),
            visibleMonthLabel: monthLabel,
            weekdayLabels: _pickerWeekdayLabels(context),
            weeks: _buildWeeks(),
            todayLabel: context.messages.dailyOsTodayButton,
            onTodayPressed: _onTodayPressed,
          ),
        ),
        _CalendarPreviewColumn(
          title: context.messages.designSystemWeeklyCalendarLabel,
          child: _WeeklyCalendarPreview(
            referenceDate: _rangeStart ?? _today,
            selectedDate: _rangeStart,
            onDayPressed: _onDayPressed,
          ),
        ),
      ],
    );
  }
}

class _CalendarPreviewColumn extends StatelessWidget {
  const _CalendarPreviewColumn({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeeklyCalendarPreview extends StatelessWidget {
  const _WeeklyCalendarPreview({
    required this.referenceDate,
    required this.selectedDate,
    required this.onDayPressed,
  });

  final DateTime referenceDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayPressed;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final monday = referenceDate.subtract(
      Duration(days: referenceDate.weekday - 1),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final date = monday.add(Duration(days: i));
              final label = DateFormat.E(localeTag).format(date);
              final isSelected =
                  selectedDate != null && _isSameDay(date, selectedDate!);

              return DesignSystemCalendarDateCard(
                weekdayLabel: label,
                dayLabel: '${date.day}',
                selected: isSelected,
                onPressed: () => onDayPressed(date),
              );
            },
          ),
      ],
    );
  }
}

List<String> _pickerWeekdayLabels(BuildContext context) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  final monday = DateTime(2026, 1, 5);

  return List.generate(7, (index) {
    final label = DateFormat.E(localeTag).format(
      monday.add(Duration(days: index)),
    );
    return _compactWeekdayLabel(label);
  });
}

List<String> _weeklyLabels(BuildContext context) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  final sunday = DateTime(2026, 2, 15);

  return List.generate(
    7,
    (index) => DateFormat.E(localeTag).format(
      sunday.add(Duration(days: index)),
    ),
  );
}

String _compactWeekdayLabel(String label) {
  final compactLabel = label.replaceAll('.', '').trim();
  if (compactLabel.length <= 2) {
    return compactLabel;
  }
  return compactLabel.substring(0, 2);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

void _noop() {}
