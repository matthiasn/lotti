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
      // Prune stale category keys from label lookup when categories change
      labelsByCategoryId.removeWhere(
        (catId, _) => !categoriesById.containsKey(catId),
      );
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

      // Rebuild label lookup buckets
      labelsByCategoryId.clear();
      _globalLabels.clear();
      for (final label in labels) {
        if (label.deletedAt != null) continue;
        final cats = label.applicableCategoryIds;
        if (cats == null || cats.isEmpty) {
          _globalLabels.add(label);
        } else {
          for (final catId in cats) {
            labelsByCategoryId
                .putIfAbsent(catId, () => <LabelDefinition>[])
                .add(label);
          }
        }
      }
      // Sort buckets by label name (case-insensitive)
      _globalLabels
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final entry in labelsByCategoryId.entries) {
        entry.value.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      // Notify listeners that labels changed so task views can refresh
      final locator = getIt;
      if (locator.isRegistered<UpdateNotifications>()) {
        locator<UpdateNotifications>().notify({'LABELS_UPDATED'});
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
  Map<String, List<LabelDefinition>> labelsByCategoryId = {};
  final List<LabelDefinition> _globalLabels = [];
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

  List<LabelDefinition> get globalLabels => List.unmodifiable(_globalLabels);

  /// Returns union of global labels and labels scoped to [categoryId],
  /// optionally filtering private entries based on [includePrivate].
  List<LabelDefinition> availableLabelsForCategory(
    String? categoryId, {
    bool? includePrivate,
  }) {
    final allowPrivate = includePrivate ?? _showPrivateEntries;
    final dedup = <String, LabelDefinition>{};
    bool isVisible(LabelDefinition l) =>
        l.deletedAt == null && (allowPrivate || !(l.private ?? false));

    for (final l in _globalLabels.where(isVisible)) {
      dedup[l.id] = l;
    }
    if (categoryId != null) {
      final bucket =
          labelsByCategoryId[categoryId] ?? const <LabelDefinition>[];
      for (final l in bucket.where(isVisible)) {
        dedup[l.id] = l;
      }
    }
    final res = dedup.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return res;
  }

  /// Pure helper used by reactive providers to compute category-scoped labels
  /// from an arbitrary [all] set (e.g., stream-provided list), independent of
  /// internal cache state.
  ///
  /// Note: PromptBuilderHelper contains a local copy of this logic to avoid a
  /// hard test-time dependency on GetIt/EntitiesCacheService when assembling
  /// prompt JSON. If you change scoping rules here, mirror the change in
  /// PromptBuilderHelper._filterLabelsForCategory.
  List<LabelDefinition> filterLabelsForCategory(
    List<LabelDefinition> all,
    String? categoryId, {
    bool? includePrivate,
  }) {
    final allowPrivate = includePrivate ?? _showPrivateEntries;
    final dedup = <String, LabelDefinition>{};
    for (final l in all) {
      if (l.deletedAt != null) continue;
      if (!allowPrivate && (l.private ?? false)) continue;
      final cats = l.applicableCategoryIds;
      final isGlobal = cats == null || cats.isEmpty;
      final inCategory =
          categoryId != null && (cats?.contains(categoryId) ?? false);
      if (isGlobal || inCategory) {
        dedup[l.id] = l;
      }
    }
    final res = dedup.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return res;
  }
}
