import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_log_today_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  final today = DateTime.utc(2026, 8, 13);
  late MockGoalHabitCompletionService completionService;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    completionService = MockGoalHabitCompletionService();
  });

  GoalProgressView progress({int measureValueToday = 0}) => GoalProgressView(
    today: today,
    habits: [
      GoalHabitProgressView(
        habitId: 'measure',
        name: 'Measure Blood Pressure',
        targetCount: 5,
        days: [
          for (var offset = 6; offset >= 0; offset--)
            GoalProgressDay(
              day: today.subtract(Duration(days: offset)),
              value: offset == 0 ? measureValueToday : 0,
            ),
        ],
        successfulWeeks: 0,
      ),
      GoalHabitProgressView(
        habitId: 'meds',
        name: 'BP meds',
        targetCount: 7,
        days: [
          for (var offset = 6; offset >= 0; offset--)
            GoalProgressDay(
              day: today.subtract(Duration(days: offset)),
              value: 1,
            ),
        ],
        successfulWeeks: 1,
      ),
    ],
    metrics: [
      GoalMetricProgressView(
        name: 'Systolic blood pressure',
        target: 125,
        days: [GoalProgressDay(day: today, value: 129)],
      ),
    ],
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    int measureValueToday = 0,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalLogTodaySheet(
            agentId: 'goal-1',
            progress: progress(measureValueToday: measureValueToday),
          ),
        ),
        overrides: [
          goalHabitCompletionServiceProvider.overrideWithValue(
            completionService,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every dimension with the date: one-tap Mark done for '
      'blank habits, a done check for completed ones, read-only data rows', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Log today'), findsOneWidget);
    expect(find.text('Thursday, August 13'), findsOneWidget);
    // The blank habit gets the button, the completed one the check.
    expect(
      find.byKey(const ValueKey('goal-log-today-mark-measure')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-log-today-done-meds')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-log-today-mark-meds')),
      findsNothing,
    );
    // Data dimensions never pretend to be typeable here.
    expect(find.text('Systolic blood pressure'), findsOneWidget);
    expect(find.text('Updates from its linked source'), findsOneWidget);
  });

  testWidgets('Mark done records a success for TODAY through the shared '
      'completion path and flips the row to done', (tester) async {
    when(
      () => completionService.record(
        agentId: 'goal-1',
        habitId: 'measure',
        day: today,
        outcome: HabitCompletionType.success,
      ),
    ).thenAnswer((_) async => true);
    await pumpSheet(tester);

    await withClock(Clock.fixed(DateTime.utc(2026, 8, 13, 14)), () async {
      await tester.tap(
        find.byKey(const ValueKey('goal-log-today-mark-measure')),
      );
      await tester.pumpAndSettle();
    });

    verify(
      () => completionService.record(
        agentId: 'goal-1',
        habitId: 'measure',
        day: today,
        outcome: HabitCompletionType.success,
      ),
    ).called(1);
    expect(
      find.byKey(const ValueKey('goal-log-today-done-measure')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-log-today-mark-measure')),
      findsNothing,
    );
  });

  testWidgets('a failed save keeps the button and reports the failure', (
    tester,
  ) async {
    when(
      () => completionService.record(
        agentId: any(named: 'agentId'),
        habitId: any(named: 'habitId'),
        day: any(named: 'day'),
        outcome: any(named: 'outcome'),
      ),
    ).thenAnswer((_) async => false);
    await pumpSheet(tester);

    await tester.tap(
      find.byKey(const ValueKey('goal-log-today-mark-measure')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-log-today-mark-measure')),
      findsOneWidget,
    );
    expect(find.text("That didn't save — please try again."), findsOneWidget);
  });

  testWidgets('a sheet held open across midnight writes the NEW day, never '
      'the stale constructor snapshot', (tester) async {
    final afterMidnight = DateTime.utc(2026, 8, 14, 0, 30);
    when(
      () => completionService.record(
        agentId: any(named: 'agentId'),
        habitId: any(named: 'habitId'),
        day: any(named: 'day'),
        outcome: any(named: 'outcome'),
      ),
    ).thenAnswer((_) async => true);
    await pumpSheet(tester);

    await withClock(Clock.fixed(afterMidnight), () async {
      await tester.tap(
        find.byKey(const ValueKey('goal-log-today-mark-measure')),
      );
      await tester.pumpAndSettle();
    });

    verify(
      () => completionService.record(
        agentId: 'goal-1',
        habitId: 'measure',
        day: DateTime.utc(2026, 8, 14),
        outcome: HabitCompletionType.success,
      ),
    ).called(1);
  });

  testWidgets('a composite goal with many dimensions scrolls — later rows '
      'and their actions stay reachable', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final manyHabits = GoalProgressView(
      today: today,
      habits: [
        for (var i = 0; i < 20; i++)
          GoalHabitProgressView(
            habitId: 'habit-$i',
            name: 'Habit $i',
            targetCount: 3,
            days: [
              for (var offset = 6; offset >= 0; offset--)
                GoalProgressDay(
                  day: today.subtract(Duration(days: offset)),
                  value: 0,
                ),
            ],
            successfulWeeks: 0,
          ),
      ],
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalLogTodaySheet(agentId: 'goal-1', progress: manyHabits),
        ),
        overrides: [
          goalHabitCompletionServiceProvider.overrideWithValue(
            completionService,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // SingleChildScrollView children are always built, so reachability is
    // a geometry claim: the last action starts below the fold and scrolling
    // brings it into the viewport.
    const lastRow = ValueKey('goal-log-today-mark-habit-19');
    expect(tester.getRect(find.byKey(lastRow)).bottom, greaterThan(500));
    await tester.scrollUntilVisible(
      find.byKey(lastRow),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getRect(find.byKey(lastRow)).bottom,
      lessThanOrEqualTo(500),
    );
  });

  testWidgets('the sheet closes itself when the local day rolls over — a '
      'stale snapshot must not keep offering yesterday', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => GoalLogTodaySheet(
                    agentId: 'goal-1',
                    progress: progress(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [
          goalHabitCompletionServiceProvider.overrideWithValue(
            completionService,
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalLogTodaySheet), findsOneWidget);

    // Cross the midnight boundary in fake-async time: the sheet pops.
    await tester.pump(const Duration(hours: 25));
    await tester.pumpAndSettle();
    expect(find.byType(GoalLogTodaySheet), findsNothing);
  });

  testWidgets('a habit already completed today opens as done', (tester) async {
    await pumpSheet(tester, measureValueToday: 1);

    expect(
      find.byKey(const ValueKey('goal-log-today-done-measure')),
      findsOneWidget,
    );
    verifyNever(
      () => completionService.record(
        agentId: any(named: 'agentId'),
        habitId: any(named: 'habitId'),
        day: any(named: 'day'),
        outcome: any(named: 'outcome'),
      ),
    );
  });
}
