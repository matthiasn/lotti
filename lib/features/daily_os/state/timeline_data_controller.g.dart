// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_data_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides timeline data for plan vs actual comparison.

@ProviderFor(TimelineDataController)
final timelineDataControllerProvider = TimelineDataControllerFamily._();

/// Provides timeline data for plan vs actual comparison.
final class TimelineDataControllerProvider
    extends $AsyncNotifierProvider<TimelineDataController, DailyTimelineData> {
  /// Provides timeline data for plan vs actual comparison.
  TimelineDataControllerProvider._(
      {required TimelineDataControllerFamily super.from,
      required DateTime super.argument})
      : super(
          retry: null,
          name: r'timelineDataControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$timelineDataControllerHash();

  @override
  String toString() {
    return r'timelineDataControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TimelineDataController create() => TimelineDataController();

  @override
  bool operator ==(Object other) {
    return other is TimelineDataControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timelineDataControllerHash() =>
    r'c6c7f5e551cbae2ce9248629eb16c4efb65ad3f1';

/// Provides timeline data for plan vs actual comparison.

final class TimelineDataControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            TimelineDataController,
            AsyncValue<DailyTimelineData>,
            DailyTimelineData,
            FutureOr<DailyTimelineData>,
            DateTime> {
  TimelineDataControllerFamily._()
      : super(
          retry: null,
          name: r'timelineDataControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provides timeline data for plan vs actual comparison.

  TimelineDataControllerProvider call({
    required DateTime date,
  }) =>
      TimelineDataControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'timelineDataControllerProvider';
}

/// Provides timeline data for plan vs actual comparison.

abstract class _$TimelineDataController
    extends $AsyncNotifier<DailyTimelineData> {
  late final _$args = ref.$arg as DateTime;
  DateTime get date => _$args;

  FutureOr<DailyTimelineData> build({
    required DateTime date,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<DailyTimelineData>, DailyTimelineData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DailyTimelineData>, DailyTimelineData>,
        AsyncValue<DailyTimelineData>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              date: _$args,
            ));
  }
}
