import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_today_portion.dart';

void main() {
  const evaluator = GoalProgressEvaluator();
  DateTime d(int day) => DateTime.utc(2026, 8, day);
  // 2026-08-08, a Saturday: the evaluation day throughout.
  final today = d(8);

  bool met(GoalCriterion criterion, GoalSignalWindow signals) =>
      goalTodayPortionMet(
        criterion: criterion,
        signals: signals,
        evaluation: evaluator.evaluate(criterion, signals, today),
        reference: today,
      );

  // Spoken check-ins — the audio goal: three minutes a day, averaged over a
  // rolling week.
  const checkIns = GoalCriterion.checkInTime(
    criterionId: 'check-ins',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    targetMinutes: 3,
  );

  group('a per-day target', () {
    test("today's own recordings meet it while the week is still behind", () {
      // Two recordings today, 1.5 + 2 minutes; nothing the six days before,
      // so the zero-filled week averages 0.5 — far below 3.
      final signals = GoalSignalWindow(checkInDailyMinutes: {today: 3.5});
      expect(
        evaluator.evaluate(checkIns, signals, today).satisfied,
        isFalse,
        reason: 'the precondition: the window itself is not met',
      );
      expect(met(checkIns, signals), isTrue);
    });

    test('a short day counts only when the window is already met', () {
      final signals = GoalSignalWindow(
        checkInDailyMinutes: {
          for (var day = 1; day < 8; day++) d(day): day == 7 ? 1 : 10,
        },
      );
      // The week averages well above target — but the window ends today and
      // today's 1 minute is short. The window verdict still answers first.
      expect(evaluator.evaluate(checkIns, signals, today).satisfied, isTrue);
      expect(met(checkIns, signals), isTrue);

      final behind = GoalSignalWindow(
        checkInDailyMinutes: {d(7): 3, today: 1},
      );
      expect(met(checkIns, behind), isFalse);
    });

    test('a day with nothing recorded is never met', () {
      // Yesterday's 5 minutes leave the zero-filled week at 5/7 — behind.
      final signals = GoalSignalWindow(checkInDailyMinutes: {d(7): 5});
      expect(evaluator.evaluate(checkIns, signals, today).satisfied, isFalse);
      expect(met(checkIns, signals), isFalse);
    });

    test('max needs one day at target, and today is that day', () {
      const best = GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'cumulative_step_count',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.max,
        target: 10000,
      );
      GoalSignalWindow steps(num value) => GoalSignalWindow(
        quantitativeDailySums: {
          'cumulative_step_count': {today: value},
        },
      );
      expect(met(best, steps(10000)), isTrue);
      expect(met(best, steps(9999)), isFalse);
    });
  });

  group('a period total', () {
    const weeklySteps = GoalCriterion.metric(
      criterionId: 'steps',
      dataType: 'cumulative_step_count',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.sum,
      target: 70000,
    );
    GoalSignalWindow steps(num value) => GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {today: value},
      },
    );

    test("is met by today's even share of it", () {
      expect(met(weeklySteps, steps(10000)), isTrue);
      expect(met(weeklySteps, steps(9999)), isFalse);
    });

    test('a calendar month shares by its own length', () {
      // August has 31 days: 31 hours a month is one hour a day.
      const monthly = GoalCriterion.measurable(
        criterionId: 'reading',
        dataTypeId: 'reading-hours',
        window: GoalWindow.calendarMonth(),
        aggregation: GoalAggregation.sum,
        target: 31,
      );
      GoalSignalWindow reading(num value) => GoalSignalWindow(
        measurableDailySums: {
          'reading-hours': {today: value},
        },
      );
      expect(met(monthly, reading(1)), isTrue);
      expect(met(monthly, reading(0.9)), isFalse);
    });

    test('a count of active days is met by any value today', () {
      const activeDays = GoalCriterion.measurable(
        criterionId: 'water',
        dataTypeId: 'water',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.count,
        target: 5,
      );
      expect(
        met(
          activeDays,
          GoalSignalWindow(
            measurableDailySums: {
              'water': {today: 1},
            },
          ),
        ),
        isTrue,
      );
      expect(
        met(
          activeDays,
          GoalSignalWindow(
            measurableDailySums: {
              'water': {d(7): 1},
            },
          ),
        ),
        isFalse,
      );
    });
  });

  group('a habit quota', () {
    GoalSignalWindow habit(Map<DateTime, int> byDay) =>
        GoalSignalWindow(habitSuccessesByDay: {'walk': byDay});

    test('a rolling quota is met once today is credited', () {
      const rolling = GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 5,
      );
      expect(met(rolling, habit({today: 1})), isTrue);
      expect(met(rolling, habit({d(7): 1})), isFalse);
    });

    test('a one-day window needs its whole quota today', () {
      const twiceDaily = GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk',
        window: GoalWindow.day(),
        targetCount: 2,
      );
      expect(met(twiceDaily, habit({today: 1})), isFalse);
      expect(met(twiceDaily, habit({today: 2})), isTrue);
    });

    test('a weekly quota already reached leaves nothing for today', () {
      const weekly = GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk',
        window: GoalWindow.calendarWeek(),
        targetCount: 3,
      );
      // 2026-08-03 is the week's Monday.
      expect(met(weekly, habit({d(3): 1, d(4): 1, d(5): 1})), isTrue);
      expect(met(weekly, habit({d(3): 1, d(4): 1})), isFalse);
    });
  });

  test('a ceiling cannot vouch for a day that is not over', () {
    const espressos = GoalCriterion.measurable(
      criterionId: 'espresso',
      dataTypeId: 'espresso',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 2,
      direction: GoalDirection.atMost,
    );
    // Under the cap all week and nothing yet today: still not "done".
    final signals = GoalSignalWindow(
      measurableDailySums: {
        'espresso': {d(7): 1, today: 0},
      },
    );
    expect(evaluator.evaluate(espressos, signals, today).satisfied, isTrue);
    expect(met(espressos, signals), isFalse);
  });

  group('composites fold their children', () {
    const walk = GoalCriterion.habit(
      criterionId: 'walk',
      habitId: 'walk',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 5,
    );
    const read = GoalCriterion.habit(
      criterionId: 'read',
      habitId: 'read',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 5,
    );
    const meditate = GoalCriterion.habit(
      criterionId: 'meditate',
      habitId: 'meditate',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 5,
    );
    GoalSignalWindow done(Set<String> habits) => GoalSignalWindow(
      habitSuccessesByDay: {
        for (final id in habits) id: {today: 1},
      },
    );

    test('allOf needs every child', () {
      const routine = GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [walk, read],
      );
      expect(met(routine, done({'walk'})), isFalse);
      expect(met(routine, done({'walk', 'read'})), isTrue);
    });

    test('anyOf needs one child', () {
      const either = GoalCriterion.anyOf(
        criterionId: 'either',
        criteria: [walk, read],
      );
      expect(met(either, done({})), isFalse);
      expect(met(either, done({'read'})), isTrue);
    });

    test('atLeastCount needs its successes', () {
      const twoOfThree = GoalCriterion.atLeastCount(
        criterionId: 'pillars',
        criteria: [walk, read, meditate],
        successes: 2,
      );
      expect(met(twoOfThree, done({'walk'})), isFalse);
      expect(met(twoOfThree, done({'walk', 'meditate'})), isTrue);
    });
  });

  test('a criterion of an unknown kind is never done', () {
    const unknown = GoalCriterion.allOf(
      criterionId: 'mixed',
      criteria: [
        checkIns,
        GoalCriterion.unsupported(criterionId: 'from-the-future'),
      ],
    );
    expect(
      goalTodayPortionMet(
        criterion: unknown,
        signals: GoalSignalWindow(checkInDailyMinutes: {today: 30}),
        // Never consulted: the unknown leaf decides before any evaluation.
        evaluation: evaluator.evaluate(
          checkIns,
          GoalSignalWindow(checkInDailyMinutes: {today: 30}),
          today,
        ),
        reference: today,
      ),
      isFalse,
    );
  });
}
