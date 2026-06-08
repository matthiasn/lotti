import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados, any;
import 'package:lotti/widgets/charts/utils.dart';

import '../../test_data/test_data.dart';
import 'utils_test_helpers.dart';

void main() {
  group('Chart utils', () {
    test('Hours as int are correctly formatted', () {
      expect(
        hoursToHhMm(12),
        '12:00',
      );
    });

    test('Hours as float is rounded down', () {
      expect(
        hoursToHhMm(1.333333),
        '01:19',
      );
    });

    test('Hours as float from fraction are correctly formatted', () {
      expect(
        hoursToHhMm(2 / 3),
        '00:40',
      );
    });

    test('Hours are nullable, returning 00:00', () {
      expect(
        hoursToHhMm(null),
        '00:00',
      );
    });

    test('Hours are rounded down', () {
      expect(
        hoursToHhMm(1.999),
        '01:59',
      );
    });

    test('Minutes as int are correctly formatted', () {
      expect(
        minutesToHhMm(183),
        '03:03',
      );
    });

    test('Minutes as float are correctly formatted', () {
      expect(
        minutesToHhMm(1.3333),
        '00:01',
      );
    });

    test('Minutes are rounded down', () {
      expect(
        minutesToHhMm(1.999),
        '00:01',
      );
    });

    test('Minutes are nullable, returning 00:00', () {
      expect(
        minutesToHhMm(null),
        '00:00',
      );
    });
  });

  group('aggregateAvgByDay', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 13);

    test(
      'averages same-day measurements and skips empty days',
      () {
        final result = aggregateAvgByDay(
          [
            buildMeasurementEntry(
              id: 'a',
              timestamp: DateTime(2024, 3, 10, 9),
              value: 10,
            ),
            buildMeasurementEntry(
              id: 'b',
              timestamp: DateTime(2024, 3, 10, 18),
              value: 30,
            ),
            buildMeasurementEntry(
              id: 'c',
              timestamp: DateTime(2024, 3, 11, 12),
              value: 7,
            ),
            // 2024-03-12 intentionally has no measurement.
          ],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(result, hasLength(2));
        final byDay = {
          for (final obs in result) obs.dateTime.toIso8601String(): obs.value,
        };
        expect(byDay[DateTime(2024, 3, 10).toIso8601String()], 20.0);
        expect(byDay[DateTime(2024, 3, 11).toIso8601String()], 7);
        expect(
          byDay.containsKey(DateTime(2024, 3, 12).toIso8601String()),
          isFalse,
        );
      },
    );

    test(
      'ignores non-measurement entities',
      () {
        final result = aggregateAvgByDay(
          [
            buildMeasurementEntry(
              id: 'a',
              timestamp: DateTime(2024, 3, 10, 9),
              value: 5,
            ),
            testTextEntry, // not a MeasurementEntry — must be skipped
          ],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(result, hasLength(1));
        expect(result.single.value, 5);
      },
    );

    test('returns empty when input has no MeasurementEntry rows at all', () {
      final result = aggregateAvgByDay(
        [testTextEntry],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      expect(result, isEmpty);
    });

    test(
      'filters out measurements outside [rangeStart, rangeEnd)',
      () {
        final result = aggregateAvgByDay(
          [
            // Two days before rangeStart — must be filtered out.
            buildMeasurementEntry(
              id: 'pre',
              timestamp: DateTime(2024, 3, 8, 12),
              value: 100,
            ),
            // Inside the window.
            buildMeasurementEntry(
              id: 'in',
              timestamp: DateTime(2024, 3, 10, 12),
              value: 5,
            ),
            // On rangeEnd — must be filtered out (window is half-open).
            buildMeasurementEntry(
              id: 'on-end',
              timestamp: DateTime(2024, 3, 13),
              value: 99,
            ),
          ],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(result, hasLength(1));
        expect(result.single.dateTime, DateTime(2024, 3, 10));
        expect(result.single.value, 5);
      },
    );

    test(
      'returns empty without throwing when rangeEnd <= rangeStart — a '
      'caller passing an inverted or zero-width window should not crash',
      () {
        final result = aggregateAvgByDay(
          [
            buildMeasurementEntry(
              id: 'in',
              timestamp: DateTime(2024, 3, 10, 12),
              value: 5,
            ),
          ],
          rangeStart: DateTime(2024, 3, 13),
          rangeEnd: DateTime(2024, 3, 10),
        );
        expect(result, isEmpty);
      },
    );

    test(
      'emits observations in chronological order on shuffled input',
      () {
        final result = aggregateAvgByDay(
          [
            buildMeasurementEntry(
              id: 'c',
              timestamp: DateTime(2024, 3, 12, 9),
              value: 30,
            ),
            buildMeasurementEntry(
              id: 'a',
              timestamp: DateTime(2024, 3, 10, 9),
              value: 10,
            ),
            buildMeasurementEntry(
              id: 'b',
              timestamp: DateTime(2024, 3, 11, 9),
              value: 20,
            ),
          ],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(
          result.map((o) => o.dateTime).toList(),
          [
            DateTime(2024, 3, 10),
            DateTime(2024, 3, 11),
            DateTime(2024, 3, 12),
          ],
        );
      },
    );
  });

  group('Observation', () {
    test('toString renders dateTime and value', () {
      expect(
        Observation(DateTime(2024, 3, 15), 7).toString(),
        '${DateTime(2024, 3, 15)} 7',
      );
    });

    test('equality is value-based on dateTime and value', () {
      expect(
        Observation(DateTime(2024, 3, 15), 7),
        Observation(DateTime(2024, 3, 15), 7),
      );
      expect(
        Observation(DateTime(2024, 3, 15), 7),
        isNot(Observation(DateTime(2024, 3, 15), 8)),
      );
    });
  });

  group('ymdh', () {
    test('truncates to the beginning of the hour as ISO 8601', () {
      expect(
        ymdh(DateTime(2024, 3, 15, 14, 37, 22)),
        DateTime(2024, 3, 15, 14).toIso8601String(),
      );
    });
  });

  group('date formatters', () {
    final millis = DateTime(2024, 3, 15, 9, 5).millisecondsSinceEpoch;

    test('chartDateFormatterYMD formats a full localized date', () {
      expect(chartDateFormatterYMD(millis), 'Mar 15, 2024');
    });

    test('chartDateFormatterFull includes the time of day', () {
      expect(chartDateFormatterFull(millis), 'Mar 15, 09:05');
    });
  });

  group('aggregateSumByDay', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 13);

    test('sums same-day values and emits zero for empty days', () {
      final result = aggregateSumByDay(
        [
          buildMeasurementEntry(
            id: 'a',
            timestamp: DateTime(2024, 3, 10, 9),
            value: 4,
          ),
          buildMeasurementEntry(
            id: 'b',
            timestamp: DateTime(2024, 3, 10, 18),
            value: 6,
          ),
          testTextEntry, // non-measurement is ignored
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final byDay = {
        for (final obs in result) obs.dateTime: obs.value,
      };
      expect(byDay[DateTime(2024, 3, 10)], 10);
      expect(byDay[DateTime(2024, 3, 11)], 0);
      expect(byDay[DateTime(2024, 3, 12)], 0);
    });

    Glados(any.sumByDayScenario, ExploreConfig(numRuns: 120)).test(
      "emits one observation per range day summing that day's values",
      (scenario) {
        final result = aggregateSumByDay(
          scenario.entities,
          rangeStart: scenario.rangeStart,
          rangeEnd: scenario.rangeEnd,
        );
        expect(result, scenario.expected, reason: '$scenario');
      },
      tags: 'glados',
    );
  });

  group('aggregateSumByHour', () {
    test('sums same-hour values and emits zero for empty hours', () {
      final result = aggregateSumByHour(
        [
          buildMeasurementEntry(
            id: 'a',
            timestamp: DateTime(2024, 3, 10, 9, 15),
            value: 2,
          ),
          buildMeasurementEntry(
            id: 'b',
            timestamp: DateTime(2024, 3, 10, 9, 45),
            value: 3,
          ),
          testTextEntry, // ignored
        ],
        rangeStart: DateTime(2024, 3, 10, 9),
        rangeEnd: DateTime(2024, 3, 10, 12),
      );

      final byHour = {
        for (final obs in result) obs.dateTime: obs.value,
      };
      expect(byHour[DateTime(2024, 3, 10, 9)], 5);
      expect(byHour[DateTime(2024, 3, 10, 10)], 0);
      expect(byHour[DateTime(2024, 3, 10, 11)], 0);
    });
  });

  group('aggregateMaxByDay', () {
    test('keeps the per-day maximum and emits zero for empty days', () {
      final result = aggregateMaxByDay(
        [
          buildMeasurementEntry(
            id: 'a',
            timestamp: DateTime(2024, 3, 10, 9),
            value: 4,
          ),
          buildMeasurementEntry(
            id: 'b',
            timestamp: DateTime(2024, 3, 10, 18),
            value: 9,
          ),
          buildMeasurementEntry(
            id: 'c',
            timestamp: DateTime(2024, 3, 10, 20),
            value: 2,
          ),
          testTextEntry, // ignored
        ],
        rangeStart: DateTime(2024, 3, 10),
        rangeEnd: DateTime(2024, 3, 12),
      );

      final byDay = {
        for (final obs in result) obs.dateTime: obs.value,
      };
      expect(byDay[DateTime(2024, 3, 10)], 9);
      expect(byDay[DateTime(2024, 3, 11)], 0);
    });
  });

  group('aggregateMeasurementNone', () {
    test(
      'maps each measurement to an observation and drops other entities',
      () {
        final result = aggregateMeasurementNone([
          buildMeasurementEntry(
            id: 'a',
            timestamp: DateTime(2024, 3, 10, 9),
            value: 4,
          ),
          testTextEntry, // ignored via orElse
          buildMeasurementEntry(
            id: 'b',
            timestamp: DateTime(2024, 3, 11, 9),
            value: 8,
          ),
        ]);

        expect(result, hasLength(2));
        expect(result[0].dateTime, DateTime(2024, 3, 10, 9));
        expect(result[0].value, 4);
        expect(result[1].value, 8);
      },
    );
  });

  group('habitSorter', () {
    test('returns 0 when priority, schedule, and name all tie', () {
      // Same name, both unscheduled and unprioritised → every comparator ties,
      // exercising the firstWhere orElse fallback.
      final twin = habitFlossing.copyWith(id: 'a-different-id');
      expect(habitSorter(habitFlossing, twin), 0);
    });
  });

  // -------------------------------------------------------------------------
  // aggregateAvgByDay — Glados property test
  //
  // Property: for any random set of measurements in [rangeStart, rangeEnd),
  //   • output length equals the number of distinct days that carry at least
  //     one measurement (days with count == 0 are omitted),
  //   • each emitted Observation.value equals the arithmetic mean of all
  //     measurements on that day.
  // -------------------------------------------------------------------------
  group('aggregateAvgByDay — Glados properties', () {
    Glados(any.avgByDayScenario, ExploreConfig(numRuns: 120)).test(
      'output length equals distinct measured-day count and '
      'values equal per-day arithmetic mean',
      (scenario) {
        final result = aggregateAvgByDay(
          scenario.entities,
          rangeStart: scenario.rangeStart,
          rangeEnd: scenario.rangeEnd,
        );

        // Result must contain exactly the days that have measurements.
        expect(
          result,
          hasLength(scenario.measuredDayCount),
          reason: '$scenario',
        );

        // Each observation must equal the per-day arithmetic mean.
        for (final obs in result) {
          final dayString = obs.dateTime.toIso8601String().substring(0, 10);
          final expected = scenario.expectedMeanForDay[dayString];
          expect(
            expected,
            isNotNull,
            reason: 'day $dayString not in expected map — $scenario',
          );
          expect(
            obs.value,
            closeTo(expected!, 1e-9),
            reason: 'mean mismatch for $dayString — $scenario',
          );
        }
      },
      tags: 'glados',
    );
  });
}
