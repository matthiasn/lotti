import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpControl(
    WidgetTester tester, {
    required HabitDisplayFilter filter,
    required void Function(HabitDisplayFilter?) onValueChanged,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: HabitStatusSegmentedControl(
            filter: filter,
            onValueChanged: onValueChanged,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the four localized segment labels', (tester) async {
    await pumpControl(
      tester,
      filter: HabitDisplayFilter.openNow,
      onValueChanged: (_) {},
    );

    expect(find.text('due'), findsOneWidget);
    expect(find.text('later'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
    expect(find.text('all'), findsOneWidget);
  });

  testWidgets('tapping each segment reports its filter value', (tester) async {
    // (label, expected filter) for every non-selected segment; start on a
    // different selection so each tap is a real change.
    for (final (label, expected) in [
      ('later', HabitDisplayFilter.pendingLater),
      ('done', HabitDisplayFilter.completed),
      ('all', HabitDisplayFilter.all),
      ('due', HabitDisplayFilter.openNow),
    ]) {
      HabitDisplayFilter? reported;
      await pumpControl(
        tester,
        filter: expected == HabitDisplayFilter.openNow
            ? HabitDisplayFilter.all
            : HabitDisplayFilter.openNow,
        onValueChanged: (value) => reported = value,
      );

      await tester.tap(find.text(label));
      await tester.pump();

      expect(reported, expected, reason: label);
    }
  });
}
