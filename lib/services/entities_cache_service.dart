import 'dart:async';

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/services/db_notification.dart';

class EntitiesCacheService {
  EntitiesCacheService({
    required JournalDb journalDb,
    required UpdateNotifications updateNotifications,
  })  : _journalDb = journalDb,
        _updateNotifications = updateNotifications;

  final JournalDb _journalDb;
  final UpdateNotifications _updateNotifications;
  StreamSubscription<Set<String>>? _notificationSub;

  Map<String, MeasurableDataType> dataTypesById = {};
  Map<String, CategoryDefinition> categoriesById = {};
  Map<String, HabitDefinition> habitsById = {};
  Map<String, DashboardDefinition> dashboardsById = {};
  Map<String, LabelDefinition> labelsById = {};
  Map<String, TagEntity> tagsById = {};
  Map<String, List<LabelDefinition>> labelsByCategoryId = {};
  final List<LabelDefinition> _globalLabels = [];
  bool _showPrivateEntries = false;

  // Per-type fetch serialization flags
  bool _measurablesLoading = false;
  bool _measurablesPending = false;
  bool _categoriesLoading = false;
  bool _categoriesPending = false;
  bool _habitsLoading = false;
  bool _habitsPending = false;
  bool _dashboardsLoading = false;
  bool _dashboardsPending = false;
  bool _labelsLoading = false;
  bool _labelsPending = false;
  bool _tagsLoading = false;
  bool _tagsPending = false;

  bool get showPrivateEntries => _showPrivateEntries;

  /// Initializes the cache. Must be awaited before the service is used.
  ///
  /// Subscribes to notifications BEFORE the initial fetch so that any
  /// writes occurring during the fetch will trigger a subsequent refetch.
  Future<void> init() async {
    _notificationSub =
        _updateNotifications.updateStream.listen(_onNotification);

    await Future.wait([
      _loadMeasurables(),
      _loadCategories(),
      _loadHabits(),
      _loadDashboards(),
      _loadLabels(),
      _loadTags(),
      _loadPrivateFlag(),
    ]);
  }

  void _onNotification(Set<String> ids) {
    final needCategories = ids.contains(categoriesNotification) ||
        ids.contains(privateToggleNotification);
    final needHabits = ids.contains(habitsNotification) ||
        ids.contains(privateToggleNotification);
    final needDashboards = ids.contains(dashboardsNotification) ||
        ids.contains(privateToggleNotification);
    final needMeasurables = ids.contains(measurablesNotification) ||
        ids.contains(privateToggleNotification);
    final needLabels = ids.contains(labelsNotification) ||
        ids.contains(privateToggleNotification);
    final needTags = ids.contains(tagsNotification) ||
        ids.contains(privateToggleNotification);

    if (ids.contains(privateToggleNotification)) {
      _loadPrivateFlag();
    }
    if (needCategories) _loadCategories();
    if (needHabits) _loadHabits();
    if (needDashboards) _loadDashboards();
    if (needMeasurables) _loadMeasurables();
    if (needLabels) _loadLabels();
    if (needTags) _loadTags();
  }

  Future<void> _loadMeasurables() async {
    if (_measurablesLoading) {
      _measurablesPending = true;
      return;
    }
    _measurablesLoading = true;
    try {
      final items = await _journalDb.getAllMeasurableDataTypes();
      dataTypesById.clear();
      for (final item in items) {
        dataTypesById[item.id] = item;
      }
    } finally {
      _measurablesLoading = false;
      if (_measurablesPending) {
        _measurablesPending = false;
        await _loadMeasurables();
      }
    }
  }

  Future<void> _loadCategories() async {
    if (_categoriesLoading) {
      _categoriesPending = true;
      return;
    }
    _categoriesLoading = true;
    try {
      final items = await _journalDb.getAllCategories();
      categoriesById.clear();
      for (final item in items) {
        categoriesById[item.id] = item;
      }
      // Prune stale category keys from label lookup when categories change
      labelsByCategoryId.removeWhere(
        (catId, _) => !categoriesById.containsKey(catId),
      );
    } finally {
      _categoriesLoading = false;
      if (_categoriesPending) {
        _categoriesPending = false;
        await _loadCategories();
      }
    }
  }

  Future<void> _loadHabits() async {
    if (_habitsLoading) {
      _habitsPending = true;
      return;
    }
    _habitsLoading = true;
    try {
      final items = await _journalDb.getAllHabitDefinitions();
      habitsById.clear();
      for (final item in items) {
        habitsById[item.id] = item;
      }
    } finally {
      _habitsLoading = false;
      if (_habitsPending) {
        _habitsPending = false;
        await _loadHabits();
      }
    }
  }

  Future<void> _loadDashboards() async {
    if (_dashboardsLoading) {
      _dashboardsPending = true;
      return;
    }
    _dashboardsLoading = true;
    try {
      final items = await _journalDb.getAllDashboards();
      dashboardsById.clear();
      for (final item in items) {
        dashboardsById[item.id] = item;
      }
    } finally {
      _dashboardsLoading = false;
      if (_dashboardsPending) {
        _dashboardsPending = false;
        await _loadDashboards();
      }
    }
  }

  Future<void> _loadLabels() async {
    if (_labelsLoading) {
      _labelsPending = true;
      return;
    }
    _labelsLoading = true;
    try {
      final labels = await _journalDb.getAllLabelDefinitions();
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
      _globalLabels.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      for (final entry in labelsByCategoryId.entries) {
        entry.value.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      }
    } finally {
      _labelsLoading = false;
      if (_labelsPending) {
        _labelsPending = false;
        await _loadLabels();
      }
    }
  }

  Future<void> _loadTags() async {
    if (_tagsLoading) {
      _tagsPending = true;
      return;
    }
    _tagsLoading = true;
    try {
      final items = await _journalDb.getAllTags();
      tagsById.clear();
      for (final item in items) {
        tagsById[item.id] = item;
      }
    } finally {
      _tagsLoading = false;
      if (_tagsPending) {
        _tagsPending = false;
        await _loadTags();
      }
    }
  }

  Future<void> _loadPrivateFlag() async {
    _showPrivateEntries = await _journalDb.getConfigFlag('private');
  }

  /// Cancels the notification subscription. Call when disposing the service.
  void dispose() {
    _notificationSub?.cancel();
  }

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
  /// Privacy filtering is handled at the database layer via config flags.
  List<LabelDefinition> filterLabelsForCategory(
    List<LabelDefinition> all,
    String? categoryId,
  ) {
    final dedup = <String, LabelDefinition>{};
    for (final l in all) {
      if (l.deletedAt != null) continue;
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
