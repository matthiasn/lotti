// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_entries_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$linkedEntriesControllerHash() =>
    r'd5fa807c8730c555ada7a5b0b931c1e493137413';

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

abstract class _$LinkedEntriesController
    extends BuildlessAutoDisposeAsyncNotifier<List<EntryLink>> {
  late final String id;

  FutureOr<List<EntryLink>> build({
    required String id,
  });
}

/// See also [LinkedEntriesController].
@ProviderFor(LinkedEntriesController)
const linkedEntriesControllerProvider = LinkedEntriesControllerFamily();

/// See also [LinkedEntriesController].
class LinkedEntriesControllerFamily
    extends Family<AsyncValue<List<EntryLink>>> {
  /// See also [LinkedEntriesController].
  const LinkedEntriesControllerFamily();

  /// See also [LinkedEntriesController].
  LinkedEntriesControllerProvider call({
    required String id,
  }) {
    return LinkedEntriesControllerProvider(
      id: id,
    );
  }

  @override
  LinkedEntriesControllerProvider getProviderOverride(
    covariant LinkedEntriesControllerProvider provider,
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
  String? get name => r'linkedEntriesControllerProvider';
}

/// See also [LinkedEntriesController].
class LinkedEntriesControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<LinkedEntriesController,
        List<EntryLink>> {
  /// See also [LinkedEntriesController].
  LinkedEntriesControllerProvider({
    required String id,
  }) : this._internal(
          () => LinkedEntriesController()..id = id,
          from: linkedEntriesControllerProvider,
          name: r'linkedEntriesControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$linkedEntriesControllerHash,
          dependencies: LinkedEntriesControllerFamily._dependencies,
          allTransitiveDependencies:
              LinkedEntriesControllerFamily._allTransitiveDependencies,
          id: id,
        );

  LinkedEntriesControllerProvider._internal(
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
  FutureOr<List<EntryLink>> runNotifierBuild(
    covariant LinkedEntriesController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(LinkedEntriesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LinkedEntriesControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<LinkedEntriesController,
      List<EntryLink>> createElement() {
    return _LinkedEntriesControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedEntriesControllerProvider && other.id == id;
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
mixin LinkedEntriesControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<EntryLink>> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LinkedEntriesControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<LinkedEntriesController,
        List<EntryLink>> with LinkedEntriesControllerRef {
  _LinkedEntriesControllerProviderElement(super.provider);

  @override
  String get id => (origin as LinkedEntriesControllerProvider).id;
}

String _$includeHiddenControllerHash() =>
    r'8edd4a77df97b17dd1c49287aec43358881ca3f2';

/// See also [IncludeHiddenController].
@ProviderFor(IncludeHiddenController)
final includeHiddenControllerProvider =
    AutoDisposeNotifierProvider<IncludeHiddenController, bool>.internal(
  IncludeHiddenController.new,
  name: r'includeHiddenControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$includeHiddenControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$IncludeHiddenController = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
