// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_from_entries_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$linkedFromEntriesControllerHash() =>
    r'f0e539e16b539e4177fd402ed1150b391b3248f3';

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

abstract class _$LinkedFromEntriesController
    extends BuildlessAutoDisposeAsyncNotifier<List<JournalEntity>> {
  late final String id;

  FutureOr<List<JournalEntity>> build({
    required String id,
  });
}

/// See also [LinkedFromEntriesController].
@ProviderFor(LinkedFromEntriesController)
const linkedFromEntriesControllerProvider = LinkedFromEntriesControllerFamily();

/// See also [LinkedFromEntriesController].
class LinkedFromEntriesControllerFamily
    extends Family<AsyncValue<List<JournalEntity>>> {
  /// See also [LinkedFromEntriesController].
  const LinkedFromEntriesControllerFamily();

  /// See also [LinkedFromEntriesController].
  LinkedFromEntriesControllerProvider call({
    required String id,
  }) {
    return LinkedFromEntriesControllerProvider(
      id: id,
    );
  }

  @override
  LinkedFromEntriesControllerProvider getProviderOverride(
    covariant LinkedFromEntriesControllerProvider provider,
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
  String? get name => r'linkedFromEntriesControllerProvider';
}

/// See also [LinkedFromEntriesController].
class LinkedFromEntriesControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<LinkedFromEntriesController,
        List<JournalEntity>> {
  /// See also [LinkedFromEntriesController].
  LinkedFromEntriesControllerProvider({
    required String id,
  }) : this._internal(
          () => LinkedFromEntriesController()..id = id,
          from: linkedFromEntriesControllerProvider,
          name: r'linkedFromEntriesControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$linkedFromEntriesControllerHash,
          dependencies: LinkedFromEntriesControllerFamily._dependencies,
          allTransitiveDependencies:
              LinkedFromEntriesControllerFamily._allTransitiveDependencies,
          id: id,
        );

  LinkedFromEntriesControllerProvider._internal(
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
  FutureOr<List<JournalEntity>> runNotifierBuild(
    covariant LinkedFromEntriesController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(LinkedFromEntriesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LinkedFromEntriesControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<LinkedFromEntriesController,
      List<JournalEntity>> createElement() {
    return _LinkedFromEntriesControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedFromEntriesControllerProvider && other.id == id;
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
mixin LinkedFromEntriesControllerRef
    on AutoDisposeAsyncNotifierProviderRef<List<JournalEntity>> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LinkedFromEntriesControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<LinkedFromEntriesController,
        List<JournalEntity>> with LinkedFromEntriesControllerRef {
  _LinkedFromEntriesControllerProviderElement(super.provider);

  @override
  String get id => (origin as LinkedFromEntriesControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
