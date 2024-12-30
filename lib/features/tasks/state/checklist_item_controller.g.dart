// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_item_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$checklistItemControllerHash() =>
    r'd2d3983a388385dec375dd7648ab5ba26f05195b';

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

abstract class _$ChecklistItemController
    extends BuildlessAutoDisposeAsyncNotifier<ChecklistItem?> {
  late final String id;

  FutureOr<ChecklistItem?> build({
    required String id,
  });
}

/// See also [ChecklistItemController].
@ProviderFor(ChecklistItemController)
const checklistItemControllerProvider = ChecklistItemControllerFamily();

/// See also [ChecklistItemController].
class ChecklistItemControllerFamily extends Family<AsyncValue<ChecklistItem?>> {
  /// See also [ChecklistItemController].
  const ChecklistItemControllerFamily();

  /// See also [ChecklistItemController].
  ChecklistItemControllerProvider call({
    required String id,
  }) {
    return ChecklistItemControllerProvider(
      id: id,
    );
  }

  @override
  ChecklistItemControllerProvider getProviderOverride(
    covariant ChecklistItemControllerProvider provider,
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
  String? get name => r'checklistItemControllerProvider';
}

/// See also [ChecklistItemController].
class ChecklistItemControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ChecklistItemController,
        ChecklistItem?> {
  /// See also [ChecklistItemController].
  ChecklistItemControllerProvider({
    required String id,
  }) : this._internal(
          () => ChecklistItemController()..id = id,
          from: checklistItemControllerProvider,
          name: r'checklistItemControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$checklistItemControllerHash,
          dependencies: ChecklistItemControllerFamily._dependencies,
          allTransitiveDependencies:
              ChecklistItemControllerFamily._allTransitiveDependencies,
          id: id,
        );

  ChecklistItemControllerProvider._internal(
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
  FutureOr<ChecklistItem?> runNotifierBuild(
    covariant ChecklistItemController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(ChecklistItemController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChecklistItemControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChecklistItemController,
      ChecklistItem?> createElement() {
    return _ChecklistItemControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistItemControllerProvider && other.id == id;
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
mixin ChecklistItemControllerRef
    on AutoDisposeAsyncNotifierProviderRef<ChecklistItem?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ChecklistItemControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChecklistItemController,
        ChecklistItem?> with ChecklistItemControllerRef {
  _ChecklistItemControllerProviderElement(super.provider);

  @override
  String get id => (origin as ChecklistItemControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
