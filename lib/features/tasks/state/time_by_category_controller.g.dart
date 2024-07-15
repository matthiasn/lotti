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

typedef TimeByDayChartRef
    = AutoDisposeFutureProviderRef<List<TimeByDayAndCategory>>;
String _$timeByCategoryControllerHash() =>
    r'028feca67380c004afb04877200549f4b47edcf5';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
