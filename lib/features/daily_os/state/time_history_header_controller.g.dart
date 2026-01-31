// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_history_header_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the time history header data layer.
///
/// Fetches and aggregates time-by-category data for multiple days,
/// supporting incremental loading for infinite scroll.

@ProviderFor(TimeHistoryHeaderController)
final timeHistoryHeaderControllerProvider =
    TimeHistoryHeaderControllerProvider._();

/// Controller for the time history header data layer.
///
/// Fetches and aggregates time-by-category data for multiple days,
/// supporting incremental loading for infinite scroll.
final class TimeHistoryHeaderControllerProvider extends $AsyncNotifierProvider<
    TimeHistoryHeaderController, TimeHistoryData> {
  /// Controller for the time history header data layer.
  ///
  /// Fetches and aggregates time-by-category data for multiple days,
  /// supporting incremental loading for infinite scroll.
  TimeHistoryHeaderControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'timeHistoryHeaderControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$timeHistoryHeaderControllerHash();

  @$internal
  @override
  TimeHistoryHeaderController create() => TimeHistoryHeaderController();
}

String _$timeHistoryHeaderControllerHash() =>
    r'c8a5de2e32112ec23d2a7a39f827a8061b697706';

/// Controller for the time history header data layer.
///
/// Fetches and aggregates time-by-category data for multiple days,
/// supporting incremental loading for infinite scroll.

abstract class _$TimeHistoryHeaderController
    extends $AsyncNotifier<TimeHistoryData> {
  FutureOr<TimeHistoryData> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TimeHistoryData>, TimeHistoryData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<TimeHistoryData>, TimeHistoryData>,
        AsyncValue<TimeHistoryData>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
