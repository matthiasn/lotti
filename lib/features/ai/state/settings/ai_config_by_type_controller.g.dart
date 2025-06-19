// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_by_type_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiConfigByIdHash() => r'4dce6fd111f80adaa5a13ea60f7cdfb8fe96ee5a';

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

/// Provider for getting a specific AiConfig by its ID
///
/// Copied from [aiConfigById].
@ProviderFor(aiConfigById)
const aiConfigByIdProvider = AiConfigByIdFamily();

/// Provider for getting a specific AiConfig by its ID
///
/// Copied from [aiConfigById].
class AiConfigByIdFamily extends Family<AsyncValue<AiConfig?>> {
  /// Provider for getting a specific AiConfig by its ID
  ///
  /// Copied from [aiConfigById].
  const AiConfigByIdFamily();

  /// Provider for getting a specific AiConfig by its ID
  ///
  /// Copied from [aiConfigById].
  AiConfigByIdProvider call(
    String id,
  ) {
    return AiConfigByIdProvider(
      id,
    );
  }

  @override
  AiConfigByIdProvider getProviderOverride(
    covariant AiConfigByIdProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'aiConfigByIdProvider';
}

/// Provider for getting a specific AiConfig by its ID
///
/// Copied from [aiConfigById].
class AiConfigByIdProvider extends AutoDisposeFutureProvider<AiConfig?> {
  /// Provider for getting a specific AiConfig by its ID
  ///
  /// Copied from [aiConfigById].
  AiConfigByIdProvider(
    String id,
  ) : this._internal(
          (ref) => aiConfigById(
            ref as AiConfigByIdRef,
            id,
          ),
          from: aiConfigByIdProvider,
          name: r'aiConfigByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiConfigByIdHash,
          dependencies: AiConfigByIdFamily._dependencies,
          allTransitiveDependencies:
              AiConfigByIdFamily._allTransitiveDependencies,
          id: id,
        );

  AiConfigByIdProvider._internal(
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
  Override overrideWith(
    FutureOr<AiConfig?> Function(AiConfigByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AiConfigByIdProvider._internal(
        (ref) => create(ref as AiConfigByIdRef),
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
  AutoDisposeFutureProviderElement<AiConfig?> createElement() {
    return _AiConfigByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiConfigByIdProvider && other.id == id;
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
mixin AiConfigByIdRef on AutoDisposeFutureProviderRef<AiConfig?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _AiConfigByIdProviderElement
    extends AutoDisposeFutureProviderElement<AiConfig?> with AiConfigByIdRef {
  _AiConfigByIdProviderElement(super.provider);

  @override
  String get id => (origin as AiConfigByIdProvider).id;
}

String _$aiConfigByTypeControllerHash() =>
    r'a808c63b14000abab40ea37fa9fdbafdfb1b1254';

abstract class _$AiConfigByTypeController
    extends BuildlessAutoDisposeStreamNotifier<List<AiConfig>> {
  late final AiConfigType configType;

  Stream<List<AiConfig>> build({
    required AiConfigType configType,
  });
}

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type
///
/// Copied from [AiConfigByTypeController].
@ProviderFor(AiConfigByTypeController)
const aiConfigByTypeControllerProvider = AiConfigByTypeControllerFamily();

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type
///
/// Copied from [AiConfigByTypeController].
class AiConfigByTypeControllerFamily
    extends Family<AsyncValue<List<AiConfig>>> {
  /// Controller for getting a list of AiConfig items of a specific type
  /// Used in settings list pages to display all configurations of a particular type
  ///
  /// Copied from [AiConfigByTypeController].
  const AiConfigByTypeControllerFamily();

  /// Controller for getting a list of AiConfig items of a specific type
  /// Used in settings list pages to display all configurations of a particular type
  ///
  /// Copied from [AiConfigByTypeController].
  AiConfigByTypeControllerProvider call({
    required AiConfigType configType,
  }) {
    return AiConfigByTypeControllerProvider(
      configType: configType,
    );
  }

  @override
  AiConfigByTypeControllerProvider getProviderOverride(
    covariant AiConfigByTypeControllerProvider provider,
  ) {
    return call(
      configType: provider.configType,
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
  String? get name => r'aiConfigByTypeControllerProvider';
}

/// Controller for getting a list of AiConfig items of a specific type
/// Used in settings list pages to display all configurations of a particular type
///
/// Copied from [AiConfigByTypeController].
class AiConfigByTypeControllerProvider
    extends AutoDisposeStreamNotifierProviderImpl<AiConfigByTypeController,
        List<AiConfig>> {
  /// Controller for getting a list of AiConfig items of a specific type
  /// Used in settings list pages to display all configurations of a particular type
  ///
  /// Copied from [AiConfigByTypeController].
  AiConfigByTypeControllerProvider({
    required AiConfigType configType,
  }) : this._internal(
          () => AiConfigByTypeController()..configType = configType,
          from: aiConfigByTypeControllerProvider,
          name: r'aiConfigByTypeControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiConfigByTypeControllerHash,
          dependencies: AiConfigByTypeControllerFamily._dependencies,
          allTransitiveDependencies:
              AiConfigByTypeControllerFamily._allTransitiveDependencies,
          configType: configType,
        );

  AiConfigByTypeControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.configType,
  }) : super.internal();

  final AiConfigType configType;

  @override
  Stream<List<AiConfig>> runNotifierBuild(
    covariant AiConfigByTypeController notifier,
  ) {
    return notifier.build(
      configType: configType,
    );
  }

  @override
  Override overrideWith(AiConfigByTypeController Function() create) {
    return ProviderOverride(
      origin: this,
      override: AiConfigByTypeControllerProvider._internal(
        () => create()..configType = configType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        configType: configType,
      ),
    );
  }

  @override
  AutoDisposeStreamNotifierProviderElement<AiConfigByTypeController,
      List<AiConfig>> createElement() {
    return _AiConfigByTypeControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiConfigByTypeControllerProvider &&
        other.configType == configType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, configType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AiConfigByTypeControllerRef
    on AutoDisposeStreamNotifierProviderRef<List<AiConfig>> {
  /// The parameter `configType` of this provider.
  AiConfigType get configType;
}

class _AiConfigByTypeControllerProviderElement
    extends AutoDisposeStreamNotifierProviderElement<AiConfigByTypeController,
        List<AiConfig>> with AiConfigByTypeControllerRef {
  _AiConfigByTypeControllerProviderElement(super.provider);

  @override
  AiConfigType get configType =>
      (origin as AiConfigByTypeControllerProvider).configType;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
