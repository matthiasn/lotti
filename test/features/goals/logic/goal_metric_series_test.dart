import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/logic/goal_metric_series.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  GoalProgressDay day(int offset, num value, {bool observed = true}) =>
      GoalProgressDay(
        day: today.subtract(Duration(days: offset)),
        value: value,
        isObserved: observed,
      );

  GoalMetricProgressView metric({
    required List<GoalProgressDay> days,
    String sourceId = GoalHealthDataTypes.weight,
    GoalAggregation aggregation = GoalAggregation.dailySumThenAverage,
  }) => GoalMetricProgressView(
    name: 'Weight',
    sourceId: sourceId,
    target: 88,
    aggregation: aggregation,
    days: days,
  );

  group('goalMetricObservations', () {
    test('keeps only observed days, oldest first', () {
      final observations = goalMetricObservations(
        metric(
          days: [
            day(0, 90),
            day(2, 0, observed: false),
            day(1, 92),
          ],
        ),
      );

      expect(observations.map((o) => o.value), [92, 90]);
      expect(
        observations.map((o) => o.dateTime),
        [today.subtract(const Duration(days: 1)), today],
      );
    });
  });

  group('goalMetricShowsSevenDayAverage', () {
    test('covers the daily quantities an average actually reads, and no '
        'other aggregation of them', () {
      expect(goalMetricShowsSevenDayAverage(metric(days: const [])), isTrue);
      expect(
        goalMetricShowsSevenDayAverage(
          metric(days: const [], sourceId: GoalHealthDataTypes.steps),
        ),
        isTrue,
      );
      // A SUM of weights is a different question; averaging it would answer
      // one nobody asked.
      expect(
        goalMetricShowsSevenDayAverage(
          metric(days: const [], aggregation: GoalAggregation.sum),
        ),
        isFalse,
      );
      expect(
        goalMetricShowsSevenDayAverage(
          metric(days: const [], sourceId: 'meditation-minutes'),
        ),
        isFalse,
      );
    });
  });

  group('goalMetricSevenDayAverage', () {
    test('starts only once a full week of history stands behind the day', () {
      final averages = goalMetricSevenDayAverage(
        metric(
          days: [for (var offset = 7; offset >= 0; offset--) day(offset, 90)],
        ),
        today: today,
      );

      // Eight days of history yields two windows: the seventh day and today.
      expect(averages, hasLength(2));
      expect(averages.first.dateTime, today.subtract(const Duration(days: 1)));
      expect(averages.last.dateTime, today);
      expect(averages.map((o) => o.value), everyElement(90));
    });

    test(
      'a missed day lowers nothing — it is skipped, not counted as zero',
      () {
        final averages = goalMetricSevenDayAverage(
          metric(
            days: [
              for (var offset = 7; offset >= 1; offset--) day(offset, 90),
              day(0, 0, observed: false),
            ],
          ),
          today: today,
        );

        expect(averages.last.value, 90);
      },
    );

    test(
      'never reaches past today, even when the window holds future days',
      () {
        final averages = goalMetricSevenDayAverage(
          metric(
            days: [
              for (var offset = 6; offset >= 0; offset--) day(offset, 94),
              for (var ahead = 1; ahead <= 3; ahead++)
                GoalProgressDay(
                  day: today.add(Duration(days: ahead)),
                  value: 0,
                  isObserved: false,
                ),
            ],
          ),
          today: today,
        );

        expect(averages, hasLength(1));
        expect(averages.single.dateTime, today);
      },
    );
  });

  group('goalMetricSevenDayAverageOn', () {
    test('returns the mean of the window ENDING on the asked-for day', () {
      final series = metric(
        days: [
          day(7, 100),
          day(6, 98),
          day(5, 96),
          day(4, 94),
          day(3, 92),
          day(2, 90),
          day(1, 88),
          day(0, 30),
        ],
      );

      // Yesterday's window is the seven days before it: 100…88.
      expect(
        goalMetricSevenDayAverageOn(
          series,
          day: today.subtract(const Duration(days: 1)),
        ),
        (100 + 98 + 96 + 94 + 92 + 90 + 88) / 7,
      );
      // Today's window drops the 100 and adds the 30 — the number the day's
      // own value is dragging down, which is exactly what the reflection
      // sheet prints beside it.
      expect(
        goalMetricSevenDayAverageOn(series, day: today),
        (98 + 96 + 94 + 92 + 90 + 88 + 30) / 7,
      );
    });

    test('is null before a full week of history exists', () {
      expect(
        goalMetricSevenDayAverageOn(
          metric(
            days: [for (var offset = 3; offset >= 0; offset--) day(offset, 90)],
          ),
          day: today,
        ),
        isNull,
      );
    });
  });
}
