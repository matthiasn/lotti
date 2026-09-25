import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_spec_validator.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

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

    test('measurable leaves get the same target and window checks', () {
      const bad = GoalCriterion.measurable(
        criterionId: 'water',
        dataTypeId: 'water-id',
        window: GoalWindow.rollingDays(count: -2),
        aggregation: GoalAggregation.sum,
        target: double.infinity,
      );
      final issues = GoalSpecValidator.criterionIssues(bad);
      expect(issues, hasLength(2));
      expect(issues, anyElement(contains('water: target must be finite')));
      expect(issues, anyElement(contains('water: rolling window')));
    });

    test('category time validates category, target and daily time band', () {
      const bad = GoalCriterion.categoryTime(
        criterionId: 'late-coding',
        categoryId: '  ',
        window: GoalWindow.rollingDays(count: 0),
        aggregation: GoalAggregation.sum,
        targetHours: -1,
        dailyTimeRange: GoalDailyTimeRange(
          startMinute: 1440,
          endMinute: 1440,
        ),
      );

      final issues = GoalSpecValidator.criterionIssues(bad);

      expect(issues, hasLength(5));
      expect(issues, anyElement(contains('categoryId must not be blank')));
      expect(issues, anyElement(contains('targetHours must not be negative')));
      expect(issues, anyElement(contains('rolling window')));
      expect(issues, anyElement(contains('startMinute')));
      expect(issues, anyElement(contains('endMinute')));
    });

    test('category time raw JSON rejects fractional time-band minutes', () {
      const criterion = GoalCriterion.categoryTime(
        criterionId: 'late-coding',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 0,
        dailyTimeRange: GoalDailyTimeRange(
          startMinute: 1290,
          endMinute: 420,
        ),
      );
      final json = jsonOf(criterion);
      (json['dailyTimeRange'] as Map<String, dynamic>)['startMinute'] = 1290.5;

      final issues = GoalSpecValidator.criterionJsonIssues(json);

      expect(issues.single, contains('dailyTimeRange.startMinute'));
      expect(
        () => GoalSpecValidator.decodeValidated(json),
        throwsFormatException,
      );
    });

    test('category time rejects an empty daily time band', () {
      const criterion = GoalCriterion.categoryTime(
        criterionId: 'late-coding',
        categoryId: 'vibe-coding',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: 0,
        dailyTimeRange: GoalDailyTimeRange(
          startMinute: 22 * 60,
          endMinute: 22 * 60,
        ),
      );

      final issues = GoalSpecValidator.criterionIssues(criterion);

      expect(issues.single, contains('endpoints must differ'));
    });

    test('category time rejects day-count aggregation for hour targets', () {
      const criterion = GoalCriterion.categoryTime(
        criterionId: 'coding-days',
        categoryId: 'vibe-coding',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.count,
        targetHours: 2,
      );

      final issues = GoalSpecValidator.criterionIssues(criterion);

      expect(issues.single, contains('count aggregation uses day units'));
    });

    test('an empty atLeastCount reports childlessness, not a quota', () {
      const empty = GoalCriterion.atLeastCount(
        criterionId: 'root',
        criteria: [],
        successes: 2,
      );
      final issues = GoalSpecValidator.criterionIssues(empty);
      expect(issues.single, contains('no children'));
    });

    test('blank signal identifiers are corrupt config, not zero data', () {
      const blank = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: '  ',
            window: GoalWindow.calendarWeek(),
            targetCount: 1,
          ),
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: '',
            window: GoalWindow.day(),
            aggregation: GoalAggregation.sum,
            target: 10,
          ),
          GoalCriterion.measurable(
            criterionId: 'water',
            dataTypeId: '',
            window: GoalWindow.day(),
            aggregation: GoalAggregation.sum,
            target: 10,
          ),
        ],
      );
      final issues = GoalSpecValidator.criterionIssues(blank);
      expect(issues, hasLength(3));
      expect(issues, anyElement(contains('gym: habitId')));
      expect(issues, anyElement(contains('steps: dataType')));
      expect(issues, anyElement(contains('water: dataTypeId')));
    });

    test('label time requires stable ids and a non-negative hour target', () {
      const criterion = GoalCriterion.labelTime(
        criterionId: 'content-time',
        labelId: '  ',
        categoryId: '',
        window: GoalWindow.day(),
        aggregation: GoalAggregation.sum,
        targetHours: -1,
      );

      final issues = GoalSpecValidator.criterionIssues(criterion);

      expect(issues, anyElement(contains('labelId')));
      expect(issues, anyElement(contains('categoryId')));
      expect(issues, anyElement(contains('targetHours')));
    });

    test('duplicate criterion ids are rejected before they can shadow '
        'results', () {
      const duped = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'leg',
            habitId: 'h1',
            window: GoalWindow.calendarWeek(),
            targetCount: 1,
          ),
          GoalCriterion.habit(
            criterionId: 'leg',
            habitId: 'h2',
            window: GoalWindow.calendarWeek(),
            targetCount: 1,
          ),
        ],
      );
      expect(
        GoalSpecValidator.criterionIssues(duped).single,
        contains('leg: duplicate criterionId'),
      );
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

  group('authoring layer — quotas no schedule can meet', () {
    String quotaIssue(String id, int target, int capacity) =>
        '$id: targetCount $target exceeds the $capacity days the window can '
        'credit — unsatisfiable';

    GoalCriterion habit(GoalWindow window, int targetCount) =>
        GoalCriterion.habit(
          criterionId: 'h',
          habitId: 'h',
          window: window,
          targetCount: targetCount,
        );

    test('rejects a habit quota above the days its window can credit', () {
      for (final (window, capacity) in [
        (const GoalWindow.day(), 1),
        (const GoalWindow.rollingDays(count: 7), 7),
        (const GoalWindow.calendarWeek(), 7),
        (const GoalWindow.calendarMonth(), 28),
      ]) {
        expect(
          GoalSpecValidator.authoringIssues(habit(window, capacity)),
          isEmpty,
          reason: 'exactly $capacity fits $window',
        );
        expect(
          GoalSpecValidator.authoringIssues(habit(window, capacity + 1)),
          [quotaIssue('h', capacity + 1, capacity)],
        );
      }
    });

    test('rejects a rolling window beyond the ten-year maximum, on any '
        'leaf', () {
      const windowIssue =
          'water: rolling window of ${maxGoalRollingDays + 1} days exceeds '
          'the maximum of $maxGoalRollingDays';
      const tooLong = GoalWindow.rollingDays(count: maxGoalRollingDays + 1);
      expect(
        GoalSpecValidator.authoringIssues(
          const GoalCriterion.allOf(
            criterionId: 'root',
            criteria: [
              GoalCriterion.measurable(
                criterionId: 'water',
                dataTypeId: 'water',
                window: tooLong,
                aggregation: GoalAggregation.sum,
                target: 2,
              ),
            ],
          ),
        ),
        [windowIssue],
      );
      expect(
        GoalSpecValidator.authoringIssues(
          habit(
            const GoalWindow.rollingDays(count: maxGoalRollingDays),
            1,
          ),
        ),
        isEmpty,
      );
    });

    test('keeps every structural issue, and persisted specs still decode', () {
      const infeasible = GoalCriterion.anyOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'gym-habit',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 10,
          ),
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: ' ',
            window: GoalWindow.day(),
            targetCount: 1,
          ),
        ],
      );
      expect(GoalSpecValidator.authoringIssues(infeasible), [
        ...GoalSpecValidator.criterionIssues(infeasible),
        quotaIssue('gym', 10, 7),
      ]);
      // A spec minted before the check existed must keep loading on every
      // replica: decoding applies only the structural layer.
      final older = habit(const GoalWindow.rollingDays(count: 7), 10);
      expect(GoalSpecValidator.decodeValidated(jsonOf(older)), older);
    });

    test('a quota is accepted exactly when perfect adherence meets it '
        '(exhaustive against the evaluator)', () {
      // Perfect adherence: a success on every day of the period, evaluated on
      // its last day — in the period's shortest form, since a quota must be
      // reachable in every period it recurs over. February 2026 has 28 days;
      // the ISO week of 2026-08-03 ends on Sunday 2026-08-09.
      const evaluator = GoalProgressEvaluator();
      final aug31 = DateTime.utc(2026, 8, 31);
      final sunday = DateTime.utc(2026, 8, 9);
      final february = DateTime.utc(2026, 2, 28);
      final shapes = <(GoalWindow, DateTime)>[
        (const GoalWindow.day(), aug31),
        (const GoalWindow.calendarWeek(), sunday),
        (const GoalWindow.calendarMonth(), february),
        for (var count = 1; count <= 12; count++)
          (GoalWindow.rollingDays(count: count), aug31),
      ];
      var cases = 0;
      for (final (window, reference) in shapes) {
        final range = window.periodRange(reference);
        final everyDay = {
          for (
            var day = range.start;
            !day.isAfter(range.end);
            day = day.add(const Duration(days: 1))
          )
            day: 1,
        };
        for (var target = 1; target <= 40; target++) {
          cases++;
          final criterion = habit(window, target);
          final accepted = GoalSpecValidator.authoringIssues(criterion).isEmpty;
          final achievable = evaluator
              .evaluate(
                criterion,
                GoalSignalWindow(habitSuccessesByDay: {'h': everyDay}),
                reference,
              )
              .satisfied;
          expect(accepted, achievable, reason: '$target over $window');
        }
      }
      expect(cases, 15 * 40);
    });
  });
}
