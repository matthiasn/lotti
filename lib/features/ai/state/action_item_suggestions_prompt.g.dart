// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_item_suggestions_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$actionItemSuggestionsPromptControllerHash() =>
    r'b8971d11e12e8ec99b8976296c4e159c7b121bec';

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

abstract class _$ActionItemSuggestionsPromptController
    extends BuildlessAutoDisposeAsyncNotifier<String?> {
  late final String id;

  FutureOr<String?> build({
    required String id,
  });
}

/// See also [ActionItemSuggestionsPromptController].
@ProviderFor(ActionItemSuggestionsPromptController)
const actionItemSuggestionsPromptControllerProvider =
    ActionItemSuggestionsPromptControllerFamily();

/// See also [ActionItemSuggestionsPromptController].
class ActionItemSuggestionsPromptControllerFamily
    extends Family<AsyncValue<String?>> {
  /// See also [ActionItemSuggestionsPromptController].
  const ActionItemSuggestionsPromptControllerFamily();

  /// See also [ActionItemSuggestionsPromptController].
  ActionItemSuggestionsPromptControllerProvider call({
    required String id,
  }) {
    return ActionItemSuggestionsPromptControllerProvider(
      id: id,
    );
  }

  @override
  ActionItemSuggestionsPromptControllerProvider getProviderOverride(
    covariant ActionItemSuggestionsPromptControllerProvider provider,
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
  String? get name => r'actionItemSuggestionsPromptControllerProvider';
}

/// See also [ActionItemSuggestionsPromptController].
class ActionItemSuggestionsPromptControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<
        ActionItemSuggestionsPromptController, String?> {
  /// See also [ActionItemSuggestionsPromptController].
  ActionItemSuggestionsPromptControllerProvider({
    required String id,
  }) : this._internal(
          () => ActionItemSuggestionsPromptController()..id = id,
          from: actionItemSuggestionsPromptControllerProvider,
          name: r'actionItemSuggestionsPromptControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$actionItemSuggestionsPromptControllerHash,
          dependencies:
              ActionItemSuggestionsPromptControllerFamily._dependencies,
          allTransitiveDependencies: ActionItemSuggestionsPromptControllerFamily
              ._allTransitiveDependencies,
          id: id,
        );

  ActionItemSuggestionsPromptControllerProvider._internal(
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
  FutureOr<String?> runNotifierBuild(
    covariant ActionItemSuggestionsPromptController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(
      ActionItemSuggestionsPromptController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ActionItemSuggestionsPromptControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ActionItemSuggestionsPromptController,
      String?> createElement() {
    return _ActionItemSuggestionsPromptControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ActionItemSuggestionsPromptControllerProvider &&
        other.id == id;
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
mixin ActionItemSuggestionsPromptControllerRef
    on AutoDisposeAsyncNotifierProviderRef<String?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ActionItemSuggestionsPromptControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<
        ActionItemSuggestionsPromptController,
        String?> with ActionItemSuggestionsPromptControllerRef {
  _ActionItemSuggestionsPromptControllerProviderElement(super.provider);

  @override
  String get id => (origin as ActionItemSuggestionsPromptControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
