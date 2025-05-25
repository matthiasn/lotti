// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_provider_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inferenceProviderFormControllerHash() =>
    r'99e75918250819e79df9a9fe1fd9a1b8a388d692';

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

abstract class _$InferenceProviderFormController
    extends BuildlessAutoDisposeAsyncNotifier<InferenceProviderFormState?> {
  late final String? configId;

  FutureOr<InferenceProviderFormState?> build({
    required String? configId,
  });
}

/// See also [InferenceProviderFormController].
@ProviderFor(InferenceProviderFormController)
const inferenceProviderFormControllerProvider =
    InferenceProviderFormControllerFamily();

/// See also [InferenceProviderFormController].
class InferenceProviderFormControllerFamily
    extends Family<AsyncValue<InferenceProviderFormState?>> {
  /// See also [InferenceProviderFormController].
  const InferenceProviderFormControllerFamily();

  /// See also [InferenceProviderFormController].
  InferenceProviderFormControllerProvider call({
    required String? configId,
  }) {
    return InferenceProviderFormControllerProvider(
      configId: configId,
    );
  }

  @override
  InferenceProviderFormControllerProvider getProviderOverride(
    covariant InferenceProviderFormControllerProvider provider,
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
  String? get name => r'inferenceProviderFormControllerProvider';
}

/// See also [InferenceProviderFormController].
class InferenceProviderFormControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<
        InferenceProviderFormController, InferenceProviderFormState?> {
  /// See also [InferenceProviderFormController].
  InferenceProviderFormControllerProvider({
    required String? configId,
  }) : this._internal(
          () => InferenceProviderFormController()..configId = configId,
          from: inferenceProviderFormControllerProvider,
          name: r'inferenceProviderFormControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$inferenceProviderFormControllerHash,
          dependencies: InferenceProviderFormControllerFamily._dependencies,
          allTransitiveDependencies:
              InferenceProviderFormControllerFamily._allTransitiveDependencies,
          configId: configId,
        );

  InferenceProviderFormControllerProvider._internal(
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
  FutureOr<InferenceProviderFormState?> runNotifierBuild(
    covariant InferenceProviderFormController notifier,
  ) {
    return notifier.build(
      configId: configId,
    );
  }

  @override
  Override overrideWith(InferenceProviderFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InferenceProviderFormControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<InferenceProviderFormController,
      InferenceProviderFormState?> createElement() {
    return _InferenceProviderFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InferenceProviderFormControllerProvider &&
        other.configId == configId;
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
mixin InferenceProviderFormControllerRef
    on AutoDisposeAsyncNotifierProviderRef<InferenceProviderFormState?> {
  /// The parameter `configId` of this provider.
  String? get configId;
}

class _InferenceProviderFormControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        InferenceProviderFormController,
        InferenceProviderFormState?> with InferenceProviderFormControllerRef {
  _InferenceProviderFormControllerProviderElement(super.provider);

  @override
  String? get configId =>
      (origin as InferenceProviderFormControllerProvider).configId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
