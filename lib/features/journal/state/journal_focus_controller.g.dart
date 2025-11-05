// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_focus_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$journalFocusControllerHash() =>
    r'229387822c8a304890ec00a6ea68319248a5594d';

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

abstract class _$JournalFocusController
    extends BuildlessAutoDisposeNotifier<JournalFocusIntent?> {
  late final String id;

  JournalFocusIntent? build({
    required String id,
  });
}

/// See also [JournalFocusController].
@ProviderFor(JournalFocusController)
const journalFocusControllerProvider = JournalFocusControllerFamily();

/// See also [JournalFocusController].
class JournalFocusControllerFamily extends Family<JournalFocusIntent?> {
  /// See also [JournalFocusController].
  const JournalFocusControllerFamily();

  /// See also [JournalFocusController].
  JournalFocusControllerProvider call({
    required String id,
  }) {
    return JournalFocusControllerProvider(
      id: id,
    );
  }

  @override
  JournalFocusControllerProvider getProviderOverride(
    covariant JournalFocusControllerProvider provider,
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
  String? get name => r'journalFocusControllerProvider';
}

/// See also [JournalFocusController].
class JournalFocusControllerProvider extends AutoDisposeNotifierProviderImpl<
    JournalFocusController, JournalFocusIntent?> {
  /// See also [JournalFocusController].
  JournalFocusControllerProvider({
    required String id,
  }) : this._internal(
          () => JournalFocusController()..id = id,
          from: journalFocusControllerProvider,
          name: r'journalFocusControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$journalFocusControllerHash,
          dependencies: JournalFocusControllerFamily._dependencies,
          allTransitiveDependencies:
              JournalFocusControllerFamily._allTransitiveDependencies,
          id: id,
        );

  JournalFocusControllerProvider._internal(
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
  JournalFocusIntent? runNotifierBuild(
    covariant JournalFocusController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(JournalFocusController Function() create) {
    return ProviderOverride(
      origin: this,
      override: JournalFocusControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<JournalFocusController,
      JournalFocusIntent?> createElement() {
    return _JournalFocusControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JournalFocusControllerProvider && other.id == id;
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
mixin JournalFocusControllerRef
    on AutoDisposeNotifierProviderRef<JournalFocusIntent?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _JournalFocusControllerProviderElement
    extends AutoDisposeNotifierProviderElement<JournalFocusController,
        JournalFocusIntent?> with JournalFocusControllerRef {
  _JournalFocusControllerProviderElement(super.provider);

  @override
  String get id => (origin as JournalFocusControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
