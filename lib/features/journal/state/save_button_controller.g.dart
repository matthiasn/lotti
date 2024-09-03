// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_button_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$saveButtonControllerHash() =>
    r'9182c8dbd4ede104a007b687a993aa73a1f2a9a4';

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

abstract class _$SaveButtonController
    extends BuildlessAutoDisposeAsyncNotifier<bool?> {
  late final String id;

  FutureOr<bool?> build({
    required String id,
  });
}

/// See also [SaveButtonController].
@ProviderFor(SaveButtonController)
const saveButtonControllerProvider = SaveButtonControllerFamily();

/// See also [SaveButtonController].
class SaveButtonControllerFamily extends Family<AsyncValue<bool?>> {
  /// See also [SaveButtonController].
  const SaveButtonControllerFamily();

  /// See also [SaveButtonController].
  SaveButtonControllerProvider call({
    required String id,
  }) {
    return SaveButtonControllerProvider(
      id: id,
    );
  }

  @override
  SaveButtonControllerProvider getProviderOverride(
    covariant SaveButtonControllerProvider provider,
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
  String? get name => r'saveButtonControllerProvider';
}

/// See also [SaveButtonController].
class SaveButtonControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<SaveButtonController, bool?> {
  /// See also [SaveButtonController].
  SaveButtonControllerProvider({
    required String id,
  }) : this._internal(
          () => SaveButtonController()..id = id,
          from: saveButtonControllerProvider,
          name: r'saveButtonControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveButtonControllerHash,
          dependencies: SaveButtonControllerFamily._dependencies,
          allTransitiveDependencies:
              SaveButtonControllerFamily._allTransitiveDependencies,
          id: id,
        );

  SaveButtonControllerProvider._internal(
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
  FutureOr<bool?> runNotifierBuild(
    covariant SaveButtonController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(SaveButtonController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SaveButtonControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<SaveButtonController, bool?>
      createElement() {
    return _SaveButtonControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveButtonControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveButtonControllerRef on AutoDisposeAsyncNotifierProviderRef<bool?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _SaveButtonControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SaveButtonController, bool?>
    with SaveButtonControllerRef {
  _SaveButtonControllerProviderElement(super.provider);

  @override
  String get id => (origin as SaveButtonControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
