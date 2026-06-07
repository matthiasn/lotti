import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';

import '../../widget_test_utils.dart';

// Plain closures (counters / captured-value lists) replace the former
// one-off Mock classes — callback assertions don't need mocktail here.

/// Pumps a [DateTimeField] inside the standard testable scaffold. Only the
/// parts that vary between tests are parameterised; the boilerplate is fixed.
Future<void> _pumpField(
  WidgetTester tester, {
  required DateTime? dateTime,
  String labelText = 'Select Date',
  void Function(DateTime)? setDateTime,
  void Function()? clear,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.dateAndTime,
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      DateTimeField(
        dateTime: dateTime,
        labelText: labelText,
        setDateTime: setDateTime ?? (_) {},
        clear: clear,
        mode: mode,
      ),
    ),
  );
}

void main() {
  group('DateTimeField Widget Tests', () {
    testWidgets('displays formatted date when dateTime is provided', (
      WidgetTester tester,
    ) async {
      await _pumpField(tester, dateTime: DateTime(2024, 1, 15, 14, 30));

      // Verify the date is displayed in the text field
      expect(find.text('2024-01-15 14:30'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
    });

    testWidgets('displays empty field when dateTime is null', (
      WidgetTester tester,
    ) async {
      await _pumpField(tester, dateTime: null);

      // Verify the field is empty
      expect(find.text(''), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
    });

    testWidgets('shows clear button when clear callback is provided', (
      WidgetTester tester,
    ) async {
      var clearCount = 0;
      await _pumpField(
        tester,
        dateTime: DateTime(2024, 3, 15, 10, 30),
        clear: () => clearCount++,
      );

      // Verify clear button is visible
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(clearCount, 1);
    });

    testWidgets('opens modal when field is tapped', (
      WidgetTester tester,
    ) async {
      await _pumpField(tester, dateTime: null);

      // Tap the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Verify modal is opened with date picker
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(DateTimeStickyActionBar), findsOneWidget);
    });

    testWidgets('displays date only format for date mode', (
      WidgetTester tester,
    ) async {
      await _pumpField(
        tester,
        dateTime: DateTime(2024, 1, 15, 14, 30),
        mode: CupertinoDatePickerMode.date,
      );

      // Verify date-only format
      expect(find.text('2024-01-15'), findsOneWidget);
    });

    testWidgets('displays time only format for time mode', (
      WidgetTester tester,
    ) async {
      await _pumpField(
        tester,
        dateTime: DateTime(2024, 1, 15, 14, 30),
        labelText: 'Select Time',
        mode: CupertinoDatePickerMode.time,
      );

      // Verify time-only format
      expect(find.text('14:30'), findsOneWidget);
    });
  });

  group('DateTimeStickyActionBar Widget Tests', () {
    testWidgets('displays all three buttons with correct labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeStickyActionBar(
            onCancel: () {},
            onNow: () {},
            onDone: () {},
          ),
        ),
      );

      // Verify all buttons are present
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Verify button types
      expect(find.byType(LottiSecondaryButton), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Now'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('calls correct callbacks when buttons are tapped', (
      WidgetTester tester,
    ) async {
      var cancelCount = 0;
      var nowCount = 0;
      var doneCount = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeStickyActionBar(
            onCancel: () => cancelCount++,
            onNow: () => nowCount++,
            onDone: () => doneCount++,
          ),
        ),
      );

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelCount, 1);

      // Tap Now button
      await tester.tap(find.text('Now'));
      await tester.pump();
      expect(nowCount, 1);

      // Tap Done button
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(doneCount, 1);
    });
  });

  group('DateTimeBottomSheet Widget Tests', () {
    testWidgets('displays CupertinoDatePicker with initial date', (
      WidgetTester tester,
    ) async {
      final initialDate = DateTime(2024, 1, 15, 14, 30);
      DateTime? selectedDate;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeBottomSheet(
            initialDate,
            mode: CupertinoDatePickerMode.dateAndTime,
            onDateTimeSelected: (date) => selectedDate = date,
          ),
        ),
      );

      // Verify date picker is displayed
      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      // Verify initial date is set via callback (fires post-frame; one
      // extra pump is enough — no animation to settle)
      await tester.pump();
      expect(selectedDate, equals(initialDate));
    });

    testWidgets('respects different picker modes', (WidgetTester tester) async {
      // Test date-only mode
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeBottomSheet(
            DateTime(2024, 3, 15, 14, 30),
            mode: CupertinoDatePickerMode.date,
            onDateTimeSelected: (_) {},
          ),
        ),
      );

      final datePicker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(datePicker.mode, CupertinoDatePickerMode.date);

      // Test time-only mode
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeBottomSheet(
            DateTime(2024, 3, 15, 16, 45),
            mode: CupertinoDatePickerMode.time,
            onDateTimeSelected: (_) {},
          ),
        ),
      );

      final timePicker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(timePicker.mode, CupertinoDatePickerMode.time);
    });

    testWidgets('uses 24-hour format', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeBottomSheet(
            DateTime(2024, 3, 15, 14, 30),
            mode: CupertinoDatePickerMode.time,
            onDateTimeSelected: (_) {},
          ),
        ),
      );

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.use24hFormat, isTrue);
    });
  });

  group('DateTimeField Modal Integration Tests', () {
    testWidgets('complete flow: open modal, select date, tap done', (
      WidgetTester tester,
    ) async {
      final initialDate = DateTime(2024, 1, 15, 14, 30);
      final setDates = <DateTime>[];

      await _pumpField(
        tester,
        dateTime: initialDate,
        setDateTime: setDates.add,
      );

      // Tap field to open modal
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(DateTimeBottomSheet), findsOneWidget);
      expect(find.byType(DateTimeStickyActionBar), findsOneWidget);

      // Tap Done button
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Verify callback was called with the selected date
      expect(setDates, [initialDate]);

      // Verify modal is closed
      expect(find.byType(DateTimeBottomSheet), findsNothing);
    });

    testWidgets('complete flow: open modal, tap now button', (
      WidgetTester tester,
    ) async {
      final setDates = <DateTime>[];

      await _pumpField(tester, dateTime: null, setDateTime: setDates.add);

      // Tap field to open modal
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Tap Now button, bracketing the tap with wall-clock readings so the
      // captured value can be pinned to the live-clock window.
      final before = DateTime.now();
      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();
      final after = DateTime.now();

      // Verify callback was called exactly once with the current time
      expect(setDates, hasLength(1));
      final captured = setDates.single;
      expect(
        !captured.isBefore(before) && !captured.isAfter(after),
        isTrue,
        reason:
            'onNow must pass the wall-clock time of the tap, '
            'got $captured outside [$before, $after]',
      );

      // Verify modal is closed
      expect(find.byType(DateTimeBottomSheet), findsNothing);
    });

    testWidgets('complete flow: open modal, tap cancel', (
      WidgetTester tester,
    ) async {
      final initialDate = DateTime(2024, 1, 15, 14, 30);
      final setDates = <DateTime>[];

      await _pumpField(
        tester,
        dateTime: initialDate,
        setDateTime: setDates.add,
      );

      // Tap field to open modal
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify callback was not called
      expect(setDates, isEmpty);

      // Verify modal is closed
      expect(find.byType(DateTimeBottomSheet), findsNothing);
    });
  });
}
