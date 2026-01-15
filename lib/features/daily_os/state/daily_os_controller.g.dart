// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_os_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the selected date for the Daily OS view.

@ProviderFor(DailyOsSelectedDate)
final dailyOsSelectedDateProvider = DailyOsSelectedDateProvider._();

/// Provides the selected date for the Daily OS view.
final class DailyOsSelectedDateProvider
    extends $NotifierProvider<DailyOsSelectedDate, DateTime> {
  /// Provides the selected date for the Daily OS view.
  DailyOsSelectedDateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dailyOsSelectedDateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dailyOsSelectedDateHash();

  @$internal
  @override
  DailyOsSelectedDate create() => DailyOsSelectedDate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$dailyOsSelectedDateHash() =>
    r'c3800905cdbd658c554c92c87f379b58008181f0';

/// Provides the selected date for the Daily OS view.

abstract class _$DailyOsSelectedDate extends $Notifier<DateTime> {
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

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.

@ProviderFor(DailyOsController)
final dailyOsControllerProvider = DailyOsControllerProvider._();

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.
final class DailyOsControllerProvider
    extends $AsyncNotifierProvider<DailyOsController, DailyOsState> {
  /// Main controller for the Daily OS view.
  ///
  /// Combines day plan, budget progress, and timeline data into a unified state.
  DailyOsControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dailyOsControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dailyOsControllerHash();

  @$internal
  @override
  DailyOsController create() => DailyOsController();
}

String _$dailyOsControllerHash() => r'a48162a997950117851c615ce5b2dab5522af76f';

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.

abstract class _$DailyOsController extends $AsyncNotifier<DailyOsState> {
  FutureOr<DailyOsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DailyOsState>, DailyOsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DailyOsState>, DailyOsState>,
        AsyncValue<DailyOsState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
