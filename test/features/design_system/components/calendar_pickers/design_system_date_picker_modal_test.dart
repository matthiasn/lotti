import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/utils/device_region.dart';

import '../../../../test_helper.dart';

void main() {
  testWidgets('calendar confirms a weekday-visible selected date', (
    tester,
  ) async {
    DesignSystemDatePickerResult? result;
    await _pumpLauncher(
      tester,
      onPressed: (context) async {
        result = await showDesignSystemDatePicker(
          context: context,
          title: 'Target date',
          initialDate: DateTime(2025, 6, 15),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
      },
    );

    expect(find.text('Target date'), findsOneWidget);
    expect(find.text('Sunday, June 15, 2025'), findsOneWidget);
    expect(find.text('June 2025'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DesignSystemPickerSection), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);

    await tester.tap(find.text('16'));
    await tester.pump();
    expect(find.text('Monday, June 16, 2025'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(result?.date, DateTime(2025, 6, 16));
    expect(result?.cleared, isFalse);
  });

  for (final scenario in [
    (
      name: 'German locale',
      locale: const Locale('de', 'DE'),
      firstDayOfWeekIndex: DateTime.monday % 7,
      weekdayLabels: const ['M', 'D', 'M', 'D', 'F', 'S', 'S'],
      dayOneColumn: 6,
    ),
    (
      name: 'US locale',
      locale: const Locale('en', 'US'),
      firstDayOfWeekIndex: DateTime.sunday % 7,
      weekdayLabels: const ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
      dayOneColumn: 0,
    ),
    (
      name: 'English UI with a German region',
      locale: const Locale('en', 'US'),
      firstDayOfWeekIndex: DateTime.monday % 7,
      weekdayLabels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      dayOneColumn: 6,
    ),
  ]) {
    testWidgets(
      '${scenario.name} orders the weekday header and month grid regionally',
      (tester) async {
        await _pumpLauncher(
          tester,
          locale: scenario.locale,
          firstDayOfWeekIndex: scenario.firstDayOfWeekIndex,
          onPressed: (context) => showDesignSystemDatePicker(
            context: context,
            title: 'Target date',
            initialDate: DateTime(2025, 6, 15),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
        );
        await tester.pump();

        final headerCells = _weekdayHeaderCells(tester);
        expect(
          headerCells.map((cell) => cell.label),
          scenario.weekdayLabels,
        );

        final dayOne = find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('1'),
        );
        expect(dayOne, findsOneWidget);
        expect(
          tester.getCenter(dayOne).dx,
          closeTo(headerCells[scenario.dayOneColumn].dx, 0.1),
        );
      },
    );
  }

  testWidgets('optional Clear is distinct from dismissing the modal', (
    tester,
  ) async {
    DesignSystemDatePickerResult? result;
    await _pumpLauncher(
      tester,
      onPressed: (context) async {
        result = await showDesignSystemDatePicker(
          context: context,
          title: 'Due date',
          initialDate: DateTime(2025, 6, 15),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          allowClear: true,
        );
      },
    );

    await tester.tap(find.text('Clear'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result?.cleared, isTrue);
    expect(result?.date, isNull);
  });

  testWidgets('Today is disabled when it is already selected', (tester) async {
    final today = DateTime(2026, 7, 14);
    await withClock(Clock.fixed(today), () async {
      await _pumpLauncher(
        tester,
        onPressed: (context) => showDesignSystemDatePicker(
          context: context,
          title: 'Due date',
          initialDate: today,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        ),
      );
    });

    final todayButton = tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, 'Today'),
    );
    expect(todayButton.onPressed, isNull);
  });

  for (final scenario in [
    (
      name: 'before first date',
      initial: DateTime(2010, 6, 15),
      expected: DateTime(2020),
      label: 'Wednesday, January 1, 2020',
    ),
    (
      name: 'after last date in UTC',
      initial: DateTime.utc(2040, 6, 15),
      expected: DateTime.utc(2030),
      label: 'Tuesday, January 1, 2030',
    ),
  ]) {
    testWidgets('clamps an initial date ${scenario.name}', (tester) async {
      DesignSystemDatePickerResult? result;
      await _pumpLauncher(
        tester,
        onPressed: (context) async {
          result = await showDesignSystemDatePicker(
            context: context,
            title: 'Due date',
            initialDate: scenario.initial,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
        },
      );

      expect(find.text(scenario.label), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(result?.date, scenario.expected);
      expect(result?.date?.isUtc, scenario.expected.isUtc);
    });
  }

  testWidgets('calendar selection preserves a UTC initial value', (
    tester,
  ) async {
    DesignSystemDatePickerResult? result;
    await _pumpLauncher(
      tester,
      onPressed: (context) async {
        result = await showDesignSystemDatePicker(
          context: context,
          title: 'Due date',
          initialDate: DateTime.utc(2025, 6, 15),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
      },
    );

    await tester.tap(find.text('16'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(result?.date, DateTime.utc(2025, 6, 16));
    expect(result?.date?.isUtc, isTrue);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onPressed,
  Locale? locale,
  int? firstDayOfWeekIndex,
}) async {
  await tester.pumpWidget(
    WidgetTestBench(
      locale: locale,
      overrides: [
        if (firstDayOfWeekIndex != null)
          firstDayOfWeekIndexProvider.overrideWith(
            (ref) => firstDayOfWeekIndex,
          ),
      ],
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => onPressed(context),
          child: const Text('Open picker'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

List<({String label, double dx})> _weekdayHeaderCells(WidgetTester tester) {
  final textElements = find
      .descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.byType(Text),
      )
      .evaluate();
  final singleCharacterCells = <({String label, Offset center})>[];

  for (final element in textElements) {
    final text = element.widget as Text;
    final label = text.data;
    if (label == null || label.runes.length != 1) continue;
    final renderBox = element.renderObject! as RenderBox;
    singleCharacterCells.add((
      label: label,
      center: renderBox.localToGlobal(renderBox.size.center(Offset.zero)),
    ));
  }

  final headerY = singleCharacterCells
      .map((cell) => cell.center.dy)
      .reduce((a, b) => a < b ? a : b);
  final headerCells =
      singleCharacterCells
          .where((cell) => (cell.center.dy - headerY).abs() < 0.1)
          .map((cell) => (label: cell.label, dx: cell.center.dx))
          .toList()
        ..sort((a, b) => a.dx.compareTo(b.dx));

  expect(headerCells, hasLength(7));
  return headerCells;
}
