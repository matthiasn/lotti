// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_chart_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$healthChartDataControllerHash() =>
    r'a8861ff8ffc25462e01bf2de63cb864fbe0e9bb2';

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

abstract class _$HealthChartDataController
    extends BuildlessAutoDisposeAsyncNotifier<List<JournalEntity>> {
  late final String healthDataType;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<JournalEntity>> build({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [HealthChartDataController].
@ProviderFor(HealthChartDataController)
const healthChartDataControllerProvider = HealthChartDataControllerFamily();

/// See also [HealthChartDataController].
class HealthChartDataControllerFamily
    extends Family<AsyncValue<List<JournalEntity>>> {
  /// See also [HealthChartDataController].
  const HealthChartDataControllerFamily();

  /// See also [HealthChartDataController].
  HealthChartDataControllerProvider call({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return HealthChartDataControllerProvider(
      healthDataType: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  HealthChartDataControllerProvider getProviderOverride(
    covariant HealthChartDataControllerProvider provider,
  ) {
    return call(
      healthDataType: provider.healthDataType,
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
  String? get name => r'healthChartDataControllerProvider';
}

/// See also [HealthChartDataController].
class HealthChartDataControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<HealthChartDataController,
        List<JournalEntity>> {
  /// See also [HealthChartDataController].
  HealthChartDataControllerProvider({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => HealthChartDataController()
            ..healthDataType = healthDataType
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
          from: healthChartDataControllerProvider,
          name: r'healthChartDataControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$healthChartDataControllerHash,
          dependencies: HealthChartDataControllerFamily._dependencies,
          allTransitiveDependencies:
              HealthChartDataControllerFamily._allTransitiveDependencies,
          healthDataType: healthDataType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

  HealthChartDataControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.healthDataType,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super.internal();

  final String healthDataType;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<JournalEntity>> runNotifierBuild(
    covariant HealthChartDataController notifier,
  ) {
    return notifier.build(
      healthDataType: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Override overrideWith(HealthChartDataController Function() create) {
    return ProviderOverride(
      origin: this,
      override: HealthChartDataControllerProvider._internal(
        () => create()
          ..healthDataType = healthDataType
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        healthDataType: healthDataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<HealthChartDataController,
      List<JournalEntity>> createElement() {
    return _HealthChartDataControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HealthChartDataControllerProvider &&
        other.healthDataType == healthDataType &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, healthDataType.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HealthChartDataControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<JournalEntity>> {
  /// The parameter `healthDataType` of this provider.
  String get healthDataType;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _HealthChartDataControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<HealthChartDataController,
        List<JournalEntity>> with HealthChartDataControllerRef {
  _HealthChartDataControllerProviderElement(super.provider);

  @override
  String get healthDataType =>
      (origin as HealthChartDataControllerProvider).healthDataType;
  @override
  DateTime get rangeStart =>
      (origin as HealthChartDataControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as HealthChartDataControllerProvider).rangeEnd;
}

String _$healthObservationsControllerHash() =>
    r'ac52068fe735260ad5fca783a267cb4f15747e6f';

abstract class _$HealthObservationsController
    extends BuildlessAutoDisposeAsyncNotifier<List<Observation>> {
  late final String healthDataType;
  late final DateTime rangeStart;
  late final DateTime rangeEnd;

  FutureOr<List<Observation>> build({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

/// See also [HealthObservationsController].
@ProviderFor(HealthObservationsController)
const healthObservationsControllerProvider =
    HealthObservationsControllerFamily();

/// See also [HealthObservationsController].
class HealthObservationsControllerFamily
    extends Family<AsyncValue<List<Observation>>> {
  /// See also [HealthObservationsController].
  const HealthObservationsControllerFamily();

  /// See also [HealthObservationsController].
  HealthObservationsControllerProvider call({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return HealthObservationsControllerProvider(
      healthDataType: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  HealthObservationsControllerProvider getProviderOverride(
    covariant HealthObservationsControllerProvider provider,
  ) {
    return call(
      healthDataType: provider.healthDataType,
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
  String? get name => r'healthObservationsControllerProvider';
}

/// See also [HealthObservationsController].
class HealthObservationsControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<HealthObservationsController,
        List<Observation>> {
  /// See also [HealthObservationsController].
  HealthObservationsControllerProvider({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) : this._internal(
          () => HealthObservationsController()
            ..healthDataType = healthDataType
            ..rangeStart = rangeStart
            ..rangeEnd = rangeEnd,
          from: healthObservationsControllerProvider,
          name: r'healthObservationsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$healthObservationsControllerHash,
          dependencies: HealthObservationsControllerFamily._dependencies,
          allTransitiveDependencies:
              HealthObservationsControllerFamily._allTransitiveDependencies,
          healthDataType: healthDataType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

  HealthObservationsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.healthDataType,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super.internal();

  final String healthDataType;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  FutureOr<List<Observation>> runNotifierBuild(
    covariant HealthObservationsController notifier,
  ) {
    return notifier.build(
      healthDataType: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Override overrideWith(HealthObservationsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: HealthObservationsControllerProvider._internal(
        () => create()
          ..healthDataType = healthDataType
          ..rangeStart = rangeStart
          ..rangeEnd = rangeEnd,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        healthDataType: healthDataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<HealthObservationsController,
      List<Observation>> createElement() {
    return _HealthObservationsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HealthObservationsControllerProvider &&
        other.healthDataType == healthDataType &&
        other.rangeStart == rangeStart &&
        other.rangeEnd == rangeEnd;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, healthDataType.hashCode);
    hash = _SystemHash.combine(hash, rangeStart.hashCode);
    hash = _SystemHash.combine(hash, rangeEnd.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HealthObservationsControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<Observation>> {
  /// The parameter `healthDataType` of this provider.
  String get healthDataType;

  /// The parameter `rangeStart` of this provider.
  DateTime get rangeStart;

  /// The parameter `rangeEnd` of this provider.
  DateTime get rangeEnd;
}

class _HealthObservationsControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        HealthObservationsController,
        List<Observation>> with HealthObservationsControllerRef {
  _HealthObservationsControllerProviderElement(super.provider);

  @override
  String get healthDataType =>
      (origin as HealthObservationsControllerProvider).healthDataType;
  @override
  DateTime get rangeStart =>
      (origin as HealthObservationsControllerProvider).rangeStart;
  @override
  DateTime get rangeEnd =>
      (origin as HealthObservationsControllerProvider).rangeEnd;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
