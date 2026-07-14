import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_status_bar.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, EntryDateTimeRange range) =>
      tester.pumpWidget(
        makeTestableWidgetWithScaffold(EntryDateTimeStatusBar(range: range)),
      );

  testWidgets('valid same-day range shows the duration and no chip/warning', (
    tester,
  ) async {
    await pump(
      tester,
      EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 14, minute: 30),
        endTime: const TimeOfDay(hour: 15, minute: 15),
        differentDates: false,
      ),
    );

    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget);
    expect(find.byType(DsPill), findsOneWidget);
    expect(
      tester.widget<Visibility>(find.byType(Visibility)).visible,
      isFalse,
    );
    expect(find.text('Invalid Date Range'), findsNothing);
  });

  testWidgets('overnight auto-roll shows the teal next-day chip', (
    tester,
  ) async {
    await pump(
      tester,
      EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 23, minute: 30),
        endTime: const TimeOfDay(hour: 0, minute: 30),
        differentDates: false,
      ),
    );

    expect(find.text('1h'), findsOneWidget);
    expect(find.byType(DsPill), findsOneWidget);
    expect(find.textContaining('(next day)'), findsOneWidget);
  });

  testWidgets('crossing midnight does not change the status height', (
    tester,
  ) async {
    await pump(
      tester,
      EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 14, minute: 30),
        endTime: const TimeOfDay(hour: 15, minute: 15),
        differentDates: false,
      ),
    );
    final sameDayHeight = tester
        .getSize(
          find.byType(EntryDateTimeStatusBar),
        )
        .height;

    await pump(
      tester,
      EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 23, minute: 30),
        endTime: const TimeOfDay(hour: 0, minute: 30),
        differentDates: false,
      ),
    );

    expect(
      tester.getSize(find.byType(EntryDateTimeStatusBar)).height,
      sameDayHeight,
    );
  });

  testWidgets('an invalid range shows the warning instead of a duration', (
    tester,
  ) async {
    await pump(
      tester,
      EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 0),
        differentDates: true,
        endDateOverride: _dateBefore, // end day before the start day
      ),
    );

    expect(find.text('Invalid Date Range'), findsOneWidget);
    expect(find.text('Duration'), findsNothing);
    expect(find.byType(DsPill), findsNothing);
  });

  testWidgets('narrow layouts omit the repeated year from the range label', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 14, minute: 30),
        endTime: const TimeOfDay(hour: 15, minute: 15),
        differentDates: false,
      ),
    );

    expect(find.textContaining('Sat, Jun 15 ·'), findsOneWidget);
    expect(find.textContaining('2024'), findsNothing);
  });
}

final _date = DateTime(2024, 6, 15);
final _dateBefore = DateTime(2024, 6, 14);
