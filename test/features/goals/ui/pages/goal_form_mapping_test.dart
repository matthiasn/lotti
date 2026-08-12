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

  test('a habit target above the form range stays losslessly read-only', () {
    const criteria = GoalCriterion.habit(
      criterionId: 'habit-gym',
      habitId: 'gym',
      title: 'Legacy strength target',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 8,
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

  test('a non-positive steps target stays losslessly read-only', () {
    const criteria = GoalCriterion.metric(
      criterionId: 'steps-zero',
      dataType: 'cumulative_step_count',
      title: 'Legacy zero target',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 0,
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

  test('new leaves avoid every id reserved by the loaded criterion tree', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'routine',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'habit-run',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 2,
        ),
        GoalCriterion.habit(
          criterionId: 'habit-run-2',
          habitId: 'swim',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 4,
        ),
      ],
    );

    final draft = GoalFormMapping.fromCriteria(criteria);
    final rebuilt =
        draft.buildCriteria(
              stepsTitle: 'Average steps per day',
              habitTargets: const {'gym': 2, 'swim': 4, 'run': 3},
            )!
            as GoalCriterionAllOf;

    expect(
      rebuilt.criteria.map((criterion) => criterion.criterionId),
      ['habit-run', 'habit-run-2', 'habit-run-3'],
    );
    expect(
      {
        rebuilt.criterionId,
        ...rebuilt.criteria.map((criterion) => criterion.criterionId),
      },
      hasLength(rebuilt.criteria.length + 1),
    );
  });

  test('a newly added steps leaf avoids ids reserved by habits', () {
    const criteria = GoalCriterion.habit(
      criterionId: 'steps',
      habitId: 'gym',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 2,
    );

    final rebuilt =
        GoalFormMapping.fromCriteria(criteria).buildCriteria(
              stepsTitle: 'Average steps per day',
              habitTargets: const {'gym': 2},
              watchesSteps: true,
            )!
            as GoalCriterionAllOf;

    expect(
      rebuilt.criteria.map((criterion) => criterion.criterionId),
      ['steps', 'steps-2'],
    );
    expect(
      (rebuilt.criteria.last as GoalCriterionMetric).title,
      'Average steps per day',
    );
  });

  test('a loaded single-child all-of retains its wrapper and title', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'authored-wrapper',
      title: 'Every part matters',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'habit-gym',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 2,
        ),
      ],
    );

    final rebuilt = GoalFormMapping.fromCriteria(criteria).buildCriteria(
      stepsTitle: 'Average steps per day',
      habitTargets: const {'gym': 2},
    );

    expect(rebuilt, criteria);
  });

  test('an existing steps leaf retains its stored title', () {
    const criteria = GoalCriterion.metric(
      criterionId: 'steps',
      dataType: 'cumulative_step_count',
      title: 'My authored step target',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 9000,
    );

    final rebuilt = GoalFormMapping.fromCriteria(criteria).buildCriteria(
      stepsTitle: 'Localized default title',
      habitTargets: const {},
      stepsTarget: 10000,
    );

    expect(
      rebuilt,
      const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'cumulative_step_count',
        title: 'My authored step target',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 10000,
      ),
    );
  });

  test('existing habit leaves retain authored titles', () {
    const criteria = GoalCriterion.habit(
      criterionId: 'habit-gym',
      habitId: 'gym',
      title: 'Strength practice',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 2,
    );

    final rebuilt = GoalFormMapping.fromCriteria(criteria).buildCriteria(
      stepsTitle: 'Average steps per day',
      habitTargets: const {'gym': 3},
    );

    expect(
      rebuilt,
      const GoalCriterion.habit(
        criterionId: 'habit-gym',
        habitId: 'gym',
        title: 'Strength practice',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 3,
      ),
    );
  });

  test('an editable mixed tree retains its authored leaf order', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'routine',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'habit-gym',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 2,
        ),
        GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 9000,
        ),
      ],
    );

    final rebuilt = GoalFormMapping.fromCriteria(criteria).buildCriteria(
      stepsTitle: 'Average steps per day',
      habitTargets: const {'gym': 2},
    );

    expect(rebuilt, criteria);
  });

  test('round-trips measurable dimensions and their composite rule', () {
    const criteria = GoalCriterion.anyOf(
      criterionId: 'reading-flex',
      criteria: [
        GoalCriterion.measurable(
          criterionId: 'pages',
          dataTypeId: 'pages-read',
          title: 'Pages read',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          target: 60,
        ),
        GoalCriterion.habit(
          criterionId: 'library',
          habitId: 'visit-library',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 1,
        ),
      ],
    );

    final draft = GoalFormMapping.fromCriteria(criteria);

    expect(draft.isEditable, isTrue);
    expect(draft.measurableTargets, {'pages-read': 60});
    expect(draft.compositeRule, GoalFormCompositeRule.any);
    expect(
      draft.buildCriteria(
        stepsTitle: 'Steps',
        habitTargets: const {'visit-library': 1},
        measurableTargets: const {'pages-read': 75},
      ),
      const GoalCriterion.anyOf(
        criterionId: 'reading-flex',
        criteria: [
          GoalCriterion.measurable(
            criterionId: 'pages',
            dataTypeId: 'pages-read',
            title: 'Pages read',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.sum,
            target: 75,
          ),
          GoalCriterion.habit(
            criterionId: 'library',
            habitId: 'visit-library',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 1,
          ),
        ],
      ),
    );
  });

  test('builds an at-least-N rule for newly selected dimensions', () {
    const draft = GoalFormMapping.empty();

    final rebuilt = draft.buildCriteria(
      stepsTitle: 'Steps',
      habitTargets: const {'walk': 4},
      measurableTargets: const {'pages': 60},
      measurableTitles: const {'pages': 'Pages read'},
      compositeRule: GoalFormCompositeRule.atLeast,
      requiredSuccesses: 1,
    );

    expect(
      rebuilt,
      const GoalCriterion.atLeastCount(
        criterionId: 'routine',
        successes: 1,
        criteria: [
          GoalCriterion.habit(
            criterionId: 'habit-walk',
            habitId: 'walk',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 4,
          ),
          GoalCriterion.measurable(
            criterionId: 'measurable-pages',
            dataTypeId: 'pages',
            title: 'Pages read',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.sum,
            target: 60,
          ),
        ],
      ),
    );
  });

  test('round-trips editable weight and blood-pressure dimensions', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'health-baseline',
      criteria: [
        GoalCriterion.metric(
          criterionId: 'weight-v2',
          dataType: GoalHealthDataTypes.weight,
          title: 'Weekly weight trend',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 82,
          direction: GoalDirection.atMost,
        ),
        GoalCriterion.metric(
          criterionId: 'systolic-v2',
          dataType: GoalHealthDataTypes.bloodPressureSystolic,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 125,
          direction: GoalDirection.atMost,
        ),
        GoalCriterion.metric(
          criterionId: 'diastolic-v2',
          dataType: GoalHealthDataTypes.bloodPressureDiastolic,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 85,
          direction: GoalDirection.atMost,
        ),
      ],
    );

    final draft = GoalFormMapping.fromCriteria(criteria);

    expect(draft.isEditable, isTrue);
    expect(draft.healthTargets, {
      GoalHealthDataTypes.weight: 82,
      GoalHealthDataTypes.bloodPressureSystolic: 125,
      GoalHealthDataTypes.bloodPressureDiastolic: 85,
    });
    expect(draft.healthDirections.values, everyElement(GoalDirection.atMost));
    expect(
      draft.buildCriteria(
        stepsTitle: 'Steps',
        habitTargets: const {},
        healthTargets: const {
          GoalHealthDataTypes.weight: 80,
          GoalHealthDataTypes.bloodPressureSystolic: 120,
          GoalHealthDataTypes.bloodPressureDiastolic: 80,
        },
        healthDirections: const {
          GoalHealthDataTypes.weight: GoalDirection.atLeast,
          GoalHealthDataTypes.bloodPressureSystolic: GoalDirection.atMost,
          GoalHealthDataTypes.bloodPressureDiastolic: GoalDirection.atMost,
        },
      ),
      const GoalCriterion.allOf(
        criterionId: 'health-baseline',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'weight-v2',
            dataType: GoalHealthDataTypes.weight,
            title: 'Weekly weight trend',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 80,
          ),
          GoalCriterion.metric(
            criterionId: 'systolic-v2',
            dataType: GoalHealthDataTypes.bloodPressureSystolic,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 120,
            direction: GoalDirection.atMost,
          ),
          GoalCriterion.metric(
            criterionId: 'diastolic-v2',
            dataType: GoalHealthDataTypes.bloodPressureDiastolic,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 80,
            direction: GoalDirection.atMost,
          ),
        ],
      ),
    );
  });

  test('builds new health leaves with stable canonical identifiers', () {
    const draft = GoalFormMapping.empty();

    expect(
      draft.buildCriteria(
        stepsTitle: 'Steps',
        habitTargets: const {},
        healthTargets: const {
          GoalHealthDataTypes.weight: 75,
          GoalHealthDataTypes.bloodPressureSystolic: 120,
        },
        healthDirections: const {
          GoalHealthDataTypes.weight: GoalDirection.atMost,
          GoalHealthDataTypes.bloodPressureSystolic: GoalDirection.atMost,
        },
        healthTitles: const {
          GoalHealthDataTypes.weight: 'Weight',
          GoalHealthDataTypes.bloodPressureSystolic: 'Systolic blood pressure',
        },
      ),
      const GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'health-weight',
            dataType: GoalHealthDataTypes.weight,
            title: 'Weight',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 75,
            direction: GoalDirection.atMost,
          ),
          GoalCriterion.metric(
            criterionId: 'health-blood-pressure-systolic',
            dataType: GoalHealthDataTypes.bloodPressureSystolic,
            title: 'Systolic blood pressure',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 120,
            direction: GoalDirection.atMost,
          ),
        ],
      ),
    );
  });

  test('loaded untitled dimensions remain untitled when rebuilt', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'untitled-dimensions',
      criteria: [
        GoalCriterion.measurable(
          criterionId: 'pages-v1',
          dataTypeId: 'pages',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          target: 50,
        ),
        GoalCriterion.metric(
          criterionId: 'weight-v1',
          dataType: GoalHealthDataTypes.weight,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 80,
          direction: GoalDirection.atMost,
        ),
      ],
    );

    final rebuilt =
        GoalFormMapping.fromCriteria(criteria).buildCriteria(
              stepsTitle: 'Steps',
              habitTargets: const {},
              measurableTargets: const {'pages': 55},
              measurableTitles: const {'pages': 'Localized pages'},
              healthTargets: const {GoalHealthDataTypes.weight: 79},
              healthTitles: const {
                GoalHealthDataTypes.weight: 'Localized weight',
              },
            )!
            as GoalCriterionAllOf;

    expect(
      rebuilt.criteria.map((criterion) => criterion.title),
      [null, null],
    );
  });
}
