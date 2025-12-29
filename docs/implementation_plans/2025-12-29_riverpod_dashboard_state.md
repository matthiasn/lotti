# Refactor Dashboards from Bloc to Riverpod

## Status: COMPLETED (2025-12-29)

All tasks completed successfully:
- Created Riverpod providers in `lib/features/dashboards/state/dashboards_page_controller.dart`
- Updated all UI components to use Riverpod instead of Bloc
- Deleted old Bloc files from `lib/blocs/dashboards/`
- Fixed `ref.watch` inside StreamBuilder issue by adding `dashboardCategoriesProvider`
- Added comprehensive unit tests (20 test cases covering all providers)
- Added widget tests for filter modal behavior and list rendering (6 tests)
- All 26 dashboard-related tests pass
- Added CHANGELOG entry for the refactoring

## Overview
Migrate the dashboards page state management from Bloc (`lib/blocs/dashboards/`) to Riverpod (`lib/features/dashboards/state/`), following established Riverpod patterns used throughout the codebase.

## Current State

### Files to Remove (after migration complete)
- `lib/blocs/dashboards/dashboards_page_cubit.dart`
- `lib/blocs/dashboards/dashboards_page_state.dart`
- `lib/blocs/dashboards/dashboards_page_state.freezed.dart`

### Current Bloc State Structure
```dart
@freezed
class DashboardsPageState {
  List<DashboardDefinition> allDashboards;
  List<DashboardDefinition> filteredSortedDashboards;
  Set<String> selectedCategoryIds;
}
```

### Current Cubit Methods
- `toggleSelectedCategoryIds(String categoryId)` - Add/remove category from filter
- `emitState()` - Filter by categories and sort by name

## New Riverpod Implementation

### Step 1: Create Riverpod Provider

**File:** `lib/features/dashboards/state/dashboards_page_controller.dart`

```dart
// Stream provider for all active dashboards from database
@riverpod
Stream<List<DashboardDefinition>> dashboards(Ref ref) {
  final db = getIt<JournalDb>();
  return db.watchDashboards().map(
    (dashboards) => dashboards.where((d) => d.active).toList(),
  );
}

// Stateful provider for selected category IDs
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

// Computed provider for filtered and sorted dashboards
@riverpod
List<DashboardDefinition> filteredSortedDashboards(Ref ref) {
  final dashboardsAsync = ref.watch(dashboardsProvider);
  final selectedCategories = ref.watch(selectedCategoryIdsProvider);

  return dashboardsAsync.maybeWhen(
    data: (dashboards) {
      var filtered = dashboards;
      if (selectedCategories.isNotEmpty) {
        filtered = dashboards
            .where((d) => d.categoryId != null &&
                         selectedCategories.contains(d.categoryId))
            .toList();
      }
      return filtered..sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase())
      );
    },
    orElse: () => [],
  );
}
```

### Step 2: Update UI Components

**Files to update:**
- `lib/features/dashboards/ui/pages/dashboards_list_page.dart`
- `lib/features/dashboards/ui/widgets/dashboards_list.dart`
- `lib/features/dashboards/ui/widgets/dashboards_app_bar.dart`
- `lib/features/dashboards/ui/widgets/dashboards_filter.dart`

Changes:
1. Remove `BlocProvider<DashboardsPageCubit>` wrapper
2. Convert widgets to `ConsumerWidget` or `ConsumerStatefulWidget`
3. Replace `BlocBuilder` with `ref.watch()`
4. Replace `context.read<DashboardsPageCubit>().toggleSelectedCategoryIds()` with `ref.read(selectedCategoryIdsProvider.notifier).toggle()`

### Step 3: Update Tests

**Files:**
- `test/features/dashboards/ui/pages/dashboards_list_page_test.dart`

Changes:
1. Replace Bloc mocking with Riverpod provider overrides
2. Use `ProviderContainer` or `ProviderScope` overrides in tests
3. Follow pattern from existing tests like `config_flag_provider_test.dart`

### Step 4: Clean Up

1. Delete bloc files from `lib/blocs/dashboards/`
2. Remove bloc imports from barrel files if any
3. Run `fvm dart fix --apply` and `fvm dart format .`
4. Ensure analyzer passes

## Implementation Order

1. Create new Riverpod provider file with all providers
2. Run code generation: `fvm flutter pub run build_runner build`
3. Update `dashboards_list_page.dart` - remove BlocProvider, use ConsumerStatefulWidget
4. Update `dashboards_list.dart` - convert to ConsumerWidget, use ref.watch
5. Update `dashboards_app_bar.dart` - remove BlocBuilder (state not actually used in builder)
6. Update `dashboards_filter.dart` - convert BlocBuilder to Consumer, handle modal with ref
7. Update tests to use Riverpod patterns
8. Run all tests and analyzer
9. Delete old bloc files
10. Final verification

## Files Created
- `lib/features/dashboards/state/dashboards_page_controller.dart`
- `lib/features/dashboards/state/dashboards_page_controller.g.dart` (generated)
- `test/features/dashboards/state/dashboards_page_controller_test.dart` (new tests)

## Files to Modify
- `lib/features/dashboards/ui/pages/dashboards_list_page.dart` - Remove BlocProvider, convert to ConsumerStatefulWidget
- `lib/features/dashboards/ui/widgets/dashboards_list.dart` - Convert to ConsumerWidget
- `lib/features/dashboards/ui/widgets/dashboards_app_bar.dart` - Remove BlocBuilder (state not actually used in builder)
- `lib/features/dashboards/ui/widgets/dashboards_filter.dart` - Convert BlocBuilder to Consumer, handle modal with ref
- `test/features/dashboards/ui/pages/dashboards_list_page_test.dart` - Update to use Riverpod overrides

## Files to Delete
- `lib/blocs/dashboards/dashboards_page_cubit.dart`
- `lib/blocs/dashboards/dashboards_page_state.dart`
- `lib/blocs/dashboards/dashboards_page_state.freezed.dart`

## Notes

### DashboardsFilter Complexity
The `dashboards_filter.dart` widget has special handling needed:
- It passes the cubit to a modal bottom sheet via `BlocProvider.value`
- With Riverpod, the modal can simply use `ref.read(selectedCategoryIdsProvider.notifier).toggle(id)` since Riverpod providers are globally accessible
- The filter also uses a separate `StreamBuilder` for categories - this can be converted to a Riverpod provider too for consistency

### Categories Provider (Optional Enhancement)
Could also add a categories provider while refactoring:
```dart
@riverpod
Stream<List<CategoryDefinition>> categories(Ref ref) {
  return getIt<JournalDb>().watchCategories();
}
```
This would replace the `StreamBuilder` in `DashboardsFilter`.
