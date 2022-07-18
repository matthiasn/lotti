// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/charts/story_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../journal_test_data/test_data.dart';

void main() {
  group('Story data tests - ', () {
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
            MeasuredObservation(DateTime(2022, 7, 1), 0),
            MeasuredObservation(DateTime(2022, 7, 2), 0),
            MeasuredObservation(DateTime(2022, 7, 3), 0),
            MeasuredObservation(DateTime(2022, 7, 4), 0),
            MeasuredObservation(DateTime(2022, 7, 5), 0),
            MeasuredObservation(DateTime(2022, 7, 6), 0),
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
            MeasuredObservation(DateTime(2022, 7, 1), 0),
            MeasuredObservation(DateTime(2022, 7, 2), 0),
            MeasuredObservation(DateTime(2022, 7, 3), 60.0),
            MeasuredObservation(DateTime(2022, 7, 4), 251.55),
          ],
        );
      },
    );
  });
}
