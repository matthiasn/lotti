import 'package:collection/collection.dart';
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

    getIt<JournalDb>().watchDashboards().listen((
      List<DashboardDefinition> dashboards,
    ) {
      dashboardsById.clear();
      for (final dashboard in dashboards) {
        dashboardsById[dashboard.id] = dashboard;
      }
    });
  }

  Map<String, MeasurableDataType> dataTypesById = {};
  Map<String, CategoryDefinition> categoriesById = {};
  Map<String, HabitDefinition> habitsById = {};
  Map<String, DashboardDefinition> dashboardsById = {};

  List<CategoryDefinition> get sortedCategories {
    final res = categoriesById.values.where((e) => e.active).toList()
      ..sortBy((category) => category.name);
    return res;
  }

  MeasurableDataType? getDataTypeById(String id) {
    return dataTypesById[id];
  }

  CategoryDefinition? getCategoryById(String? id) {
    return categoriesById[id];
  }

  HabitDefinition? getHabitById(String? id) {
    return habitsById[id];
  }

  DashboardDefinition? getDashboardById(String? id) {
    return dashboardsById[id];
  }
}
