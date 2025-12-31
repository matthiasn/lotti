// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutChartDataController)
final workoutChartDataControllerProvider = WorkoutChartDataControllerFamily._();

final class WorkoutChartDataControllerProvider extends $AsyncNotifierProvider<
    WorkoutChartDataController, List<JournalEntity>> {
  WorkoutChartDataControllerProvider._(
      {required WorkoutChartDataControllerFamily super.from,
      required ({
        DateTime rangeStart,
        DateTime rangeEnd,
      })
          super.argument})
      : super(
          retry: null,
          name: r'workoutChartDataControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$workoutChartDataControllerHash();

  @override
  String toString() {
    return r'workoutChartDataControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  WorkoutChartDataController create() => WorkoutChartDataController();

  @override
  bool operator ==(Object other) {
    return other is WorkoutChartDataControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutChartDataControllerHash() =>
    r'7e7bd9a96f705b02261f25a69607751065dc4777';

final class WorkoutChartDataControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            WorkoutChartDataController,
            AsyncValue<List<JournalEntity>>,
            List<JournalEntity>,
            FutureOr<List<JournalEntity>>,
            ({
              DateTime rangeStart,
              DateTime rangeEnd,
            })> {
  WorkoutChartDataControllerFamily._()
      : super(
          retry: null,
          name: r'workoutChartDataControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  WorkoutChartDataControllerProvider call({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      WorkoutChartDataControllerProvider._(argument: (
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ), from: this);

  @override
  String toString() => r'workoutChartDataControllerProvider';
}

abstract class _$WorkoutChartDataController
    extends $AsyncNotifier<List<JournalEntity>> {
  late final _$args = ref.$arg as ({
    DateTime rangeStart,
    DateTime rangeEnd,
  });
  DateTime get rangeStart => _$args.rangeStart;
  DateTime get rangeEnd => _$args.rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<JournalEntity>>, List<JournalEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<JournalEntity>>, List<JournalEntity>>,
        AsyncValue<List<JournalEntity>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              rangeStart: _$args.rangeStart,
              rangeEnd: _$args.rangeEnd,
            ));
  }
}

@ProviderFor(WorkoutObservationsController)
final workoutObservationsControllerProvider =
    WorkoutObservationsControllerFamily._();

final class WorkoutObservationsControllerProvider
    extends $AsyncNotifierProvider<WorkoutObservationsController,
        List<Observation>> {
  WorkoutObservationsControllerProvider._(
      {required WorkoutObservationsControllerFamily super.from,
      required ({
        DashboardItem chartConfig,
        DateTime rangeStart,
        DateTime rangeEnd,
      })
          super.argument})
      : super(
          retry: null,
          name: r'workoutObservationsControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$workoutObservationsControllerHash();

  @override
  String toString() {
    return r'workoutObservationsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  WorkoutObservationsController create() => WorkoutObservationsController();

  @override
  bool operator ==(Object other) {
    return other is WorkoutObservationsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutObservationsControllerHash() =>
    r'df354a8d1aaddaef8b246bcb78310fcd105ea3ff';

final class WorkoutObservationsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            WorkoutObservationsController,
            AsyncValue<List<Observation>>,
            List<Observation>,
            FutureOr<List<Observation>>,
            ({
              DashboardItem chartConfig,
              DateTime rangeStart,
              DateTime rangeEnd,
            })> {
  WorkoutObservationsControllerFamily._()
      : super(
          retry: null,
          name: r'workoutObservationsControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  WorkoutObservationsControllerProvider call({
    required DashboardItem chartConfig,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      WorkoutObservationsControllerProvider._(argument: (
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ), from: this);

  @override
  String toString() => r'workoutObservationsControllerProvider';
}

abstract class _$WorkoutObservationsController
    extends $AsyncNotifier<List<Observation>> {
  late final _$args = ref.$arg as ({
    DashboardItem chartConfig,
    DateTime rangeStart,
    DateTime rangeEnd,
  });
  DashboardItem get chartConfig => _$args.chartConfig;
  DateTime get rangeStart => _$args.rangeStart;
  DateTime get rangeEnd => _$args.rangeEnd;

  FutureOr<List<Observation>> build({
    required DashboardItem chartConfig,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<Observation>>, List<Observation>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<Observation>>, List<Observation>>,
        AsyncValue<List<Observation>>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              chartConfig: _$args.chartConfig,
              rangeStart: _$args.rangeStart,
              rangeEnd: _$args.rangeEnd,
            ));
  }
}
