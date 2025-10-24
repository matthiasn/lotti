// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_flag_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$configFlagHash() => r'e5b746907c52cfd27327e97c82a5ee23f1ffa118';

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

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
///
/// Copied from [configFlag].
@ProviderFor(configFlag)
const configFlagProvider = ConfigFlagFamily();

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
///
/// Copied from [configFlag].
class ConfigFlagFamily extends Family<AsyncValue<bool>> {
  /// Provides a stream of the status (bool) for a specific config flag.
  /// Returns false by default if the flag doesn't exist or has no status.
  ///
  /// Copied from [configFlag].
  const ConfigFlagFamily();

  /// Provides a stream of the status (bool) for a specific config flag.
  /// Returns false by default if the flag doesn't exist or has no status.
  ///
  /// Copied from [configFlag].
  ConfigFlagProvider call(
    String flagName,
  ) {
    return ConfigFlagProvider(
      flagName,
    );
  }

  @override
  ConfigFlagProvider getProviderOverride(
    covariant ConfigFlagProvider provider,
  ) {
    return call(
      provider.flagName,
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
  String? get name => r'configFlagProvider';
}

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
///
/// Copied from [configFlag].
class ConfigFlagProvider extends AutoDisposeStreamProvider<bool> {
  /// Provides a stream of the status (bool) for a specific config flag.
  /// Returns false by default if the flag doesn't exist or has no status.
  ///
  /// Copied from [configFlag].
  ConfigFlagProvider(
    String flagName,
  ) : this._internal(
          (ref) => configFlag(
            ref as ConfigFlagRef,
            flagName,
          ),
          from: configFlagProvider,
          name: r'configFlagProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$configFlagHash,
          dependencies: ConfigFlagFamily._dependencies,
          allTransitiveDependencies:
              ConfigFlagFamily._allTransitiveDependencies,
          flagName: flagName,
        );

  ConfigFlagProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.flagName,
  }) : super.internal();

  final String flagName;

  @override
  Override overrideWith(
    Stream<bool> Function(ConfigFlagRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConfigFlagProvider._internal(
        (ref) => create(ref as ConfigFlagRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        flagName: flagName,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<bool> createElement() {
    return _ConfigFlagProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConfigFlagProvider && other.flagName == flagName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, flagName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConfigFlagRef on AutoDisposeStreamProviderRef<bool> {
  /// The parameter `flagName` of this provider.
  String get flagName;
}

class _ConfigFlagProviderElement extends AutoDisposeStreamProviderElement<bool>
    with ConfigFlagRef {
  _ConfigFlagProviderElement(super.provider);

  @override
  String get flagName => (origin as ConfigFlagProvider).flagName;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
