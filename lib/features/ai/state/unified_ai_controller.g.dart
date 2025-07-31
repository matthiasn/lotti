// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_ai_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$availablePromptsHash() => r'460586d736d16ac2ee3236a60054f1e3e538fd05';

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

/// Provider to get available prompts for a given entity
///
/// Copied from [availablePrompts].
@ProviderFor(availablePrompts)
const availablePromptsProvider = AvailablePromptsFamily();

/// Provider to get available prompts for a given entity
///
/// Copied from [availablePrompts].
class AvailablePromptsFamily extends Family<AsyncValue<List<AiConfigPrompt>>> {
  /// Provider to get available prompts for a given entity
  ///
  /// Copied from [availablePrompts].
  const AvailablePromptsFamily();

  /// Provider to get available prompts for a given entity
  ///
  /// Copied from [availablePrompts].
  AvailablePromptsProvider call({
    required JournalEntity entity,
  }) {
    return AvailablePromptsProvider(
      entity: entity,
    );
  }

  @override
  AvailablePromptsProvider getProviderOverride(
    covariant AvailablePromptsProvider provider,
  ) {
    return call(
      entity: provider.entity,
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
  String? get name => r'availablePromptsProvider';
}

/// Provider to get available prompts for a given entity
///
/// Copied from [availablePrompts].
class AvailablePromptsProvider
    extends AutoDisposeFutureProvider<List<AiConfigPrompt>> {
  /// Provider to get available prompts for a given entity
  ///
  /// Copied from [availablePrompts].
  AvailablePromptsProvider({
    required JournalEntity entity,
  }) : this._internal(
          (ref) => availablePrompts(
            ref as AvailablePromptsRef,
            entity: entity,
          ),
          from: availablePromptsProvider,
          name: r'availablePromptsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$availablePromptsHash,
          dependencies: AvailablePromptsFamily._dependencies,
          allTransitiveDependencies:
              AvailablePromptsFamily._allTransitiveDependencies,
          entity: entity,
        );

  AvailablePromptsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entity,
  }) : super.internal();

  final JournalEntity entity;

  @override
  Override overrideWith(
    FutureOr<List<AiConfigPrompt>> Function(AvailablePromptsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AvailablePromptsProvider._internal(
        (ref) => create(ref as AvailablePromptsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entity: entity,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<AiConfigPrompt>> createElement() {
    return _AvailablePromptsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AvailablePromptsProvider && other.entity == entity;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entity.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AvailablePromptsRef
    on AutoDisposeFutureProviderRef<List<AiConfigPrompt>> {
  /// The parameter `entity` of this provider.
  JournalEntity get entity;
}

class _AvailablePromptsProviderElement
    extends AutoDisposeFutureProviderElement<List<AiConfigPrompt>>
    with AvailablePromptsRef {
  _AvailablePromptsProviderElement(super.provider);

  @override
  JournalEntity get entity => (origin as AvailablePromptsProvider).entity;
}

String _$hasAvailablePromptsHash() =>
    r'71510b79d630f895c53ed091099eb1f974d4bcf6';

/// Provider to check if there are any prompts available for an entity
///
/// Copied from [hasAvailablePrompts].
@ProviderFor(hasAvailablePrompts)
const hasAvailablePromptsProvider = HasAvailablePromptsFamily();

/// Provider to check if there are any prompts available for an entity
///
/// Copied from [hasAvailablePrompts].
class HasAvailablePromptsFamily extends Family<AsyncValue<bool>> {
  /// Provider to check if there are any prompts available for an entity
  ///
  /// Copied from [hasAvailablePrompts].
  const HasAvailablePromptsFamily();

  /// Provider to check if there are any prompts available for an entity
  ///
  /// Copied from [hasAvailablePrompts].
  HasAvailablePromptsProvider call({
    required JournalEntity entity,
  }) {
    return HasAvailablePromptsProvider(
      entity: entity,
    );
  }

  @override
  HasAvailablePromptsProvider getProviderOverride(
    covariant HasAvailablePromptsProvider provider,
  ) {
    return call(
      entity: provider.entity,
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
  String? get name => r'hasAvailablePromptsProvider';
}

/// Provider to check if there are any prompts available for an entity
///
/// Copied from [hasAvailablePrompts].
class HasAvailablePromptsProvider extends AutoDisposeFutureProvider<bool> {
  /// Provider to check if there are any prompts available for an entity
  ///
  /// Copied from [hasAvailablePrompts].
  HasAvailablePromptsProvider({
    required JournalEntity entity,
  }) : this._internal(
          (ref) => hasAvailablePrompts(
            ref as HasAvailablePromptsRef,
            entity: entity,
          ),
          from: hasAvailablePromptsProvider,
          name: r'hasAvailablePromptsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$hasAvailablePromptsHash,
          dependencies: HasAvailablePromptsFamily._dependencies,
          allTransitiveDependencies:
              HasAvailablePromptsFamily._allTransitiveDependencies,
          entity: entity,
        );

  HasAvailablePromptsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entity,
  }) : super.internal();

  final JournalEntity entity;

  @override
  Override overrideWith(
    FutureOr<bool> Function(HasAvailablePromptsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HasAvailablePromptsProvider._internal(
        (ref) => create(ref as HasAvailablePromptsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entity: entity,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _HasAvailablePromptsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasAvailablePromptsProvider && other.entity == entity;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entity.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HasAvailablePromptsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `entity` of this provider.
  JournalEntity get entity;
}

class _HasAvailablePromptsProviderElement
    extends AutoDisposeFutureProviderElement<bool> with HasAvailablePromptsRef {
  _HasAvailablePromptsProviderElement(super.provider);

  @override
  JournalEntity get entity => (origin as HasAvailablePromptsProvider).entity;
}

String _$triggerNewInferenceHash() =>
    r'a0aac25a770cf5fe0a1633ee9c9f6ad3e415b673';

/// Provider to trigger a new inference run by invalidating the controller
///
/// Copied from [triggerNewInference].
@ProviderFor(triggerNewInference)
const triggerNewInferenceProvider = TriggerNewInferenceFamily();

/// Provider to trigger a new inference run by invalidating the controller
///
/// Copied from [triggerNewInference].
class TriggerNewInferenceFamily extends Family<AsyncValue<void>> {
  /// Provider to trigger a new inference run by invalidating the controller
  ///
  /// Copied from [triggerNewInference].
  const TriggerNewInferenceFamily();

  /// Provider to trigger a new inference run by invalidating the controller
  ///
  /// Copied from [triggerNewInference].
  TriggerNewInferenceProvider call({
    required String entityId,
    required String promptId,
  }) {
    return TriggerNewInferenceProvider(
      entityId: entityId,
      promptId: promptId,
    );
  }

  @override
  TriggerNewInferenceProvider getProviderOverride(
    covariant TriggerNewInferenceProvider provider,
  ) {
    return call(
      entityId: provider.entityId,
      promptId: provider.promptId,
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
  String? get name => r'triggerNewInferenceProvider';
}

/// Provider to trigger a new inference run by invalidating the controller
///
/// Copied from [triggerNewInference].
class TriggerNewInferenceProvider extends AutoDisposeFutureProvider<void> {
  /// Provider to trigger a new inference run by invalidating the controller
  ///
  /// Copied from [triggerNewInference].
  TriggerNewInferenceProvider({
    required String entityId,
    required String promptId,
  }) : this._internal(
          (ref) => triggerNewInference(
            ref as TriggerNewInferenceRef,
            entityId: entityId,
            promptId: promptId,
          ),
          from: triggerNewInferenceProvider,
          name: r'triggerNewInferenceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$triggerNewInferenceHash,
          dependencies: TriggerNewInferenceFamily._dependencies,
          allTransitiveDependencies:
              TriggerNewInferenceFamily._allTransitiveDependencies,
          entityId: entityId,
          promptId: promptId,
        );

  TriggerNewInferenceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entityId,
    required this.promptId,
  }) : super.internal();

  final String entityId;
  final String promptId;

  @override
  Override overrideWith(
    FutureOr<void> Function(TriggerNewInferenceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TriggerNewInferenceProvider._internal(
        (ref) => create(ref as TriggerNewInferenceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entityId: entityId,
        promptId: promptId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<void> createElement() {
    return _TriggerNewInferenceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TriggerNewInferenceProvider &&
        other.entityId == entityId &&
        other.promptId == promptId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entityId.hashCode);
    hash = _SystemHash.combine(hash, promptId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TriggerNewInferenceRef on AutoDisposeFutureProviderRef<void> {
  /// The parameter `entityId` of this provider.
  String get entityId;

  /// The parameter `promptId` of this provider.
  String get promptId;
}

class _TriggerNewInferenceProviderElement
    extends AutoDisposeFutureProviderElement<void> with TriggerNewInferenceRef {
  _TriggerNewInferenceProviderElement(super.provider);

  @override
  String get entityId => (origin as TriggerNewInferenceProvider).entityId;
  @override
  String get promptId => (origin as TriggerNewInferenceProvider).promptId;
}

String _$unifiedAiControllerHash() =>
    r'c8b41efe764cdb1219912f1d0a8858297041da9b';

abstract class _$UnifiedAiController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String entityId;
  late final String promptId;

  String build({
    required String entityId,
    required String promptId,
  });
}

/// Controller for running unified AI inference with configurable prompts
///
/// Copied from [UnifiedAiController].
@ProviderFor(UnifiedAiController)
const unifiedAiControllerProvider = UnifiedAiControllerFamily();

/// Controller for running unified AI inference with configurable prompts
///
/// Copied from [UnifiedAiController].
class UnifiedAiControllerFamily extends Family<String> {
  /// Controller for running unified AI inference with configurable prompts
  ///
  /// Copied from [UnifiedAiController].
  const UnifiedAiControllerFamily();

  /// Controller for running unified AI inference with configurable prompts
  ///
  /// Copied from [UnifiedAiController].
  UnifiedAiControllerProvider call({
    required String entityId,
    required String promptId,
  }) {
    return UnifiedAiControllerProvider(
      entityId: entityId,
      promptId: promptId,
    );
  }

  @override
  UnifiedAiControllerProvider getProviderOverride(
    covariant UnifiedAiControllerProvider provider,
  ) {
    return call(
      entityId: provider.entityId,
      promptId: provider.promptId,
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
  String? get name => r'unifiedAiControllerProvider';
}

/// Controller for running unified AI inference with configurable prompts
///
/// Copied from [UnifiedAiController].
class UnifiedAiControllerProvider
    extends AutoDisposeNotifierProviderImpl<UnifiedAiController, String> {
  /// Controller for running unified AI inference with configurable prompts
  ///
  /// Copied from [UnifiedAiController].
  UnifiedAiControllerProvider({
    required String entityId,
    required String promptId,
  }) : this._internal(
          () => UnifiedAiController()
            ..entityId = entityId
            ..promptId = promptId,
          from: unifiedAiControllerProvider,
          name: r'unifiedAiControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$unifiedAiControllerHash,
          dependencies: UnifiedAiControllerFamily._dependencies,
          allTransitiveDependencies:
              UnifiedAiControllerFamily._allTransitiveDependencies,
          entityId: entityId,
          promptId: promptId,
        );

  UnifiedAiControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entityId,
    required this.promptId,
  }) : super.internal();

  final String entityId;
  final String promptId;

  @override
  String runNotifierBuild(
    covariant UnifiedAiController notifier,
  ) {
    return notifier.build(
      entityId: entityId,
      promptId: promptId,
    );
  }

  @override
  Override overrideWith(UnifiedAiController Function() create) {
    return ProviderOverride(
      origin: this,
      override: UnifiedAiControllerProvider._internal(
        () => create()
          ..entityId = entityId
          ..promptId = promptId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entityId: entityId,
        promptId: promptId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<UnifiedAiController, String>
      createElement() {
    return _UnifiedAiControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnifiedAiControllerProvider &&
        other.entityId == entityId &&
        other.promptId == promptId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entityId.hashCode);
    hash = _SystemHash.combine(hash, promptId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UnifiedAiControllerRef on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `entityId` of this provider.
  String get entityId;

  /// The parameter `promptId` of this provider.
  String get promptId;
}

class _UnifiedAiControllerProviderElement
    extends AutoDisposeNotifierProviderElement<UnifiedAiController, String>
    with UnifiedAiControllerRef {
  _UnifiedAiControllerProviderElement(super.provider);

  @override
  String get entityId => (origin as UnifiedAiControllerProvider).entityId;
  @override
  String get promptId => (origin as UnifiedAiControllerProvider).promptId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
