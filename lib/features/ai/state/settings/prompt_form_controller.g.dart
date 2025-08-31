// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$promptFormControllerHash() =>
    r'b28bdcc196f8dfe8b7f5e3659b5f81e228243c37';

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

abstract class _$PromptFormController
    extends BuildlessAutoDisposeAsyncNotifier<PromptFormState?> {
  late final String? configId;

  FutureOr<PromptFormState?> build({
    required String? configId,
  });
}

/// See also [PromptFormController].
@ProviderFor(PromptFormController)
const promptFormControllerProvider = PromptFormControllerFamily();

/// See also [PromptFormController].
class PromptFormControllerFamily extends Family<AsyncValue<PromptFormState?>> {
  /// See also [PromptFormController].
  const PromptFormControllerFamily();

  /// See also [PromptFormController].
  PromptFormControllerProvider call({
    required String? configId,
  }) {
    return PromptFormControllerProvider(
      configId: configId,
    );
  }

  @override
  PromptFormControllerProvider getProviderOverride(
    covariant PromptFormControllerProvider provider,
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
  String? get name => r'promptFormControllerProvider';
}

/// See also [PromptFormController].
class PromptFormControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    PromptFormController, PromptFormState?> {
  /// See also [PromptFormController].
  PromptFormControllerProvider({
    required String? configId,
  }) : this._internal(
          () => PromptFormController()..configId = configId,
          from: promptFormControllerProvider,
          name: r'promptFormControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$promptFormControllerHash,
          dependencies: PromptFormControllerFamily._dependencies,
          allTransitiveDependencies:
              PromptFormControllerFamily._allTransitiveDependencies,
          configId: configId,
        );

  PromptFormControllerProvider._internal(
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
  FutureOr<PromptFormState?> runNotifierBuild(
    covariant PromptFormController notifier,
  ) {
    return notifier.build(
      configId: configId,
    );
  }

  @override
  Override overrideWith(PromptFormController Function() create) {
    return ProviderOverride(
      origin: this,
      override: PromptFormControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<PromptFormController,
      PromptFormState?> createElement() {
    return _PromptFormControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PromptFormControllerProvider && other.configId == configId;
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
mixin PromptFormControllerRef
    on AutoDisposeAsyncNotifierProviderRef<PromptFormState?> {
  /// The parameter `configId` of this provider.
  String? get configId;
}

class _PromptFormControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<PromptFormController,
        PromptFormState?> with PromptFormControllerRef {
  _PromptFormControllerProviderElement(super.provider);

  @override
  String? get configId => (origin as PromptFormControllerProvider).configId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
