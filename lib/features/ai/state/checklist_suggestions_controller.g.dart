// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_suggestions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checklistSuggestionsControllerHash() =>
    r'a0184684f1e8fc65f4693a2401d1c51707a22825';

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

abstract class _$ChecklistSuggestionsController
    extends BuildlessAsyncNotifier<List<ChecklistItemData>> {
  late final String id;

  FutureOr<List<ChecklistItemData>> build({
    required String id,
  });
}

/// See also [ChecklistSuggestionsController].
@ProviderFor(ChecklistSuggestionsController)
const checklistSuggestionsControllerProvider =
    ChecklistSuggestionsControllerFamily();

/// See also [ChecklistSuggestionsController].
class ChecklistSuggestionsControllerFamily
    extends Family<AsyncValue<List<ChecklistItemData>>> {
  /// See also [ChecklistSuggestionsController].
  const ChecklistSuggestionsControllerFamily();

  /// See also [ChecklistSuggestionsController].
  ChecklistSuggestionsControllerProvider call({
    required String id,
  }) {
    return ChecklistSuggestionsControllerProvider(
      id: id,
    );
  }

  @override
  ChecklistSuggestionsControllerProvider getProviderOverride(
    covariant ChecklistSuggestionsControllerProvider provider,
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
  String? get name => r'checklistSuggestionsControllerProvider';
}

/// See also [ChecklistSuggestionsController].
class ChecklistSuggestionsControllerProvider extends AsyncNotifierProviderImpl<
    ChecklistSuggestionsController, List<ChecklistItemData>> {
  /// See also [ChecklistSuggestionsController].
  ChecklistSuggestionsControllerProvider({
    required String id,
  }) : this._internal(
          () => ChecklistSuggestionsController()..id = id,
          from: checklistSuggestionsControllerProvider,
          name: r'checklistSuggestionsControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistSuggestionsControllerHash,
          dependencies: ChecklistSuggestionsControllerFamily._dependencies,
          allTransitiveDependencies:
              ChecklistSuggestionsControllerFamily._allTransitiveDependencies,
          id: id,
        );

  ChecklistSuggestionsControllerProvider._internal(
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
  FutureOr<List<ChecklistItemData>> runNotifierBuild(
    covariant ChecklistSuggestionsController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ChecklistSuggestionsController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistSuggestionsControllerProvider._internal(
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
  AsyncNotifierProviderElement<ChecklistSuggestionsController,
      List<ChecklistItemData>> createElement() {
    return _ChecklistSuggestionsControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistSuggestionsControllerProvider && other.id == id;
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
mixin ChecklistSuggestionsControllerRef
    on AsyncNotifierProviderRef<List<ChecklistItemData>> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ChecklistSuggestionsControllerProviderElement
    extends AsyncNotifierProviderElement<ChecklistSuggestionsController,
        List<ChecklistItemData>> with ChecklistSuggestionsControllerRef {
  _ChecklistSuggestionsControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistSuggestionsControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
