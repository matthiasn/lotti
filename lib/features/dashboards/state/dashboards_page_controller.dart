// ignore_for_file: specify_nonobvious_property_types

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// Stream provider for all active dashboards from database.
final StreamProvider<List<DashboardDefinition>> dashboardsProvider =
    StreamProvider.autoDispose<List<DashboardDefinition>>((ref) {
  final db = getIt<JournalDb>();
  return db.watchDashboards().map(
        (dashboards) => dashboards.where((d) => d.active).toList(),
      );
});

/// Stateful provider for selected category IDs used for filtering dashboards.
final selectedCategoryIdsProvider =
    NotifierProvider.autoDispose<SelectedCategoryIds, Set<String>>(
  SelectedCategoryIds.new,
);

class SelectedCategoryIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String categoryId) {
    if (state.contains(categoryId)) {
      state = {...state}..remove(categoryId);
    } else {
      state = {...state, categoryId};
    }
  }

  void clear() {
    state = {};
  }
}

/// Stream provider for categories from database.
final StreamProvider<List<CategoryDefinition>> dashboardCategoriesProvider =
    StreamProvider.autoDispose<List<CategoryDefinition>>((ref) {
  final db = getIt<JournalDb>();
  return db.watchCategories();
});

/// Computed provider for dashboards filtered by selected categories and sorted
/// by name.
final Provider<List<DashboardDefinition>> filteredSortedDashboardsProvider =
    Provider.autoDispose<List<DashboardDefinition>>((ref) {
  final dashboardsAsync = ref.watch(dashboardsProvider);
  final selectedCategories = ref.watch(selectedCategoryIdsProvider);

  return dashboardsAsync.maybeWhen(
    data: (dashboards) {
      final filtered = selectedCategories.isNotEmpty
          ? dashboards.where((d) => selectedCategories.contains(d.categoryId))
          : dashboards;
      return filtered.sortedBy((item) => item.name.toLowerCase());
    },
    orElse: () => [],
  );
});
