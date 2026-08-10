import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';

import '../../../widget_test_utils.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  GoalProgressDay day(int offset, num value) => GoalProgressDay(
    day: today.subtract(Duration(days: offset)),
    value: value,
  );

  testWidgets('habit card renders the rolling-window hierarchy, per-habit '
      'distance and reliability without a percentage', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  day(7, 1),
                  day(6, 1),
                  day(5, 0),
                  day(4, 0),
                  day(3, 1),
                  day(2, 0),
                  day(1, 0),
                  day(0, 0),
                ],
                successfulWeeks: 4,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('This rolling week'), findsOneWidget);
    expect(find.text('trailing 7 days · slides at midnight'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('3× per 7 days'), findsOneWidget);
    expect(find.text('1 day to healthy'), findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('done'), findsOneWidget);
    expect(find.text('ages out tonight'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
  });

  testWidgets('compact strip reports the number of successful days once in '
      'semantics', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalCompactWindowStrip(
          days: [true, false, true, false, false, true, false],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        '3 successful days in the trailing seven-day window',
      ),
      findsOneWidget,
    );
  });

  testWidgets('metric card renders seven bars in the same rolling frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Daily steps',
              target: 8000,
              days: [
                for (var index = 0; index < 7; index++)
                  day(6 - index, index.isEven ? 9000 : 5000),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Daily steps'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(7));
  });
}
