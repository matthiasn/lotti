// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_item_suggestions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$actionItemSuggestionsControllerHash() =>
    r'ebaed46416b8da04fdd67092aa73d91ace8066f0';

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

abstract class _$ActionItemSuggestionsController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [ActionItemSuggestionsController].
@ProviderFor(ActionItemSuggestionsController)
const actionItemSuggestionsControllerProvider =
    ActionItemSuggestionsControllerFamily();

/// See also [ActionItemSuggestionsController].
class ActionItemSuggestionsControllerFamily extends Family<String> {
  /// See also [ActionItemSuggestionsController].
  const ActionItemSuggestionsControllerFamily();

  /// See also [ActionItemSuggestionsController].
  ActionItemSuggestionsControllerProvider call({
    required String id,
  }) {
    return ActionItemSuggestionsControllerProvider(
      id: id,
    );
  }

  @override
  ActionItemSuggestionsControllerProvider getProviderOverride(
    covariant ActionItemSuggestionsControllerProvider provider,
  ) {
    return call(
      id: provider.id,
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
  String? get name => r'actionItemSuggestionsControllerProvider';
}

/// See also [ActionItemSuggestionsController].
class ActionItemSuggestionsControllerProvider
    extends AutoDisposeNotifierProviderImpl<ActionItemSuggestionsController,
        String> {
  /// See also [ActionItemSuggestionsController].
  ActionItemSuggestionsControllerProvider({
    required String id,
  }) : this._internal(
          () => ActionItemSuggestionsController()..id = id,
          from: actionItemSuggestionsControllerProvider,
          name: r'actionItemSuggestionsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$actionItemSuggestionsControllerHash,
          dependencies: ActionItemSuggestionsControllerFamily._dependencies,
          allTransitiveDependencies:
              ActionItemSuggestionsControllerFamily._allTransitiveDependencies,
          id: id,
        );

  ActionItemSuggestionsControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  String runNotifierBuild(
    covariant ActionItemSuggestionsController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ActionItemSuggestionsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ActionItemSuggestionsControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ActionItemSuggestionsController, String>
      createElement() {
    return _ActionItemSuggestionsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ActionItemSuggestionsControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ActionItemSuggestionsControllerRef
    on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ActionItemSuggestionsControllerProviderElement
    extends AutoDisposeNotifierProviderElement<ActionItemSuggestionsController,
        String> with ActionItemSuggestionsControllerRef {
  _ActionItemSuggestionsControllerProviderElement(super.provider);

  @override
  String get id => (origin as ActionItemSuggestionsControllerProvider).id;
}

String _$suggestionsStatusControllerHash() =>
    r'7e960c050871c96f9f05d1a95412ed1a268a4d18';

abstract class _$SuggestionsStatusController
    extends BuildlessAutoDisposeNotifier<SuggestionsInferenceStatus> {
  late final String id;

  SuggestionsInferenceStatus build({
    required String id,
  });
}

/// See also [SuggestionsStatusController].
@ProviderFor(SuggestionsStatusController)
const suggestionsStatusControllerProvider = SuggestionsStatusControllerFamily();

/// See also [SuggestionsStatusController].
class SuggestionsStatusControllerFamily
    extends Family<SuggestionsInferenceStatus> {
  /// See also [SuggestionsStatusController].
  const SuggestionsStatusControllerFamily();

  /// See also [SuggestionsStatusController].
  SuggestionsStatusControllerProvider call({
    required String id,
  }) {
    return SuggestionsStatusControllerProvider(
      id: id,
    );
  }

  @override
  SuggestionsStatusControllerProvider getProviderOverride(
    covariant SuggestionsStatusControllerProvider provider,
  ) {
    return call(
      id: provider.id,
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
  String? get name => r'suggestionsStatusControllerProvider';
}

/// See also [SuggestionsStatusController].
class SuggestionsStatusControllerProvider
    extends AutoDisposeNotifierProviderImpl<SuggestionsStatusController,
        SuggestionsInferenceStatus> {
  /// See also [SuggestionsStatusController].
  SuggestionsStatusControllerProvider({
    required String id,
  }) : this._internal(
          () => SuggestionsStatusController()..id = id,
          from: suggestionsStatusControllerProvider,
          name: r'suggestionsStatusControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$suggestionsStatusControllerHash,
          dependencies: SuggestionsStatusControllerFamily._dependencies,
          allTransitiveDependencies:
              SuggestionsStatusControllerFamily._allTransitiveDependencies,
          id: id,
        );

  SuggestionsStatusControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  SuggestionsInferenceStatus runNotifierBuild(
    covariant SuggestionsStatusController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(SuggestionsStatusController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SuggestionsStatusControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<SuggestionsStatusController,
      SuggestionsInferenceStatus> createElement() {
    return _SuggestionsStatusControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SuggestionsStatusControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SuggestionsStatusControllerRef
    on AutoDisposeNotifierProviderRef<SuggestionsInferenceStatus> {
  /// The parameter `id` of this provider.
  String get id;
}

class _SuggestionsStatusControllerProviderElement
    extends AutoDisposeNotifierProviderElement<SuggestionsStatusController,
        SuggestionsInferenceStatus> with SuggestionsStatusControllerRef {
  _SuggestionsStatusControllerProviderElement(super.provider);

  @override
  String get id => (origin as SuggestionsStatusControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
