// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurables_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$measurableDataTypeControllerHash() =>
    r'2a28aa20dc0c5e0e19b11f342b11c8a977491008';

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

abstract class _$MeasurableDataTypeController
    extends BuildlessAutoDisposeAsyncNotifier<MeasurableDataType?> {
  late final String id;

  FutureOr<MeasurableDataType?> build({
    required String id,
  });
}

/// See also [MeasurableDataTypeController].
@ProviderFor(MeasurableDataTypeController)
const measurableDataTypeControllerProvider =
    MeasurableDataTypeControllerFamily();

/// See also [MeasurableDataTypeController].
class MeasurableDataTypeControllerFamily
    extends Family<AsyncValue<MeasurableDataType?>> {
  /// See also [MeasurableDataTypeController].
  const MeasurableDataTypeControllerFamily();

  /// See also [MeasurableDataTypeController].
  MeasurableDataTypeControllerProvider call({
    required String id,
  }) {
    return MeasurableDataTypeControllerProvider(
      id: id,
    );
  }

  @override
  MeasurableDataTypeControllerProvider getProviderOverride(
    covariant MeasurableDataTypeControllerProvider provider,
  ) {
    return call(
      id: provider.id,
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
  String? get name => r'measurableDataTypeControllerProvider';
}

/// See also [MeasurableDataTypeController].
class MeasurableDataTypeControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<MeasurableDataTypeController,
        MeasurableDataType?> {
  /// See also [MeasurableDataTypeController].
  MeasurableDataTypeControllerProvider({
    required String id,
  }) : this._internal(
          () => MeasurableDataTypeController()..id = id,
          from: measurableDataTypeControllerProvider,
          name: r'measurableDataTypeControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$measurableDataTypeControllerHash,
          dependencies: MeasurableDataTypeControllerFamily._dependencies,
          allTransitiveDependencies:
              MeasurableDataTypeControllerFamily._allTransitiveDependencies,
          id: id,
        );

  MeasurableDataTypeControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  FutureOr<MeasurableDataType?> runNotifierBuild(
    covariant MeasurableDataTypeController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(MeasurableDataTypeController Function() create) {
    return ProviderOverride(
      origin: this,
      override: MeasurableDataTypeControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MeasurableDataTypeController,
      MeasurableDataType?> createElement() {
    return _MeasurableDataTypeControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurableDataTypeControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MeasurableDataTypeControllerRef
    on AutoDisposeAsyncNotifierProviderRef<MeasurableDataType?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _MeasurableDataTypeControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        MeasurableDataTypeController,
        MeasurableDataType?> with MeasurableDataTypeControllerRef {
  _MeasurableDataTypeControllerProviderElement(super.provider);

  @override
  String get id => (origin as MeasurableDataTypeControllerProvider).id;
}

String _$aggregationTypeControllerHash() =>
    r'0e5ebfe61ed46efd31230fc91bd1f81226caeef7';

abstract class _$AggregationTypeController
    extends BuildlessAutoDisposeAsyncNotifier<AggregationType> {
  late final String measurableDataTypeId;
  late final AggregationType? dashboardDefinedAggregationType;

  FutureOr<AggregationType> build({
    required String measurableDataTypeId,
    required AggregationType? dashboardDefinedAggregationType,
  });
}

/// See also [AggregationTypeController].
@ProviderFor(AggregationTypeController)
const aggregationTypeControllerProvider = AggregationTypeControllerFamily();

/// See also [AggregationTypeController].
class AggregationTypeControllerFamily
    extends Family<AsyncValue<AggregationType>> {
  /// See also [AggregationTypeController].
  const AggregationTypeControllerFamily();

  /// See also [AggregationTypeController].
  AggregationTypeControllerProvider call({
    required String measurableDataTypeId,
    required AggregationType? dashboardDefinedAggregationType,
  }) {
    return AggregationTypeControllerProvider(
      measurableDataTypeId: measurableDataTypeId,
      dashboardDefinedAggregationType: dashboardDefinedAggregationType,
    );
  }

  @override
  AggregationTypeControllerProvider getProviderOverride(
    covariant AggregationTypeControllerProvider provider,
  ) {
    return call(
      measurableDataTypeId: provider.measurableDataTypeId,
      dashboardDefinedAggregationType: provider.dashboardDefinedAggregationType,
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
  String? get name => r'aggregationTypeControllerProvider';
}

/// See also [AggregationTypeController].
class AggregationTypeControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<AggregationTypeController,
        AggregationType> {
  /// See also [AggregationTypeController].
  AggregationTypeControllerProvider({
    required String measurableDataTypeId,
    required AggregationType? dashboardDefinedAggregationType,
  }) : this._internal(
          () => AggregationTypeController()
            ..measurableDataTypeId = measurableDataTypeId
            ..dashboardDefinedAggregationType = dashboardDefinedAggregationType,
          from: aggregationTypeControllerProvider,
          name: r'aggregationTypeControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aggregationTypeControllerHash,
          dependencies: AggregationTypeControllerFamily._dependencies,
          allTransitiveDependencies:
              AggregationTypeControllerFamily._allTransitiveDependencies,
          measurableDataTypeId: measurableDataTypeId,
          dashboardDefinedAggregationType: dashboardDefinedAggregationType,
        );

  AggregationTypeControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.measurableDataTypeId,
    required this.dashboardDefinedAggregationType,
  }) : super.internal();

  final String measurableDataTypeId;
  final AggregationType? dashboardDefinedAggregationType;

  @override
  FutureOr<AggregationType> runNotifierBuild(
    covariant AggregationTypeController notifier,
  ) {
    return notifier.build(
      measurableDataTypeId: measurableDataTypeId,
      dashboardDefinedAggregationType: dashboardDefinedAggregationType,
    );
  }

  @override
  Override overrideWith(AggregationTypeController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AggregationTypeControllerProvider._internal(
        () => create()
          ..measurableDataTypeId = measurableDataTypeId
          ..dashboardDefinedAggregationType = dashboardDefinedAggregationType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        measurableDataTypeId: measurableDataTypeId,
        dashboardDefinedAggregationType: dashboardDefinedAggregationType,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<AggregationTypeController,
      AggregationType> createElement() {
    return _AggregationTypeControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AggregationTypeControllerProvider &&
        other.measurableDataTypeId == measurableDataTypeId &&
        other.dashboardDefinedAggregationType ==
            dashboardDefinedAggregationType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, measurableDataTypeId.hashCode);
    hash = _SystemHash.combine(hash, dashboardDefinedAggregationType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AggregationTypeControllerRef
    on AutoDisposeAsyncNotifierProviderRef<AggregationType> {
  /// The parameter `measurableDataTypeId` of this provider.
  String get measurableDataTypeId;

  /// The parameter `dashboardDefinedAggregationType` of this provider.
  AggregationType? get dashboardDefinedAggregationType;
}

class _AggregationTypeControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<AggregationTypeController,
        AggregationType> with AggregationTypeControllerRef {
  _AggregationTypeControllerProviderElement(super.provider);

  @override
  String get measurableDataTypeId =>
      (origin as AggregationTypeControllerProvider).measurableDataTypeId;
  @override
  AggregationType? get dashboardDefinedAggregationType =>
      (origin as AggregationTypeControllerProvider)
          .dashboardDefinedAggregationType;
}

String _$measurableChartDataControllerHash() =>
    r'd1ac2d48447f5dd52b388e4fbfb13bc4d3f05797';

abstract class _$MeasurableChartDataController
    extends BuildlessAutoDisposeAsyncNotifier<List<Observation>> {
  late final String measurableDataTypeId;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;
  late final AggregationType? dashboardDefinedAggregationType;

  FutureOr<List<Observation>> build({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    AggregationType? dashboardDefinedAggregationType,
  });
}

/// See also [MeasurableChartDataController].
@ProviderFor(MeasurableChartDataController)
const measurableChartDataControllerProvider =
    MeasurableChartDataControllerFamily();

/// See also [MeasurableChartDataController].
class MeasurableChartDataControllerFamily
    extends Family<AsyncValue<List<Observation>>> {
  /// See also [MeasurableChartDataController].
  const MeasurableChartDataControllerFamily();

  /// See also [MeasurableChartDataController].
  MeasurableChartDataControllerProvider call({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    AggregationType? dashboardDefinedAggregationType,
  }) {
    return MeasurableChartDataControllerProvider(
      measurableDataTypeId: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      dashboardDefinedAggregationType: dashboardDefinedAggregationType,
    );
  }

  @override
  MeasurableChartDataControllerProvider getProviderOverride(
    covariant MeasurableChartDataControllerProvider provider,
  ) {
    return call(
      measurableDataTypeId: provider.measurableDataTypeId,
      rangeStart: provider.rangeStart,
      rangeEnd: provider.rangeEnd,
      dashboardDefinedAggregationType: provider.dashboardDefinedAggregationType,
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
  String? get name => r'measurableChartDataControllerProvider';
}

/// See also [MeasurableChartDataController].
class MeasurableChartDataControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<MeasurableChartDataController,
        List<Observation>> {
  /// See also [MeasurableChartDataController].
  MeasurableChartDataControllerProvider({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    AggregationType? dashboardDefinedAggregationType,
  }) : this._internal(
          () => MeasurableChartDataController()
            ..measurableDataTypeId = measurableDataTypeId
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd
            ..dashboardDefinedAggregationType = dashboardDefinedAggregationType,
          from: measurableChartDataControllerProvider,
          name: r'measurableChartDataControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$measurableChartDataControllerHash,
          dependencies: MeasurableChartDataControllerFamily._dependencies,
          allTransitiveDependencies:
              MeasurableChartDataControllerFamily._allTransitiveDependencies,
          measurableDataTypeId: measurableDataTypeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: dashboardDefinedAggregationType,
        );

  MeasurableChartDataControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.measurableDataTypeId,
    required this.rangeStart,
    required this.rangeEnd,
    required this.dashboardDefinedAggregationType,
  }) : super.internal();

  final String measurableDataTypeId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final AggregationType? dashboardDefinedAggregationType;

  @override
  FutureOr<List<Observation>> runNotifierBuild(
    covariant MeasurableChartDataController notifier,
  ) {
    return notifier.build(
      measurableDataTypeId: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      dashboardDefinedAggregationType: dashboardDefinedAggregationType,
    );
  }

  @override
  Override overrideWith(MeasurableChartDataController Function() create) {
    return ProviderOverride(
      origin: this,
      override: MeasurableChartDataControllerProvider._internal(
        () => create()
          ..measurableDataTypeId = measurableDataTypeId
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd
          ..dashboardDefinedAggregationType = dashboardDefinedAggregationType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        measurableDataTypeId: measurableDataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        dashboardDefinedAggregationType: dashboardDefinedAggregationType,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MeasurableChartDataController,
      List<Observation>> createElement() {
    return _MeasurableChartDataControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurableChartDataControllerProvider &&
        other.measurableDataTypeId == measurableDataTypeId &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd &&
        other.dashboardDefinedAggregationType ==
            dashboardDefinedAggregationType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, measurableDataTypeId.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);
    hash = _SystemHash.combine(hash, dashboardDefinedAggregationType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MeasurableChartDataControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<Observation>> {
  /// The parameter `measurableDataTypeId` of this provider.
  String get measurableDataTypeId;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;

  /// The parameter `dashboardDefinedAggregationType` of this provider.
  AggregationType? get dashboardDefinedAggregationType;
}

class _MeasurableChartDataControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        MeasurableChartDataController,
        List<Observation>> with MeasurableChartDataControllerRef {
  _MeasurableChartDataControllerProviderElement(super.provider);

  @override
  String get measurableDataTypeId =>
      (origin as MeasurableChartDataControllerProvider).measurableDataTypeId;
  @override
  DateTime get rangeStart =>
      (origin as MeasurableChartDataControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as MeasurableChartDataControllerProvider).rangeEnd;
  @override
  AggregationType? get dashboardDefinedAggregationType =>
      (origin as MeasurableChartDataControllerProvider)
          .dashboardDefinedAggregationType;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
