import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

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

    getIt<JournalDb>().watchLabelDefinitions().listen((
      List<LabelDefinition> labels,
    ) {
      labelsById.clear();
      for (final label in labels) {
        labelsById[label.id] = label;
      }
      // Notify listeners that labels changed so task views can refresh
      if (getIt.isRegistered<UpdateNotifications>()) {
        getIt<UpdateNotifications>().notify({'LABELS_UPDATED'});
      }
    });

    getIt<JournalDb>().watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
    });
  }

  Map<String, MeasurableDataType> dataTypesById = {};
  Map<String, CategoryDefinition> categoriesById = {};
  Map<String, HabitDefinition> habitsById = {};
  Map<String, DashboardDefinition> dashboardsById = {};
  Map<String, LabelDefinition> labelsById = {};
  bool _showPrivateEntries = false;

  bool get showPrivateEntries => _showPrivateEntries;

  List<CategoryDefinition> get sortedCategories {
    final res = categoriesById.values.where((e) => e.active).toList()
      ..sortBy((category) => category.name.toLowerCase());
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

  LabelDefinition? getLabelById(String? id) {
    if (id == null) {
      return null;
    }
    return labelsById[id];
  }

  List<LabelDefinition> get sortedLabels {
    final res = labelsById.values
        .where((label) => label.deletedAt == null)
        .where((label) => _showPrivateEntries || !(label.private ?? false))
        .toList()
      ..sortBy((label) => label.name.toLowerCase());
    return res;
  }
}
