// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_view_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dayViewControllerHash() => r'71544d88f1f5251993c118b6fc063dc6441e4362';

/// See also [DayViewController].
@ProviderFor(DayViewController)
final dayViewControllerProvider = AutoDisposeAsyncNotifierProvider<
    DayViewController, List<CalendarEventData<CalendarEvent>>>.internal(
  DayViewController.new,
  name: r'dayViewControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dayViewControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DayViewController
    = AutoDisposeAsyncNotifier<List<CalendarEventData<CalendarEvent>>>;
String _$daySelectionControllerHash() =>
    r'12d87629da886ad08785bcf28005a9b9ea4c8397';

/// See also [DaySelectionController].
@ProviderFor(DaySelectionController)
final daySelectionControllerProvider =
    NotifierProvider<DaySelectionController, DateTime>.internal(
  DaySelectionController.new,
  name: r'daySelectionControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$daySelectionControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DaySelectionController = Notifier<DateTime>;
String _$timeChartSelectedDataHash() =>
    r'a29c2e75cefa2c3f4da828ac3262908a772b4cff';

/// See also [TimeChartSelectedData].
@ProviderFor(TimeChartSelectedData)
final timeChartSelectedDataProvider = NotifierProvider<TimeChartSelectedData,
    Map<int, Map<String, dynamic>>>.internal(
  TimeChartSelectedData.new,
  name: r'timeChartSelectedDataProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$timeChartSelectedDataHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TimeChartSelectedData = Notifier<Map<int, Map<String, dynamic>>>;
String _$calendarGlobalKeyControllerHash() =>
    r'6af4c5140ecb6879c748844d5567949135a8c089';

/// See also [CalendarGlobalKeyController].
@ProviderFor(CalendarGlobalKeyController)
final calendarGlobalKeyControllerProvider = NotifierProvider<
    CalendarGlobalKeyController, GlobalKey<DayViewState>>.internal(
  CalendarGlobalKeyController.new,
  name: r'calendarGlobalKeyControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$calendarGlobalKeyControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CalendarGlobalKeyController = Notifier<GlobalKey<DayViewState>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
