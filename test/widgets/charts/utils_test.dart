import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../test_data/test_data.dart';

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
}
