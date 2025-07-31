import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';

class MockCallback extends Mock {
  void call(DateTime dateTime);
}

class MockVoidCallback extends Mock {
  void call();
}

void main() {
  group('DateTimeField Widget Tests', () {
    late MockCallback mockSetDateTime;
    late MockVoidCallback mockClear;

    setUp(() {
      mockSetDateTime = MockCallback();
      mockClear = MockVoidCallback();
    });

    testWidgets('displays formatted date when dateTime is provided',
        (WidgetTester tester) async {
      final testDate = DateTime(2024, 1, 15, 14, 30);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: testDate,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
          ),
        ),
      );

      // Verify the date is displayed in the text field
      expect(find.text('2024-01-15 14:30'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
    });

    testWidgets('displays empty field when dateTime is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: null,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
          ),
        ),
      );

      // Verify the field is empty
      expect(find.text(''), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
    });

    testWidgets('shows clear button when clear callback is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: DateTime.now(),
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
            clear: mockClear.call,
          ),
        ),
      );

      // Verify clear button is visible
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      verify(mockClear.call).called(1);
    });

    testWidgets('opens modal when field is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: null,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
          ),
        ),
      );

      // Tap the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Verify modal is opened with date picker
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.byType(DateTimeStickyActionBar), findsOneWidget);
    });

    testWidgets('displays date only format for date mode',
        (WidgetTester tester) async {
      final testDate = DateTime(2024, 1, 15, 14, 30);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: testDate,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
            mode: CupertinoDatePickerMode.date,
          ),
        ),
      );

      // Verify date-only format
      expect(find.text('2024-01-15'), findsOneWidget);
    });

    testWidgets('displays time only format for time mode',
        (WidgetTester tester) async {
      final testDate = DateTime(2024, 1, 15, 14, 30);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: testDate,
            labelText: 'Select Time',
            setDateTime: mockSetDateTime.call,
            mode: CupertinoDatePickerMode.time,
          ),
        ),
      );

      // Verify time-only format
      expect(find.text('14:30'), findsOneWidget);
    });
  });

  group('DateTimeStickyActionBar Widget Tests', () {
    late MockVoidCallback mockOnCancel;
    late MockVoidCallback mockOnNow;
    late MockVoidCallback mockOnDone;

    setUp(() {
      mockOnCancel = MockVoidCallback();
      mockOnNow = MockVoidCallback();
      mockOnDone = MockVoidCallback();
    });

    testWidgets('displays all three buttons with correct labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeStickyActionBar(
            onCancel: mockOnCancel.call,
            onNow: mockOnNow.call,
            onDone: mockOnDone.call,
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

    testWidgets('calls correct callbacks when buttons are tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeStickyActionBar(
            onCancel: mockOnCancel.call,
            onNow: mockOnNow.call,
            onDone: mockOnDone.call,
          ),
        ),
      );

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verify(mockOnCancel.call).called(1);

      // Tap Now button
      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();
      verify(mockOnNow.call).called(1);

      // Tap Done button
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      verify(mockOnDone.call).called(1);
    });
  });

  group('DateTimeBottomSheet Widget Tests', () {
    testWidgets('displays CupertinoDatePicker with initial date',
        (WidgetTester tester) async {
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

      // Verify initial date is set via callback
      await tester.pumpAndSettle();
      expect(selectedDate, equals(initialDate));
    });

    testWidgets('respects different picker modes', (WidgetTester tester) async {
      // Test date-only mode
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeBottomSheet(
            DateTime.now(),
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
            DateTime.now(),
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
            DateTime.now(),
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
    late MockCallback mockSetDateTime;

    setUp(() {
      mockSetDateTime = MockCallback();
    });

    testWidgets('complete flow: open modal, select date, tap done',
        (WidgetTester tester) async {
      final initialDate = DateTime(2024, 1, 15, 14, 30);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: initialDate,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
          ),
        ),
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
      verify(() => mockSetDateTime(initialDate)).called(1);

      // Verify modal is closed
      expect(find.byType(DateTimeBottomSheet), findsNothing);
    });

    testWidgets('complete flow: open modal, tap now button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: null,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
          ),
        ),
      );

      // Tap field to open modal
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Tap Now button
      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();

      // Verify callback was called with a recent date
      final capturedDate = verify(() => mockSetDateTime(captureAny()))
          .captured
          .single as DateTime;
      expect(
        DateTime.now().difference(capturedDate).inSeconds,
        lessThan(2),
      );

      // Verify modal is closed
      expect(find.byType(DateTimeBottomSheet), findsNothing);
    });

    testWidgets('complete flow: open modal, tap cancel',
        (WidgetTester tester) async {
      final initialDate = DateTime(2024, 1, 15, 14, 30);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DateTimeField(
            dateTime: initialDate,
            labelText: 'Select Date',
            setDateTime: mockSetDateTime.call,
          ),
        ),
      );

      // Tap field to open modal
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify callback was not called
      verifyNever(() => mockSetDateTime(any()));

      // Verify modal is closed
      expect(find.byType(DateTimeBottomSheet), findsNothing);
    });
  });
}
