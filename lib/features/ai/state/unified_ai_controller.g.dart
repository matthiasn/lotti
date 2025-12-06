// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_ai_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$availablePromptsHash() => r'6667b88bb57b6e54f3565ddb5627ba319479a339';

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

/// Provider to get available prompts for a given entity.
/// Uses entityId as key for stable provider identity across entity updates.
///
/// Copied from [availablePrompts].
@ProviderFor(availablePrompts)
const availablePromptsProvider = AvailablePromptsFamily();

/// Provider to get available prompts for a given entity.
/// Uses entityId as key for stable provider identity across entity updates.
///
/// Copied from [availablePrompts].
class AvailablePromptsFamily extends Family<AsyncValue<List<AiConfigPrompt>>> {
  /// Provider to get available prompts for a given entity.
  /// Uses entityId as key for stable provider identity across entity updates.
  ///
  /// Copied from [availablePrompts].
  const AvailablePromptsFamily();

  /// Provider to get available prompts for a given entity.
  /// Uses entityId as key for stable provider identity across entity updates.
  ///
  /// Copied from [availablePrompts].
  AvailablePromptsProvider call({
    required String entityId,
  }) {
    return AvailablePromptsProvider(
      entityId: entityId,
    );
  }

  @override
  AvailablePromptsProvider getProviderOverride(
    covariant AvailablePromptsProvider provider,
  ) {
    return call(
      entityId: provider.entityId,
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

/// Provider to get available prompts for a given entity.
/// Uses entityId as key for stable provider identity across entity updates.
///
/// Copied from [availablePrompts].
class AvailablePromptsProvider
    extends AutoDisposeFutureProvider<List<AiConfigPrompt>> {
  /// Provider to get available prompts for a given entity.
  /// Uses entityId as key for stable provider identity across entity updates.
  ///
  /// Copied from [availablePrompts].
  AvailablePromptsProvider({
    required String entityId,
  }) : this._internal(
          (ref) => availablePrompts(
            ref as AvailablePromptsRef,
            entityId: entityId,
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
          entityId: entityId,
        );

  AvailablePromptsProvider._internal(
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
        entityId: entityId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<AiConfigPrompt>> createElement() {
    return _AvailablePromptsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AvailablePromptsProvider && other.entityId == entityId;
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
mixin AvailablePromptsRef
    on AutoDisposeFutureProviderRef<List<AiConfigPrompt>> {
  /// The parameter `entityId` of this provider.
  String get entityId;
}

class _AvailablePromptsProviderElement
    extends AutoDisposeFutureProviderElement<List<AiConfigPrompt>>
    with AvailablePromptsRef {
  _AvailablePromptsProviderElement(super.provider);

  @override
  String get entityId => (origin as AvailablePromptsProvider).entityId;
}

String _$hasAvailablePromptsHash() =>
    r'3ff03f60e22a0d72dcff2d29e012b9a92a97af4f';

/// Provider to check if there are any prompts available for an entity.
/// Uses entityId as key for stable provider identity across entity updates.
///
/// Copied from [hasAvailablePrompts].
@ProviderFor(hasAvailablePrompts)
const hasAvailablePromptsProvider = HasAvailablePromptsFamily();

/// Provider to check if there are any prompts available for an entity.
/// Uses entityId as key for stable provider identity across entity updates.
///
/// Copied from [hasAvailablePrompts].
class HasAvailablePromptsFamily extends Family<AsyncValue<bool>> {
  /// Provider to check if there are any prompts available for an entity.
  /// Uses entityId as key for stable provider identity across entity updates.
  ///
  /// Copied from [hasAvailablePrompts].
  const HasAvailablePromptsFamily();

  /// Provider to check if there are any prompts available for an entity.
  /// Uses entityId as key for stable provider identity across entity updates.
  ///
  /// Copied from [hasAvailablePrompts].
  HasAvailablePromptsProvider call({
    required String entityId,
  }) {
    return HasAvailablePromptsProvider(
      entityId: entityId,
    );
  }

  @override
  HasAvailablePromptsProvider getProviderOverride(
    covariant HasAvailablePromptsProvider provider,
  ) {
    return call(
      entityId: provider.entityId,
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

/// Provider to check if there are any prompts available for an entity.
/// Uses entityId as key for stable provider identity across entity updates.
///
/// Copied from [hasAvailablePrompts].
class HasAvailablePromptsProvider extends AutoDisposeFutureProvider<bool> {
  /// Provider to check if there are any prompts available for an entity.
  /// Uses entityId as key for stable provider identity across entity updates.
  ///
  /// Copied from [hasAvailablePrompts].
  HasAvailablePromptsProvider({
    required String entityId,
  }) : this._internal(
          (ref) => hasAvailablePrompts(
            ref as HasAvailablePromptsRef,
            entityId: entityId,
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
          entityId: entityId,
        );

  HasAvailablePromptsProvider._internal(
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
        entityId: entityId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _HasAvailablePromptsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasAvailablePromptsProvider && other.entityId == entityId;
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
mixin HasAvailablePromptsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `entityId` of this provider.
  String get entityId;
}

class _HasAvailablePromptsProviderElement
    extends AutoDisposeFutureProviderElement<bool> with HasAvailablePromptsRef {
  _HasAvailablePromptsProviderElement(super.provider);

  @override
  String get entityId => (origin as HasAvailablePromptsProvider).entityId;
}

String _$categoryChangesHash() => r'4369114da64f35988884fe3bf5cce6b09393d2ae';

/// Provider to watch category changes
///
/// Copied from [categoryChanges].
@ProviderFor(categoryChanges)
const categoryChangesProvider = CategoryChangesFamily();

/// Provider to watch category changes
///
/// Copied from [categoryChanges].
class CategoryChangesFamily extends Family<AsyncValue<void>> {
  /// Provider to watch category changes
  ///
  /// Copied from [categoryChanges].
  const CategoryChangesFamily();

  /// Provider to watch category changes
  ///
  /// Copied from [categoryChanges].
  CategoryChangesProvider call(
    String categoryId,
  ) {
    return CategoryChangesProvider(
      categoryId,
    );
  }

  @override
  CategoryChangesProvider getProviderOverride(
    covariant CategoryChangesProvider provider,
  ) {
    return call(
      provider.categoryId,
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
  String? get name => r'categoryChangesProvider';
}

/// Provider to watch category changes
///
/// Copied from [categoryChanges].
class CategoryChangesProvider extends AutoDisposeStreamProvider<void> {
  /// Provider to watch category changes
  ///
  /// Copied from [categoryChanges].
  CategoryChangesProvider(
    String categoryId,
  ) : this._internal(
          (ref) => categoryChanges(
            ref as CategoryChangesRef,
            categoryId,
          ),
          from: categoryChangesProvider,
          name: r'categoryChangesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$categoryChangesHash,
          dependencies: CategoryChangesFamily._dependencies,
          allTransitiveDependencies:
              CategoryChangesFamily._allTransitiveDependencies,
          categoryId: categoryId,
        );

  CategoryChangesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.categoryId,
  }) : super.internal();

  final String categoryId;

  @override
  Override overrideWith(
    Stream<void> Function(CategoryChangesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CategoryChangesProvider._internal(
        (ref) => create(ref as CategoryChangesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        categoryId: categoryId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<void> createElement() {
    return _CategoryChangesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryChangesProvider && other.categoryId == categoryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, categoryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CategoryChangesRef on AutoDisposeStreamProviderRef<void> {
  /// The parameter `categoryId` of this provider.
  String get categoryId;
}

class _CategoryChangesProviderElement
    extends AutoDisposeStreamProviderElement<void> with CategoryChangesRef {
  _CategoryChangesProviderElement(super.provider);

  @override
  String get categoryId => (origin as CategoryChangesProvider).categoryId;
}

String _$triggerNewInferenceHash() =>
    r'7498c5784266cb41975d8b32d33266592c8cfaf0';

/// Provider to trigger a new inference run
///
/// Copied from [triggerNewInference].
@ProviderFor(triggerNewInference)
const triggerNewInferenceProvider = TriggerNewInferenceFamily();

/// Provider to trigger a new inference run
///
/// Copied from [triggerNewInference].
class TriggerNewInferenceFamily extends Family<AsyncValue<void>> {
  /// Provider to trigger a new inference run
  ///
  /// Copied from [triggerNewInference].
  const TriggerNewInferenceFamily();

  /// Provider to trigger a new inference run
  ///
  /// Copied from [triggerNewInference].
  TriggerNewInferenceProvider call({
    required String entityId,
    required String promptId,
    String? linkedEntityId,
  }) {
    return TriggerNewInferenceProvider(
      entityId: entityId,
      promptId: promptId,
      linkedEntityId: linkedEntityId,
    );
  }

  @override
  TriggerNewInferenceProvider getProviderOverride(
    covariant TriggerNewInferenceProvider provider,
  ) {
    return call(
      entityId: provider.entityId,
      promptId: provider.promptId,
      linkedEntityId: provider.linkedEntityId,
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

/// Provider to trigger a new inference run
///
/// Copied from [triggerNewInference].
class TriggerNewInferenceProvider extends AutoDisposeFutureProvider<void> {
  /// Provider to trigger a new inference run
  ///
  /// Copied from [triggerNewInference].
  TriggerNewInferenceProvider({
    required String entityId,
    required String promptId,
    String? linkedEntityId,
  }) : this._internal(
          (ref) => triggerNewInference(
            ref as TriggerNewInferenceRef,
            entityId: entityId,
            promptId: promptId,
            linkedEntityId: linkedEntityId,
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
          linkedEntityId: linkedEntityId,
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
    required this.linkedEntityId,
  }) : super.internal();

  final String entityId;
  final String promptId;
  final String? linkedEntityId;

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
        linkedEntityId: linkedEntityId,
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
        other.promptId == promptId &&
        other.linkedEntityId == linkedEntityId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entityId.hashCode);
    hash = _SystemHash.combine(hash, promptId.hashCode);
    hash = _SystemHash.combine(hash, linkedEntityId.hashCode);

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

  /// The parameter `linkedEntityId` of this provider.
  String? get linkedEntityId;
}

class _TriggerNewInferenceProviderElement
    extends AutoDisposeFutureProviderElement<void> with TriggerNewInferenceRef {
  _TriggerNewInferenceProviderElement(super.provider);

  @override
  String get entityId => (origin as TriggerNewInferenceProvider).entityId;
  @override
  String get promptId => (origin as TriggerNewInferenceProvider).promptId;
  @override
  String? get linkedEntityId =>
      (origin as TriggerNewInferenceProvider).linkedEntityId;
}

String _$unifiedAiControllerHash() =>
    r'e582d7d622c628b4c58bdff7965ff0a155e676cb';

abstract class _$UnifiedAiController extends BuildlessNotifier<UnifiedAiState> {
  late final String entityId;
  late final String promptId;

  UnifiedAiState build({
    required String entityId,
    required String promptId,
  });
}

/// Controller for running unified AI inference with configurable prompts
/// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
/// ensuring error state persists until the widget can read it.
///
/// Copied from [UnifiedAiController].
@ProviderFor(UnifiedAiController)
const unifiedAiControllerProvider = UnifiedAiControllerFamily();

/// Controller for running unified AI inference with configurable prompts
/// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
/// ensuring error state persists until the widget can read it.
///
/// Copied from [UnifiedAiController].
class UnifiedAiControllerFamily extends Family<UnifiedAiState> {
  /// Controller for running unified AI inference with configurable prompts
  /// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
  /// ensuring error state persists until the widget can read it.
  ///
  /// Copied from [UnifiedAiController].
  const UnifiedAiControllerFamily();

  /// Controller for running unified AI inference with configurable prompts
  /// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
  /// ensuring error state persists until the widget can read it.
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
/// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
/// ensuring error state persists until the widget can read it.
///
/// Copied from [UnifiedAiController].
class UnifiedAiControllerProvider
    extends NotifierProviderImpl<UnifiedAiController, UnifiedAiState> {
  /// Controller for running unified AI inference with configurable prompts
  /// Note: keepAlive prevents auto-dispose during async operations in catch blocks,
  /// ensuring error state persists until the widget can read it.
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
  UnifiedAiState runNotifierBuild(
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
  NotifierProviderElement<UnifiedAiController, UnifiedAiState> createElement() {
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
mixin UnifiedAiControllerRef on NotifierProviderRef<UnifiedAiState> {
  /// The parameter `entityId` of this provider.
  String get entityId;

  /// The parameter `promptId` of this provider.
  String get promptId;
}

class _UnifiedAiControllerProviderElement
    extends NotifierProviderElement<UnifiedAiController, UnifiedAiState>
    with UnifiedAiControllerRef {
  _UnifiedAiControllerProviderElement(super.provider);

  @override
  String get entityId => (origin as UnifiedAiControllerProvider).entityId;
  @override
  String get promptId => (origin as UnifiedAiControllerProvider).promptId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
