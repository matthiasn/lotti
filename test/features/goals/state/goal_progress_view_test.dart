import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';

void main() {
  final today = DateTime(2026, 8, 11);
  DateTime day(int offset) => GoalWindow.dayUtc(
    today.subtract(Duration(days: offset)),
  );

  test('habit projection keeps the slipped day, active window, deficit and '
      'six-week reliability on the evaluator signal source', () {
    final successes = <DateTime, int>{
      day(7): 1,
      day(6): 1,
      day(3): 1,
      day(0): 1,
      for (final offset in [8, 10, 12, 13, 15, 17, 19, 20, 22, 24, 26])
        day(offset): 1,
    };
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-id',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 4,
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {'gym-id': successes},
      ),
      reference: today,
      habitNames: const {'gym-id': 'Gym'},
    );

    final habit = view.habits.single;
    expect(habit.name, 'Gym');
    expect(habit.days, hasLength(8));
    expect(habit.days.first.day, day(7), reason: 'slipped day stays visible');
    expect(habit.successesInWindow, 3);
    expect(habit.deficit, 1);
    expect(habit.oldestSuccessAgesOutTonight, isFalse);
    expect(habit.successfulWeeks, 2);
    expect(view.compactWindow, [true, false, false, true, false, false, true]);
  });

  test('an at-rate habit marks the oldest active success as aging out', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk-id',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
        title: 'Walk',
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'walk-id': {day(6): 1, day(0): 1},
        },
      ),
      reference: today,
    );

    final habit = view.habits.single;
    expect(habit.deficit, 0);
    expect(habit.oldestSuccessAgesOutTonight, isTrue);
  });

  test('metric projection supplies seven values and target-clearing compact '
      'days', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'steps',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 8000,
        title: 'Daily steps',
      ),
      signals: GoalSignalWindow(
        quantitativeDailySums: {
          'steps': {day(6): 9000, day(2): 8000, day(0): 7999},
        },
      ),
      reference: today,
    );

    expect(view.metric?.days, hasLength(7));
    expect(view.compactWindow, [true, false, false, false, true, false, false]);
  });

  test('composite compact strip requires every watched habit on that day', () {
    final view = buildGoalProgressView(
      criteria: const GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'a',
            habitId: 'a',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
          GoalCriterion.habit(
            criterionId: 'b',
            habitId: 'b',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
        ],
      ),
      signals: GoalSignalWindow(
        habitSuccessesByDay: {
          'a': {day(1): 1, day(0): 1},
          'b': {day(0): 1},
        },
      ),
      reference: today,
    );

    expect(view.compactWindow, [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
    ]);
  });
}
