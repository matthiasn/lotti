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

    getIt<JournalDb>().watchCategories().listen((
      List<CategoryDefinition> categories,
    ) {
      categoriesById.clear();
      for (final category in categories) {
        categoriesById[category.id] = category;
      }
    });

    getIt<JournalDb>().watchHabitDefinitions().listen((
      List<HabitDefinition> habits,
    ) {
      habitsById.clear();
      for (final habit in habits) {
        habitsById[habit.id] = habit;
      }
    });
  }

  Map<String, MeasurableDataType> dataTypesById = {};
  Map<String, CategoryDefinition> categoriesById = {};
  Map<String, HabitDefinition> habitsById = {};

  MeasurableDataType? getDataTypeById(String id) {
    return dataTypesById[id];
  }

  CategoryDefinition? getCategoryById(String? id) {
    return categoriesById[id];
  }

  HabitDefinition? getHabitById(String? id) {
    return habitsById[id];
  }
}
