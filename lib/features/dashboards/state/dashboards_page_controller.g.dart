// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboards_page_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dashboardsHash() => r'51f81e6dec63cb798c3812863fed89dc5c9553d9';

/// Stream provider for all active dashboards from database.
///
/// Copied from [dashboards].
@ProviderFor(dashboards)
final dashboardsProvider =
    AutoDisposeStreamProvider<List<DashboardDefinition>>.internal(
  dashboards,
  name: r'dashboardsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dashboardsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DashboardsRef = AutoDisposeStreamProviderRef<List<DashboardDefinition>>;
String _$dashboardCategoriesHash() =>
    r'f031890b75aa1d2cd5dab8730e8b57059ffde6b4';

/// Stream provider for categories from database.
///
/// Copied from [dashboardCategories].
@ProviderFor(dashboardCategories)
final dashboardCategoriesProvider =
    AutoDisposeStreamProvider<List<CategoryDefinition>>.internal(
  dashboardCategories,
  name: r'dashboardCategoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dashboardCategoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DashboardCategoriesRef
    = AutoDisposeStreamProviderRef<List<CategoryDefinition>>;
String _$filteredSortedDashboardsHash() =>
    r'ed3e0b4a140ae72eae1d69d26ce7988687cf9e63';

/// Computed provider for dashboards filtered by selected categories and sorted
/// by name.
///
/// Copied from [filteredSortedDashboards].
@ProviderFor(filteredSortedDashboards)
final filteredSortedDashboardsProvider =
    AutoDisposeProvider<List<DashboardDefinition>>.internal(
  filteredSortedDashboards,
  name: r'filteredSortedDashboardsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredSortedDashboardsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FilteredSortedDashboardsRef
    = AutoDisposeProviderRef<List<DashboardDefinition>>;
String _$selectedCategoryIdsHash() =>
    r'16b12be0eacef16e3466381b48bc507b72da50cc';

/// Stateful provider for selected category IDs used for filtering dashboards.
///
/// Copied from [SelectedCategoryIds].
@ProviderFor(SelectedCategoryIds)
final selectedCategoryIdsProvider =
    AutoDisposeNotifierProvider<SelectedCategoryIds, Set<String>>.internal(
  SelectedCategoryIds.new,
  name: r'selectedCategoryIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedCategoryIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedCategoryIds = AutoDisposeNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
