import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/service/goal_revision_apply.dart';

void main() {
  const steps = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );
  const gym = GoalCriterion.habit(
    criterionId: 'gym',
    habitId: 'gym-habit',
    window: GoalWindow.calendarWeek(),
    targetCount: 3,
  );
  const water = GoalCriterion.measurable(
    criterionId: 'water',
    dataTypeId: 'water-id',
    window: GoalWindow.day(),
    aggregation: GoalAggregation.sum,
    target: 2000,
  );

  GoalRevisionApplied applied(GoalRevisionResult result) {
    expect(result, isA<GoalRevisionApplied>(), reason: '$result');
    return result as GoalRevisionApplied;
  }

  String rejected(GoalRevisionResult result) {
    expect(result, isA<GoalRevisionRejected>(), reason: '$result');
    return (result as GoalRevisionRejected).reason;
  }

  test('a target change on a single-leaf goal binds without naming it', () {
    final result = applied(
      applyGoalRevisionChanges(
        criteria: steps,
        changes: {'targetValue': 8000},
      ),
    );
    expect((result.criteria as GoalCriterionMetric).target, 8000);
    expect(result.changeSummaries, ['target: 10000 → 8000']);
  });

  test('inside a composite, the metric field disambiguates by criterionId '
      'or dataType — and only the named leaf changes', () {
    const composite = GoalCriterion.allOf(
      criterionId: 'fit',
      criteria: [steps, water, gym],
    );
    for (final metric in ['steps', 'CUMULATIVE_STEP_COUNT']) {
      final result = applied(
        applyGoalRevisionChanges(
          criteria: composite,
          changes: {'metric': metric, 'targetValue': 12000},
        ),
      );
      final revised = result.criteria as GoalCriterionAllOf;
      expect(
        (revised.criteria[0] as GoalCriterionMetric).target,
        12000,
      );
      expect((revised.criteria[1] as GoalCriterionMeasurable).target, 2000);
      expect((revised.criteria[2] as GoalCriterionHabit).targetCount, 3);
    }
  });

  test('two quantitative leaves and no metric name → rejected, never '
      'guessed', () {
    const composite = GoalCriterion.allOf(
      criterionId: 'fit',
      criteria: [steps, water],
    );
    expect(
      rejected(
        applyGoalRevisionChanges(
          criteria: composite,
          changes: {'targetValue': 12000},
        ),
      ),
      contains('does not identify a single measurable criterion'),
    );
  });

  test('period phrases parse the FACTS vocabulary; garbage is rejected', () {
    expect(parseGoalWindowPhrase('day'), const GoalWindow.day());
    expect(parseGoalWindowPhrase('daily'), const GoalWindow.day());
    expect(
      parseGoalWindowPhrase('Rolling 14 days'),
      const GoalWindow.rollingDays(count: 14),
    );
    expect(
      parseGoalWindowPhrase('calendar week (Mon-Sun)'),
      const GoalWindow.calendarWeek(),
    );
    expect(parseGoalWindowPhrase('monthly'), const GoalWindow.calendarMonth());
    expect(parseGoalWindowPhrase('fortnight'), isNull);

    final result = applied(
      applyGoalRevisionChanges(
        criteria: steps,
        changes: {'period': 'rolling 14 days'},
      ),
    );
    expect(
      (result.criteria as GoalCriterionMetric).window,
      const GoalWindow.rollingDays(count: 14),
    );
    expect(
      rejected(
        applyGoalRevisionChanges(
          criteria: steps,
          changes: {'period': 'fortnight'},
        ),
      ),
      contains('unrecognized period'),
    );
  });

  test('cadence binds to the single habit leaf and parses count phrases', () {
    const composite = GoalCriterion.allOf(
      criterionId: 'fit',
      criteria: [steps, gym],
    );
    for (final cadence in [4, '4', '4x', '4 times per week']) {
      final result = applied(
        applyGoalRevisionChanges(
          criteria: composite,
          changes: {'cadence': cadence},
        ),
      );
      final revised = result.criteria as GoalCriterionAllOf;
      expect((revised.criteria[1] as GoalCriterionHabit).targetCount, 4);
    }
    expect(
      rejected(
        applyGoalRevisionChanges(
          criteria: composite,
          changes: {'cadence': 'whenever'},
        ),
      ),
      contains('unrecognized cadence'),
    );
    expect(
      rejected(
        applyGoalRevisionChanges(criteria: steps, changes: {'cadence': 3}),
      ),
      contains('no habit criterion'),
    );
  });

  test('invalid target values are rejected; zero is legal (atMost-0 '
      'goals exist)', () {
    for (final bad in ['8000', -1, double.nan]) {
      expect(
        rejected(
          applyGoalRevisionChanges(
            criteria: steps,
            changes: {'targetValue': bad},
          ),
        ),
        contains('targetValue must be a non-negative number'),
      );
    }
    final zeroed = applied(
      applyGoalRevisionChanges(criteria: steps, changes: {'targetValue': 0}),
    );
    expect((zeroed.criteria as GoalCriterionMetric).target, 0);
  });

  test('a proposal restating the current values is a rejected no-op — it '
      'must not reset the grace history', () {
    expect(
      rejected(
        applyGoalRevisionChanges(
          criteria: steps,
          changes: {'targetValue': 10000},
        ),
      ),
      contains('restates the current criteria'),
    );
  });

  test('cadence strings with trailing garbage are rejected, not '
      'truncated', () {
    const composite = GoalCriterion.allOf(
      criterionId: 'fit',
      criteria: [steps, gym],
    );
    for (final bad in ['3.5', '3 bananas', '3x weekly-ish']) {
      expect(
        rejected(
          applyGoalRevisionChanges(
            criteria: composite,
            changes: {'cadence': bad},
          ),
        ),
        contains('unrecognized cadence'),
      );
    }
  });

  test('absurdly long digit runs reject instead of throwing', () {
    expect(
      parseGoalWindowPhrase('rolling 99999999999999999999999 days'),
      isNull,
    );
    const composite = GoalCriterion.allOf(
      criterionId: 'fit',
      criteria: [steps, gym],
    );
    expect(
      rejected(
        applyGoalRevisionChanges(
          criteria: composite,
          changes: {'cadence': '99999999999999999999999'},
        ),
      ),
      contains('unrecognized cadence'),
    );
  });

  test('successCriteria alone never rewrites the tree', () {
    expect(
      rejected(
        applyGoalRevisionChanges(
          criteria: steps,
          changes: {'successCriteria': 'just feel better about walking'},
        ),
      ),
      contains('no applicable structural change'),
    );
  });

  test('target and cadence apply together across a composite', () {
    const composite = GoalCriterion.atLeastCount(
      criterionId: 'two-of',
      successes: 2,
      criteria: [steps, gym, water],
    );
    final result = applied(
      applyGoalRevisionChanges(
        criteria: composite,
        changes: {'metric': 'steps', 'targetValue': 9000, 'cadence': 2},
      ),
    );
    final revised = result.criteria as GoalCriterionAtLeastCount;
    expect((revised.criteria[0] as GoalCriterionMetric).target, 9000);
    expect((revised.criteria[1] as GoalCriterionHabit).targetCount, 2);
    expect(result.changeSummaries, hasLength(2));
  });

  test('a measurable leaf takes target and period changes too', () {
    final result =
        applyGoalRevisionChanges(
              criteria: water,
              changes: {'targetValue': 2500, 'period': 'rolling 3 days'},
            )
            as GoalRevisionApplied;
    final revised = result.criteria as GoalCriterionMeasurable;
    expect(revised.target, 2500);
    expect(revised.window, const GoalWindow.rollingDays(count: 3));
  });

  test(
    'category time takes target and period changes and binds by category',
    () {
      const categoryTime = GoalCriterion.categoryTime(
        criterionId: 'late-coding',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 0,
        dailyTimeRange: GoalDailyTimeRange(
          startMinute: 21 * 60 + 30,
          endMinute: 7 * 60,
        ),
      );
      const composite = GoalCriterion.allOf(
        criterionId: 'detox',
        criteria: [steps, categoryTime],
      );

      final result = applied(
        applyGoalRevisionChanges(
          criteria: composite,
          changes: {
            'metric': 'vibe-coding',
            'targetValue': 1.5,
            'period': 'rolling 14 days',
          },
        ),
      );
      final revised = result.criteria as GoalCriterionAllOf;
      final time = revised.criteria.last as GoalCriterionCategoryTime;
      expect(time.targetHours, 1.5);
      expect(time.window, const GoalWindow.rollingDays(count: 14));
      expect(
        time.dailyTimeRange,
        const GoalDailyTimeRange(
          startMinute: 21 * 60 + 30,
          endMinute: 7 * 60,
        ),
        reason: 'changing the cap must preserve the authored daily band',
      );
      expect((revised.criteria.first as GoalCriterionMetric).target, 10000);
    },
  );

  test('label time takes target and period changes and binds by category', () {
    const labelTime = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      categoryId: 'work',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );
    const composite = GoalCriterion.allOf(
      criterionId: 'creative-day',
      criteria: [steps, labelTime],
    );

    final result = applied(
      applyGoalRevisionChanges(
        criteria: composite,
        changes: {
          'metric': 'work',
          'targetValue': 1.5,
          'period': 'rolling 3 days',
        },
      ),
    );
    final revised = result.criteria as GoalCriterionAllOf;
    final time = revised.criteria.last as GoalCriterionLabelTime;

    expect(time.targetHours, 1.5);
    expect(time.categoryId, 'work');
    expect(time.window, const GoalWindow.rollingDays(count: 3));
    expect((revised.criteria.first as GoalCriterionMetric).target, 10000);
  });

  test('a label-time sibling does not make habit cadence ambiguous', () {
    const labelTime = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );
    const composite = GoalCriterion.allOf(
      criterionId: 'balanced-day',
      criteria: [gym, labelTime],
    );

    final result = applied(
      applyGoalRevisionChanges(
        criteria: composite,
        changes: {'cadence': 2},
      ),
    );
    final revised = result.criteria as GoalCriterionAllOf;

    expect((revised.criteria.first as GoalCriterionHabit).targetCount, 2);
    expect(revised.criteria.last, labelTime);
  });

  test('two habit leaves make a cadence change ambiguous — rejected', () {
    const twoGyms = GoalCriterion.anyOf(
      criterionId: 'either-gym',
      criteria: [
        gym,
        GoalCriterion.habit(
          criterionId: 'home-gym',
          habitId: 'home-gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 2,
        ),
      ],
    );
    final result = applyGoalRevisionChanges(
      criteria: twoGyms,
      changes: {'cadence': 4},
    );
    expect(
      (result as GoalRevisionRejected).reason,
      contains('2 habit criteria'),
    );
  });

  test('the rewrite recurses through anyOf composites', () {
    const nested = GoalCriterion.anyOf(
      criterionId: 'either',
      criteria: [steps],
    );
    final result =
        applyGoalRevisionChanges(
              criteria: nested,
              changes: {'targetValue': 9000},
            )
            as GoalRevisionApplied;
    final revised = result.criteria as GoalCriterionAnyOf;
    expect((revised.criteria.single as GoalCriterionMetric).target, 9000);
  });

  test('a cadence beyond the window capacity is rejected — one success '
      'per day is the observable maximum', () {
    const weekly = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.calendarWeek(),
      targetCount: 3,
    );
    final outcome = applyGoalRevisionChanges(
      criteria: weekly,
      changes: {'cadence': '8 times per week'},
    );
    expect(
      (outcome as GoalRevisionRejected).reason,
      contains('exceeds the window capacity of 7'),
    );

    // The bound is the window's, not a constant: rolling 10 days takes 8.
    const rolling = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.rollingDays(count: 10),
      targetCount: 3,
    );
    final ok = applyGoalRevisionChanges(
      criteria: rolling,
      changes: {'cadence': 8},
    );
    expect(ok, isA<GoalRevisionApplied>());
  });

  test('a multi-habit routine binds a cadence change through the metric '
      'identifier; without one it stays rejected', () {
    const routine = GoalCriterion.allOf(
      criterionId: 'routine',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'habit-gym',
          habitId: 'gym-id',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        GoalCriterion.habit(
          criterionId: 'habit-run',
          habitId: 'run-id',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
      ],
    );

    final resolved = applyGoalRevisionChanges(
      criteria: routine,
      changes: {'cadence': 4, 'metric': 'habit-run'},
    );
    final revised = (resolved as GoalRevisionApplied).criteria;
    final leaves = (revised as GoalCriterionAllOf).criteria
        .whereType<GoalCriterionHabit>()
        .toList();
    expect(
      leaves.singleWhere((h) => h.criterionId == 'habit-run').targetCount,
      4,
    );
    expect(
      leaves.singleWhere((h) => h.criterionId == 'habit-gym').targetCount,
      3,
      reason: 'only the identified habit changes',
    );

    // habitId works as the identifier too.
    expect(
      applyGoalRevisionChanges(
        criteria: routine,
        changes: {'cadence': 4, 'metric': 'gym-id'},
      ),
      isA<GoalRevisionApplied>(),
    );

    final ambiguous = applyGoalRevisionChanges(
      criteria: routine,
      changes: {'cadence': 4},
    );
    expect(
      (ambiguous as GoalRevisionRejected).reason,
      contains('must identify which one'),
    );
  });

  test('a cadence naming a unit other than the habit window is rejected — '
      '"per month" must not silently apply weekly', () {
    const weekly = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.calendarWeek(),
      targetCount: 3,
    );
    final mismatch = applyGoalRevisionChanges(
      criteria: weekly,
      changes: {'cadence': '3 times per month'},
    );
    expect(
      (mismatch as GoalRevisionRejected).reason,
      contains('names "per month" but the habit is evaluated per week'),
    );

    // A matching unit and a bare count both pass.
    expect(
      applyGoalRevisionChanges(
        criteria: weekly,
        changes: {'cadence': '4 times per week'},
      ),
      isA<GoalRevisionApplied>(),
    );
    expect(
      applyGoalRevisionChanges(criteria: weekly, changes: {'cadence': 4}),
      isA<GoalRevisionApplied>(),
    );
  });

  test('a cadence naming "month" binds against a calendar-month habit; '
      'naming any other unit is rejected', () {
    const monthly = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.calendarMonth(),
      targetCount: 8,
    );
    final matched = applied(
      applyGoalRevisionChanges(
        criteria: monthly,
        changes: {'cadence': '3 times per month'},
      ),
    );
    expect((matched.criteria as GoalCriterionHabit).targetCount, 3);

    final mismatch = applyGoalRevisionChanges(
      criteria: monthly,
      changes: {'cadence': '3 times per week'},
    );
    expect(
      (mismatch as GoalRevisionRejected).reason,
      contains('names "per week" but the habit is evaluated per month'),
    );
  });

  test('a cadence naming a unit against a rolling-days habit is rejected '
      'with "per rolling window", not a phantom unit name', () {
    const rolling = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.rollingDays(count: 10),
      targetCount: 3,
    );
    final outcome = applyGoalRevisionChanges(
      criteria: rolling,
      changes: {'cadence': '3 times per week'},
    );
    expect(
      (outcome as GoalRevisionRejected).reason,
      contains(
        'names "per week" but the habit is evaluated per rolling '
        'window',
      ),
    );
  });

  test('a calendar-month habit caps cadence at 28 — the guaranteed minimum '
      'so the goal never wedges in February', () {
    const monthly = GoalCriterion.habit(
      criterionId: 'gym',
      habitId: 'gym-habit',
      window: GoalWindow.calendarMonth(),
      targetCount: 3,
    );
    final tooMany = applyGoalRevisionChanges(
      criteria: monthly,
      changes: {'cadence': 29},
    );
    expect(
      (tooMany as GoalRevisionRejected).reason,
      contains('exceeds the window capacity of 28'),
    );

    final atBoundary = applyGoalRevisionChanges(
      criteria: monthly,
      changes: {'cadence': 28},
    );
    expect(atBoundary, isA<GoalRevisionApplied>());
    expect(
      (atBoundary as GoalRevisionApplied).criteria as GoalCriterionHabit,
      isA<GoalCriterionHabit>(),
    );
    expect((atBoundary.criteria as GoalCriterionHabit).targetCount, 28);
  });

  test('an absurd rolling window is rejected at the parse boundary — an '
      'approved 1e9-day window would wedge every later evaluation', () {
    const steps = GoalCriterion.metric(
      criterionId: 'steps',
      dataType: 'cumulative_step_count',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 10000,
    );
    final outcome = applyGoalRevisionChanges(
      criteria: steps,
      changes: {'period': 'rolling 1000000000 days'},
    );
    expect(
      (outcome as GoalRevisionRejected).reason,
      contains('unrecognized period'),
    );
    expect(parseGoalWindowPhrase('rolling 3650 days'), isNotNull);
    expect(parseGoalWindowPhrase('rolling 3651 days'), isNull);
  });
}
