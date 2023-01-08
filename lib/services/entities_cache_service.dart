import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class EntitiesCacheService {
  EntitiesCacheService() {
    getIt<JournalDb>().watchMeasurableDataTypes().listen((
      List<MeasurableDataType> dataTypes,
    ) {
      dataTypesById.clear();
      for (final dataType in dataTypes) {
        dataTypesById[dataType.id] = dataType;
      }
    });
  }

  Map<String, MeasurableDataType> dataTypesById = {};

  MeasurableDataType? getDataTypeById(String id) {
    return dataTypesById[id];
  }
}
