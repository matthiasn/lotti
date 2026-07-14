import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';

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
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onPressed,
}) async {
  await tester.pumpWidget(
    WidgetTestBench(
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
