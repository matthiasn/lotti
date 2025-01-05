import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

void addDiscreteQuantEntity({
  required DateTime dt,
  required String dataType,
  required num value,
  required List<JournalEntity> entities,
}) {
  entities.add(
    JournalEntity.quantitative(
      meta: Metadata(
        createdAt: dt,
        id: 'test-id',
        dateTo: dt,
        dateFrom: dt,
        updatedAt: dt,
      ),
      data: QuantitativeData.discreteQuantityData(
        dateFrom: dt,
        dateTo: dt,
        value: value,
        dataType: dataType,
        unit: 'unit',
      ),
    ),
  );
}

void main() {
  final entities = <JournalEntity>[];

  addDiscreteQuantEntity(
    dt: DateTime(2022, 02, 23, 1),
    dataType: '',
    value: 1,
    entities: entities,
  );

  addDiscreteQuantEntity(
    dt: DateTime(2022, 02, 23, 2),
    dataType: '',
    value: 2,
    entities: entities,
  );

  addDiscreteQuantEntity(
    dt: DateTime(2022, 02, 23, 3),
    dataType: '',
    value: 3,
    entities: entities,
  );

  addDiscreteQuantEntity(
    dt: DateTime(2022, 02, 24, 10),
    dataType: '',
    value: 8,
    entities: entities,
  );

  addDiscreteQuantEntity(
    dt: DateTime(2022, 02, 24, 9),
    dataType: '',
    value: 9,
    entities: entities,
  );

  addDiscreteQuantEntity(
    dt: DateTime(2022, 02, 24, 8),
    dataType: '',
    value: 10,
    entities: entities,
  );

  test(
    'Weight data is transformed into discrete values',
    () async {
      final aggregated = aggregateByType(
        entities,
        'HealthDataType.WEIGHT',
      );
      expect(aggregated, [
        Observation(DateTime(2022, 02, 23, 1), 1),
        Observation(DateTime(2022, 02, 23, 2), 2),
        Observation(DateTime(2022, 02, 23, 3), 3),
        Observation(DateTime(2022, 02, 24, 10), 8),
        Observation(DateTime(2022, 02, 24, 9), 9),
        Observation(DateTime(2022, 02, 24, 8), 10),
      ]);
    },
  );

  test(
    'Percentages are multiplied by a hundred',
    () async {
      final percentageEntities = <JournalEntity>[];

      addDiscreteQuantEntity(
        dt: DateTime(2022, 2, 6),
        dataType: 'HealthDataType.BODY_FAT_PERCENTAGE',
        value: 0.25,
        entities: percentageEntities,
      );

      addDiscreteQuantEntity(
        dt: DateTime(2022, 3, 6),
        dataType: 'HealthDataType.BODY_FAT_PERCENTAGE',
        value: 0.2,
        entities: percentageEntities,
      );

      final aggregated = aggregateByType(
        percentageEntities,
        'HealthDataType.BODY_FAT_PERCENTAGE',
      );
      expect(aggregated, [
        Observation(DateTime(2022, 2, 6), 25.0),
        Observation(DateTime(2022, 3, 6), 20.0),
      ]);
    },
  );

  test(
    'Steps data is transformed into daily max values',
    () async {
      final aggregated = aggregateByType(
        entities,
        'cumulative_step_count',
      );
      expect(aggregated, [
        Observation(DateTime(2022, 02, 23), 3),
        Observation(DateTime(2022, 02, 24), 10),
      ]);
    },
  );

  test(
    'Sleep data is transformed into daily sums',
    () async {
      final aggregated = aggregateByType(
        entities,
        'HealthDataType.SLEEP_ASLEEP',
      );
      expect(aggregated, [
        Observation(DateTime(2022, 02, 23), 0.1),
        Observation(DateTime(2022, 02, 24), 0.45),
      ]);
    },
  );

  test(
    'Chart color is generated for observation',
    () async {
      final config = HealthTypeConfig(
        displayName: 'Steps',
        healthType: 'cumulative_step_count',
        chartType: HealthChartType.barChart,
        aggregationType: HealthAggregationType.dailyMax,
        unit: 'steps',
        colorByValue: {
          10000: '#4BB543',
          6000: '#FF5F1F',
          0: '#FC100D',
        },
      );

      final now = DateTime.now();

      expect(
        colorFromCssHex('#FC100D'),
        colorByValueAndType(Observation(now, 1000), config),
      );

      expect(
        colorFromCssHex('#FF5F1F'),
        colorByValueAndType(Observation(now, 7000), config),
      );

      expect(
        colorFromCssHex('#4BB543'),
        colorByValueAndType(Observation(now, 17000), config),
      );
    },
  );

  test(
    'Min and max functions find the respective values',
    () async {
      final observations = <Observation>[
        Observation(DateTime(2022, 3), 6),
        Observation(DateTime(2022, 3), 27),
        Observation(DateTime(2022, 3), 1),
        Observation(DateTime(2022, 3), 99),
        Observation(DateTime(2022, 3), 42),
      ];
      expect(findMin(observations), 1);
      expect(findMax(observations), 99);
    },
  );

  test(
    'Determine if min or max are near a range',
    () async {
      expect(
        nearRange(
          min: 28,
          max: 29.5,
          lowerBound: 30,
          upperBound: 34.99,
        ),
        true,
      );
      expect(
        nearRange(
          min: 28,
          max: 29.5,
          lowerBound: 35,
          upperBound: 39.99,
        ),
        false,
      );
    },
  );
}
