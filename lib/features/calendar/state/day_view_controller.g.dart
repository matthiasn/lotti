// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_view_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DayViewController)
final dayViewControllerProvider = DayViewControllerProvider._();

final class DayViewControllerProvider extends $AsyncNotifierProvider<
    DayViewController, List<CalendarEventData<CalendarEvent>>> {
  DayViewControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dayViewControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dayViewControllerHash();

  @$internal
  @override
  DayViewController create() => DayViewController();
}

String _$dayViewControllerHash() => r'b58c5d557a5c8c20bf2a1102de8ab4bd353c7462';

abstract class _$DayViewController
    extends $AsyncNotifier<List<CalendarEventData<CalendarEvent>>> {
  FutureOr<List<CalendarEventData<CalendarEvent>>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<
        AsyncValue<List<CalendarEventData<CalendarEvent>>>,
        List<CalendarEventData<CalendarEvent>>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<CalendarEventData<CalendarEvent>>>,
            List<CalendarEventData<CalendarEvent>>>,
        AsyncValue<List<CalendarEventData<CalendarEvent>>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(DaySelectionController)
final daySelectionControllerProvider = DaySelectionControllerProvider._();

final class DaySelectionControllerProvider
    extends $NotifierProvider<DaySelectionController, DateTime> {
  DaySelectionControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'daySelectionControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$daySelectionControllerHash();

  @$internal
  @override
  DaySelectionController create() => DaySelectionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$daySelectionControllerHash() =>
    r'12d87629da886ad08785bcf28005a9b9ea4c8397';

abstract class _$DaySelectionController extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DateTime, DateTime>, DateTime, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(TimeChartSelectedData)
final timeChartSelectedDataProvider = TimeChartSelectedDataProvider._();

final class TimeChartSelectedDataProvider extends $NotifierProvider<
    TimeChartSelectedData, Map<int, Map<String, dynamic>>> {
  TimeChartSelectedDataProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'timeChartSelectedDataProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$timeChartSelectedDataHash();

  @$internal
  @override
  TimeChartSelectedData create() => TimeChartSelectedData();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, Map<String, dynamic>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<int, Map<String, dynamic>>>(value),
    );
  }
}

String _$timeChartSelectedDataHash() =>
    r'a29c2e75cefa2c3f4da828ac3262908a772b4cff';

abstract class _$TimeChartSelectedData
    extends $Notifier<Map<int, Map<String, dynamic>>> {
  Map<int, Map<String, dynamic>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<Map<int, Map<String, dynamic>>, Map<int, Map<String, dynamic>>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Map<int, Map<String, dynamic>>,
            Map<int, Map<String, dynamic>>>,
        Map<int, Map<String, dynamic>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(CalendarGlobalKeyController)
final calendarGlobalKeyControllerProvider =
    CalendarGlobalKeyControllerProvider._();

final class CalendarGlobalKeyControllerProvider extends $NotifierProvider<
    CalendarGlobalKeyController, GlobalKey<DayViewState<Object?>>> {
  CalendarGlobalKeyControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'calendarGlobalKeyControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$calendarGlobalKeyControllerHash();

  @$internal
  @override
  CalendarGlobalKeyController create() => CalendarGlobalKeyController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalKey<DayViewState<Object?>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<GlobalKey<DayViewState<Object?>>>(value),
    );
  }
}

String _$calendarGlobalKeyControllerHash() =>
    r'6af4c5140ecb6879c748844d5567949135a8c089';

abstract class _$CalendarGlobalKeyController
    extends $Notifier<GlobalKey<DayViewState<Object?>>> {
  GlobalKey<DayViewState<Object?>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<GlobalKey<DayViewState<Object?>>,
        GlobalKey<DayViewState<Object?>>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<GlobalKey<DayViewState<Object?>>,
            GlobalKey<DayViewState<Object?>>>,
        GlobalKey<DayViewState<Object?>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
