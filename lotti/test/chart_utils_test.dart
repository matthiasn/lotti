import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

void main() {
  List<JournalEntity> entities = [];

  void addDiscreteQuantEntity(DateTime dt, num value) {
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
          dataType: 'dataType',
          unit: 'unit',
        ),
      ),
    );
  }

  addDiscreteQuantEntity(DateTime(2022, 02, 23, 1), 1);
  addDiscreteQuantEntity(DateTime(2022, 02, 23, 2), 2);
  addDiscreteQuantEntity(DateTime(2022, 02, 23, 3), 3);
  addDiscreteQuantEntity(DateTime(2022, 02, 24, 10), 8);
  addDiscreteQuantEntity(DateTime(2022, 02, 24, 9), 9);
  addDiscreteQuantEntity(DateTime(2022, 02, 24, 8), 10);

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
    'Workout data is transformed into daily sums',
    () async {
      final aggregated = aggregateByType(
        entities,
        'HealthDataType.WORKOUT',
      );
      expect(aggregated, [
        Observation(DateTime(2022, 02, 23), 6),
        Observation(DateTime(2022, 02, 24), 27),
      ]);
    },
  );
}
