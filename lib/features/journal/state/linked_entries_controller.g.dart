// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_entries_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$linkedEntriesControllerHash() =>
    r'846f664c0a5e59e63d0a6fe1e012d2a1c6298d06';

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
  late final String entryId;
  late final bool includedHidden;

  FutureOr<List<EntryLink>> build({
    required String entryId,
    bool includedHidden = false,
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
    required String entryId,
    bool includedHidden = false,
  }) {
    return LinkedEntriesControllerProvider(
      entryId: entryId,
      includedHidden: includedHidden,
    );
  }

  @override
  LinkedEntriesControllerProvider getProviderOverride(
    covariant LinkedEntriesControllerProvider provider,
  ) {
    return call(
      entryId: provider.entryId,
      includedHidden: provider.includedHidden,
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
    required String entryId,
    bool includedHidden = false,
  }) : this._internal(
          () => LinkedEntriesController()
            ..entryId = entryId
            ..includedHidden = includedHidden,
          from: linkedEntriesControllerProvider,
          name: r'linkedEntriesControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$linkedEntriesControllerHash,
          dependencies: LinkedEntriesControllerFamily._dependencies,
          allTransitiveDependencies:
              LinkedEntriesControllerFamily._allTransitiveDependencies,
          entryId: entryId,
          includedHidden: includedHidden,
        );

  LinkedEntriesControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.entryId,
    required this.includedHidden,
  }) : super.internal();

  final String entryId;
  final bool includedHidden;

  @override
  FutureOr<List<EntryLink>> runNotifierBuild(
    covariant LinkedEntriesController notifier,
  ) {
    return notifier.build(
      entryId: entryId,
      includedHidden: includedHidden,
    );
  }

  @override
  Override overrideWith(LinkedEntriesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LinkedEntriesControllerProvider._internal(
        () => create()
          ..entryId = entryId
          ..includedHidden = includedHidden,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        entryId: entryId,
        includedHidden: includedHidden,
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
    return other is LinkedEntriesControllerProvider &&
        other.entryId == entryId &&
        other.includedHidden == includedHidden;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, entryId.hashCode);
    hash = _SystemHash.combine(hash, includedHidden.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LinkedEntriesControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<EntryLink>> {
  /// The parameter `entryId` of this provider.
  String get entryId;

  /// The parameter `includedHidden` of this provider.
  bool get includedHidden;
}

class _LinkedEntriesControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<LinkedEntriesController,
        List<EntryLink>> with LinkedEntriesControllerRef {
  _LinkedEntriesControllerProviderElement(super.provider);

  @override
  String get entryId => (origin as LinkedEntriesControllerProvider).entryId;
  @override
  bool get includedHidden =>
      (origin as LinkedEntriesControllerProvider).includedHidden;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
