// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workoutChartDataControllerHash() =>
    r'7e7bd9a96f705b02261f25a69607751065dc4777';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$WorkoutChartDataController
    extends BuildlessAutoDisposeAsyncNotifier<List<JournalEntity>> {
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [WorkoutChartDataController].
@ProviderFor(WorkoutChartDataController)
const workoutChartDataControllerProvider = WorkoutChartDataControllerFamily();

/// See also [WorkoutChartDataController].
class WorkoutChartDataControllerFamily
    extends Family<AsyncValue<List<JournalEntity>>> {
  /// See also [WorkoutChartDataController].
  const WorkoutChartDataControllerFamily();

  /// See also [WorkoutChartDataController].
  WorkoutChartDataControllerProvider call({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return WorkoutChartDataControllerProvider(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  WorkoutChartDataControllerProvider getProviderOverride(
    covariant WorkoutChartDataControllerProvider provider,
  ) {
    return call(
      rangeStart: provider.rangeStart,
      rangeEnd: provider.rangeEnd,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'workoutChartDataControllerProvider';
}

/// See also [WorkoutChartDataController].
class WorkoutChartDataControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<WorkoutChartDataController,
        List<JournalEntity>> {
  /// See also [WorkoutChartDataController].
  WorkoutChartDataControllerProvider({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => WorkoutChartDataController()
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
          from: workoutChartDataControllerProvider,
          name: r'workoutChartDataControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workoutChartDataControllerHash,
          dependencies: WorkoutChartDataControllerFamily._dependencies,
          allTransitiveDependencies:
              WorkoutChartDataControllerFamily._allTransitiveDependencies,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

  WorkoutChartDataControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super.internal();

  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<JournalEntity>> runNotifierBuild(
    covariant WorkoutChartDataController notifier,
  ) {
    return notifier.build(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Override overrideWith(WorkoutChartDataController Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorkoutChartDataControllerProvider._internal(
        () => create()
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<WorkoutChartDataController,
      List<JournalEntity>> createElement() {
    return _WorkoutChartDataControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutChartDataControllerProvider &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WorkoutChartDataControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<JournalEntity>> {
  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _WorkoutChartDataControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<WorkoutChartDataController,
        List<JournalEntity>> with WorkoutChartDataControllerRef {
  _WorkoutChartDataControllerProviderElement(super.provider);

  @override
  DateTime get rangeStart =>
      (origin as WorkoutChartDataControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as WorkoutChartDataControllerProvider).rangeEnd;
}

String _$workoutObservationsControllerHash() =>
    r'e650d9abdfe76c2a82230e44655930295b2da358';

abstract class _$WorkoutObservationsController
    extends BuildlessAutoDisposeAsyncNotifier<List<Observation>> {
  late final DashboardItem chartConfig;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<Observation>> build({
    required DashboardItem chartConfig,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [WorkoutObservationsController].
@ProviderFor(WorkoutObservationsController)
const workoutObservationsControllerProvider =
    WorkoutObservationsControllerFamily();

/// See also [WorkoutObservationsController].
class WorkoutObservationsControllerFamily
    extends Family<AsyncValue<List<Observation>>> {
  /// See also [WorkoutObservationsController].
  const WorkoutObservationsControllerFamily();

  /// See also [WorkoutObservationsController].
  WorkoutObservationsControllerProvider call({
    required DashboardItem chartConfig,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return WorkoutObservationsControllerProvider(
      chartConfig: chartConfig,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  WorkoutObservationsControllerProvider getProviderOverride(
    covariant WorkoutObservationsControllerProvider provider,
  ) {
    return call(
      chartConfig: provider.chartConfig,
      rangeStart: provider.rangeStart,
      rangeEnd: provider.rangeEnd,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'workoutObservationsControllerProvider';
}

/// See also [WorkoutObservationsController].
class WorkoutObservationsControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<WorkoutObservationsController,
        List<Observation>> {
  /// See also [WorkoutObservationsController].
  WorkoutObservationsControllerProvider({
    required DashboardItem chartConfig,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => WorkoutObservationsController()
            ..chartConfig = chartConfig
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
          from: workoutObservationsControllerProvider,
          name: r'workoutObservationsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workoutObservationsControllerHash,
          dependencies: WorkoutObservationsControllerFamily._dependencies,
          allTransitiveDependencies:
              WorkoutObservationsControllerFamily._allTransitiveDependencies,
          chartConfig: chartConfig,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

  WorkoutObservationsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super.internal();

  final DashboardItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<Observation>> runNotifierBuild(
    covariant WorkoutObservationsController notifier,
  ) {
    return notifier.build(
      chartConfig: chartConfig,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Override overrideWith(WorkoutObservationsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorkoutObservationsControllerProvider._internal(
        () => create()
          ..chartConfig = chartConfig
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<WorkoutObservationsController,
      List<Observation>> createElement() {
    return _WorkoutObservationsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutObservationsControllerProvider &&
        other.chartConfig == chartConfig &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, chartConfig.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WorkoutObservationsControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<Observation>> {
  /// The parameter `chartConfig` of this provider.
  DashboardItem get chartConfig;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _WorkoutObservationsControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        WorkoutObservationsController,
        List<Observation>> with WorkoutObservationsControllerRef {
  _WorkoutObservationsControllerProviderElement(super.provider);

  @override
  DashboardItem get chartConfig =>
      (origin as WorkoutObservationsControllerProvider).chartConfig;
  @override
  DateTime get rangeStart =>
      (origin as WorkoutObservationsControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as WorkoutObservationsControllerProvider).rangeEnd;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
