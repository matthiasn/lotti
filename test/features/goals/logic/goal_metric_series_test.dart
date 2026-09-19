import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('warm-up run-up', () {
    final today = DateTime.utc(2026, 8, 20);

    GoalMetricProgressView metric({Map<DateTime, num> warmup = const {}}) =>
        GoalMetricProgressView(
          name: 'Steps',
          target: 10000,
          warmupValues: warmup,
          days: [
            for (var offset = 6; offset >= 0; offset--)
              GoalProgressDay(
                day: today.subtract(Duration(days: offset)),
                value: 1000,
                // ignore: avoid_redundant_argument_values
                isObserved: true,
              ),
          ],
        );

    test('a run-up lets the mean start on the first VISIBLE day', () {
      // Regression: the series gated on the first day of `metric.days`,
      // which is the visible span — so the line could not produce a point
      // until six days into the chart and began a week late, leaving the
      // earliest part of the range looking trend-less rather than undrawn.
      final averages = goalMetricSevenDayAverage(
        metric(
          warmup: {
            for (var offset = 12; offset >= 7; offset--)
              today.subtract(Duration(days: offset)): 4000,
          },
        ),
        today: today,
      );

      expect(averages, hasLength(7));
      expect(averages.first.dateTime, today.subtract(const Duration(days: 6)));
      // Six run-up days at 4000 plus the first visible day at 1000.
      expect(averages.first.value, closeTo((4000 * 6 + 1000) / 7, 0.001));
      // By the last day the run-up has aged out of the window entirely.
      expect(averages.last.value, closeTo(1000, 0.001));
    });

    test('without a run-up it still waits for a full window rather than '
        'averaging two days and calling it a week', () {
      final averages = goalMetricSevenDayAverage(metric(), today: today);

      expect(averages, hasLength(1));
      expect(averages.single.dateTime, today);
      expect(averages.single.value, closeTo(1000, 0.001));
    });

    test('run-up days at or after the visible start are ignored, so a day '
        'cannot be counted twice', () {
      final averages = goalMetricSevenDayAverage(
        metric(
          warmup: {
            // Overlaps the visible span: already present in `days`.
            today.subtract(const Duration(days: 3)): 99999,
            today.subtract(const Duration(days: 8)): 4000,
          },
        ),
        today: today,
      );

      expect(averages, isNotEmpty);
      for (final point in averages) {
        expect(point.value, lessThan(9999));
      }
    });
  });

  group('the single-day helper agrees with the series', () {
    final today = DateTime.utc(2026, 8, 20);

    GoalMetricProgressView metric({Map<DateTime, num> warmup = const {}}) =>
        GoalMetricProgressView(
          name: 'Steps',
          target: 10000,
          warmupValues: warmup,
          days: [
            for (var offset = 6; offset >= 0; offset--)
              GoalProgressDay(
                day: today.subtract(Duration(days: offset)),
                value: 1000,
                // ignore: avoid_redundant_argument_values
                isObserved: true,
              ),
          ],
        );

    test('every day the series draws, the per-day helper can also answer', () {
      // Regression: the reflection sheet reads the per-day helper while the
      // card reads the series. The helper gated on a full week of RENDERED
      // history, so for the first six visible days it returned null for
      // exactly the dates the chart had just started plotting — and quoted a
      // different figure once the span grew long enough to reach back.
      final warmup = {
        for (var offset = 12; offset >= 7; offset--)
          today.subtract(Duration(days: offset)): 4000,
      };
      final series = goalMetricSevenDayAverage(
        metric(warmup: warmup),
        today: today,
      );
      expect(series, isNotEmpty);

      for (final point in series) {
        final onDay = goalMetricSevenDayAverageOn(
          metric(warmup: warmup),
          day: point.dateTime,
        );
        expect(
          onDay,
          isNotNull,
          reason: 'the series plots ${point.dateTime}, so the sheet must too',
        );
        expect(onDay, closeTo(point.value, 0.001));
      }
    });

    test('a run-up entry overlapping a rendered day is counted once, not '
        'twice, and does not stand in for the missing week', () {
      // The series admits only warm-up entries strictly BEFORE the first
      // rendered day. The helper admitted any entry up to the day asked
      // about, so a provider that ever emitted an overlapping entry would
      // have it added twice — once as run-up, once as an observation — and
      // an entry inside the rendered range would satisfy the run-up test
      // that the series still fails, skipping the full-week guard.
      final overlapping = {
        for (var offset = 6; offset >= 0; offset--)
          today.subtract(Duration(days: offset)): 9000,
      };

      final series = goalMetricSevenDayAverage(
        metric(warmup: overlapping),
        today: today,
      );
      // Every rendered day is 1000, and the overlapping entries are all
      // discarded, so the mean is the rendered value alone.
      expect(series, hasLength(1));
      expect(series.single.value, closeTo(1000, 0.001));

      // The helper agrees — it neither double-counts nor waives the guard.
      expect(
        goalMetricSevenDayAverageOn(metric(warmup: overlapping), day: today),
        closeTo(1000, 0.001),
      );
      expect(
        goalMetricSevenDayAverageOn(
          metric(warmup: overlapping),
          day: today.subtract(const Duration(days: 3)),
        ),
        isNull,
        reason: 'an overlapping entry is not a week of history',
      );
    });

    test('with no run-up both still decline the same days', () {
      final series = goalMetricSevenDayAverage(metric(), today: today);
      expect(series, hasLength(1));
      expect(
        goalMetricSevenDayAverageOn(
          metric(),
          day: today.subtract(const Duration(days: 3)),
        ),
        isNull,
      );
      expect(goalMetricSevenDayAverageOn(metric(), day: today), isNotNull);
    });
  });

  group('seven-day average properties', () {
    glados.Glados(
      glados.any.metricHistory,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'the one-day reading agrees with the series, and skipped days have none',
      (history) {
        final view = history.view(today);
        final series = goalMetricSevenDayAverage(view, today: today);
        final byDay = {for (final point in series) point.dateTime: point.value};

        expect(byDay, hasLength(series.length));
        for (final entry in view.days) {
          if (entry.day.isAfter(today)) continue;
          expect(
            goalMetricSevenDayAverageOn(view, day: entry.day),
            byDay[entry.day],
            reason: '${entry.day}',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.metricHistory,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'each point is sorted, within today, and inside its window’s values',
      (history) {
        final view = history.view(today);
        final series = goalMetricSevenDayAverage(view, today: today);
        final firstDay = view.days
            .map((d) => d.day)
            .where((d) => !d.isAfter(today))
            .fold<DateTime?>(
              null,
              (first, d) => first == null || d.isBefore(first) ? d : first,
            );
        // Everything the window may draw on: observed days, plus run-up
        // strictly before the first rendered day.
        final values = <DateTime, num>{
          for (final MapEntry(:key, :value) in view.warmupValues.entries)
            if (firstDay != null && key.isBefore(firstDay)) key: value,
          for (final d in view.days)
            if (d.isObserved && !d.day.isAfter(today)) d.day: d.value,
        };

        for (var i = 1; i < series.length; i++) {
          expect(series[i].dateTime.isAfter(series[i - 1].dateTime), isTrue);
        }
        for (final point in series) {
          expect(point.dateTime.isAfter(today), isFalse);
          final window = [
            for (final MapEntry(:key, :value) in values.entries)
              if (!key.isAfter(point.dateTime) &&
                  point.dateTime.difference(key).inDays < 7)
                value,
          ];
          expect(window, isNotEmpty);
          expect(
            point.value,
            inInclusiveRange(
              window.reduce((a, b) => a < b ? a : b),
              window.reduce((a, b) => a > b ? a : b),
            ),
          );
        }
      },
      tags: 'glados',
    );
  });
}

class _MetricHistory {
  const _MetricHistory(this.days, this.warmup);

  /// Days before today → (value, observed); negative offsets lie ahead.
  final Map<int, (int, bool)> days;

  /// Run-up days before today → value; may overlap the rendered days.
  final Map<int, int> warmup;

  GoalMetricProgressView view(DateTime today) => GoalMetricProgressView(
    name: 'Weight',
    sourceId: GoalHealthDataTypes.weight,
    target: 88,
    days: [
      for (final MapEntry(:key, value: (value, observed)) in days.entries)
        GoalProgressDay(
          day: today.subtract(Duration(days: key)),
          value: value,
          isObserved: observed,
        ),
    ],
    warmupValues: {
      for (final MapEntry(:key, :value) in warmup.entries)
        today.subtract(Duration(days: key)): value,
    },
  );

  @override
  String toString() => '_MetricHistory(days: $days, warmup: $warmup)';
}

extension _AnyMetricHistory on glados.Any {
  glados.Generator<_MetricHistory> get metricHistory =>
      glados.CombinableAny(this).combine2(
        glados.MapAnys(this).map(
          glados.IntAnys(this).intInRange(-3, 25),
          glados.CombinableAny(this).combine2(
            glados.IntAnys(this).intInRange(60, 100),
            glados.IntAnys(this).intInRange(0, 4),
            (int value, int seed) => (value, seed != 0),
          ),
        ),
        glados.MapAnys(this).map(
          glados.IntAnys(this).intInRange(0, 35),
          glados.IntAnys(this).intInRange(60, 100),
        ),
        _MetricHistory.new,
      );
}
