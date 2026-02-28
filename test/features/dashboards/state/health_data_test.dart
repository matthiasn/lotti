import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../test_utils.dart';

void main() {
  group('aggregateNone', () {
    test('returns one observation per quantitative entity', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 10),
          value: 72.5,
          dataType: 'HealthDataType.WEIGHT',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16, 11),
          value: 73.0,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateNone(entities, 'HealthDataType.WEIGHT');

      expect(result, hasLength(2));
      expect(result[0].dateTime, DateTime(2024, 3, 15, 10));
      expect(result[0].value, 72.5);
      expect(result[1].dateTime, DateTime(2024, 3, 16, 11));
      expect(result[1].value, 73.0);
    });

    test('multiplies by 100 for PERCENTAGE types', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15),
          value: 0.25,
          dataType: 'HealthDataType.BODY_FAT_PERCENTAGE',
        ),
      ];

      final result =
          aggregateNone(entities, 'HealthDataType.BODY_FAT_PERCENTAGE');

      expect(result, hasLength(1));
      expect(result[0].value, 25.0);
    });

    test('does not multiply for non-PERCENTAGE types', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15),
          value: 72.0,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateNone(entities, 'HealthDataType.WEIGHT');

      expect(result[0].value, 72.0);
    });

    test('returns empty list for empty entities', () {
      final result = aggregateNone([], 'HealthDataType.WEIGHT');
      expect(result, isEmpty);
    });
  });

  group('aggregateDailyMax', () {
    test('takes max value per calendar day', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 8),
          value: 5000,
          dataType: 'cumulative_step_count',
          id: 'a',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 18),
          value: 12000,
          dataType: 'cumulative_step_count',
          id: 'b',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16, 20),
          value: 8000,
          dataType: 'cumulative_step_count',
          id: 'c',
        ),
      ];

      final result = aggregateDailyMax(entities);

      expect(result, hasLength(2));

      final day15 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 15),
      );
      expect(day15.value, 12000);

      final day16 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 16),
      );
      expect(day16.value, 8000);
    });

    test('returns empty list for empty entities', () {
      expect(aggregateDailyMax([]), isEmpty);
    });
  });

  group('aggregateDailySum', () {
    test('sums values per calendar day', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 8),
          value: 30,
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          id: 'a',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 9),
          value: 20,
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          id: 'b',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16, 10),
          value: 45,
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          id: 'c',
        ),
      ];

      final result = aggregateDailySum(entities);

      expect(result, hasLength(2));

      final day15 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 15),
      );
      expect(day15.value, 50);

      final day16 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 16),
      );
      expect(day16.value, 45);
    });

    test('returns empty list for empty entities', () {
      expect(aggregateDailySum([]), isEmpty);
    });
  });

  group('transformToHours', () {
    test('divides each value by 60', () {
      final observations = [
        Observation(DateTime(2024, 3, 15), 120),
        Observation(DateTime(2024, 3, 16), 90),
      ];

      final result = transformToHours(observations);

      expect(result, hasLength(2));
      expect(result[0].value, 2.0);
      expect(result[1].value, 1.5);
    });

    test('preserves date times', () {
      final dt = DateTime(2024, 3, 15, 12);
      final result = transformToHours([Observation(dt, 60)]);
      expect(result[0].dateTime, dt);
    });

    test('returns empty list for empty input', () {
      expect(transformToHours([]), isEmpty);
    });
  });

  group('aggregateByType', () {
    test('routes to aggregateNone for none aggregation type', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 10),
          value: 72.5,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateByType(entities, 'HealthDataType.WEIGHT');

      expect(result, hasLength(1));
      expect(result[0].value, 72.5);
    });

    test('routes to aggregateDailyMax for dailyMax aggregation type', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 8),
          value: 5000,
          dataType: 'cumulative_step_count',
          id: 'a',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 18),
          value: 12000,
          dataType: 'cumulative_step_count',
          id: 'b',
        ),
      ];

      final result = aggregateByType(entities, 'cumulative_step_count');

      expect(result, hasLength(1));
      expect(result[0].value, 12000);
    });

    test(
      'routes to dailyTimeSum and transforms to hours',
      () {
        final entities = [
          makeQuantitativeEntry(
            dateFrom: DateTime(2024, 3, 15),
            value: 120,
            dataType: 'HealthDataType.SLEEP_ASLEEP',
          ),
        ];

        final result = aggregateByType(entities, 'HealthDataType.SLEEP_ASLEEP');

        expect(result, hasLength(1));
        expect(result[0].value, 2.0);
      },
    );

    test('returns empty list for unknown data type', () {
      final result = aggregateByType([], 'UNKNOWN_TYPE');
      expect(result, isEmpty);
    });
  });

  group('colorByValueAndType', () {
    test('returns default color when config is null', () {
      final obs = Observation(DateTime(2024, 3, 15), 10000);
      final color = colorByValueAndType(obs, null);
      expect(color, isA<Color>());
    });

    test('returns default color when colorByValue is null', () {
      final config = HealthTypeConfig(
        displayName: 'Weight',
        healthType: 'HealthDataType.WEIGHT',
        chartType: HealthChartType.lineChart,
        aggregationType: HealthAggregationType.none,
        unit: 'kg',
      );
      final obs = Observation(DateTime(2024, 3, 15), 72);
      final color = colorByValueAndType(obs, config);
      expect(color, isA<Color>());
    });

    test('selects color based on threshold', () {
      final config = HealthTypeConfig(
        displayName: 'Steps',
        healthType: 'cumulative_step_count',
        chartType: HealthChartType.barChart,
        aggregationType: HealthAggregationType.dailyMax,
        unit: 'steps',
        colorByValue: {
          10000: '#82E6CE',
          6000: '#C4ECE2',
          0: '#FF9595',
        },
      );

      // Above 10000 → should get '#82E6CE'
      final highObs = Observation(DateTime(2024, 3, 15), 15000);
      final highColor = colorByValueAndType(highObs, config);
      expect(highColor, isA<Color>());

      // Between 6000 and 10000 → should get '#C4ECE2'
      final midObs = Observation(DateTime(2024, 3, 15), 7000);
      final midColor = colorByValueAndType(midObs, config);
      expect(midColor, isA<Color>());

      // Below 6000 → should get '#FF9595'
      final lowObs = Observation(DateTime(2024, 3, 15), 3000);
      final lowColor = colorByValueAndType(lowObs, config);
      expect(lowColor, isA<Color>());

      // All three colors should be different
      expect(highColor, isNot(equals(lowColor)));
      expect(highColor, isNot(equals(midColor)));
      expect(midColor, isNot(equals(lowColor)));
    });
  });

  group('findExtreme', () {
    test('returns 0 for empty observations', () {
      expect(findExtreme([], (a, b) => a > b ? a : b), 0.0);
    });

    test('finds extreme using given function', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), 10),
        Observation(DateTime(2024, 3, 16), 5),
        Observation(DateTime(2024, 3, 17), 20),
      ];
      // Use max
      final result = findExtreme(obs, (a, b) => a > b ? a : b);
      expect(result, 20);
    });
  });

  group('findMin', () {
    test('returns 0 for empty list', () {
      expect(findMin([]), 0.0);
    });

    test('finds minimum value', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), 10),
        Observation(DateTime(2024, 3, 16), 3),
        Observation(DateTime(2024, 3, 17), 7),
      ];
      expect(findMin(obs), 3);
    });

    test('works with single observation', () {
      final obs = [Observation(DateTime(2024, 3, 15), 42)];
      expect(findMin(obs), 42);
    });
  });

  group('findMax', () {
    test('returns 0 for empty list', () {
      expect(findMax([]), 0.0);
    });

    test('finds maximum value', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), 10),
        Observation(DateTime(2024, 3, 16), 25),
        Observation(DateTime(2024, 3, 17), 7),
      ];
      expect(findMax(obs), 25);
    });

    test('works with negative values', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), -10),
        Observation(DateTime(2024, 3, 16), -3),
        Observation(DateTime(2024, 3, 17), -7),
      ];
      expect(findMax(obs), -3);
    });
  });
}
