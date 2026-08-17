import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/workflow/goal_agent_workflow.dart';

/// The aggregates a report's rolling standing is held to. The rule is narrow
/// on purpose: only metric leaves carry a mean worth quoting, and only when
/// the window actually holds observations.
void main() {
  GoalCriterion metric(String id, {num target = 100}) => GoalCriterion.metric(
    criterionId: id,
    dataType: 'cumulative_step_count',
    window: const GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: target,
  );

  GoalCriterionResult result(
    String id, {
    required num actual,
    int sampleCount = 3,
    num target = 100,
  }) => GoalCriterionResult(
    criterionId: id,
    actual: actual,
    target: target,
    ratio: 1,
    satisfied: true,
    sampleCount: sampleCount,
  );

  test('a metric leaf contributes its pre-rounded aggregate', () {
    // Quantised the same way the dimension card's headline is, so the report
    // cannot quote a precision the card above it never showed: 9482.4 renders
    // as 9500, and that is the string FACTS carry.
    expect(
      goalRollingAggregateStrings(metric('steps'), {
        'steps': result('steps', actual: 9482.4, target: 10000),
      }),
      ['9500'],
    );
  });

  test('every composite shape is walked to its metric leaves', () {
    final results = {
      'a': result('a', actual: 12),
      'b': result('b', actual: 34),
      'c': result('c', actual: 56),
    };
    for (final tree in [
      GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          metric('a'),
          GoalCriterion.anyOf(criterionId: 'inner', criteria: [metric('b')]),
        ],
      ),
      GoalCriterion.anyOf(
        criterionId: 'root',
        criteria: [
          metric('a'),
          GoalCriterion.atLeastCount(
            criterionId: 'inner',
            successes: 1,
            criteria: [metric('b')],
          ),
        ],
      ),
      GoalCriterion.atLeastCount(
        criterionId: 'root',
        successes: 1,
        criteria: [metric('a'), metric('b')],
      ),
    ]) {
      expect(
        goalRollingAggregateStrings(tree, results)..sort(),
        ['12', '34'],
        reason: 'nested composites must not hide a metric leaf',
      );
    }
  });

  test('non-metric leaves contribute nothing', () {
    // A habit's `actual` is a completion count and a composite's is a count of
    // satisfied children. Requiring those would match any stray digit in the
    // sentence rather than prove the aggregate was read.
    // Every non-metric leaf shape, so a new variant cannot slip in unnoticed.
    final tree = GoalCriterion.allOf(
      criterionId: 'root',
      criteria: [
        const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        const GoalCriterion.measurable(
          criterionId: 'mood',
          dataTypeId: 'mood-scale',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 4,
        ),
        const GoalCriterion.categoryTime(
          criterionId: 'deep-work',
          categoryId: 'category-1',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          targetHours: 2,
        ),
        const GoalCriterion.labelTime(
          criterionId: 'admin',
          labelId: 'label-1',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          targetHours: 1,
        ),
        metric('steps'),
      ],
    );
    expect(
      goalRollingAggregateStrings(tree, {
        'gym': result('gym', actual: 2),
        'mood': result('mood', actual: 3),
        'deep-work': result('deep-work', actual: 5),
        'admin': result('admin', actual: 7),
        'steps': result('steps', actual: 88),
        'root': result('root', actual: 1),
      }),
      ['88'],
    );
  });

  test('an empty window is skipped rather than demanding a number', () {
    // insufficientData reports name the gap; requiring a mean over zero
    // observations would force the model to invent one.
    expect(
      goalRollingAggregateStrings(metric('steps'), {
        'steps': result('steps', actual: 0, sampleCount: 0),
      }),
      isEmpty,
    );
  });

  test('a criterion absent from the results contributes nothing', () {
    expect(goalRollingAggregateStrings(metric('steps'), const {}), isEmpty);
  });
}
