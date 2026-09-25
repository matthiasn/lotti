import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

void main() {
  test('json round trip preserves a nested tree', () {
    const criterion = GoalCriterion.atLeastCount(
      criterionId: 'c',
      successes: 1,
      criteria: [
        GoalCriterion.allOf(
          criterionId: 'c.0',
          criteria: [
            GoalCriterion.metric(
              criterionId: 'c.0.min',
              dataType: 'sleep_minutes',
              window: GoalWindow.calendarWeek(),
              aggregation: GoalAggregation.sum,
              target: 420,
            ),
            GoalCriterion.metric(
              criterionId: 'c.0.max',
              dataType: 'sleep_minutes',
              window: GoalWindow.calendarWeek(),
              aggregation: GoalAggregation.sum,
              target: 540,
              direction: GoalDirection.atMost,
            ),
          ],
        ),
        GoalCriterion.habit(
          criterionId: 'c.1',
          habitId: 'h1',
          window: GoalWindow.calendarWeek(),
          targetCount: 1,
        ),
      ],
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

  test('goalCriterionMetricDataTypes collects the quantitative leaves and '
      'nothing else', () {
    const criterion = GoalCriterion.allOf(
      criterionId: 'root',
      criteria: [
        GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 10000,
        ),
        GoalCriterion.anyOf(
          criterionId: 'either',
          criteria: [
            GoalCriterion.metric(
              criterionId: 'weight',
              dataType: 'HealthDataType.WEIGHT',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.dailySumThenAverage,
              target: 88,
              direction: GoalDirection.atMost,
            ),
            // The kinds a goal reads out of its OWN journal. They are current
            // by construction, and the health-refresh join must not ask an
            // importer for them.
            GoalCriterion.habit(
              criterionId: 'gym',
              habitId: 'gym',
              window: GoalWindow.rollingDays(count: 7),
              targetCount: 3,
            ),
            GoalCriterion.measurable(
              criterionId: 'words',
              dataTypeId: 'words-written',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.sum,
              target: 1000,
            ),
            GoalCriterion.categoryTime(
              criterionId: 'coding',
              categoryId: 'vibe-coding',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.sum,
              targetHours: 8,
            ),
            GoalCriterion.labelTime(
              criterionId: 'content',
              labelId: 'content',
              window: GoalWindow.day(),
              aggregation: GoalAggregation.sum,
              targetHours: 1,
            ),
          ],
        ),
      ],
    );

    expect(goalCriterionMetricDataTypes(criterion), {
      'cumulative_step_count',
      'HealthDataType.WEIGHT',
    });
  });
}
