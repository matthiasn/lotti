// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$apiKeyFormControllerHash() =>
    r'baf9e4264f52ae2713e00da03c79798a020bfba1';

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

abstract class _$ApiKeyFormController
    extends BuildlessAutoDisposeAsyncNotifier<ApiKeyFormState?> {
  late final String? configId;

  FutureOr<ApiKeyFormState?> build({
    required String? configId,
  });
}

/// See also [ApiKeyFormController].
@ProviderFor(ApiKeyFormController)
const apiKeyFormControllerProvider = ApiKeyFormControllerFamily();

/// See also [ApiKeyFormController].
class ApiKeyFormControllerFamily extends Family<AsyncValue<ApiKeyFormState?>> {
  /// See also [ApiKeyFormController].
  const ApiKeyFormControllerFamily();

  /// See also [ApiKeyFormController].
  ApiKeyFormControllerProvider call({
    required String? configId,
  }) {
    return ApiKeyFormControllerProvider(
      configId: configId,
    );
  }

  @override
  ApiKeyFormControllerProvider getProviderOverride(
    covariant ApiKeyFormControllerProvider provider,
  ) {
    return call(
      configId: provider.configId,
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
  String? get name => r'apiKeyFormControllerProvider';
}

/// See also [ApiKeyFormController].
class ApiKeyFormControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ApiKeyFormController, ApiKeyFormState?> {
  /// See also [ApiKeyFormController].
  ApiKeyFormControllerProvider({
    required String? configId,
  }) : this._internal(
          () => ApiKeyFormController()..configId = configId,
          from: apiKeyFormControllerProvider,
          name: r'apiKeyFormControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$apiKeyFormControllerHash,
          dependencies: ApiKeyFormControllerFamily._dependencies,
          allTransitiveDependencies:
              ApiKeyFormControllerFamily._allTransitiveDependencies,
          configId: configId,
        );

  ApiKeyFormControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.configId,
  }) : super.internal();

  final String? configId;

  @override
  FutureOr<ApiKeyFormState?> runNotifierBuild(
    covariant ApiKeyFormController notifier,
  ) {
    return notifier.build(
      configId: configId,
    );
  }

  @override
  Override overrideWith(ApiKeyFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ApiKeyFormControllerProvider._internal(
        () => create()..configId = configId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        configId: configId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ApiKeyFormController,
      ApiKeyFormState?> createElement() {
    return _ApiKeyFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ApiKeyFormControllerProvider && other.configId == configId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, configId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ApiKeyFormControllerRef
    on AutoDisposeAsyncNotifierProviderRef<ApiKeyFormState?> {
  /// The parameter `configId` of this provider.
  String? get configId;
}

class _ApiKeyFormControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ApiKeyFormController,
        ApiKeyFormState?> with ApiKeyFormControllerRef {
  _ApiKeyFormControllerProviderElement(super.provider);

  @override
  String? get configId => (origin as ApiKeyFormControllerProvider).configId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
