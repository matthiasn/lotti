// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_model_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inferenceModelFormControllerHash() =>
    r'e6781e9be008dedea56355848b94b4bb6ceeba59';

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

abstract class _$InferenceModelFormController
    extends BuildlessAutoDisposeAsyncNotifier<InferenceModelFormState?> {
  late final String? configId;

  FutureOr<InferenceModelFormState?> build({
    required String? configId,
  });
}

/// See also [InferenceModelFormController].
@ProviderFor(InferenceModelFormController)
const inferenceModelFormControllerProvider =
    InferenceModelFormControllerFamily();

/// See also [InferenceModelFormController].
class InferenceModelFormControllerFamily
    extends Family<AsyncValue<InferenceModelFormState?>> {
  /// See also [InferenceModelFormController].
  const InferenceModelFormControllerFamily();

  /// See also [InferenceModelFormController].
  InferenceModelFormControllerProvider call({
    required String? configId,
  }) {
    return InferenceModelFormControllerProvider(
      configId: configId,
    );
  }

  @override
  InferenceModelFormControllerProvider getProviderOverride(
    covariant InferenceModelFormControllerProvider provider,
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
  String? get name => r'inferenceModelFormControllerProvider';
}

/// See also [InferenceModelFormController].
class InferenceModelFormControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<InferenceModelFormController,
        InferenceModelFormState?> {
  /// See also [InferenceModelFormController].
  InferenceModelFormControllerProvider({
    required String? configId,
  }) : this._internal(
          () => InferenceModelFormController()..configId = configId,
          from: inferenceModelFormControllerProvider,
          name: r'inferenceModelFormControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$inferenceModelFormControllerHash,
          dependencies: InferenceModelFormControllerFamily._dependencies,
          allTransitiveDependencies:
              InferenceModelFormControllerFamily._allTransitiveDependencies,
          configId: configId,
        );

  InferenceModelFormControllerProvider._internal(
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
  FutureOr<InferenceModelFormState?> runNotifierBuild(
    covariant InferenceModelFormController notifier,
  ) {
    return notifier.build(
      configId: configId,
    );
  }

  @override
  Override overrideWith(InferenceModelFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InferenceModelFormControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<InferenceModelFormController,
      InferenceModelFormState?> createElement() {
    return _InferenceModelFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InferenceModelFormControllerProvider &&
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
mixin InferenceModelFormControllerRef
    on AutoDisposeAsyncNotifierProviderRef<InferenceModelFormState?> {
  /// The parameter `configId` of this provider.
  String? get configId;
}

class _InferenceModelFormControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        InferenceModelFormController,
        InferenceModelFormState?> with InferenceModelFormControllerRef {
  _InferenceModelFormControllerProviderElement(super.provider);

  @override
  String? get configId =>
      (origin as InferenceModelFormControllerProvider).configId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
