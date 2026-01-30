// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_daily_os_data_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Unified data controller for the Daily OS view.
///
/// This controller solves the auto-update problem by:
/// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
/// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
///    which is NOT affected by Riverpod 3's automatic pausing
/// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
///    than watching sub-controllers
/// 4. Updating state atomically when any relevant notification arrives
///
/// This ensures that when a time entry is created or synced, all UI components
/// (timeline, budget progress bars, summary) update together.

@ProviderFor(UnifiedDailyOsDataController)
final unifiedDailyOsDataControllerProvider =
    UnifiedDailyOsDataControllerFamily._();

/// Unified data controller for the Daily OS view.
///
/// This controller solves the auto-update problem by:
/// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
/// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
///    which is NOT affected by Riverpod 3's automatic pausing
/// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
///    than watching sub-controllers
/// 4. Updating state atomically when any relevant notification arrives
///
/// This ensures that when a time entry is created or synced, all UI components
/// (timeline, budget progress bars, summary) update together.
final class UnifiedDailyOsDataControllerProvider
    extends $AsyncNotifierProvider<UnifiedDailyOsDataController, DailyOsData> {
  /// Unified data controller for the Daily OS view.
  ///
  /// This controller solves the auto-update problem by:
  /// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
  /// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
  ///    which is NOT affected by Riverpod 3's automatic pausing
  /// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
  ///    than watching sub-controllers
  /// 4. Updating state atomically when any relevant notification arrives
  ///
  /// This ensures that when a time entry is created or synced, all UI components
  /// (timeline, budget progress bars, summary) update together.
  UnifiedDailyOsDataControllerProvider._(
      {required UnifiedDailyOsDataControllerFamily super.from,
      required DateTime super.argument})
      : super(
          retry: null,
          name: r'unifiedDailyOsDataControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$unifiedDailyOsDataControllerHash();

  @override
  String toString() {
    return r'unifiedDailyOsDataControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  UnifiedDailyOsDataController create() => UnifiedDailyOsDataController();

  @override
  bool operator ==(Object other) {
    return other is UnifiedDailyOsDataControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$unifiedDailyOsDataControllerHash() =>
    r'18da710cfca862f868a1fe5bc23447f176cea49b';

/// Unified data controller for the Daily OS view.
///
/// This controller solves the auto-update problem by:
/// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
/// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
///    which is NOT affected by Riverpod 3's automatic pausing
/// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
///    than watching sub-controllers
/// 4. Updating state atomically when any relevant notification arrives
///
/// This ensures that when a time entry is created or synced, all UI components
/// (timeline, budget progress bars, summary) update together.

final class UnifiedDailyOsDataControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            UnifiedDailyOsDataController,
            AsyncValue<DailyOsData>,
            DailyOsData,
            FutureOr<DailyOsData>,
            DateTime> {
  UnifiedDailyOsDataControllerFamily._()
      : super(
          retry: null,
          name: r'unifiedDailyOsDataControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Unified data controller for the Daily OS view.
  ///
  /// This controller solves the auto-update problem by:
  /// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
  /// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
  ///    which is NOT affected by Riverpod 3's automatic pausing
  /// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
  ///    than watching sub-controllers
  /// 4. Updating state atomically when any relevant notification arrives
  ///
  /// This ensures that when a time entry is created or synced, all UI components
  /// (timeline, budget progress bars, summary) update together.

  UnifiedDailyOsDataControllerProvider call({
    required DateTime date,
  }) =>
      UnifiedDailyOsDataControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'unifiedDailyOsDataControllerProvider';
}

/// Unified data controller for the Daily OS view.
///
/// This controller solves the auto-update problem by:
/// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
/// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
///    which is NOT affected by Riverpod 3's automatic pausing
/// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
///    than watching sub-controllers
/// 4. Updating state atomically when any relevant notification arrives
///
/// This ensures that when a time entry is created or synced, all UI components
/// (timeline, budget progress bars, summary) update together.

abstract class _$UnifiedDailyOsDataController
    extends $AsyncNotifier<DailyOsData> {
  late final _$args = ref.$arg as DateTime;
  DateTime get date => _$args;

  FutureOr<DailyOsData> build({
    required DateTime date,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DailyOsData>, DailyOsData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DailyOsData>, DailyOsData>,
        AsyncValue<DailyOsData>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              date: _$args,
            ));
  }
}
