// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurables_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$measurableDataTypeControllerHash() =>
    r'766d72c5025d5834bcbb5db6d16305039305bff2';

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
    r'89bb3517da84a1355c4ca2e00d1c0557f7df3f52';

abstract class _$AggregationTypeController
    extends BuildlessAutoDisposeAsyncNotifier<AggregationType> {
  late final String measurableDataTypeId;
  late final AggregationType? dashboardDefinedAggregationType;

  FutureOr<AggregationType> build({
    required String measurableDataTypeId,
    AggregationType? dashboardDefinedAggregationType,
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
    AggregationType? dashboardDefinedAggregationType,
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
    AggregationType? dashboardDefinedAggregationType,
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
    r'c0f67d690b9369db464f84616a1052a5d1423129';

abstract class _$MeasurableChartDataController
    extends BuildlessAutoDisposeAsyncNotifier<List<JournalEntity>> {
  late final String measurableDataTypeId;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [MeasurableChartDataController].
@ProviderFor(MeasurableChartDataController)
const measurableChartDataControllerProvider =
    MeasurableChartDataControllerFamily();

/// See also [MeasurableChartDataController].
class MeasurableChartDataControllerFamily
    extends Family<AsyncValue<List<JournalEntity>>> {
  /// See also [MeasurableChartDataController].
  const MeasurableChartDataControllerFamily();

  /// See also [MeasurableChartDataController].
  MeasurableChartDataControllerProvider call({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return MeasurableChartDataControllerProvider(
      measurableDataTypeId: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
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
        List<JournalEntity>> {
  /// See also [MeasurableChartDataController].
  MeasurableChartDataControllerProvider({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => MeasurableChartDataController()
            ..measurableDataTypeId = measurableDataTypeId
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
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
  }) : super.internal();

  final String measurableDataTypeId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<JournalEntity>> runNotifierBuild(
    covariant MeasurableChartDataController notifier,
  ) {
    return notifier.build(
      measurableDataTypeId: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
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
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        measurableDataTypeId: measurableDataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MeasurableChartDataController,
      List<JournalEntity>> createElement() {
    return _MeasurableChartDataControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurableChartDataControllerProvider &&
        other.measurableDataTypeId == measurableDataTypeId &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, measurableDataTypeId.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MeasurableChartDataControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<JournalEntity>> {
  /// The parameter `measurableDataTypeId` of this provider.
  String get measurableDataTypeId;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _MeasurableChartDataControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        MeasurableChartDataController,
        List<JournalEntity>> with MeasurableChartDataControllerRef {
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
}

String _$measurableObservationsControllerHash() =>
    r'e60e9fd4ef2c1d232438fe7e73217923a0dd41e1';

abstract class _$MeasurableObservationsController
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

/// See also [MeasurableObservationsController].
@ProviderFor(MeasurableObservationsController)
const measurableObservationsControllerProvider =
    MeasurableObservationsControllerFamily();

/// See also [MeasurableObservationsController].
class MeasurableObservationsControllerFamily
    extends Family<AsyncValue<List<Observation>>> {
  /// See also [MeasurableObservationsController].
  const MeasurableObservationsControllerFamily();

  /// See also [MeasurableObservationsController].
  MeasurableObservationsControllerProvider call({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    AggregationType? dashboardDefinedAggregationType,
  }) {
    return MeasurableObservationsControllerProvider(
      measurableDataTypeId: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      dashboardDefinedAggregationType: dashboardDefinedAggregationType,
    );
  }

  @override
  MeasurableObservationsControllerProvider getProviderOverride(
    covariant MeasurableObservationsControllerProvider provider,
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
  String? get name => r'measurableObservationsControllerProvider';
}

/// See also [MeasurableObservationsController].
class MeasurableObservationsControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<
        MeasurableObservationsController, List<Observation>> {
  /// See also [MeasurableObservationsController].
  MeasurableObservationsControllerProvider({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    AggregationType? dashboardDefinedAggregationType,
  }) : this._internal(
          () => MeasurableObservationsController()
            ..measurableDataTypeId = measurableDataTypeId
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd
            ..dashboardDefinedAggregationType = dashboardDefinedAggregationType,
          from: measurableObservationsControllerProvider,
          name: r'measurableObservationsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$measurableObservationsControllerHash,
          dependencies: MeasurableObservationsControllerFamily._dependencies,
          allTransitiveDependencies:
              MeasurableObservationsControllerFamily._allTransitiveDependencies,
          measurableDataTypeId: measurableDataTypeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: dashboardDefinedAggregationType,
        );

  MeasurableObservationsControllerProvider._internal(
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
    covariant MeasurableObservationsController notifier,
  ) {
    return notifier.build(
      measurableDataTypeId: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      dashboardDefinedAggregationType: dashboardDefinedAggregationType,
    );
  }

  @override
  Override overrideWith(MeasurableObservationsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: MeasurableObservationsControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<MeasurableObservationsController,
      List<Observation>> createElement() {
    return _MeasurableObservationsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurableObservationsControllerProvider &&
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
mixin MeasurableObservationsControllerRef
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

class _MeasurableObservationsControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        MeasurableObservationsController,
        List<Observation>> with MeasurableObservationsControllerRef {
  _MeasurableObservationsControllerProviderElement(super.provider);

  @override
  String get measurableDataTypeId =>
      (origin as MeasurableObservationsControllerProvider).measurableDataTypeId;
  @override
  DateTime get rangeStart =>
      (origin as MeasurableObservationsControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as MeasurableObservationsControllerProvider).rangeEnd;
  @override
  AggregationType? get dashboardDefinedAggregationType =>
      (origin as MeasurableObservationsControllerProvider)
          .dashboardDefinedAggregationType;
}

String _$measurableSuggestionsControllerHash() =>
    r'775f0746d67c96aa9831fe97415cabd8e6de1889';

abstract class _$MeasurableSuggestionsController
    extends BuildlessAutoDisposeAsyncNotifier<List<num>?> {
  late final String measurableDataTypeId;

  FutureOr<List<num>?> build({
    required String measurableDataTypeId,
  });
}

/// See also [MeasurableSuggestionsController].
@ProviderFor(MeasurableSuggestionsController)
const measurableSuggestionsControllerProvider =
    MeasurableSuggestionsControllerFamily();

/// See also [MeasurableSuggestionsController].
class MeasurableSuggestionsControllerFamily
    extends Family<AsyncValue<List<num>?>> {
  /// See also [MeasurableSuggestionsController].
  const MeasurableSuggestionsControllerFamily();

  /// See also [MeasurableSuggestionsController].
  MeasurableSuggestionsControllerProvider call({
    required String measurableDataTypeId,
  }) {
    return MeasurableSuggestionsControllerProvider(
      measurableDataTypeId: measurableDataTypeId,
    );
  }

  @override
  MeasurableSuggestionsControllerProvider getProviderOverride(
    covariant MeasurableSuggestionsControllerProvider provider,
  ) {
    return call(
      measurableDataTypeId: provider.measurableDataTypeId,
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
  String? get name => r'measurableSuggestionsControllerProvider';
}

/// See also [MeasurableSuggestionsController].
class MeasurableSuggestionsControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<
        MeasurableSuggestionsController, List<num>?> {
  /// See also [MeasurableSuggestionsController].
  MeasurableSuggestionsControllerProvider({
    required String measurableDataTypeId,
  }) : this._internal(
          () => MeasurableSuggestionsController()
            ..measurableDataTypeId = measurableDataTypeId,
          from: measurableSuggestionsControllerProvider,
          name: r'measurableSuggestionsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$measurableSuggestionsControllerHash,
          dependencies: MeasurableSuggestionsControllerFamily._dependencies,
          allTransitiveDependencies:
              MeasurableSuggestionsControllerFamily._allTransitiveDependencies,
          measurableDataTypeId: measurableDataTypeId,
        );

  MeasurableSuggestionsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.measurableDataTypeId,
  }) : super.internal();

  final String measurableDataTypeId;

  @override
  FutureOr<List<num>?> runNotifierBuild(
    covariant MeasurableSuggestionsController notifier,
  ) {
    return notifier.build(
      measurableDataTypeId: measurableDataTypeId,
    );
  }

  @override
  Override overrideWith(MeasurableSuggestionsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: MeasurableSuggestionsControllerProvider._internal(
        () => create()..measurableDataTypeId = measurableDataTypeId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        measurableDataTypeId: measurableDataTypeId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<MeasurableSuggestionsController,
      List<num>?> createElement() {
    return _MeasurableSuggestionsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MeasurableSuggestionsControllerProvider &&
        other.measurableDataTypeId == measurableDataTypeId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, measurableDataTypeId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MeasurableSuggestionsControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<num>?> {
  /// The parameter `measurableDataTypeId` of this provider.
  String get measurableDataTypeId;
}

class _MeasurableSuggestionsControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        MeasurableSuggestionsController,
        List<num>?> with MeasurableSuggestionsControllerRef {
  _MeasurableSuggestionsControllerProviderElement(super.provider);

  @override
  String get measurableDataTypeId =>
      (origin as MeasurableSuggestionsControllerProvider).measurableDataTypeId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
