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
    test(
      'Ranked values for empty list of measurements returns empty list.',
      () {
        expect(
          rankedByPopularity(measurements: []),
          <num>[],
        );
      },
    );
    test(
      'Ranked values for empty list of measurements returns empty list.',
      () {
        final measurements = testMeasurements(
          <num>[111, 500, 250, 500, 250, 500, 250, 500, 100, 100, 50],
        );

        expect(
          rankedByPopularity(measurements: measurements),
          <num>[500, 250, 100],
        );
      },
    );
  });
}

List<MeasurementEntry> testMeasurements(List<num> values) {
  final testDate = DateTime(2024, 3, 15, 10, 30);
  return values
      .map(
        (value) => MeasurementEntry(
          meta: Metadata(
            id: 'foo',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: MeasurementData(
            value: value,
            dateFrom: testDate,
            dateTo: testDate,
            dataTypeId: 'dataTypeId',
          ),
        ),
      )
      .toList();
}
