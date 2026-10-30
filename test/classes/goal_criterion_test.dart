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

  test('check-in time round trips and claims no habit or health type', () {
    const criterion = GoalCriterion.checkInTime(
      criterionId: 'reflect',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetMinutes: 3,
      title: 'Check-in time',
    );

    final decoded = GoalCriterion.fromJson(
      jsonDecode(jsonEncode(criterion)) as Map<String, dynamic>,
    );

    expect(decoded, criterion);
    // A reflection target defaults to a floor, not a ceiling.
    expect(
      (decoded as GoalCriterionCheckInTime).direction,
      GoalDirection.atLeast,
    );
    expect(goalCriterionHabitIds(criterion), isEmpty);
    expect(goalCriterionMetricDataTypes(criterion), isEmpty);
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

  group('a criterion kind this build does not know (ADR 0145)', () {
    Map<String, dynamic> future({String id = 'future'}) => {
      'runtimeType': 'sleepQuality',
      'criterionId': id,
      'title': 'Sleep quality',
      'window': {'runtimeType': 'day'},
      'targetScore': 80,
    };

    test('decodes as unsupported with its id and title instead of throwing, '
        'at any depth', () {
      final leaf = GoalCriterion.fromJson(future());
      expect(
        leaf,
        GoalCriterion.unsupported(
          criterionId: 'future',
          title: 'Sleep quality',
          source: future(),
        ),
      );

      final tree = GoalCriterion.fromJson({
        'runtimeType': 'allOf',
        'criterionId': 'root',
        'criteria': [
          // As it arrives over sync: plain JSON all the way down.
          jsonDecode(
            jsonEncode(
              const GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'h1',
                window: GoalWindow.calendarWeek(),
                targetCount: 3,
              ),
            ),
          ),
          future(id: 'nested'),
        ],
      });
      expect(goalCriterionHasUnsupported(tree), isTrue);
      expect(goalCriterionHabitIds(tree), {'h1'});
    });

    test('keeps the node it arrived as through storage, so an updated '
        'build reads the criterion it never lost', () {
      final tree = GoalCriterion.fromJson({
        'runtimeType': 'allOf',
        'criterionId': 'root',
        'criteria': [future(id: 'nested')],
      });
      // What the inbound sync persists, as the database stores it.
      final stored =
          jsonDecode(jsonEncode(tree.toJson())) as Map<String, dynamic>;

      // Read back on this build: still unsupported, still whole.
      final reread = GoalCriterion.fromJson(stored);
      expect(reread, tree);
      expect(
        jsonDecode(jsonEncode(reread.toJson())),
        stored,
        reason: 'storage round-trips without shedding a field',
      );

      // The stub around a kind an updated build knows decodes as that kind.
      final habit =
          jsonDecode(
                jsonEncode(
                  const GoalCriterion.habit(
                    criterionId: 'walk',
                    habitId: 'h1',
                    window: GoalWindow.calendarWeek(),
                    targetCount: 3,
                  ),
                ),
              )
              as Map<String, dynamic>;
      expect(
        GoalCriterion.fromJson({
          'runtimeType': 'habit',
          'criterionId': 'walk',
          goalCriterionSourceKey: habit,
        }),
        const GoalCriterion.habit(
          criterionId: 'walk',
          habitId: 'h1',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
      );
    });

    test('a tree of known kinds holds none', () {
      expect(
        goalCriterionHasUnsupported(
          const GoalCriterion.anyOf(
            criterionId: 'root',
            criteria: [
              GoalCriterion.checkInTime(
                criterionId: 'journal',
                window: GoalWindow.day(),
                aggregation: GoalAggregation.sum,
                targetMinutes: 10,
              ),
            ],
          ),
        ),
        isFalse,
      );
    });
  });
}
