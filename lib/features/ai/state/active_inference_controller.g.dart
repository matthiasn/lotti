// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_inference_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeInferenceControllerHash() =>
    r'd96687a383e71b961e8f507950d92f80db1e633a';

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

abstract class _$ActiveInferenceController
    extends BuildlessAutoDisposeNotifier<ActiveInferenceData?> {
  late final String entityId;
  late final AiResponseType aiResponseType;

  ActiveInferenceData? build({
    required String entityId,
    required AiResponseType aiResponseType,
  });
}

/// See also [ActiveInferenceController].
@ProviderFor(ActiveInferenceController)
const activeInferenceControllerProvider = ActiveInferenceControllerFamily();

/// See also [ActiveInferenceController].
class ActiveInferenceControllerFamily extends Family<ActiveInferenceData?> {
  /// See also [ActiveInferenceController].
  const ActiveInferenceControllerFamily();

  /// See also [ActiveInferenceController].
  ActiveInferenceControllerProvider call({
    required String entityId,
    required AiResponseType aiResponseType,
  }) {
    return ActiveInferenceControllerProvider(
      entityId: entityId,
      aiResponseType: aiResponseType,
    );
  }

  @override
  ActiveInferenceControllerProvider getProviderOverride(
    covariant ActiveInferenceControllerProvider provider,
  ) {
    return call(
      entityId: provider.entityId,
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
  String? get name => r'activeInferenceControllerProvider';
}

/// See also [ActiveInferenceController].
class ActiveInferenceControllerProvider extends AutoDisposeNotifierProviderImpl<
    ActiveInferenceController, ActiveInferenceData?> {
  /// See also [ActiveInferenceController].
  ActiveInferenceControllerProvider({
    required String entityId,
    required AiResponseType aiResponseType,
  }) : this._internal(
          () => ActiveInferenceController()
            ..entityId = entityId
            ..aiResponseType = aiResponseType,
          from: activeInferenceControllerProvider,
          name: r'activeInferenceControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$activeInferenceControllerHash,
          dependencies: ActiveInferenceControllerFamily._dependencies,
          allTransitiveDependencies:
              ActiveInferenceControllerFamily._allTransitiveDependencies,
          entityId: entityId,
          aiResponseType: aiResponseType,
        );

  ActiveInferenceControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entityId,
    required this.aiResponseType,
  }) : super.internal();

  final String entityId;
  final AiResponseType aiResponseType;

  @override
  ActiveInferenceData? runNotifierBuild(
    covariant ActiveInferenceController notifier,
  ) {
    return notifier.build(
      entityId: entityId,
      aiResponseType: aiResponseType,
    );
  }

  @override
  Override overrideWith(ActiveInferenceController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ActiveInferenceControllerProvider._internal(
        () => create()
          ..entityId = entityId
          ..aiResponseType = aiResponseType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entityId: entityId,
        aiResponseType: aiResponseType,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ActiveInferenceController,
      ActiveInferenceData?> createElement() {
    return _ActiveInferenceControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveInferenceControllerProvider &&
        other.entityId == entityId &&
        other.aiResponseType == aiResponseType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entityId.hashCode);
    hash = _SystemHash.combine(hash, aiResponseType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ActiveInferenceControllerRef
    on AutoDisposeNotifierProviderRef<ActiveInferenceData?> {
  /// The parameter `entityId` of this provider.
  String get entityId;

  /// The parameter `aiResponseType` of this provider.
  AiResponseType get aiResponseType;
}

class _ActiveInferenceControllerProviderElement
    extends AutoDisposeNotifierProviderElement<ActiveInferenceController,
        ActiveInferenceData?> with ActiveInferenceControllerRef {
  _ActiveInferenceControllerProviderElement(super.provider);

  @override
  String get entityId => (origin as ActiveInferenceControllerProvider).entityId;
  @override
  AiResponseType get aiResponseType =>
      (origin as ActiveInferenceControllerProvider).aiResponseType;
}

String _$activeInferenceByEntityHash() =>
    r'8154dbc469fdbab7f789ab4e56f4b8c801ce5fe1';

abstract class _$ActiveInferenceByEntity
    extends BuildlessAutoDisposeNotifier<ActiveInferenceData?> {
  late final String entityId;

  ActiveInferenceData? build(
    String entityId,
  );
}

/// See also [ActiveInferenceByEntity].
@ProviderFor(ActiveInferenceByEntity)
const activeInferenceByEntityProvider = ActiveInferenceByEntityFamily();

/// See also [ActiveInferenceByEntity].
class ActiveInferenceByEntityFamily extends Family<ActiveInferenceData?> {
  /// See also [ActiveInferenceByEntity].
  const ActiveInferenceByEntityFamily();

  /// See also [ActiveInferenceByEntity].
  ActiveInferenceByEntityProvider call(
    String entityId,
  ) {
    return ActiveInferenceByEntityProvider(
      entityId,
    );
  }

  @override
  ActiveInferenceByEntityProvider getProviderOverride(
    covariant ActiveInferenceByEntityProvider provider,
  ) {
    return call(
      provider.entityId,
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
  String? get name => r'activeInferenceByEntityProvider';
}

/// See also [ActiveInferenceByEntity].
class ActiveInferenceByEntityProvider extends AutoDisposeNotifierProviderImpl<
    ActiveInferenceByEntity, ActiveInferenceData?> {
  /// See also [ActiveInferenceByEntity].
  ActiveInferenceByEntityProvider(
    String entityId,
  ) : this._internal(
          () => ActiveInferenceByEntity()..entityId = entityId,
          from: activeInferenceByEntityProvider,
          name: r'activeInferenceByEntityProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$activeInferenceByEntityHash,
          dependencies: ActiveInferenceByEntityFamily._dependencies,
          allTransitiveDependencies:
              ActiveInferenceByEntityFamily._allTransitiveDependencies,
          entityId: entityId,
        );

  ActiveInferenceByEntityProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entityId,
  }) : super.internal();

  final String entityId;

  @override
  ActiveInferenceData? runNotifierBuild(
    covariant ActiveInferenceByEntity notifier,
  ) {
    return notifier.build(
      entityId,
    );
  }

  @override
  Override overrideWith(ActiveInferenceByEntity Function() create) {
    return ProviderOverride(
      origin: this,
      override: ActiveInferenceByEntityProvider._internal(
        () => create()..entityId = entityId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entityId: entityId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ActiveInferenceByEntity,
      ActiveInferenceData?> createElement() {
    return _ActiveInferenceByEntityProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveInferenceByEntityProvider &&
        other.entityId == entityId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entityId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ActiveInferenceByEntityRef
    on AutoDisposeNotifierProviderRef<ActiveInferenceData?> {
  /// The parameter `entityId` of this provider.
  String get entityId;
}

class _ActiveInferenceByEntityProviderElement
    extends AutoDisposeNotifierProviderElement<ActiveInferenceByEntity,
        ActiveInferenceData?> with ActiveInferenceByEntityRef {
  _ActiveInferenceByEntityProviderElement(super.provider);

  @override
  String get entityId => (origin as ActiveInferenceByEntityProvider).entityId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
