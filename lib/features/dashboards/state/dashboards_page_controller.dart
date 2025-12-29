import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboards_page_controller.g.dart';

/// Stream provider for all active dashboards from database.
@riverpod
Stream<List<DashboardDefinition>> dashboards(Ref ref) {
  final db = getIt<JournalDb>();
  return db.watchDashboards().map(
        (dashboards) => dashboards.where((d) => d.active).toList(),
      );
}

/// Stateful provider for selected category IDs used for filtering dashboards.
@riverpod
class SelectedCategoryIds extends _$SelectedCategoryIds {
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

/// Computed provider for dashboards filtered by selected categories and sorted
/// by name.
@riverpod
List<DashboardDefinition> filteredSortedDashboards(Ref ref) {
  final dashboardsAsync = ref.watch(dashboardsProvider);
  final selectedCategories = ref.watch(selectedCategoryIdsProvider);

  return dashboardsAsync.maybeWhen(
    data: (dashboards) {
      final filtered = selectedCategories.isNotEmpty
          ? dashboards
              .where((d) => selectedCategories.contains(d.categoryId))
              .toList()
          : dashboards;
      return filtered.sortedBy((item) => item.name.toLowerCase());
    },
    orElse: () => [],
  );
}
