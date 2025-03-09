// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$entryControllerHash() => r'6050c83c03664fa61db6a3216ae3da81685f381c';

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

abstract class _$EntryController
    extends BuildlessAutoDisposeAsyncNotifier<EntryState?> {
  late final String id;

  FutureOr<EntryState?> build({
    required String id,
  });
}

/// See also [EntryController].
@ProviderFor(EntryController)
const entryControllerProvider = EntryControllerFamily();

/// See also [EntryController].
class EntryControllerFamily extends Family<AsyncValue<EntryState?>> {
  /// See also [EntryController].
  const EntryControllerFamily();

  /// See also [EntryController].
  EntryControllerProvider call({
    required String id,
  }) {
    return EntryControllerProvider(
      id: id,
    );
  }

  @override
  EntryControllerProvider getProviderOverride(
    covariant EntryControllerProvider provider,
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
  String? get name => r'entryControllerProvider';
}

/// See also [EntryController].
class EntryControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<EntryController, EntryState?> {
  /// See also [EntryController].
  EntryControllerProvider({
    required String id,
  }) : this._internal(
          () => EntryController()..id = id,
          from: entryControllerProvider,
          name: r'entryControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$entryControllerHash,
          dependencies: EntryControllerFamily._dependencies,
          allTransitiveDependencies:
              EntryControllerFamily._allTransitiveDependencies,
          id: id,
        );

  EntryControllerProvider._internal(
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
  FutureOr<EntryState?> runNotifierBuild(
    covariant EntryController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(EntryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: EntryControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<EntryController, EntryState?>
      createElement() {
    return _EntryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EntryControllerProvider && other.id == id;
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
mixin EntryControllerRef on AutoDisposeAsyncNotifierProviderRef<EntryState?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _EntryControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<EntryController,
        EntryState?> with EntryControllerRef {
  _EntryControllerProviderElement(super.provider);

  @override
  String get id => (origin as EntryControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
