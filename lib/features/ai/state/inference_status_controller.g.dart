// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_status_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inferenceStatusControllerHash() =>
    r'7b6d14f4f9f60e17756a8aaa77f7f3dc0177a8a6';

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

abstract class _$InferenceStatusController
    extends BuildlessAutoDisposeNotifier<InferenceStatus> {
  late final String id;
  late final String aiResponseType;

  InferenceStatus build({
    required String id,
    required String aiResponseType,
  });
}

/// See also [InferenceStatusController].
@ProviderFor(InferenceStatusController)
const inferenceStatusControllerProvider = InferenceStatusControllerFamily();

/// See also [InferenceStatusController].
class InferenceStatusControllerFamily extends Family<InferenceStatus> {
  /// See also [InferenceStatusController].
  const InferenceStatusControllerFamily();

  /// See also [InferenceStatusController].
  InferenceStatusControllerProvider call({
    required String id,
    required String aiResponseType,
  }) {
    return InferenceStatusControllerProvider(
      id: id,
      aiResponseType: aiResponseType,
    );
  }

  @override
  InferenceStatusControllerProvider getProviderOverride(
    covariant InferenceStatusControllerProvider provider,
  ) {
    return call(
      id: provider.id,
      aiResponseType: provider.aiResponseType,
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
  String? get name => r'inferenceStatusControllerProvider';
}

/// See also [InferenceStatusController].
class InferenceStatusControllerProvider extends AutoDisposeNotifierProviderImpl<
    InferenceStatusController, InferenceStatus> {
  /// See also [InferenceStatusController].
  InferenceStatusControllerProvider({
    required String id,
    required String aiResponseType,
  }) : this._internal(
          () => InferenceStatusController()
            ..id = id
            ..aiResponseType = aiResponseType,
          from: inferenceStatusControllerProvider,
          name: r'inferenceStatusControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$inferenceStatusControllerHash,
          dependencies: InferenceStatusControllerFamily._dependencies,
          allTransitiveDependencies:
              InferenceStatusControllerFamily._allTransitiveDependencies,
          id: id,
          aiResponseType: aiResponseType,
        );

  InferenceStatusControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.aiResponseType,
  }) : super.internal();

  final String id;
  final String aiResponseType;

  @override
  InferenceStatus runNotifierBuild(
    covariant InferenceStatusController notifier,
  ) {
    return notifier.build(
      id: id,
      aiResponseType: aiResponseType,
    );
  }

  @override
  Override overrideWith(InferenceStatusController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InferenceStatusControllerProvider._internal(
        () => create()
          ..id = id
          ..aiResponseType = aiResponseType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        aiResponseType: aiResponseType,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<InferenceStatusController, InferenceStatus>
      createElement() {
    return _InferenceStatusControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InferenceStatusControllerProvider &&
        other.id == id &&
        other.aiResponseType == aiResponseType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, aiResponseType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin InferenceStatusControllerRef
    on AutoDisposeNotifierProviderRef<InferenceStatus> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `aiResponseType` of this provider.
  String get aiResponseType;
}

class _InferenceStatusControllerProviderElement
    extends AutoDisposeNotifierProviderElement<InferenceStatusController,
        InferenceStatus> with InferenceStatusControllerRef {
  _InferenceStatusControllerProviderElement(super.provider);

  @override
  String get id => (origin as InferenceStatusControllerProvider).id;
  @override
  String get aiResponseType =>
      (origin as InferenceStatusControllerProvider).aiResponseType;
}

String _$inferenceRunningControllerHash() =>
    r'f7ab0d70298907cd8e83db3f491244fe6df9f7dc';

abstract class _$InferenceRunningController
    extends BuildlessAutoDisposeNotifier<bool> {
  late final String id;
  late final Set<String> responseTypes;

  bool build({
    required String id,
    required Set<String> responseTypes,
  });
}

/// See also [InferenceRunningController].
@ProviderFor(InferenceRunningController)
const inferenceRunningControllerProvider = InferenceRunningControllerFamily();

/// See also [InferenceRunningController].
class InferenceRunningControllerFamily extends Family<bool> {
  /// See also [InferenceRunningController].
  const InferenceRunningControllerFamily();

  /// See also [InferenceRunningController].
  InferenceRunningControllerProvider call({
    required String id,
    required Set<String> responseTypes,
  }) {
    return InferenceRunningControllerProvider(
      id: id,
      responseTypes: responseTypes,
    );
  }

  @override
  InferenceRunningControllerProvider getProviderOverride(
    covariant InferenceRunningControllerProvider provider,
  ) {
    return call(
      id: provider.id,
      responseTypes: provider.responseTypes,
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
  String? get name => r'inferenceRunningControllerProvider';
}

/// See also [InferenceRunningController].
class InferenceRunningControllerProvider
    extends AutoDisposeNotifierProviderImpl<InferenceRunningController, bool> {
  /// See also [InferenceRunningController].
  InferenceRunningControllerProvider({
    required String id,
    required Set<String> responseTypes,
  }) : this._internal(
          () => InferenceRunningController()
            ..id = id
            ..responseTypes = responseTypes,
          from: inferenceRunningControllerProvider,
          name: r'inferenceRunningControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$inferenceRunningControllerHash,
          dependencies: InferenceRunningControllerFamily._dependencies,
          allTransitiveDependencies:
              InferenceRunningControllerFamily._allTransitiveDependencies,
          id: id,
          responseTypes: responseTypes,
        );

  InferenceRunningControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.responseTypes,
  }) : super.internal();

  final String id;
  final Set<String> responseTypes;

  @override
  bool runNotifierBuild(
    covariant InferenceRunningController notifier,
  ) {
    return notifier.build(
      id: id,
      responseTypes: responseTypes,
    );
  }

  @override
  Override overrideWith(InferenceRunningController Function() create) {
    return ProviderOverride(
      origin: this,
      override: InferenceRunningControllerProvider._internal(
        () => create()
          ..id = id
          ..responseTypes = responseTypes,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        responseTypes: responseTypes,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<InferenceRunningController, bool>
      createElement() {
    return _InferenceRunningControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is InferenceRunningControllerProvider &&
        other.id == id &&
        other.responseTypes == responseTypes;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, responseTypes.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin InferenceRunningControllerRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `responseTypes` of this provider.
  Set<String> get responseTypes;
}

class _InferenceRunningControllerProviderElement
    extends AutoDisposeNotifierProviderElement<InferenceRunningController, bool>
    with InferenceRunningControllerRef {
  _InferenceRunningControllerProviderElement(super.provider);

  @override
  String get id => (origin as InferenceRunningControllerProvider).id;
  @override
  Set<String> get responseTypes =>
      (origin as InferenceRunningControllerProvider).responseTypes;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
