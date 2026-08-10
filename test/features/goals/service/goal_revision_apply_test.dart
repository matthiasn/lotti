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
}
