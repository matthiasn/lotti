// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eligibleChatModelsForCategoryHash() =>
    r'af9ae8fbd283e902184cac20aea7939c7d2232f2';

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

/// Eligible chat models for a category
/// Criteria:
/// - Model id is referenced by at least one allowed prompt in the category
/// - Model supports function calling
/// - Model supports text input modality
///
/// Copied from [eligibleChatModelsForCategory].
@ProviderFor(eligibleChatModelsForCategory)
const eligibleChatModelsForCategoryProvider =
    EligibleChatModelsForCategoryFamily();

/// Eligible chat models for a category
/// Criteria:
/// - Model id is referenced by at least one allowed prompt in the category
/// - Model supports function calling
/// - Model supports text input modality
///
/// Copied from [eligibleChatModelsForCategory].
class EligibleChatModelsForCategoryFamily
    extends Family<AsyncValue<List<AiConfigModel>>> {
  /// Eligible chat models for a category
  /// Criteria:
  /// - Model id is referenced by at least one allowed prompt in the category
  /// - Model supports function calling
  /// - Model supports text input modality
  ///
  /// Copied from [eligibleChatModelsForCategory].
  const EligibleChatModelsForCategoryFamily();

  /// Eligible chat models for a category
  /// Criteria:
  /// - Model id is referenced by at least one allowed prompt in the category
  /// - Model supports function calling
  /// - Model supports text input modality
  ///
  /// Copied from [eligibleChatModelsForCategory].
  EligibleChatModelsForCategoryProvider call(
    String categoryId,
  ) {
    return EligibleChatModelsForCategoryProvider(
      categoryId,
    );
  }

  @override
  EligibleChatModelsForCategoryProvider getProviderOverride(
    covariant EligibleChatModelsForCategoryProvider provider,
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
  String? get name => r'eligibleChatModelsForCategoryProvider';
}

/// Eligible chat models for a category
/// Criteria:
/// - Model id is referenced by at least one allowed prompt in the category
/// - Model supports function calling
/// - Model supports text input modality
///
/// Copied from [eligibleChatModelsForCategory].
class EligibleChatModelsForCategoryProvider
    extends AutoDisposeFutureProvider<List<AiConfigModel>> {
  /// Eligible chat models for a category
  /// Criteria:
  /// - Model id is referenced by at least one allowed prompt in the category
  /// - Model supports function calling
  /// - Model supports text input modality
  ///
  /// Copied from [eligibleChatModelsForCategory].
  EligibleChatModelsForCategoryProvider(
    String categoryId,
  ) : this._internal(
          (ref) => eligibleChatModelsForCategory(
            ref as EligibleChatModelsForCategoryRef,
            categoryId,
          ),
          from: eligibleChatModelsForCategoryProvider,
          name: r'eligibleChatModelsForCategoryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$eligibleChatModelsForCategoryHash,
          dependencies: EligibleChatModelsForCategoryFamily._dependencies,
          allTransitiveDependencies:
              EligibleChatModelsForCategoryFamily._allTransitiveDependencies,
          categoryId: categoryId,
        );

  EligibleChatModelsForCategoryProvider._internal(
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
    FutureOr<List<AiConfigModel>> Function(
            EligibleChatModelsForCategoryRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EligibleChatModelsForCategoryProvider._internal(
        (ref) => create(ref as EligibleChatModelsForCategoryRef),
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
  AutoDisposeFutureProviderElement<List<AiConfigModel>> createElement() {
    return _EligibleChatModelsForCategoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EligibleChatModelsForCategoryProvider &&
        other.categoryId == categoryId;
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
mixin EligibleChatModelsForCategoryRef
    on AutoDisposeFutureProviderRef<List<AiConfigModel>> {
  /// The parameter `categoryId` of this provider.
  String get categoryId;
}

class _EligibleChatModelsForCategoryProviderElement
    extends AutoDisposeFutureProviderElement<List<AiConfigModel>>
    with EligibleChatModelsForCategoryRef {
  _EligibleChatModelsForCategoryProviderElement(super.provider);

  @override
  String get categoryId =>
      (origin as EligibleChatModelsForCategoryProvider).categoryId;
}

String _$hasReasoningModelForCategoryHash() =>
    r'c5c561f358e856de8e211e5a23436035b614d479';

/// Whether at least one reasoning-capable eligible model exists for a category
///
/// Copied from [hasReasoningModelForCategory].
@ProviderFor(hasReasoningModelForCategory)
const hasReasoningModelForCategoryProvider =
    HasReasoningModelForCategoryFamily();

/// Whether at least one reasoning-capable eligible model exists for a category
///
/// Copied from [hasReasoningModelForCategory].
class HasReasoningModelForCategoryFamily extends Family<AsyncValue<bool>> {
  /// Whether at least one reasoning-capable eligible model exists for a category
  ///
  /// Copied from [hasReasoningModelForCategory].
  const HasReasoningModelForCategoryFamily();

  /// Whether at least one reasoning-capable eligible model exists for a category
  ///
  /// Copied from [hasReasoningModelForCategory].
  HasReasoningModelForCategoryProvider call(
    String categoryId,
  ) {
    return HasReasoningModelForCategoryProvider(
      categoryId,
    );
  }

  @override
  HasReasoningModelForCategoryProvider getProviderOverride(
    covariant HasReasoningModelForCategoryProvider provider,
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
  String? get name => r'hasReasoningModelForCategoryProvider';
}

/// Whether at least one reasoning-capable eligible model exists for a category
///
/// Copied from [hasReasoningModelForCategory].
class HasReasoningModelForCategoryProvider
    extends AutoDisposeFutureProvider<bool> {
  /// Whether at least one reasoning-capable eligible model exists for a category
  ///
  /// Copied from [hasReasoningModelForCategory].
  HasReasoningModelForCategoryProvider(
    String categoryId,
  ) : this._internal(
          (ref) => hasReasoningModelForCategory(
            ref as HasReasoningModelForCategoryRef,
            categoryId,
          ),
          from: hasReasoningModelForCategoryProvider,
          name: r'hasReasoningModelForCategoryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$hasReasoningModelForCategoryHash,
          dependencies: HasReasoningModelForCategoryFamily._dependencies,
          allTransitiveDependencies:
              HasReasoningModelForCategoryFamily._allTransitiveDependencies,
          categoryId: categoryId,
        );

  HasReasoningModelForCategoryProvider._internal(
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
    FutureOr<bool> Function(HasReasoningModelForCategoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HasReasoningModelForCategoryProvider._internal(
        (ref) => create(ref as HasReasoningModelForCategoryRef),
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
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _HasReasoningModelForCategoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasReasoningModelForCategoryProvider &&
        other.categoryId == categoryId;
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
mixin HasReasoningModelForCategoryRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `categoryId` of this provider.
  String get categoryId;
}

class _HasReasoningModelForCategoryProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with HasReasoningModelForCategoryRef {
  _HasReasoningModelForCategoryProviderElement(super.provider);

  @override
  String get categoryId =>
      (origin as HasReasoningModelForCategoryProvider).categoryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
