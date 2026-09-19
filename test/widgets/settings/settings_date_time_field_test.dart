import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/date_time/datetime_bottom_sheet.dart';
import 'package:lotti/widgets/settings/settings_date_time_field.dart';

import '../../widget_test_utils.dart';

void main() {
  final value = DateTime(2024, 1, 15, 14, 30);

  Future<void> pumpField(
    WidgetTester tester, {
    required DateTime? dateTime,
    void Function(DateTime)? setDateTime,
    CupertinoDatePickerMode mode = CupertinoDatePickerMode.dateAndTime,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SettingsDateTimeField(
          dateTime: dateTime,
          labelText: 'Active from',
          setDateTime: setDateTime ?? (_) {},
          mode: mode,
        ),
      ),
    );
  }

  for (final (mode, expected) in [
    (CupertinoDatePickerMode.dateAndTime, '2024-01-15 14:30'),
    (CupertinoDatePickerMode.date, '2024-01-15'),
    (CupertinoDatePickerMode.time, '14:30'),
  ]) {
    testWidgets('formats the value for ${mode.name} mode as "$expected"', (
      tester,
    ) async {
      await pumpField(tester, dateTime: value, mode: mode);

      expect(find.text(expected), findsOneWidget);
    });
  }

  testWidgets('tapping the field opens the shared picker in the same mode '
      'and Done applies the value', (tester) async {
    final picked = <DateTime>[];
    await pumpField(
      tester,
      dateTime: value,
      setDateTime: picked.add,
      mode: CupertinoDatePickerMode.date,
    );

    await tester.tap(find.text('2024-01-15'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.mode, CupertinoDatePickerMode.date);
    expect(picker.initialDateTime, value);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(picked, [value]);
    expect(find.byType(DateTimeBottomSheet), findsNothing);
  });
}
