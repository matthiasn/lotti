// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_by_category_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$timeByDayChartHash() => r'74bb3ef819bea42d16baefda30f192ee4b2561f0';

/// See also [timeByDayChart].
@ProviderFor(timeByDayChart)
final timeByDayChartProvider =
    AutoDisposeFutureProvider<List<TimeByDayAndCategory>>.internal(
  timeByDayChart,
  name: r'timeByDayChartProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$timeByDayChartHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TimeByDayChartRef
    = AutoDisposeFutureProviderRef<List<TimeByDayAndCategory>>;
String _$maxCategoriesCountHash() =>
    r'5ddf03e2337770b00da85a662ea0642546de55d7';

/// See also [maxCategoriesCount].
@ProviderFor(maxCategoriesCount)
final maxCategoriesCountProvider = AutoDisposeFutureProvider<int>.internal(
  maxCategoriesCount,
  name: r'maxCategoriesCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$maxCategoriesCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MaxCategoriesCountRef = AutoDisposeFutureProviderRef<int>;
String _$timeByCategoryControllerHash() =>
    r'549d3d9f76df5dcedd0a5dd63193bf1ed838379c';

/// See also [TimeByCategoryController].
@ProviderFor(TimeByCategoryController)
final timeByCategoryControllerProvider = AutoDisposeAsyncNotifierProvider<
    TimeByCategoryController,
    Map<DateTime, Map<CategoryDefinition?, Duration>>>.internal(
  TimeByCategoryController.new,
  name: r'timeByCategoryControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$timeByCategoryControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TimeByCategoryController = AutoDisposeAsyncNotifier<
    Map<DateTime, Map<CategoryDefinition?, Duration>>>;
String _$timeFrameControllerHash() =>
    r'b80408b62af6b80fe8675e47d9ce95cb14d6a521';

/// See also [TimeFrameController].
@ProviderFor(TimeFrameController)
final timeFrameControllerProvider =
    AutoDisposeNotifierProvider<TimeFrameController, int>.internal(
  TimeFrameController.new,
  name: r'timeFrameControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$timeFrameControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TimeFrameController = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
