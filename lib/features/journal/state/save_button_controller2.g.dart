// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_button_controller2.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$saveButtonController2Hash() =>
    r'fc55b184e70174b2cd10d5a1e082cead3bfcddea';

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

abstract class _$SaveButtonController2
    extends BuildlessAutoDisposeAsyncNotifier<bool?> {
  late final String id;
  late final String? linkedFromId;

  FutureOr<bool?> build({
    required String id,
    String? linkedFromId,
  });
}

/// See also [SaveButtonController2].
@ProviderFor(SaveButtonController2)
const saveButtonController2Provider = SaveButtonController2Family();

/// See also [SaveButtonController2].
class SaveButtonController2Family extends Family<AsyncValue<bool?>> {
  /// See also [SaveButtonController2].
  const SaveButtonController2Family();

  /// See also [SaveButtonController2].
  SaveButtonController2Provider call({
    required String id,
    String? linkedFromId,
  }) {
    return SaveButtonController2Provider(
      id: id,
      linkedFromId: linkedFromId,
    );
  }

  @override
  SaveButtonController2Provider getProviderOverride(
    covariant SaveButtonController2Provider provider,
  ) {
    return call(
      id: provider.id,
      linkedFromId: provider.linkedFromId,
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
  String? get name => r'saveButtonController2Provider';
}

/// See also [SaveButtonController2].
class SaveButtonController2Provider
    extends AutoDisposeAsyncNotifierProviderImpl<SaveButtonController2, bool?> {
  /// See also [SaveButtonController2].
  SaveButtonController2Provider({
    required String id,
    String? linkedFromId,
  }) : this._internal(
          () => SaveButtonController2()
            ..id = id
            ..linkedFromId = linkedFromId,
          from: saveButtonController2Provider,
          name: r'saveButtonController2Provider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveButtonController2Hash,
          dependencies: SaveButtonController2Family._dependencies,
          allTransitiveDependencies:
              SaveButtonController2Family._allTransitiveDependencies,
          id: id,
          linkedFromId: linkedFromId,
        );

  SaveButtonController2Provider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.linkedFromId,
  }) : super.internal();

  final String id;
  final String? linkedFromId;

  @override
  FutureOr<bool?> runNotifierBuild(
    covariant SaveButtonController2 notifier,
  ) {
    return notifier.build(
      id: id,
      linkedFromId: linkedFromId,
    );
  }

  @override
  Override overrideWith(SaveButtonController2 Function() create) {
    return ProviderOverride(
      origin: this,
      override: SaveButtonController2Provider._internal(
        () => create()
          ..id = id
          ..linkedFromId = linkedFromId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        linkedFromId: linkedFromId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<SaveButtonController2, bool?>
      createElement() {
    return _SaveButtonController2ProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveButtonController2Provider &&
        other.id == id &&
        other.linkedFromId == linkedFromId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, linkedFromId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveButtonController2Ref on AutoDisposeAsyncNotifierProviderRef<bool?> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `linkedFromId` of this provider.
  String? get linkedFromId;
}

class _SaveButtonController2ProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SaveButtonController2,
        bool?> with SaveButtonController2Ref {
  _SaveButtonController2ProviderElement(super.provider);

  @override
  String get id => (origin as SaveButtonController2Provider).id;
  @override
  String? get linkedFromId =>
      (origin as SaveButtonController2Provider).linkedFromId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
