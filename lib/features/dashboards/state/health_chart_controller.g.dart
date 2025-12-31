// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HealthChartDataController)
final healthChartDataControllerProvider = HealthChartDataControllerFamily._();

final class HealthChartDataControllerProvider extends $AsyncNotifierProvider<
    HealthChartDataController, List<JournalEntity>> {
  HealthChartDataControllerProvider._(
      {required HealthChartDataControllerFamily super.from,
      required ({
        String healthDataType,
        DateTime rangeStart,
        DateTime rangeEnd,
      })
          super.argument})
      : super(
          retry: null,
          name: r'healthChartDataControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$healthChartDataControllerHash();

  @override
  String toString() {
    return r'healthChartDataControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  HealthChartDataController create() => HealthChartDataController();

  @override
  bool operator ==(Object other) {
    return other is HealthChartDataControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$healthChartDataControllerHash() =>
    r'a8861ff8ffc25462e01bf2de63cb864fbe0e9bb2';

final class HealthChartDataControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            HealthChartDataController,
            AsyncValue<List<JournalEntity>>,
            List<JournalEntity>,
            FutureOr<List<JournalEntity>>,
            ({
              String healthDataType,
              DateTime rangeStart,
              DateTime rangeEnd,
            })> {
  HealthChartDataControllerFamily._()
      : super(
          retry: null,
          name: r'healthChartDataControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  HealthChartDataControllerProvider call({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      HealthChartDataControllerProvider._(argument: (
        healthDataType: healthDataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ), from: this);

  @override
  String toString() => r'healthChartDataControllerProvider';
}

abstract class _$HealthChartDataController
    extends $AsyncNotifier<List<JournalEntity>> {
  late final _$args = ref.$arg as ({
    String healthDataType,
    DateTime rangeStart,
    DateTime rangeEnd,
  });
  String get healthDataType => _$args.healthDataType;
  DateTime get rangeStart => _$args.rangeStart;
  DateTime get rangeEnd => _$args.rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required String healthDataType,
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
              healthDataType: _$args.healthDataType,
              rangeStart: _$args.rangeStart,
              rangeEnd: _$args.rangeEnd,
            ));
  }
}

@ProviderFor(HealthObservationsController)
final healthObservationsControllerProvider =
    HealthObservationsControllerFamily._();

final class HealthObservationsControllerProvider extends $AsyncNotifierProvider<
    HealthObservationsController, List<Observation>> {
  HealthObservationsControllerProvider._(
      {required HealthObservationsControllerFamily super.from,
      required ({
        String healthDataType,
        DateTime rangeStart,
        DateTime rangeEnd,
      })
          super.argument})
      : super(
          retry: null,
          name: r'healthObservationsControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$healthObservationsControllerHash();

  @override
  String toString() {
    return r'healthObservationsControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  HealthObservationsController create() => HealthObservationsController();

  @override
  bool operator ==(Object other) {
    return other is HealthObservationsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$healthObservationsControllerHash() =>
    r'd0179e81781f38fc4818ff4cef2b89fd6ec51060';

final class HealthObservationsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            HealthObservationsController,
            AsyncValue<List<Observation>>,
            List<Observation>,
            FutureOr<List<Observation>>,
            ({
              String healthDataType,
              DateTime rangeStart,
              DateTime rangeEnd,
            })> {
  HealthObservationsControllerFamily._()
      : super(
          retry: null,
          name: r'healthObservationsControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  HealthObservationsControllerProvider call({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      HealthObservationsControllerProvider._(argument: (
        healthDataType: healthDataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ), from: this);

  @override
  String toString() => r'healthObservationsControllerProvider';
}

abstract class _$HealthObservationsController
    extends $AsyncNotifier<List<Observation>> {
  late final _$args = ref.$arg as ({
    String healthDataType,
    DateTime rangeStart,
    DateTime rangeEnd,
  });
  String get healthDataType => _$args.healthDataType;
  DateTime get rangeStart => _$args.rangeStart;
  DateTime get rangeEnd => _$args.rangeEnd;

  FutureOr<List<Observation>> build({
    required String healthDataType,
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
              healthDataType: _$args.healthDataType,
              rangeStart: _$args.rangeStart,
              rangeEnd: _$args.rangeEnd,
            ));
  }
}
