import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/ui/pages/goal_form_mapping.dart';

void main() {
  test(
    'round-trips a mixed observable goal without flattening habit targets',
    () {
      const criteria = GoalCriterion.allOf(
        criterionId: 'routine-v3',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'steps-v3',
            dataType: 'cumulative_step_count',
            title: 'Average steps per day',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 8500,
          ),
          GoalCriterion.habit(
            criterionId: 'gym-v3',
            habitId: 'gym',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
          GoalCriterion.habit(
            criterionId: 'run-v3',
            habitId: 'run',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 5,
          ),
        ],
      );

      final draft = GoalFormMapping.fromCriteria(criteria);

      expect(draft.isEditable, isTrue);
      expect(draft.watchesSteps, isTrue);
      expect(draft.stepsTarget, 8500);
      expect(draft.habitTargets, {'gym': 2, 'run': 5});
      expect(
        draft.buildCriteria(
          stepsTitle: 'Average steps per day',
          habitTargets: {'gym': 3, 'run': 6},
        ),
        const GoalCriterion.allOf(
          criterionId: 'routine-v3',
          criteria: [
            GoalCriterion.metric(
              criterionId: 'steps-v3',
              dataType: 'cumulative_step_count',
              title: 'Average steps per day',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.dailySumThenAverage,
              target: 8500,
            ),
            GoalCriterion.habit(
              criterionId: 'gym-v3',
              habitId: 'gym',
              window: GoalWindow.rollingDays(count: 7),
              targetCount: 3,
            ),
            GoalCriterion.habit(
              criterionId: 'run-v3',
              habitId: 'run',
              window: GoalWindow.rollingDays(count: 7),
              targetCount: 6,
            ),
          ],
        ),
      );
    },
  );

  test('new habits receive stable leaf ids and retain their own counts', () {
    const draft = GoalFormMapping.empty();

    expect(
      draft.buildCriteria(
        stepsTitle: 'Average steps per day',
        habitTargets: {'gym': 2, 'morning': 5},
      ),
      const GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'habit-gym',
            habitId: 'gym',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
          GoalCriterion.habit(
            criterionId: 'habit-morning',
            habitId: 'morning',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 5,
          ),
        ],
      ),
    );
  });

  test('an unsupported criterion is preserved and cannot be flattened', () {
    const criteria = GoalCriterion.anyOf(
      criterionId: 'flexible',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym',
          window: GoalWindow.calendarWeek(),
          targetCount: 2,
        ),
        GoalCriterion.metric(
          criterionId: 'distance',
          dataType: 'walking_distance',
          window: GoalWindow.calendarWeek(),
          aggregation: GoalAggregation.sum,
          target: 20,
        ),
      ],
    );

    final draft = GoalFormMapping.fromCriteria(criteria);

    expect(draft.isEditable, isFalse);
    expect(
      draft.buildCriteria(
        stepsTitle: 'Average steps per day',
        habitTargets: const {},
      ),
      criteria,
    );
  });

  test(
    'an at-most steps criterion stays read-only and preserves direction',
    () {
      const criteria = GoalCriterion.metric(
        criterionId: 'steps-cap',
        dataType: 'cumulative_step_count',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 12000,
        direction: GoalDirection.atMost,
      );

      final draft = GoalFormMapping.fromCriteria(criteria);

      expect(draft.isEditable, isFalse);
      expect(
        draft.buildCriteria(
          stepsTitle: 'Average steps per day',
          habitTargets: const {},
        ),
        criteria,
      );
    },
  );

  test('a composite added around a routine leaf receives a distinct id', () {
    const criteria = GoalCriterion.habit(
      criterionId: 'routine',
      habitId: 'gym',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 2,
    );

    final draft = GoalFormMapping.fromCriteria(criteria);
    final rebuilt =
        draft.buildCriteria(
              stepsTitle: 'Average steps per day',
              habitTargets: const {'gym': 2, 'run': 3},
            )!
            as GoalCriterionAllOf;

    expect(rebuilt.criterionId, isNot('routine'));
    expect(
      rebuilt.criteria.map((criterion) => criterion.criterionId).toSet(),
      contains('routine'),
    );
    expect(
      {
        rebuilt.criterionId,
        ...rebuilt.criteria.map((criterion) => criterion.criterionId),
      },
      hasLength(rebuilt.criteria.length + 1),
    );
  });
}
