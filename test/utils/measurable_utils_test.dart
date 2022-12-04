import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/measurable_utils.dart';

void main() {
  group('Measurable utils test', () {
    test('Ranked values for null value returns empty list.', () {
      expect(
        rankedByPopularity(measurements: null),
        <num>[],
      );
    });
    test('Ranked values for empty list of measurements returns empty list.',
        () {
      expect(
        rankedByPopularity(measurements: []),
        <num>[],
      );
    });
    test('Ranked values for empty list of measurements returns empty list.',
        () {
      final measurements = <num>[
        111,
        500,
        250,
        500,
        250,
        500,
        250,
        500,
        100,
        100,
        50,
      ]
          .map(
            (value) => MeasurementEntry(
              meta: Metadata(
                id: 'foo',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                dateFrom: DateTime.now(),
                dateTo: DateTime.now(),
              ),
              data: MeasurementData(
                value: value,
                dateFrom: DateTime.now(),
                dateTo: DateTime.now(),
                dataTypeId: 'dataTypeId',
              ),
            ),
          )
          .toList();

      expect(
        rankedByPopularity(measurements: measurements),
        <num>[500, 250, 100],
      );
    });
  });
}
