import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

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

  group('label-time leaf — daily fulfillment', () {
    const criterion = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );

    test('45 minutes is in progress', () {
      final evaluation = evaluator.evaluate(
        criterion,
        GoalSignalWindow(
          labelTimeDailyHours: {
            'daily-content': {d(8): 0.75},
          },
        ),
        saturday,
      );

      expect(evaluation.results['daily-content']!.actual, 0.75);
      expect(evaluation.attainment, 0.75);
      expect(evaluation.satisfied, isFalse);
    });

    test('another 20 minutes fulfills the same daily criterion', () {
      final evaluation = evaluator.evaluate(
        criterion,
        GoalSignalWindow(
          labelTimeDailyHours: {
            'daily-content': {d(8): 65 / 60},
          },
        ),
        saturday,
      );

      expect(
        evaluation.results['daily-content']!.actual,
        closeTo(65 / 60, 1e-9),
      );
      expect(evaluation.attainment, 1);
      expect(evaluation.satisfied, isTrue);
    });

    test('short-term attainment re-windows the same label-time ledger', () {
      final attainment = evaluator.shortTermAttainment(
        criterion,
        GoalSignalWindow(
          labelTimeDailyHours: {
            'daily-content': {
              d(6): 0.25,
              d(7): 0.5,
              d(8): 0.75,
            },
          },
        ),
        saturday,
      );

      expect(attainment, 1);
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

    test('a sustained downward trend projects an at-most target on track', () {
      const weight = GoalCriterion.metric(
        criterionId: 'weight',
        dataType: 'HealthDataType.WEIGHT',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 80,
        direction: GoalDirection.atMost,
      );
      final evaluation = evaluator.evaluate(
        weight,
        GoalSignalWindow(
          quantitativeDailySums: {
            'HealthDataType.WEIGHT': {
              d(2): 88,
              d(3): 87.5,
              d(4): 87,
              d(5): 86.5,
              d(6): 86,
              d(7): 85.5,
              d(8): 85,
            },
          },
        ),
        saturday,
      );

      expect(evaluation.satisfied, isFalse);
      expect(evaluation.onTrackByTrend, isTrue);
      expect(evaluation.results['weight']!.projectedDaysToTarget, 13);
    });

    test('a flat or too-slow health trend is not projected on track', () {
      const systolic = GoalCriterion.metric(
        criterionId: 'systolic',
        dataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 120,
        direction: GoalDirection.atMost,
      );
      final evaluation = evaluator.evaluate(
        systolic,
        GoalSignalWindow(
          quantitativeDailySums: {
            'HealthDataType.BLOOD_PRESSURE_SYSTOLIC': {
              d(2): 140,
              d(3): 140,
              d(4): 139.9,
              d(5): 139.9,
              d(6): 139.8,
              d(7): 139.8,
              d(8): 139.7,
            },
          },
        ),
        saturday,
      );

      expect(evaluation.onTrackByTrend, isFalse);
      expect(evaluation.results['systolic']!.projectedDaysToTarget, isNull);
    });

    test('trend projection needs at least four observed days', () {
      const weight = GoalCriterion.metric(
        criterionId: 'weight',
        dataType: 'HealthDataType.WEIGHT',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 80,
        direction: GoalDirection.atMost,
      );
      final evaluation = evaluator.evaluate(
        weight,
        GoalSignalWindow(
          quantitativeDailySums: {
            'HealthDataType.WEIGHT': {d(6): 84, d(7): 83, d(8): 82},
          },
        ),
        saturday,
      );

      expect(evaluation.onTrackByTrend, isFalse);
      expect(evaluation.results['weight']!.projectedDaysToTarget, isNull);
    });

    test('an upward health target uses the same bounded projection', () {
      const weight = GoalCriterion.metric(
        criterionId: 'weight',
        dataType: 'HealthDataType.WEIGHT',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 85,
      );
      final evaluation = evaluator.evaluate(
        weight,
        GoalSignalWindow(
          quantitativeDailySums: {
            'HealthDataType.WEIGHT': {
              d(2): 78,
              d(3): 78.5,
              d(4): 79,
              d(5): 79.5,
              d(6): 80,
              d(7): 80.5,
              d(8): 81,
            },
          },
        ),
        saturday,
      );

      expect(evaluation.satisfied, isFalse);
      expect(evaluation.onTrackByTrend, isTrue);
      expect(evaluation.results['weight']!.projectedDaysToTarget, 11);
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

  group('category time leaf', () {
    const weeklyCap = GoalCriterion.categoryTime(
      criterionId: 'coding-cap',
      categoryId: 'vibe-coding',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.sum,
      targetHours: 6,
    );

    test('sums tracked hours and applies an at-most cap', () {
      final under = evaluator.evaluate(
        weeklyCap,
        GoalSignalWindow(
          categoryTimeDailyHours: {
            'coding-cap': {d(7): 2.25, d(8): 3.5},
          },
        ),
        saturday,
      );
      expect(under.results['coding-cap']!.actual, 5.75);
      expect(under.satisfied, isTrue);
      expect(under.dataCoverage, 1);

      final over = evaluator.evaluate(
        weeklyCap,
        GoalSignalWindow(
          categoryTimeDailyHours: {
            'coding-cap': {d(6): 2, d(7): 2, d(8): 3},
          },
        ),
        saturday,
      );
      expect(over.results['coding-cap']!.actual, 7);
      expect(over.satisfied, isFalse);
      expect(over.attainment, closeTo(6 / 7, 1e-9));
    });

    test('at-least and at-most thresholds include the exact boundary', () {
      const minimum = GoalCriterion.categoryTime(
        criterionId: 'creative-minimum',
        categoryId: 'creative-work',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 4,
        direction: GoalDirection.atLeast,
      );
      final exactSignals = GoalSignalWindow(
        categoryTimeDailyHours: {
          'creative-minimum': {d(7): 1.5, d(8): 2.5},
          'coding-cap': {d(7): 1.5, d(8): 4.5},
        },
      );

      expect(
        evaluator.evaluate(minimum, exactSignals, saturday).satisfied,
        isTrue,
      );
      expect(
        evaluator.evaluate(weeklyCap, exactSignals, saturday).satisfied,
        isTrue,
      );

      final below = evaluator.evaluate(
        minimum,
        GoalSignalWindow(
          categoryTimeDailyHours: {
            'creative-minimum': {d(8): 3.99},
          },
        ),
        saturday,
      );
      expect(below.satisfied, isFalse);
    });

    test(
      'count aggregation counts days with tracked time, not zero-filled days',
      () {
        const activeDays = GoalCriterion.categoryTime(
          criterionId: 'coding-days',
          categoryId: 'vibe-coding',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.count,
          targetHours: 2,
          direction: GoalDirection.atLeast,
        );
        final evaluation = evaluator.evaluate(
          activeDays,
          GoalSignalWindow(
            categoryTimeDailyHours: {
              'coding-days': {d(6): 0.5, d(8): 2},
            },
          ),
          saturday,
        );

        expect(evaluation.results['coding-days']!.actual, 2);
        expect(evaluation.satisfied, isTrue);
      },
    );

    test('no matching tracked time is a real zero, not missing telemetry', () {
      const curfew = GoalCriterion.categoryTime(
        criterionId: 'late-coding',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 0,
        dailyTimeRange: GoalDailyTimeRange(
          startMinute: 1290,
          endMinute: 420,
        ),
      );

      final evaluation = evaluator.evaluate(
        curfew,
        const GoalSignalWindow(),
        saturday,
      );

      expect(evaluation.results['late-coding']!.actual, 0);
      expect(evaluation.results['late-coding']!.sampleCount, 7);
      expect(evaluation.dataCoverage, 1);
      expect(evaluation.satisfied, isTrue);
    });

    test('short-term attainment re-windows the same category series', () {
      final signals = GoalSignalWindow(
        categoryTimeDailyHours: {
          'coding-cap': {d(6): 1, d(7): 1, d(8): 1},
        },
      );

      expect(
        evaluator.shortTermAttainment(weeklyCap, signals, saturday),
        1,
      );
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

  group('rolling-window habit leaf — deficit and buffer', () {
    // Rolling 7 ending Saturday d(8): the window is d(2)..d(8).
    const gym = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 3,
    );
    GoalSignalWindow days(Map<DateTime, int> byDay) =>
        GoalSignalWindow(habitSuccessesByDay: {'gym-habit': byDay});
    GoalCriterionResult leafFor(Map<DateTime, int> byDay) =>
        evaluator.evaluate(gym, days(byDay), saturday).results['gym']!;

    test('an empty window is a full deficit (= target) — a restart, not a '
        'verdict; no buffer', () {
      final leaf = leafFor(const {});
      expect(leaf.deficit, 3);
      expect(leaf.satisfied, isFalse);
      expect(leaf.ratio, 0);
      expect(leaf.buffer, isNull);
    });

    test('one short of target reads deficit 1', () {
      final leaf = leafFor({d(4): 1, d(6): 1});
      expect(leaf.deficit, 1);
      expect(leaf.satisfied, isFalse);
    });

    test('a single-leaf goal lifts the leaf deficit/buffer to the evaluation '
        'root — what the register persists and the list surfaces', () {
      final behind = evaluator.evaluate(
        gym,
        days({d(4): 1, d(6): 1}),
        saturday,
      );
      expect(behind.deficit, 1);
      expect(behind.buffer, isNull);

      final atRate = evaluator.evaluate(
        gym,
        days({d(4): 1, d(6): 1, d(8): 1}),
        saturday,
      );
      expect(atRate.deficit, 0);
      expect(atRate.buffer, 2);
    });

    test('exactly at target: deficit 0, and buffer is days until the OLDEST '
        'success ages out — 0 when it sits on the window edge', () {
      // Successes on d(2) (the window start), d(4), d(6).
      final leaf = leafFor({d(2): 1, d(4): 1, d(6): 1});
      expect(leaf.deficit, 0);
      expect(leaf.satisfied, isTrue);
      expect(leaf.buffer, 0, reason: 'the d(2) success ages out tonight');
    });

    test('exactly at target with the oldest success two days into the '
        'window: buffer 2', () {
      final leaf = leafFor({d(4): 1, d(6): 1, d(8): 1});
      expect(leaf.deficit, 0);
      expect(leaf.buffer, 2, reason: 'd(4) is two days past the d(2) edge');
    });

    test(
      'above target computes a LARGER buffer — losing the oldest still '
      'leaves it satisfied; the count drops when the critical success ages',
      () {
        // Four successes, target 3. Losing d(2) still leaves 3; the count drops
        // below target when d(4) — the critical (creditable - target)-th oldest
        // — ages out, two days from the d(2) edge.
        final leaf = leafFor({d(2): 1, d(4): 1, d(6): 1, d(8): 1});
        expect(leaf.deficit, 0);
        expect(leaf.buffer, 2);
      },
    );

    test('recovery days SIMULATE the sliding window — an old success at the '
        'left edge is not worth one day of recovery', () {
      // target 3, successes on the window-start day d(2) and yesterday d(7):
      // succeeding tomorrow ages d(2) out, so the count stays 2, not 3. Two
      // days of perfect adherence are needed, not the static one.
      final leaf = leafFor({d(2): 1, d(7): 1});
      expect(leaf.actual, 2);
      expect(leaf.deficit, 2);
    });

    test('multiple completions on one day are ONE creditable day', () {
      // Rolling counts days, not raw completions (unlike the calendar path).
      final leaf = leafFor({d(3): 2, d(5): 1});
      expect(leaf.actual, 2);
      expect(leaf.deficit, 1);
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

    test('an allOf routine of rolling habits aggregates the hints: worst '
        'child deficit, and — only when every child is at rate — the first '
        'buffer to run out', () {
      GoalSignalWindow world(Map<String, Map<DateTime, int>> byHabit) =>
          GoalSignalWindow(habitSuccessesByDay: byHabit);
      const routine = GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'a',
            habitId: 'a-habit',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
          GoalCriterion.habit(
            criterionId: 'b',
            habitId: 'b-habit',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
        ],
      );

      // A behind: deficit 1 (2 of 3). B at rate: deficit 0, buffer 2. The
      // routine takes the WORST deficit and NO buffer (a child is behind).
      final behind = evaluator.evaluate(
        routine,
        world({
          'a-habit': {d(4): 1, d(6): 1},
          'b-habit': {d(4): 1, d(6): 1, d(8): 1},
        }),
        saturday,
      );
      expect(behind.deficit, 1);
      expect(behind.buffer, isNull);

      // Both at rate: A buffer 2 (d(4)), B buffer 0 (d(2) edge). The routine
      // loses rate when the FIRST runs out → buffer 0.
      final atRate = evaluator.evaluate(
        routine,
        world({
          'a-habit': {d(4): 1, d(6): 1, d(8): 1},
          'b-habit': {d(2): 1, d(4): 1, d(6): 1},
        }),
        saturday,
      );
      expect(atRate.deficit, 0);
      expect(atRate.buffer, 0);
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

    test('a rolling habit leaf contributes its recent slice — three strong '
        'recent days read as a full turnaround', () {
      const gym = GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 7, // every day over the trailing week
      );
      final signals = GoalSignalWindow(
        habitSuccessesByDay: {
          'gym-habit': {d(6): 1, d(7): 1, d(8): 1},
        },
      );
      // shortTarget = 7 * 3 / 7 = 3; three creditable days → 1.0.
      expect(evaluator.shortTermAttainment(gym, signals, saturday), 1.0);
    });

    test('a calendar-week habit still has no short-term slice', () {
      const gym = GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 3,
      );
      final signals = GoalSignalWindow(
        habitSuccessesByDay: {
          'gym-habit': {d(8): 1},
        },
      );
      expect(evaluator.shortTermAttainment(gym, signals, saturday), isNull);
    });
  });

  group('evaluation properties', () {
    // A goal at least zero with a negative aggregate (a measurable can go
    // below zero) is not met — and must not read as fully attained either.
    test('an unmet at-least-zero target is not reported as attained', () {
      const criterion = GoalCriterion.measurable(
        criterionId: 'balance',
        dataTypeId: 'balance-type',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        target: 0,
      );
      final evaluation = evaluator.evaluate(
        criterion,
        GoalSignalWindow(
          measurableDailySums: {
            'balance-type': {saturday: -3},
          },
        ),
        saturday,
      );
      expect(evaluation.satisfied, isFalse);
      expect(evaluation.attainment, 0);
    });

    glados.Glados(
      glados.any.goalTree,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'ratios and coverage stay in [0, 1] and a met criterion is fully met',
      (tree) {
        final evaluation = evaluator.evaluate(
          tree.criterion,
          tree.signals(),
          saturday,
        );

        expect(evaluation.attainment, inInclusiveRange(0, 1));
        expect(evaluation.dataCoverage, inInclusiveRange(0, 1));
        for (final result in evaluation.results.values) {
          expect(result.ratio, inInclusiveRange(0, 1), reason: '$result');
          // Met and fully attained are the same statement.
          expect(
            result.ratio == 1,
            result.satisfied,
            reason:
                '${result.criterionId}: ${result.actual} vs '
                '${result.target}, ratio ${result.ratio}',
          );
        }
        final short = evaluator.shortTermAttainment(
          tree.criterion,
          tree.signals(),
          saturday,
        );
        if (short != null) expect(short, inInclusiveRange(0, 1));
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.goalTree,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'a composite is met exactly when its children say so',
      (tree) {
        final evaluation = evaluator.evaluate(
          tree.criterion,
          tree.signals(),
          saturday,
        );
        final met = [
          for (final leaf in tree.leaves)
            evaluation.results[leaf.id]!.satisfied,
        ];
        final metCount = met.where((m) => m).length;

        expect(evaluation.satisfied, switch (tree.criterion) {
          GoalCriterionAllOf() => metCount == met.length,
          GoalCriterionAnyOf() => metCount > 0,
          GoalCriterionAtLeastCount(:final successes) => metCount >= successes,
          _ => met.single,
        });
        for (final leaf in tree.leaves) {
          if (leaf.isMeasurable && leaf.series.isEmpty) {
            expect(evaluation.results[leaf.id]!.satisfied, isFalse);
            expect(evaluation.results[leaf.id]!.ratio, 0);
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.goalTree,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'the order signals were recorded in does not matter',
      (tree) {
        final forward = evaluator.evaluate(
          tree.criterion,
          tree.signals(),
          saturday,
        );
        final reversed = evaluator.evaluate(
          tree.criterion,
          tree.signals(reversed: true),
          saturday,
        );

        expect(reversed.attainment, forward.attainment);
        expect(reversed.satisfied, forward.satisfied);
        expect(reversed.dataCoverage, forward.dataCoverage);
        Map<String, Object?> fields(GoalEvaluation e) => e.results.map(
          (id, r) => MapEntry(id, [
            r.actual,
            r.target,
            r.ratio,
            r.satisfied,
            r.sampleCount,
            r.paceFeasible,
            r.deficit,
            r.buffer,
            r.projectedDaysToTarget,
          ]),
        );
        expect(fields(reversed), fields(forward));
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.goalLeaf,
      glados.IntAnys(glados.any).intInRange(0, 10),
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'raising the values never hurts an at-least goal nor helps an at-most one',
      (leaf, bump) {
        final measurable = leaf.asMeasurable;
        final tree = _GoalTree(3, [measurable], 1);
        final raised = _GoalTree(3, [measurable.raisedBy(bump)], 1);
        final before = evaluator.evaluate(
          tree.criterion,
          tree.signals(),
          saturday,
        );
        final after = evaluator.evaluate(
          raised.criterion,
          raised.signals(),
          saturday,
        );

        if (measurable.direction == GoalDirection.atLeast) {
          expect(after.attainment, greaterThanOrEqualTo(before.attainment));
          if (before.satisfied) expect(after.satisfied, isTrue);
        } else {
          expect(after.attainment, lessThanOrEqualTo(before.attainment));
          if (after.satisfied) expect(before.satisfied, isTrue);
        }
      },
      tags: 'glados',
    );
  });
}

/// One generated leaf: a measurable (or a habit when [isMeasurable] is false)
/// reading series `m<i>` / `h<i>` in days before 2026-08-08.
class _GoalLeaf {
  const _GoalLeaf({
    required this.index,
    required this.isMeasurable,
    required this.aggregation,
    required this.direction,
    required this.target,
    required this.window,
    required this.series,
  });

  final int index;
  final bool isMeasurable;
  final GoalAggregation aggregation;
  final GoalDirection direction;
  final int target;
  final GoalWindow window;

  /// Days before the reference → value.
  final Map<int, int> series;

  String get id => 'c$index';

  _GoalLeaf withIndex(int i) => _GoalLeaf(
    index: i,
    isMeasurable: isMeasurable,
    aggregation: aggregation,
    direction: direction,
    target: target,
    window: window,
    series: series,
  );

  _GoalLeaf get asMeasurable => _GoalLeaf(
    index: index,
    isMeasurable: true,
    aggregation: aggregation,
    direction: direction,
    target: target,
    window: window,
    series: series,
  );

  _GoalLeaf raisedBy(int bump) => _GoalLeaf(
    index: index,
    isMeasurable: isMeasurable,
    aggregation: aggregation,
    direction: direction,
    target: target,
    window: window,
    series: series.map((day, value) => MapEntry(day, value + bump)),
  );

  GoalCriterion get criterion => isMeasurable
      ? GoalCriterion.measurable(
          criterionId: id,
          dataTypeId: 'm$index',
          window: window,
          aggregation: aggregation,
          target: target,
          direction: direction,
        )
      : GoalCriterion.habit(
          criterionId: id,
          habitId: 'h$index',
          window: window,
          targetCount: target % 8,
        );

  @override
  String toString() => '$criterion $series';
}

/// A leaf (kind 3) or a composite of kind 0 allOf, 1 anyOf, 2 atLeastCount.
class _GoalTree {
  _GoalTree(this.kind, List<_GoalLeaf> leaves, int successes)
    : leaves = [
        for (final (i, leaf) in leaves.take(kind == 3 ? 1 : 4).indexed)
          leaf.withIndex(i),
      ],
      successes = 1 + (successes - 1) % leaves.length;

  final int kind;
  final List<_GoalLeaf> leaves;
  final int successes;

  GoalCriterion get criterion {
    final children = [for (final leaf in leaves) leaf.criterion];
    return switch (kind) {
      0 => GoalCriterion.allOf(criterionId: 'root', criteria: children),
      1 => GoalCriterion.anyOf(criterionId: 'root', criteria: children),
      2 => GoalCriterion.atLeastCount(
        criterionId: 'root',
        criteria: children,
        successes: successes,
      ),
      _ => children.first,
    };
  }

  GoalSignalWindow signals({bool reversed = false}) {
    Map<DateTime, T> byDay<T>(_GoalLeaf leaf, T Function(int) value) {
      final entries = [
        for (final MapEntry(:key, value: v) in leaf.series.entries)
          MapEntry(
            DateTime.utc(2026, 8, 8).subtract(Duration(days: key)),
            value(v),
          ),
      ];
      return Map.fromEntries(reversed ? entries.reversed : entries);
    }

    final measurables = [
      for (final leaf in leaves)
        if (leaf.isMeasurable)
          MapEntry('m${leaf.index}', byDay(leaf, (v) => v)),
    ];
    final habits = [
      for (final leaf in leaves)
        if (!leaf.isMeasurable)
          MapEntry('h${leaf.index}', byDay(leaf, (v) => v.abs() % 3)),
    ];
    return GoalSignalWindow(
      measurableDailySums: Map.fromEntries(
        reversed ? measurables.reversed : measurables,
      ),
      habitSuccessesByDay: Map.fromEntries(
        reversed ? habits.reversed : habits,
      ),
    );
  }

  @override
  String toString() => '_GoalTree($criterion, $leaves)';
}

extension _AnyGoalTree on glados.Any {
  glados.Generator<GoalWindow> get _evaluationWindow => glados.IntAnys(this)
      .intInRange(0, 13)
      .map(
        (seed) => switch (seed) {
          0 => const GoalWindow.day(),
          11 => const GoalWindow.calendarWeek(),
          12 => const GoalWindow.calendarMonth(),
          _ => GoalWindow.rollingDays(count: seed),
        },
      );

  glados.Generator<_GoalLeaf> get goalLeaf =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 4),
        glados.AnyUtils(this).choose(GoalAggregation.values),
        glados.AnyUtils(this).choose(GoalDirection.values),
        glados.IntAnys(this).intInRange(0, 21),
        _evaluationWindow,
        glados.ListAnys(this).listWithLengthInRange(
          0,
          10,
          glados.CombinableAny(this).combine2(
            glados.IntAnys(this).intInRange(0, 14),
            glados.IntAnys(this).intInRange(-5, 21),
            MapEntry<int, int>.new,
          ),
        ),
        (
          int kind,
          GoalAggregation aggregation,
          GoalDirection direction,
          int target,
          GoalWindow window,
          List<MapEntry<int, int>> series,
        ) => _GoalLeaf(
          index: 0,
          isMeasurable: kind < 3,
          aggregation: aggregation,
          direction: direction,
          target: target,
          window: window,
          series: Map.fromEntries(series),
        ),
      );

  glados.Generator<_GoalTree> get goalTree =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 4),
        glados.ListAnys(this).listWithLengthInRange(1, 5, goalLeaf),
        glados.IntAnys(this).intInRange(1, 5),
        _GoalTree.new,
      );
}
