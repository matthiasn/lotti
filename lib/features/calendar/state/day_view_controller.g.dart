// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_view_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dayViewControllerHash() => r'75cbe6d6ef472707901d3d982735aa106ebd1e96';

/// See also [DayViewController].
@ProviderFor(DayViewController)
final dayViewControllerProvider = AutoDisposeAsyncNotifierProvider<
    DayViewController, List<CalendarEventData<JournalEntity>>>.internal(
  DayViewController.new,
  name: r'dayViewControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dayViewControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DayViewController
    = AutoDisposeAsyncNotifier<List<CalendarEventData<JournalEntity>>>;
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
