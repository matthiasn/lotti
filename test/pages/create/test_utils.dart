import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';

import '../../test_data/test_data.dart';

List<MeasurementEntry> measurementSuggestionFixture() {
  MeasurementEntry entry(String id, num value, DateTime at) => MeasurementEntry(
    meta: Metadata(
      id: id,
      createdAt: at,
      dateFrom: at,
      dateTo: at,
      updatedAt: at,
      starred: false,
      private: false,
    ),
    data: MeasurementData(
      value: value,
      dataTypeId: measurableWater.id,
      dateTo: at,
      dateFrom: at,
    ),
  );

  return [
    entry('suggestion-1', 500, DateTime(2024, 3, 15, 10, 30)),
    entry('suggestion-2', 500, DateTime(2024, 3, 14, 9)),
    entry('suggestion-3', 250, DateTime(2024, 3, 13, 8)),
  ];
}
