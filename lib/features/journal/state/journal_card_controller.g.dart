// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_card_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$journalCardControllerHash() =>
    r'15a2d0afee709b7aeb550e37ceb20ab8df792888';

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

abstract class _$JournalCardController
    extends BuildlessAutoDisposeAsyncNotifier<JournalEntity?> {
  late final String id;

  FutureOr<JournalEntity?> build({
    required String id,
  });
}

/// See also [JournalCardController].
@ProviderFor(JournalCardController)
const journalCardControllerProvider = JournalCardControllerFamily();

/// See also [JournalCardController].
class JournalCardControllerFamily extends Family<AsyncValue<JournalEntity?>> {
  /// See also [JournalCardController].
  const JournalCardControllerFamily();

  /// See also [JournalCardController].
  JournalCardControllerProvider call({
    required String id,
  }) {
    return JournalCardControllerProvider(
      id: id,
    );
  }

  @override
  JournalCardControllerProvider getProviderOverride(
    covariant JournalCardControllerProvider provider,
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
  String? get name => r'journalCardControllerProvider';
}

/// See also [JournalCardController].
class JournalCardControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<JournalCardController,
        JournalEntity?> {
  /// See also [JournalCardController].
  JournalCardControllerProvider({
    required String id,
  }) : this._internal(
          () => JournalCardController()..id = id,
          from: journalCardControllerProvider,
          name: r'journalCardControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$journalCardControllerHash,
          dependencies: JournalCardControllerFamily._dependencies,
          allTransitiveDependencies:
              JournalCardControllerFamily._allTransitiveDependencies,
          id: id,
        );

  JournalCardControllerProvider._internal(
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
  FutureOr<JournalEntity?> runNotifierBuild(
    covariant JournalCardController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(JournalCardController Function() create) {
    return ProviderOverride(
      origin: this,
      override: JournalCardControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<JournalCardController, JournalEntity?>
      createElement() {
    return _JournalCardControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalCardControllerProvider && other.id == id;
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
mixin JournalCardControllerRef
    on AutoDisposeAsyncNotifierProviderRef<JournalEntity?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _JournalCardControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<JournalCardController,
        JournalEntity?> with JournalCardControllerRef {
  _JournalCardControllerProviderElement(super.provider);

  @override
  String get id => (origin as JournalCardControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
