import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/workflow/goal_criterion_names.dart';

void main() {
  test('collects every habit and measurable id under a composite tree, '
      'once each, and nothing from the other leaf kinds', () {
    const tree = GoalCriterion.allOf(
      criterionId: 'all',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'gym',
          habitId: '71ca84b0-1f1e-4f5d-9c2e-6b4a1d0c9e01',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        GoalCriterion.anyOf(
          criterionId: 'either',
          criteria: [
            GoalCriterion.measurable(
              criterionId: 'water',
              dataTypeId: '0d2f9b6a-3c4e-4a1b-8e7d-5f6a7b8c9d0e',
              window: GoalWindow.day(),
              aggregation: GoalAggregation.sum,
              target: 2000,
            ),
            GoalCriterion.atLeastCount(
              criterionId: 'two',
              successes: 1,
              criteria: [
                // The same habit again: a set, not a list.
                GoalCriterion.habit(
                  criterionId: 'gym-again',
                  habitId: '71ca84b0-1f1e-4f5d-9c2e-6b4a1d0c9e01',
                  window: GoalWindow.day(),
                  targetCount: 1,
                ),
                GoalCriterion.metric(
                  criterionId: 'steps',
                  dataType: 'cumulative_step_count',
                  window: GoalWindow.day(),
                  aggregation: GoalAggregation.sum,
                  target: 1,
                ),
                GoalCriterion.categoryTime(
                  criterionId: 'coding',
                  categoryId: 'coding-category',
                  window: GoalWindow.day(),
                  aggregation: GoalAggregation.sum,
                  targetHours: 1,
                ),
                GoalCriterion.labelTime(
                  criterionId: 'deep',
                  labelId: 'deep-label',
                  window: GoalWindow.day(),
                  aggregation: GoalAggregation.sum,
                  targetHours: 1,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final ids = goalCriterionEntityIds(tree);
    expect(ids.habitIds, {'71ca84b0-1f1e-4f5d-9c2e-6b4a1d0c9e01'});
    expect(ids.dataTypeIds, {'0d2f9b6a-3c4e-4a1b-8e7d-5f6a7b8c9d0e'});
  });

  test('a tree without user-defined entities yields empty sets', () {
    const tree = GoalCriterion.metric(
      criterionId: 'steps',
      dataType: 'cumulative_step_count',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 10000,
    );
    final ids = goalCriterionEntityIds(tree);
    expect(ids.habitIds, isEmpty);
    expect(ids.dataTypeIds, isEmpty);
  });
}
