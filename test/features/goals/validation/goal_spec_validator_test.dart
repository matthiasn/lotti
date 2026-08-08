import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/validation/goal_spec_validator.dart';

void main() {
  Map<String, dynamic> jsonOf(GoalCriterion criterion) =>
      jsonDecode(jsonEncode(criterion)) as Map<String, dynamic>;

  const validTree = GoalCriterion.atLeastCount(
    criterionId: 'root',
    criteria: [
      GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'cumulative_step_count',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 10000,
      ),
      GoalCriterion.habit(
        criterionId: 'gym',
        habitId: 'gym-habit',
        window: GoalWindow.calendarWeek(),
        targetCount: 3,
      ),
    ],
    successes: 1,
  );

  group('raw JSON layer — truncation is caught before decode hides it', () {
    test('fractional targetCount is rejected, not truncated to 1', () {
      final json = jsonOf(validTree);
      ((json['criteria'] as List)[1] as Map<String, dynamic>)['targetCount'] =
          1.9;
      // The decoder would silently accept this...
      expect(
        (GoalCriterion.fromJson(json) as GoalCriterionAtLeastCount).criteria[1],
        isA<GoalCriterionHabit>().having((h) => h.targetCount, 'truncated', 1),
      );
      // ...which is exactly why the validator must refuse it first.
      final issues = GoalSpecValidator.criterionJsonIssues(json);
      expect(issues, hasLength(1));
      expect(issues.single, contains('1.9'));
      expect(issues.single, contains('truncated'));
      expect(
        () => GoalSpecValidator.decodeValidated(json),
        throwsFormatException,
      );
    });

    test('fractional successes and rolling counts are caught, with paths', () {
      final json = jsonOf(validTree);
      json['successes'] = 1.5;
      (((json['criteria'] as List)[0] as Map<String, dynamic>)['window']
              as Map<String, dynamic>)['count'] =
          6.5;
      final issues = GoalSpecValidator.criterionJsonIssues(json);
      expect(issues, hasLength(2));
      expect(issues, anyElement(contains('criteria.successes')));
      expect(issues, anyElement(contains('criteria[0].window.count')));
    });

    test('a clean payload decodes to the identical tree', () {
      expect(
        GoalSpecValidator.decodeValidated(jsonOf(validTree)),
        validTree,
      );
    });
  });

  group('structural layer', () {
    test('empty composites are rejected', () {
      const empty = GoalCriterion.allOf(criterionId: 'root', criteria: []);
      expect(
        GoalSpecValidator.criterionIssues(empty).single,
        contains('no children'),
      );
    });

    test('an unsatisfiable quota names both numbers', () {
      const doomed = GoalCriterion.atLeastCount(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'h',
            window: GoalWindow.calendarWeek(),
            targetCount: 1,
          ),
        ],
        successes: 2,
      );
      expect(
        GoalSpecValidator.criterionIssues(doomed).single,
        contains('2 of 1'),
      );
    });

    test('non-positive counts and non-finite targets are rejected', () {
      const bad = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'h',
            window: GoalWindow.calendarWeek(),
            targetCount: 0,
          ),
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'steps',
            window: GoalWindow.rollingDays(count: 0),
            aggregation: GoalAggregation.sum,
            target: double.nan,
          ),
          GoalCriterion.atLeastCount(
            criterionId: 'quota',
            criteria: [
              GoalCriterion.habit(
                criterionId: 'walk',
                habitId: 'w',
                window: GoalWindow.day(),
                targetCount: 1,
              ),
            ],
            successes: 0,
          ),
        ],
      );
      final issues = GoalSpecValidator.criterionIssues(bad);
      expect(issues, hasLength(4));
      expect(issues, anyElement(contains('gym: targetCount')));
      expect(issues, anyElement(contains('steps: rolling window')));
      expect(issues, anyElement(contains('steps: target must be finite')));
      expect(issues, anyElement(contains('quota: successes')));
    });

    test('decodeValidated reports structural issues too', () {
      final json = jsonOf(
        const GoalCriterion.anyOf(criterionId: 'root', criteria: []),
      );
      expect(
        () => GoalSpecValidator.decodeValidated(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('no children'),
          ),
        ),
      );
    });

    test('a valid tree has no issues at either layer', () {
      expect(GoalSpecValidator.criterionIssues(validTree), isEmpty);
      expect(
        GoalSpecValidator.criterionJsonIssues(jsonOf(validTree)),
        isEmpty,
      );
    });
  });
}
