import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/ui/pages/goal_form_mapping.dart';

void main() {
  test('round-trips a daily label-time criterion with category scope', () {
    const criteria = GoalCriterion.labelTime(
      criterionId: 'daily-content-v2',
      labelId: 'content',
      categoryId: 'client-work',
      title: 'Content work',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );

    final draft = GoalFormMapping.fromCriteria(criteria);

    expect(draft.isEditable, isTrue);
    expect(draft.labelTimeTargets, {'content': 1});
    expect(draft.labelTimeCategoryIds, {'content': 'client-work'});
    expect(
      draft.buildCriteria(
        stepsTitle: 'Average steps per day',
        habitTargets: const {},
        labelTimeTargets: const {'content': 1.5},
        labelTimeTitles: const {'content': 'Renamed label'},
      ),
      const GoalCriterion.labelTime(
        criterionId: 'daily-content-v2',
        labelId: 'content',
        categoryId: 'client-work',
        title: 'Content work',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 1.5,
      ),
    );
  });

  test('new label time defaults cross-category but can be scoped', () {
    const draft = GoalFormMapping.empty();

    expect(
      draft.buildCriteria(
        stepsTitle: 'Average steps per day',
        habitTargets: const {},
        labelTimeTargets: const {'content': 1},
      ),
      const GoalCriterion.labelTime(
        criterionId: 'label-time-content',
        labelId: 'content',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 1,
      ),
    );
    expect(
      draft.buildCriteria(
        stepsTitle: 'Average steps per day',
        habitTargets: const {},
        labelTimeTargets: const {'content': 1},
        labelTimeCategoryIds: const {'content': 'work'},
      ),
      const GoalCriterion.labelTime(
        criterionId: 'label-time-content',
        labelId: 'content',
        categoryId: 'work',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 1,
      ),
    );
  });

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

  test('round-trips editable category-time dimensions', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'balanced-week',
      criteria: [
        GoalCriterion.categoryTime(
          criterionId: 'deep-work-hours',
          categoryId: 'deep-work',
          title: 'Deep work',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          targetHours: 12,
        ),
        GoalCriterion.habit(
          criterionId: 'habit-walk',
          habitId: 'walk',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 4,
        ),
      ],
    );

    final draft = GoalFormMapping.fromCriteria(criteria);

    expect(draft.isEditable, isTrue);
    expect(draft.categoryTimeTargets, {'deep-work': 12});
    expect(draft.categoryTimeDirections, {
      'deep-work': GoalDirection.atMost,
    });
    expect(
      draft.buildCriteria(
        stepsTitle: 'Steps',
        habitTargets: const {'walk': 4},
        categoryTimeTargets: const {'deep-work': 15},
        categoryTimeDirections: const {
          'deep-work': GoalDirection.atLeast,
        },
      ),
      const GoalCriterion.allOf(
        criterionId: 'balanced-week',
        criteria: [
          GoalCriterion.categoryTime(
            criterionId: 'deep-work-hours',
            categoryId: 'deep-work',
            title: 'Deep work',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.sum,
            targetHours: 15,
            direction: GoalDirection.atLeast,
          ),
          GoalCriterion.habit(
            criterionId: 'habit-walk',
            habitId: 'walk',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 4,
          ),
        ],
      ),
    );
  });

  test('preserves a category-time direction when no override is supplied', () {
    const criteria = GoalCriterion.categoryTime(
      criterionId: 'deep-work-hours',
      categoryId: 'deep-work',
      title: 'Deep work',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.sum,
      targetHours: 12,
      direction: GoalDirection.atLeast,
    );

    final draft = GoalFormMapping.fromCriteria(criteria);

    expect(
      draft.buildCriteria(
        stepsTitle: 'Steps',
        habitTargets: const {},
        categoryTimeTargets: const {'deep-work': 15},
      ),
      const GoalCriterion.categoryTime(
        criterionId: 'deep-work-hours',
        categoryId: 'deep-work',
        title: 'Deep work',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 15,
        direction: GoalDirection.atLeast,
      ),
    );
  });

  test('builds new category-time leaves with stable identifiers', () {
    const draft = GoalFormMapping.empty();

    expect(
      draft.buildCriteria(
        stepsTitle: 'Steps',
        habitTargets: const {},
        categoryTimeTargets: const {'deep-work': 10},
        categoryTimeDirections: const {
          'deep-work': GoalDirection.atMost,
        },
        categoryTimeTitles: const {'deep-work': 'Deep work'},
      ),
      const GoalCriterion.categoryTime(
        criterionId: 'category-time-deep-work',
        categoryId: 'deep-work',
        title: 'Deep work',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 10,
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

  group('mapping properties', () {
    GoalCriterion? rebuild(
      GoalFormMapping mapping, {
      Map<String, int> extraHabits = const {},
      Map<String, num> extraMeasurables = const {},
    }) => mapping.buildCriteria(
      stepsTitle: 'Average steps per day',
      habitTargets: {...mapping.habitTargets, ...extraHabits},
      measurableTargets: {...mapping.measurableTargets, ...extraMeasurables},
      healthTargets: mapping.healthTargets,
      healthDirections: mapping.healthDirections,
      categoryTimeTargets: mapping.categoryTimeTargets,
      categoryTimeDirections: mapping.categoryTimeDirections,
      labelTimeTargets: mapping.labelTimeTargets,
      labelTimeDirections: mapping.labelTimeDirections,
      labelTimeCategoryIds: mapping.labelTimeCategoryIds,
    );

    List<String> idsOf(GoalCriterion criterion) => [
      criterion.criterionId,
      ...switch (criterion) {
        GoalCriterionAllOf(:final criteria) ||
        GoalCriterionAnyOf(:final criteria) ||
        GoalCriterionAtLeastCount(:final criteria) => criteria.expand(idsOf),
        _ => const <String>[],
      },
    ];

    glados.Glados(
      glados.any.formCriteria,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'an unedited form rebuilds the tree it was read from',
      (criteria) {
        final mapping = GoalFormMapping.fromCriteria(criteria);

        // Editable or read-only, saving untouched controls changes nothing.
        expect(rebuild(mapping), criteria);
        if (!mapping.isEditable) {
          expect(mapping.unsupportedCriteria, same(criteria));
          expect(
            rebuild(mapping, extraHabits: const {'new-habit': 3}),
            same(criteria),
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.formCriteria,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'criteria added in the form get ids no other criterion has',
      (criteria) {
        final mapping = GoalFormMapping.fromCriteria(criteria);
        if (!mapping.isEditable) return;
        final rebuilt = rebuild(
          mapping,
          extraHabits: const {'new-habit': 3, 'k0': 2},
          extraMeasurables: const {'new-measure': 4, 'k1': 5},
        )!;

        final ids = idsOf(rebuilt);
        expect(ids.toSet(), hasLength(ids.length), reason: '$ids');
        // Everything the original tree named keeps its id.
        expect(ids, containsAll(idsOf(criteria)));
      },
      tags: 'glados',
    );
  });
}

/// A leaf of kind 0 steps, 1 health, 2 habit, 3 measurable, 4 category
/// time, 5 label time, 6 a habit the form cannot edit; `key` picks from a
/// small id pool so keys collide now and then.
typedef _FormLeafSpec = ({
  int kind,
  int key,
  int target,
  GoalDirection direction,
  bool titled,
});

GoalCriterion _formLeaf(_FormLeafSpec spec, int index) {
  final id = 'c$index';
  final key = 'k${spec.key}';
  final title = spec.titled ? 'Leaf $index' : null;
  const week = GoalWindow.rollingDays(count: 7);
  return switch (spec.kind) {
    0 => GoalCriterion.metric(
      criterionId: id,
      dataType: GoalHealthDataTypes.steps,
      title: title,
      window: week,
      aggregation: GoalAggregation.dailySumThenAverage,
      target: spec.target * 1000,
    ),
    1 => GoalCriterion.metric(
      criterionId: id,
      dataType: GoalHealthDataTypes.supported.elementAt(spec.key % 3),
      title: title,
      window: week,
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 60 + spec.target,
      direction: spec.direction,
    ),
    2 => GoalCriterion.habit(
      criterionId: id,
      habitId: key,
      title: title,
      window: week,
      targetCount: 1 + spec.target % 7,
    ),
    3 => GoalCriterion.measurable(
      criterionId: id,
      dataTypeId: key,
      title: title,
      window: week,
      aggregation: GoalAggregation.sum,
      target: spec.target,
    ),
    4 => GoalCriterion.categoryTime(
      criterionId: id,
      categoryId: key,
      title: title,
      window: week,
      aggregation: GoalAggregation.sum,
      targetHours: spec.target,
      direction: spec.direction,
    ),
    5 => GoalCriterion.labelTime(
      criterionId: id,
      labelId: key,
      categoryId: spec.titled ? 'cat-$key' : null,
      title: title,
      window: const GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: spec.target,
      direction: spec.direction,
    ),
    _ => GoalCriterion.habit(
      criterionId: id,
      habitId: key,
      title: title,
      window: const GoalWindow.calendarWeek(),
      targetCount: spec.target,
    ),
  };
}

extension _AnyFormCriteria on glados.Any {
  glados.Generator<_FormLeafSpec> get _formLeafSpec =>
      glados.CombinableAny(this).combine5(
        // Kind 6 (read-only) is rarer, so most trees stay editable.
        glados.IntAnys(this).intInRange(0, 13),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(1, 13),
        glados.AnyUtils(this).choose(GoalDirection.values),
        glados.BoolAny(this).bool,
        (int kind, int key, int target, GoalDirection direction, bool titled) =>
            (
              kind: kind < 12 ? kind % 6 : 6,
              key: key,
              target: target,
              direction: direction,
              titled: titled,
            ),
      );

  /// A bare leaf (kind 3) or an allOf / anyOf / atLeastCount of one to four
  /// leaves; an atLeastCount asks for between one and all of them.
  glados.Generator<GoalCriterion> get formCriteria =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 4),
        glados.ListAnys(this).listWithLengthInRange(1, 5, _formLeafSpec),
        glados.IntAnys(this).intInRange(0, 4),
        glados.BoolAny(this).bool,
        (int kind, List<_FormLeafSpec> specs, int successes, bool titled) {
          final leaves = [
            for (final (i, spec) in specs.indexed) _formLeaf(spec, i),
          ];
          final title = titled ? 'Routine' : null;
          return switch (kind) {
            0 => GoalCriterion.allOf(
              criterionId: 'routine',
              criteria: leaves,
              title: title,
            ),
            1 => GoalCriterion.anyOf(
              criterionId: 'routine',
              criteria: leaves,
              title: title,
            ),
            2 => GoalCriterion.atLeastCount(
              criterionId: 'routine',
              criteria: leaves,
              successes: 1 + successes % leaves.length,
              title: title,
            ),
            _ => leaves.first,
          };
        },
      );
}
