// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the raw quantitative health entities of one `healthDataType` within a
/// date range and keeps them fresh.
///
/// Holds the result for `dashboardCacheDuration` so flipping between dashboards
/// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
/// change to this exact health type re-fetches and pushes new data (skipping
/// the rebuild when the rows are unchanged). The returned entities are
/// unaggregated; [HealthObservationsController] turns them into chart points.

@ProviderFor(HealthChartDataController)
final healthChartDataControllerProvider = HealthChartDataControllerFamily._();

/// Loads the raw quantitative health entities of one `healthDataType` within a
/// date range and keeps them fresh.
///
/// Holds the result for `dashboardCacheDuration` so flipping between dashboards
/// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
/// change to this exact health type re-fetches and pushes new data (skipping
/// the rebuild when the rows are unchanged). The returned entities are
/// unaggregated; [HealthObservationsController] turns them into chart points.
final class HealthChartDataControllerProvider
    extends
        $AsyncNotifierProvider<HealthChartDataController, List<JournalEntity>> {
  /// Loads the raw quantitative health entities of one `healthDataType` within a
  /// date range and keeps them fresh.
  ///
  /// Holds the result for `dashboardCacheDuration` so flipping between dashboards
  /// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
  /// change to this exact health type re-fetches and pushes new data (skipping
  /// the rebuild when the rows are unchanged). The returned entities are
  /// unaggregated; [HealthObservationsController] turns them into chart points.
  HealthChartDataControllerProvider._({
    required HealthChartDataControllerFamily super.from,
    required ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
    super.argument,
  }) : super(
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

/// Loads the raw quantitative health entities of one `healthDataType` within a
/// date range and keeps them fresh.
///
/// Holds the result for `dashboardCacheDuration` so flipping between dashboards
/// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
/// change to this exact health type re-fetches and pushes new data (skipping
/// the rebuild when the rows are unchanged). The returned entities are
/// unaggregated; [HealthObservationsController] turns them into chart points.

final class HealthChartDataControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          HealthChartDataController,
          AsyncValue<List<JournalEntity>>,
          List<JournalEntity>,
          FutureOr<List<JournalEntity>>,
          ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
        > {
  HealthChartDataControllerFamily._()
    : super(
        retry: null,
        name: r'healthChartDataControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Loads the raw quantitative health entities of one `healthDataType` within a
  /// date range and keeps them fresh.
  ///
  /// Holds the result for `dashboardCacheDuration` so flipping between dashboards
  /// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
  /// change to this exact health type re-fetches and pushes new data (skipping
  /// the rebuild when the rows are unchanged). The returned entities are
  /// unaggregated; [HealthObservationsController] turns them into chart points.

  HealthChartDataControllerProvider call({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) => HealthChartDataControllerProvider._(
    argument: (
      healthDataType: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    ),
    from: this,
  );

  @override
  String toString() => r'healthChartDataControllerProvider';
}

/// Loads the raw quantitative health entities of one `healthDataType` within a
/// date range and keeps them fresh.
///
/// Holds the result for `dashboardCacheDuration` so flipping between dashboards
/// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
/// change to this exact health type re-fetches and pushes new data (skipping
/// the rebuild when the rows are unchanged). The returned entities are
/// unaggregated; [HealthObservationsController] turns them into chart points.

abstract class _$HealthChartDataController
    extends $AsyncNotifier<List<JournalEntity>> {
  late final _$args =
      ref.$arg
          as ({String healthDataType, DateTime rangeStart, DateTime rangeEnd});
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
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<JournalEntity>>, List<JournalEntity>>,
              AsyncValue<List<JournalEntity>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(
        healthDataType: _$args.healthDataType,
        rangeStart: _$args.rangeStart,
        rangeEnd: _$args.rangeEnd,
      ),
    );
  }
}

/// Chart-ready observations for one health type: watches
/// [HealthChartDataController] for the raw entities and reduces them via
/// `aggregateByType` (the per-type rule from `healthTypes`).
///
/// On construction (outside tests) it kicks off a short, jittered-delay
/// background health-data sync for this type so the chart refreshes itself with
/// freshly imported samples without blocking first paint. The build awaits the
/// upstream future (rather than reading a possibly-empty cached value) so the
/// provider stays in `AsyncLoading` until the DB read completes — otherwise the
/// chart's stale-while-revalidate wrapper would flash an empty "No data" state.

@ProviderFor(HealthObservationsController)
final healthObservationsControllerProvider =
    HealthObservationsControllerFamily._();

/// Chart-ready observations for one health type: watches
/// [HealthChartDataController] for the raw entities and reduces them via
/// `aggregateByType` (the per-type rule from `healthTypes`).
///
/// On construction (outside tests) it kicks off a short, jittered-delay
/// background health-data sync for this type so the chart refreshes itself with
/// freshly imported samples without blocking first paint. The build awaits the
/// upstream future (rather than reading a possibly-empty cached value) so the
/// provider stays in `AsyncLoading` until the DB read completes — otherwise the
/// chart's stale-while-revalidate wrapper would flash an empty "No data" state.
final class HealthObservationsControllerProvider
    extends
        $AsyncNotifierProvider<
          HealthObservationsController,
          List<Observation>
        > {
  /// Chart-ready observations for one health type: watches
  /// [HealthChartDataController] for the raw entities and reduces them via
  /// `aggregateByType` (the per-type rule from `healthTypes`).
  ///
  /// On construction (outside tests) it kicks off a short, jittered-delay
  /// background health-data sync for this type so the chart refreshes itself with
  /// freshly imported samples without blocking first paint. The build awaits the
  /// upstream future (rather than reading a possibly-empty cached value) so the
  /// provider stays in `AsyncLoading` until the DB read completes — otherwise the
  /// chart's stale-while-revalidate wrapper would flash an empty "No data" state.
  HealthObservationsControllerProvider._({
    required HealthObservationsControllerFamily super.from,
    required ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
    super.argument,
  }) : super(
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
    r'd84c36606ad4a536b32a12ff549b5b7ffb1750b5';

/// Chart-ready observations for one health type: watches
/// [HealthChartDataController] for the raw entities and reduces them via
/// `aggregateByType` (the per-type rule from `healthTypes`).
///
/// On construction (outside tests) it kicks off a short, jittered-delay
/// background health-data sync for this type so the chart refreshes itself with
/// freshly imported samples without blocking first paint. The build awaits the
/// upstream future (rather than reading a possibly-empty cached value) so the
/// provider stays in `AsyncLoading` until the DB read completes — otherwise the
/// chart's stale-while-revalidate wrapper would flash an empty "No data" state.

final class HealthObservationsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          HealthObservationsController,
          AsyncValue<List<Observation>>,
          List<Observation>,
          FutureOr<List<Observation>>,
          ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
        > {
  HealthObservationsControllerFamily._()
    : super(
        retry: null,
        name: r'healthObservationsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Chart-ready observations for one health type: watches
  /// [HealthChartDataController] for the raw entities and reduces them via
  /// `aggregateByType` (the per-type rule from `healthTypes`).
  ///
  /// On construction (outside tests) it kicks off a short, jittered-delay
  /// background health-data sync for this type so the chart refreshes itself with
  /// freshly imported samples without blocking first paint. The build awaits the
  /// upstream future (rather than reading a possibly-empty cached value) so the
  /// provider stays in `AsyncLoading` until the DB read completes — otherwise the
  /// chart's stale-while-revalidate wrapper would flash an empty "No data" state.

  HealthObservationsControllerProvider call({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) => HealthObservationsControllerProvider._(
    argument: (
      healthDataType: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    ),
    from: this,
  );

  @override
  String toString() => r'healthObservationsControllerProvider';
}

/// Chart-ready observations for one health type: watches
/// [HealthChartDataController] for the raw entities and reduces them via
/// `aggregateByType` (the per-type rule from `healthTypes`).
///
/// On construction (outside tests) it kicks off a short, jittered-delay
/// background health-data sync for this type so the chart refreshes itself with
/// freshly imported samples without blocking first paint. The build awaits the
/// upstream future (rather than reading a possibly-empty cached value) so the
/// provider stays in `AsyncLoading` until the DB read completes — otherwise the
/// chart's stale-while-revalidate wrapper would flash an empty "No data" state.

abstract class _$HealthObservationsController
    extends $AsyncNotifier<List<Observation>> {
  late final _$args =
      ref.$arg
          as ({String healthDataType, DateTime rangeStart, DateTime rangeEnd});
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
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Observation>>, List<Observation>>,
              AsyncValue<List<Observation>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(
        healthDataType: _$args.healthDataType,
        rangeStart: _$args.rangeStart,
        rangeEnd: _$args.rangeEnd,
      ),
    );
  }
}
