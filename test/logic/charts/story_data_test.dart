// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/charts/story_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../test_data/test_data.dart';

void main() {
  group('Story data tests - ', () {
    test(
      'daysInRange for range for week',
      () {
        expect(
          daysInRange(
            rangeStart: DateTime(2022, 7, 1),
            rangeEnd: DateTime(2022, 7, 7),
          ),
          [
            '2022-07-01',
            '2022-07-02',
            '2022-07-03',
            '2022-07-04',
            '2022-07-05',
            '2022-07-06',
          ],
        );
      },
    );

    test(
      'daysInRange for single day',
      () {
        expect(
          daysInRange(
            rangeStart: DateTime(2022, 7, 1),
            rangeEnd: DateTime(2022, 7, 2, 1),
          ),
          [
            '2022-07-01',
          ],
        );
      },
    );

    test(
      'daysInRange for longer entry',
      () {
        expect(
          daysInEntryRange(
            testDurationEntry5.meta.dateFrom,
            testDurationEntry5.meta.dateTo,
          ),
          [
            '2022-07-02',
            '2022-07-03',
            '2022-07-04',
            '2022-07-05',
          ],
        );
      },
    );

    test(
      'durationsByDayInRange for short entry',
      () {
        expect(
          durationsByDayInRange(
            testDurationEntry1.meta.dateFrom,
            testDurationEntry1.meta.dateTo,
          ),
          {
            '2022-07-03': 60.0,
          },
        );
      },
    );

    test(
      'durationsByDayInRange for start null',
      () {
        expect(
          durationsByDayInRange(
            null,
            testDurationEntry1.meta.dateTo,
          ),
          <String, num>{},
        );
      },
    );

    test(
      'durationsByDayInRange for end null',
      () {
        expect(
          durationsByDayInRange(
            testDurationEntry1.meta.dateFrom,
            null,
          ),
          <String, num>{},
        );
      },
    );

    test(
      'durationsByDayInRange for longer entry',
      () {
        expect(
          durationsByDayInRange(
            testDurationEntry5.meta.dateFrom,
            testDurationEntry5.meta.dateTo,
          ),
          {
            '2022-07-02': 120.0,
            '2022-07-03': 1440.0,
            '2022-07-04': 1440.0,
            '2022-07-05': 60.0
          },
        );
      },
    );

    test(
      'daily aggregates in range created for empty data',
      () {
        expect(
          aggregateStoryTimeSum(
            [],
            rangeStart: DateTime(2022, 7, 1),
            rangeEnd: DateTime(2022, 7, 7),
            timeframe: AggregationTimeframe.daily,
          ),
          [
            Observation(DateTime(2022, 7, 1), 0),
            Observation(DateTime(2022, 7, 2), 0),
            Observation(DateTime(2022, 7, 3), 0),
            Observation(DateTime(2022, 7, 4), 0),
            Observation(DateTime(2022, 7, 5), 0),
            Observation(DateTime(2022, 7, 6), 0),
          ],
        );
      },
    );

    test(
      'daily aggregates in range created for test data',
      () {
        expect(
          aggregateStoryTimeSum(
            [
              testDurationEntry1,
              testDurationEntry2,
              testDurationEntry3,
            ],
            rangeStart: DateTime(2022, 7, 1),
            rangeEnd: DateTime(2022, 7, 5),
            timeframe: AggregationTimeframe.daily,
          ),
          [
            Observation(DateTime(2022, 7, 1), 0),
            Observation(DateTime(2022, 7, 2), 0),
            Observation(DateTime(2022, 7, 3), 60.0),
            Observation(DateTime(2022, 7, 4), 251.55),
          ],
        );
      },
    );

    test(
      'daily aggregates handle entries stretching multiple days',
      () {
        expect(
          aggregateStoryTimeSum(
            [
              testDurationEntry4,
              testDurationEntry5,
            ],
            rangeStart: DateTime(2022, 7, 1),
            rangeEnd: DateTime(2022, 7, 6),
            timeframe: AggregationTimeframe.daily,
          ),
          [
            Observation(DateTime(2022, 7, 1), 60.0),
            Observation(DateTime(2022, 7, 2), 240.0),
            Observation(DateTime(2022, 7, 3), 1440.0),
            Observation(DateTime(2022, 7, 4), 1440.0),
            Observation(DateTime(2022, 7, 5), 60.0),
          ],
        );
      },
    );

    test(
      'daily aggregates handle entries stretching multiple days, '
      'cut off at end of range',
      () {
        expect(
          aggregateStoryTimeSum(
            [
              testDurationEntry4,
              testDurationEntry5,
            ],
            rangeStart: DateTime(2022, 7, 1),
            rangeEnd: DateTime(2022, 7, 4),
            timeframe: AggregationTimeframe.daily,
          ),
          [
            Observation(DateTime(2022, 7, 1), 60.0),
            Observation(DateTime(2022, 7, 2), 240.0),
            Observation(DateTime(2022, 7, 3), 1440.0),
          ],
        );
      },
    );

    test(
      'weekly aggregates handle entries stretching multiple days',
      () {
        expect(
          aggregateStoryWeeklyTimeSum(
            [
              testDurationEntry4,
              testDurationEntry5,
              testDurationEntry6,
            ],
            rangeStart: DateTime(2022, 6, 1),
            rangeEnd: DateTime(2022, 7, 15),
          ),
          const [
            WeeklyAggregate('2022-W22', 5880.0),
            WeeklyAggregate('2022-W23', 8700.0),
            WeeklyAggregate('2022-W24', 0),
            WeeklyAggregate('2022-W25', 0),
            WeeklyAggregate('2022-W26', 1740.0),
            WeeklyAggregate('2022-W27', 1500.0),
            WeeklyAggregate('2022-W28', 0)
          ],
        );
      },
    );

    test(
      'weekly aggregates handle entries stretching multiple days',
      () {
        expect(
          aggregateStoryWeeklyTimeSum(
            [],
            rangeStart: DateTime(2022, 6, 1),
            rangeEnd: DateTime(2022, 6, 30),
          ),
          const [
            WeeklyAggregate('2022-W22', 0),
            WeeklyAggregate('2022-W23', 0),
            WeeklyAggregate('2022-W24', 0),
            WeeklyAggregate('2022-W25', 0),
            WeeklyAggregate('2022-W26', 0),
          ],
        );
      },
    );
  });
}
