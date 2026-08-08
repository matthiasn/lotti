import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_criterion.dart';
import 'package:lotti/features/goals/model/goal_enums.dart';
import 'package:lotti/features/goals/model/goal_window.dart';

void main() {
  const evaluator = GoalProgressEvaluator();
  DateTime d(int day) => DateTime.utc(2026, 8, day);
  final saturday = d(8); // 2026-08-08 is a Saturday.

  const stepsCriterion = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );

  GoalSignalWindow steps(Map<DateTime, num> byDay) => GoalSignalWindow(
    quantitativeDailySums: {
      'cumulative_step_count': byDay,
    },
  );

  group('metric leaf — dailySumThenAverage', () {
    test('full week averages all seven days', () {
      // (7120+6890+5980+6410+6205+5740+6555)/7 = 44900/7 ≈ 6414.29
      final signals = steps({
        d(2): 7120,
        d(3): 6890,
        d(4): 5980,
        d(5): 6410,
        d(6): 6205,
        d(7): 5740,
        d(8): 6555,
      });
      final evaluation = evaluator.evaluate(stepsCriterion, signals, saturday);
      final leaf = evaluation.results['steps']!;
      expect(leaf.actual, closeTo(44900 / 7, 1e-9));
      expect(evaluation.attainment, closeTo(44900 / 7 / 10000, 1e-9));
      expect(evaluation.satisfied, isFalse);
      expect(leaf.sampleCount, 7);
      expect(evaluation.dataCoverage, 1.0);
      expect(evaluation.paceFeasible, isNull);
    });

    test('missing days are excluded from the mean, not zero-filled', () {
      final signals = steps({
        d(2): 10000,
        d(4): 10000,
        d(6): 10000,
        d(8): 10000,
      });
      final evaluation = evaluator.evaluate(stepsCriterion, signals, saturday);
      expect(evaluation.results['steps']!.actual, 10000);
      expect(evaluation.satisfied, isTrue);
      expect(evaluation.dataCoverage, closeTo(4 / 7, 1e-9));
    });

    test('no data at all yields zero ratio and zero coverage', () {
      final evaluation = evaluator.evaluate(
        stepsCriterion,
        const GoalSignalWindow(),
        saturday,
      );
      final leaf = evaluation.results['steps']!;
      expect(leaf.ratio, 0);
      expect(leaf.satisfied, isFalse);
      expect(leaf.sampleCount, 0);
      expect(evaluation.dataCoverage, 0);
    });

    test('ratio clamps at 1.0 when over target', () {
      final signals = steps({d(8): 15000});
      final evaluation = evaluator.evaluate(stepsCriterion, signals, saturday);
      expect(evaluation.attainment, 1.0);
      expect(evaluation.satisfied, isTrue);
    });
  });

  group('metric leaf — directions and aggregations', () {
    test('atMost is satisfied under the cap and decays over it', () {
      const espresso = GoalCriterion.metric(
        criterionId: 'espresso',
        dataType: 'espresso_count',
        window: GoalWindow.rollingDays(count: 2),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 2,
        direction: GoalDirection.atMost,
      );
      final under = evaluator.evaluate(
        espresso,
        GoalSignalWindow(
          quantitativeDailySums: {
            'espresso_count': {d(7): 1, d(8): 2},
          },
        ),
        saturday,
      );
      // Mean 1.5 is under the cap of 2.
      expect(under.satisfied, isTrue);
      expect(under.attainment, 1.0);

      final over = evaluator.evaluate(
        espresso,
        GoalSignalWindow(
          quantitativeDailySums: {
            'espresso_count': {d(7): 3, d(8): 3},
          },
        ),
        saturday,
      );
      // Mean 3 exceeds the cap of 2 → ratio decays to 2/3.
      expect(over.satisfied, isFalse);
      expect(over.attainment, closeTo(2 / 3, 1e-9));
    });

    test('sum, count and max aggregate as named', () {
      final signals = steps({d(6): 4000, d(7): 6000, d(8): 9000});

      num actualFor(GoalAggregation aggregation) {
        final criterion = GoalCriterion.metric(
          criterionId: 'm',
          dataType: 'cumulative_step_count',
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: aggregation,
          target: 1,
        );
        return evaluator
            .evaluate(criterion, signals, saturday)
            .results['m']!
            .actual;
      }

      expect(actualFor(GoalAggregation.sum), 19000);
      expect(actualFor(GoalAggregation.count), 3);
      expect(actualFor(GoalAggregation.max), 9000);
    });

    test('measurable leaves evaluate like metric leaves on their own map', () {
      const water = GoalCriterion.measurable(
        criterionId: 'water',
        dataTypeId: 'water-id',
        window: GoalWindow.rollingDays(count: 3),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 2000,
      );
      final signals = GoalSignalWindow(
        measurableDailySums: {
          'water-id': {d(6): 1500, d(7): 1800, d(8): 1200},
        },
        // Same id in the quantitative map must NOT leak into the
        // measurable leaf — the maps are separate namespaces.
        quantitativeDailySums: {
          'water-id': {d(8): 99999},
        },
      );
      final evaluation = evaluator.evaluate(water, signals, saturday);
      final leaf = evaluation.results['water']!;
      expect(leaf.actual, closeTo(4500 / 3, 1e-9)); // mean 1500
      expect(evaluation.attainment, closeTo(0.75, 1e-9)); // 1500/2000
      expect(evaluation.satisfied, isFalse);
      expect(evaluation.dataCoverage, 1.0);

      // Short-term re-windowing hits the same measurable series.
      expect(
        evaluator.shortTermAttainment(water, signals, saturday),
        closeTo(0.75, 1e-9),
      );
    });

    test('atLeast with a zero target is trivially satisfied', () {
      const criterion = GoalCriterion.metric(
        criterionId: 'm',
        dataType: 'cumulative_step_count',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        target: 0,
      );
      final evaluation = evaluator.evaluate(
        criterion,
        steps({d(8): 5}),
        saturday,
      );
      expect(evaluation.attainment, 1.0);
      expect(evaluation.satisfied, isTrue);
    });
  });

  group('habit leaf', () {
    const gym = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.calendarWeek(),
      targetCount: 3,
    );

    GoalSignalWindow gymDays(Map<DateTime, int> byDay) =>
        GoalSignalWindow(habitSuccessesByDay: {'gym-habit': byDay});

    test('sums successes over the calendar week', () {
      // Week of Aug 3–9; Mon + Wed done, evaluated Saturday.
      final evaluation = evaluator.evaluate(
        gym,
        gymDays({d(3): 1, d(5): 1}),
        saturday,
      );
      final leaf = evaluation.results['gym']!;
      expect(leaf.actual, 2);
      expect(leaf.ratio, closeTo(2 / 3, 1e-9));
      expect(leaf.satisfied, isFalse);
      // Need 1 more; Sat (uncredited) + Sun remain → still feasible.
      expect(leaf.paceFeasible, isTrue);
      expect(evaluation.dataCoverage, 1.0);
    });

    test('quota becomes infeasible when the week runs out of days', () {
      // Evaluated Sunday Aug 9 with one success: needs 2 more, but only
      // Sunday itself (uncredited) remains.
      final evaluation = evaluator.evaluate(
        gym,
        gymDays({d(4): 1}),
        d(9),
      );
      expect(evaluation.results['gym']!.paceFeasible, isFalse);
    });

    test('a credited today does not count as remaining capacity', () {
      // Sunday with successes Wed + today: needs 1 more, zero days left.
      final evaluation = evaluator.evaluate(
        gym,
        gymDays({d(5): 1, d(9): 1}),
        d(9),
      );
      expect(evaluation.results['gym']!.paceFeasible, isFalse);
    });

    test('satisfied quotas report no pace opinion', () {
      final evaluation = evaluator.evaluate(
        gym,
        gymDays({d(3): 1, d(5): 1, d(7): 1}),
        saturday,
      );
      final leaf = evaluation.results['gym']!;
      expect(leaf.satisfied, isTrue);
      expect(leaf.paceFeasible, isNull);
    });

    test('rolling windows never compute pace', () {
      const rollingGym = GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 3,
      );
      final evaluation = evaluator.evaluate(
        rollingGym,
        gymDays({d(4): 1}),
        saturday,
      );
      expect(evaluation.results['gym']!.paceFeasible, isNull);
    });

    test('zero completions still count as full data coverage', () {
      final evaluation = evaluator.evaluate(
        gym,
        const GoalSignalWindow(),
        saturday,
      );
      expect(evaluation.dataCoverage, 1.0);
      expect(evaluation.attainment, 0);
      expect(evaluation.results['gym']!.satisfied, isFalse);
    });

    test('multiple successes on one day all count toward the quota', () {
      final evaluation = evaluator.evaluate(
        gym,
        gymDays({d(3): 2, d(5): 1}),
        saturday,
      );
      expect(evaluation.results['gym']!.actual, 3);
      expect(evaluation.satisfied, isTrue);
    });
  });

  group('composites', () {
    const halfMetric = GoalCriterion.metric(
      criterionId: 'half',
      dataType: 'a',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      target: 100,
    );
    const fullMetric = GoalCriterion.metric(
      criterionId: 'full',
      dataType: 'b',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      target: 100,
    );

    final signals = GoalSignalWindow(
      quantitativeDailySums: {
        'a': {d(8): 50},
        'b': {d(8): 100},
      },
    );

    test('allOf averages ratios and requires all children', () {
      const criterion = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [halfMetric, fullMetric],
      );
      final evaluation = evaluator.evaluate(criterion, signals, saturday);
      final root = evaluation.results['root']!;
      expect(evaluation.attainment, closeTo(0.75, 1e-9));
      expect(evaluation.satisfied, isFalse);
      expect(root.actual, 1); // one satisfied child
      expect(root.target, 2);
      expect(evaluation.results.keys, containsAll(['root', 'half', 'full']));
    });

    test('anyOf takes the best child and any satisfaction', () {
      const criterion = GoalCriterion.anyOf(
        criterionId: 'root',
        criteria: [halfMetric, fullMetric],
      );
      final evaluation = evaluator.evaluate(criterion, signals, saturday);
      expect(evaluation.attainment, 1.0);
      expect(evaluation.satisfied, isTrue);
    });

    test('atLeastCount means the top-k ratios and counts satisfactions', () {
      const zeroMetric = GoalCriterion.metric(
        criterionId: 'zero',
        dataType: 'z',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        target: 100,
      );
      const criterion = GoalCriterion.atLeastCount(
        criterionId: 'root',
        criteria: [halfMetric, fullMetric, zeroMetric],
        successes: 2,
      );
      final withZero = GoalSignalWindow(
        quantitativeDailySums: {
          'a': {d(8): 50},
          'b': {d(8): 100},
          'z': {d(8): 20},
        },
      );
      final evaluation = evaluator.evaluate(criterion, withZero, saturday);
      final root = evaluation.results['root']!;
      // Top-2 ratios are 1.0 and 0.5 → 0.75; only one child satisfied.
      expect(evaluation.attainment, closeTo(0.75, 1e-9));
      expect(evaluation.satisfied, isFalse);
      expect(root.actual, 1);
      expect(root.target, 2);
    });

    test('composite coverage is the most pessimistic child', () {
      const criterion = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          stepsCriterion,
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'gym-habit',
            window: GoalWindow.calendarWeek(),
            targetCount: 3,
          ),
        ],
      );
      final evaluation = evaluator.evaluate(
        criterion,
        GoalSignalWindow(
          quantitativeDailySums: {
            'cumulative_step_count': {d(6): 9000, d(7): 9000, d(8): 9000},
          },
          habitSuccessesByDay: {
            'gym-habit': {d(3): 1},
          },
        ),
        saturday,
      );
      // Steps leaf: 3 of 7 days; habit leaf: full coverage.
      expect(evaluation.dataCoverage, closeTo(3 / 7, 1e-9));
    });

    test('an infeasible quota sinks allOf pace, anyOf survives on one', () {
      const infeasibleGym = GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 5,
      );
      // Sunday, zero successes: 5 needed, 1 creditable day left.
      const signals = GoalSignalWindow();

      const all = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [infeasibleGym, stepsCriterion],
      );
      expect(
        evaluator.evaluate(all, signals, d(9)).paceFeasible,
        isFalse,
      );

      const feasibleWalk = GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 1,
      );
      const any = GoalCriterion.anyOf(
        criterionId: 'root',
        criteria: [infeasibleGym, feasibleWalk],
      );
      expect(
        evaluator.evaluate(any, signals, d(9)).paceFeasible,
        isTrue,
      );
    });

    test('atLeastCount pace: one dead leg cannot sink a 2-of-3 quota', () {
      // Evaluated Sunday Aug 9. deadlift needs 5 with one day left →
      // impossible; walk needs 1 and today is uncredited → feasible;
      // stretch is already satisfied.
      const dead = GoalCriterion.habit(
        criterionId: 'deadlift',
        habitId: 'deadlift-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 5,
      );
      const walk = GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 1,
      );
      const stretch = GoalCriterion.habit(
        criterionId: 'stretch',
        habitId: 'stretch-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 1,
      );
      const twoOfThree = GoalCriterion.atLeastCount(
        criterionId: 'root',
        criteria: [dead, walk, stretch],
        successes: 2,
      );
      final signals = GoalSignalWindow(
        habitSuccessesByDay: {
          'stretch-habit': {d(4): 1},
        },
      );

      // Two legs alive (walk feasible + stretch satisfied) → on pace,
      // even though the deadlift quota is unreachable.
      expect(
        evaluator.evaluate(twoOfThree, signals, d(9)).paceFeasible,
        isTrue,
      );

      // Same tree as allOf: the dead leg correctly sinks it.
      const allThree = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [dead, walk, stretch],
      );
      expect(
        evaluator.evaluate(allThree, signals, d(9)).paceFeasible,
        isFalse,
      );

      // 2-of-3 with two dead legs → genuinely impossible.
      const heavy = GoalCriterion.habit(
        criterionId: 'heavy',
        habitId: 'heavy-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 6,
      );
      const doomed = GoalCriterion.atLeastCount(
        criterionId: 'root',
        criteria: [dead, heavy, walk],
        successes: 2,
      );
      expect(
        evaluator.evaluate(doomed, signals, d(9)).paceFeasible,
        isFalse,
      );
    });

    test('metric-only trees have no pace opinion', () {
      const criterion = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [halfMetric, fullMetric],
      );
      expect(
        evaluator.evaluate(criterion, signals, saturday).paceFeasible,
        isNull,
      );
    });

    test('empty composites are rejected', () {
      const criterion = GoalCriterion.allOf(criterionId: 'root', criteria: []);
      expect(
        () => evaluator.evaluate(criterion, const GoalSignalWindow(), d(8)),
        throwsArgumentError,
      );
    });
  });

  group('shortTermAttainment', () {
    test('re-windows metric leaves to the trailing days', () {
      // Bad week overall, but the last 3 days are on pace.
      final signals = steps({
        d(2): 7000,
        d(3): 7200,
        d(4): 6800,
        d(5): 7400,
        d(6): 10500,
        d(7): 11000,
        d(8): 10200,
      });
      final weekly = evaluator.evaluate(stepsCriterion, signals, saturday);
      expect(weekly.attainment, lessThan(1));
      final shortTerm = evaluator.shortTermAttainment(
        stepsCriterion,
        signals,
        saturday,
      );
      expect(shortTerm, 1.0);
    });

    test('habit-only trees return null', () {
      const criterion = GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 3,
      );
      expect(
        evaluator.shortTermAttainment(
          criterion,
          const GoalSignalWindow(),
          saturday,
        ),
        isNull,
      );
    });

    test('composites fold only the re-windowable children', () {
      const criterion = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          stepsCriterion,
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'gym-habit',
            window: GoalWindow.calendarWeek(),
            targetCount: 3,
          ),
        ],
      );
      final signals = steps({d(6): 10000, d(7): 10000, d(8): 10000});
      expect(
        evaluator.shortTermAttainment(criterion, signals, saturday),
        1.0,
      );
    });

    test('anyOf takes the best short-term child', () {
      const criterion = GoalCriterion.anyOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'a',
            dataType: 'a',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 100,
          ),
          GoalCriterion.metric(
            criterionId: 'b',
            dataType: 'b',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 100,
          ),
        ],
      );
      final signals = GoalSignalWindow(
        quantitativeDailySums: {
          'a': {d(8): 40},
          'b': {d(8): 90},
        },
      );
      expect(
        evaluator.shortTermAttainment(criterion, signals, saturday),
        closeTo(0.9, 1e-9),
      );
    });
  });
}
