import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

void main() {
  group('fromAutoCompleteRule thresholds', () {
    test('health rule with minimum only becomes an atLeast metric', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.health(
          dataType: 'cumulative_step_count',
          minimum: 10000,
          title: 'steps',
        ),
      );
      expect(
        criterion,
        const GoalCriterion.metric(
          criterionId: 'c',
          dataType: 'cumulative_step_count',
          window: GoalWindow.day(),
          aggregation: GoalAggregation.sum,
          target: 10000,
          title: 'steps',
        ),
      );
    });

    test('health rule with maximum only becomes an atMost metric', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.health(
          dataType: 'caffeine_intake',
          maximum: 200,
        ),
      );
      expect(
        criterion,
        isA<GoalCriterionMetric>()
            .having((c) => c.target, 'target', 200)
            .having((c) => c.direction, 'direction', GoalDirection.atMost),
      );
    });

    test('minimum and maximum together become an allOf pair', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.health(
          dataType: 'sleep_minutes',
          minimum: 420,
          maximum: 540,
        ),
      );
      expect(
        criterion,
        isA<GoalCriterionAllOf>().having((c) => c.criteria, 'children', [
          isA<GoalCriterionMetric>()
              .having((m) => m.criterionId, 'id', 'c.min')
              .having((m) => m.target, 'target', 420)
              .having((m) => m.direction, 'dir', GoalDirection.atLeast),
          isA<GoalCriterionMetric>()
              .having((m) => m.criterionId, 'id', 'c.max')
              .having((m) => m.target, 'target', 540)
              .having((m) => m.direction, 'dir', GoalDirection.atMost),
        ]),
      );
    });

    test('workout rules import identically to health rules', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.workout(
          dataType: 'running_distance',
          minimum: 5000,
        ),
      );
      expect(
        criterion,
        isA<GoalCriterionMetric>()
            .having((c) => c.dataType, 'dataType', 'running_distance')
            .having((c) => c.target, 'target', 5000),
      );
    });

    test('measurable rules map to measurable criteria', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.measurable(
          dataTypeId: 'water-intake-id',
          minimum: 2000,
        ),
      );
      expect(
        criterion,
        isA<GoalCriterionMeasurable>()
            .having((c) => c.dataTypeId, 'dataTypeId', 'water-intake-id')
            .having((c) => c.target, 'target', 2000),
      );
    });

    test('a threshold rule with neither bound throws', () {
      expect(
        () => GoalCriterion.fromAutoCompleteRule(
          const AutoCompleteRule.health(dataType: 'steps'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('fromAutoCompleteRule structure', () {
    test('habit rules become single-completion quotas', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.habit(habitId: 'gym-habit', title: 'Gym'),
      );
      expect(
        criterion,
        const GoalCriterion.habit(
          criterionId: 'c',
          habitId: 'gym-habit',
          window: GoalWindow.day(),
          targetCount: 1,
          title: 'Gym',
        ),
      );
    });

    test('and/or/multiple map to allOf/anyOf/atLeastCount with path ids', () {
      final criterion = GoalCriterion.fromAutoCompleteRule(
        const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.habit(habitId: 'h1'),
            AutoCompleteRule.multiple(
              rules: [
                AutoCompleteRule.habit(habitId: 'h2'),
                AutoCompleteRule.or(
                  rules: [
                    AutoCompleteRule.habit(habitId: 'h3'),
                    AutoCompleteRule.health(dataType: 'steps', minimum: 8000),
                  ],
                ),
              ],
              successes: 1,
            ),
          ],
        ),
      );

      final root = criterion as GoalCriterionAllOf;
      expect(root.criterionId, 'c');
      expect((root.criteria[0] as GoalCriterionHabit).criterionId, 'c.0');

      final multiple = root.criteria[1] as GoalCriterionAtLeastCount;
      expect(multiple.criterionId, 'c.1');
      expect(multiple.successes, 1);
      expect(
        (multiple.criteria[0] as GoalCriterionHabit).criterionId,
        'c.1.0',
      );

      final or = multiple.criteria[1] as GoalCriterionAnyOf;
      expect(or.criterionId, 'c.1.1');
      expect((or.criteria[1] as GoalCriterionMetric).criterionId, 'c.1.1.1');
    });

    test('window and aggregation upgrades propagate to every leaf', () {
      final criterion =
          GoalCriterion.fromAutoCompleteRule(
                const AutoCompleteRule.and(
                  rules: [
                    AutoCompleteRule.health(dataType: 'steps', minimum: 10000),
                    AutoCompleteRule.habit(habitId: 'h1'),
                  ],
                ),
                window: const GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
              )
              as GoalCriterionAllOf;

      final metric = criterion.criteria[0] as GoalCriterionMetric;
      expect(metric.window, const GoalWindow.rollingDays(count: 7));
      expect(metric.aggregation, GoalAggregation.dailySumThenAverage);
      final habit = criterion.criteria[1] as GoalCriterionHabit;
      expect(habit.window, const GoalWindow.rollingDays(count: 7));
    });

    test('repeated imports of the same rule are identical', () {
      const rule = AutoCompleteRule.and(
        rules: [
          AutoCompleteRule.health(dataType: 'steps', minimum: 10000),
          AutoCompleteRule.habit(habitId: 'h1'),
        ],
      );
      expect(
        GoalCriterion.fromAutoCompleteRule(rule),
        GoalCriterion.fromAutoCompleteRule(rule),
      );
    });
  });

  test('json round trip preserves a nested tree', () {
    final criterion = GoalCriterion.fromAutoCompleteRule(
      const AutoCompleteRule.multiple(
        rules: [
          AutoCompleteRule.health(
            dataType: 'sleep_minutes',
            minimum: 420,
            maximum: 540,
          ),
          AutoCompleteRule.habit(habitId: 'h1'),
        ],
        successes: 1,
      ),
      window: const GoalWindow.calendarWeek(),
    );
    // Through the string form, as sync transports entities — bare toJson()
    // leaves nested union children unserialized by json_serializable default.
    final decoded = GoalCriterion.fromJson(
      jsonDecode(jsonEncode(criterion)) as Map<String, dynamic>,
    );
    expect(decoded, criterion);
  });

  test('category time round trip preserves a cross-midnight band', () {
    const criterion = GoalCriterion.categoryTime(
      criterionId: 'late-coding',
      categoryId: 'vibe-coding',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.sum,
      targetHours: 0,
      dailyTimeRange: GoalDailyTimeRange(
        startMinute: 21 * 60 + 30,
        endMinute: 7 * 60,
      ),
      title: 'Late vibe coding',
    );

    final decoded = GoalCriterion.fromJson(
      jsonDecode(jsonEncode(criterion)) as Map<String, dynamic>,
    );

    expect(decoded, criterion);
  });

  test('label time round trip preserves label and optional category scope', () {
    const criterion = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      categoryId: 'work',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
      title: 'Create content',
    );

    final decoded = GoalCriterion.fromJson(
      jsonDecode(jsonEncode(criterion)) as Map<String, dynamic>,
    );

    expect(decoded, criterion);
    expect(goalCriterionHabitIds(criterion), isEmpty);
  });
}
