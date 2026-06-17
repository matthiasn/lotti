import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/widgets/charts/habits/habit_chart_stats.dart';

import '../../../test_data/test_data.dart';

void main() {
  HabitsState stateWith({
    required List<String> days,
    Map<String, Set<String>> allByDay = const {},
    Map<String, Set<String>> successfulByDay = const {},
    List<HabitDefinition> habitDefinitions = const [],
  }) {
    return HabitsState.initial().copyWith(
      days: days,
      timeSpanDays: days.length,
      allByDay: allByDay,
      successfulByDay: successfulByDay,
      habitDefinitions: habitDefinitions,
    );
  }

  group('habitChartStats — daily rates', () {
    test('rate is success / active habits per day', () {
      final stats = habitChartStats(
        stateWith(
          days: ['2024-03-14', '2024-03-15'],
          allByDay: {
            '2024-03-14': {'h1', 'h2'},
            '2024-03-15': {'h1', 'h2'},
          },
          successfulByDay: {
            '2024-03-14': {'h1'}, // 1 of 2 → 50
            '2024-03-15': {'h1', 'h2'}, // 2 of 2 → 100
          },
        ),
      );

      expect(stats.dailyRates, [50.0, 100.0]);
      expect(stats.windowDays, 2);
    });

    test('a day with no active habits is a 0 rate, never a divide-by-zero', () {
      final stats = habitChartStats(
        stateWith(
          days: ['2024-03-14', '2024-03-15'],
          allByDay: {
            '2024-03-15': {'h1'},
          },
          successfulByDay: {
            '2024-03-15': {'h1'},
          },
        ),
      );

      expect(stats.dailyRates, [0.0, 100.0]);
    });

    test(
      'rate clamps to 100 when back-dated successes exceed the day total',
      () {
        final stats = habitChartStats(
          stateWith(
            days: ['2024-03-15'],
            allByDay: {
              '2024-03-15': {'h1', 'h2'},
            },
            successfulByDay: {
              '2024-03-15': {'h1', 'h2', 'h3'}, // 3 of 2 → capped
            },
          ),
        );

        expect(stats.dailyRates.single, 100.0);
      },
    );
  });

  group('habitChartStats — rolling average', () {
    // 7 days: a miss on day 0, then six perfect days.
    final state = () {
      final days = [
        for (var d = 8; d <= 14; d++) '2024-03-${d.toString().padLeft(2, '0')}',
      ];
      return stateWith(
        days: days,
        allByDay: {
          for (final day in days) day: <String>{'h1'},
        },
        successfulByDay: {
          for (final day in days)
            day: day == '2024-03-08' ? <String>{} : <String>{'h1'},
        },
      );
    }();

    test('early days use the partial trailing window', () {
      final stats = habitChartStats(state);
      // day0 = 0; day1 = avg(0,100) = 50; day6 = avg(0,100*6)/7 ≈ 85.7
      expect(stats.rollingAverage.first, 0.0);
      expect(stats.rollingAverage[1], 50.0);
      expect(stats.rollingAverage.last, closeTo(600 / 7, 0.001));
    });

    test('current average is the trailing 7-day mean', () {
      final stats = habitChartStats(state);
      expect(stats.currentAverage, closeTo(600 / 7, 0.001));
    });

    test('on a single 7-day window the trend is flat (no prior week)', () {
      final stats = habitChartStats(state);
      expect(stats.trendDelta, 0.0);
    });
  });

  group('habitChartStats — trend vs previous week', () {
    test('compares the last 7 days against the 7 before them', () {
      final days = [
        for (var d = 1; d <= 14; d++) '2024-03-${d.toString().padLeft(2, '0')}',
      ];
      // First week all missed (0%), second week all kept (100%).
      final stats = habitChartStats(
        stateWith(
          days: days,
          allByDay: {
            for (final day in days) day: <String>{'h1'},
          },
          successfulByDay: {
            for (var i = 0; i < days.length; i++)
              if (i >= 7) days[i]: <String>{'h1'},
          },
        ),
      );

      expect(stats.currentAverage, 100.0);
      expect(stats.trendDelta, 100.0); // 100 now − 0 prior week
    });
  });

  group('habitChartStats — days on track', () {
    test('counts days at or above the 80% target', () {
      final days = ['2024-03-13', '2024-03-14', '2024-03-15'];
      final stats = habitChartStats(
        stateWith(
          days: days,
          allByDay: {
            for (final day in days) day: <String>{'h1', 'h2'},
          },
          successfulByDay: {
            '2024-03-13': {'h1', 'h2'}, // 100 → on track
            '2024-03-14': {'h1'}, // 50 → off
            '2024-03-15': {'h1', 'h2'}, // 100 → on track
          },
        ),
      );

      expect(stats.daysOnTrack, 2);
      expect(stats.windowDays, 3);
      expect(stats.target, 80);
    });
  });

  group('habitChartStats — laggard habit', () {
    final days = ['2024-03-13', '2024-03-14', '2024-03-15'];

    test('names the worst below-target habit and its missed count', () {
      final stats = habitChartStats(
        stateWith(
          days: days,
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          allByDay: {
            for (final day in days)
              day: {habitFlossing.id, habitFlossingDueLater.id},
          },
          // Flossing kept every day; the other kept none.
          successfulByDay: {
            for (final day in days) day: {habitFlossing.id},
          },
        ),
      );

      expect(stats.laggardName, habitFlossingDueLater.name);
      expect(stats.laggardMissed, 3);
    });

    test('no laggard when every habit is at or above target', () {
      final stats = habitChartStats(
        stateWith(
          days: days,
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          allByDay: {
            for (final day in days)
              day: {habitFlossing.id, habitFlossingDueLater.id},
          },
          successfulByDay: {
            for (final day in days)
              day: {habitFlossing.id, habitFlossingDueLater.id},
          },
        ),
      );

      expect(stats.laggardName, isNull);
      expect(stats.laggardMissed, 0);
    });
  });

  group('habitChartStats — empty', () {
    test('no days yields zeroed, non-throwing stats', () {
      final stats = habitChartStats(stateWith(days: const []));

      expect(stats.dailyRates, isEmpty);
      expect(stats.rollingAverage, isEmpty);
      expect(stats.currentAverage, 0.0);
      expect(stats.trendDelta, 0.0);
      expect(stats.daysOnTrack, 0);
      expect(stats.windowDays, 0);
      expect(stats.laggardName, isNull);
    });
  });
}
