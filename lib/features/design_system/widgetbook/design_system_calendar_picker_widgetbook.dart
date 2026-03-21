import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemCalendarPickerWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Calendar picker',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _CalendarPickerOverviewPage(),
      ),
    ],
  );
}

class _CalendarPickerOverviewPage extends StatelessWidget {
  const _CalendarPickerOverviewPage();

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
            child: const _CalendarViews(),
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

class _CalendarViews extends StatelessWidget {
  const _CalendarViews();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _CalendarPreviewColumn(
          title: context.messages.designSystemCalendarPickerLabel,
          child: DesignSystemCalendarPicker(
            monthSections: _monthSections(context),
            visibleMonthLabel: _pickerMonthLabel(context),
            weekdayLabels: _pickerWeekdayLabels(context),
            weeks: _pickerWeeks(),
            todayLabel: context.messages.dailyOsTodayButton,
            onTodayPressed: _noop,
          ),
        ),
        _CalendarPreviewColumn(
          title: context.messages.designSystemWeeklyCalendarLabel,
          child: _WeeklyCalendarPreview(labels: _weeklyLabels(context)),
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
    required this.labels,
  });

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          DesignSystemCalendarDateCard(
            weekdayLabel: labels[index],
            dayLabel: '${15 + index}',
            selected: index == 2,
            onPressed: _noop,
          ),
      ],
    );
  }
}

List<DesignSystemCalendarMonthRailSection> _monthSections(
  BuildContext context,
) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();

  DesignSystemCalendarMonthRailItem item(
    int year,
    int month, {
    bool selected = false,
  }) {
    return DesignSystemCalendarMonthRailItem(
      label: DateFormat.MMM(localeTag).format(DateTime(year, month)),
      selected: selected,
      onPressed: _noop,
    );
  }

  return [
    DesignSystemCalendarMonthRailSection(
      yearLabel: '2025',
      items: [
        item(2025, 8),
        item(2025, 9),
        item(2025, 10),
        item(2025, 11),
        item(2025, 12),
      ],
    ),
    DesignSystemCalendarMonthRailSection(
      yearLabel: '2026',
      items: [
        item(2026, 1, selected: true),
        item(2026, 2),
      ],
    ),
  ];
}

String _pickerMonthLabel(BuildContext context) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMM(localeTag).format(DateTime(2026));
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

List<List<DesignSystemCalendarDayCellData?>> _pickerWeeks() {
  DesignSystemCalendarDayCellData active(String label) {
    return DesignSystemCalendarDayCellData(
      label: label,
      type: DesignSystemCalendarDayCellType.activeMonth,
      onPressed: _noop,
    );
  }

  DesignSystemCalendarDayCellData selected(
    String label,
    DesignSystemCalendarDayCellSelectionPosition position,
  ) {
    return DesignSystemCalendarDayCellData(
      label: label,
      type: DesignSystemCalendarDayCellType.selected,
      selectionPosition: position,
      onPressed: _noop,
    );
  }

  return [
    [
      null,
      null,
      null,
      selected('1', DesignSystemCalendarDayCellSelectionPosition.start),
      selected('2', DesignSystemCalendarDayCellSelectionPosition.middle),
      selected('3', DesignSystemCalendarDayCellSelectionPosition.middle),
      selected('4', DesignSystemCalendarDayCellSelectionPosition.end),
    ],
    [
      active('5'),
      active('6'),
      active('7'),
      active('8'),
      active('9'),
      active('10'),
      active('11'),
    ],
    [
      active('12'),
      active('13'),
      active('14'),
      active('15'),
      active('16'),
      active('17'),
      active('18'),
    ],
    [
      active('19'),
      active('20'),
      active('21'),
      active('22'),
      active('23'),
      active('24'),
      active('25'),
    ],
    [
      active('26'),
      active('27'),
      active('28'),
      active('29'),
      active('30'),
      active('31'),
      null,
    ],
  ];
}

void _noop() {}
