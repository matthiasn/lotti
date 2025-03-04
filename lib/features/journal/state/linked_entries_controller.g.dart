// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_entries_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$linkedEntriesControllerHash() =>
    r'233ba30fd610e9366af282fd28573fb8df7eb040';

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
    r'224d7a7bbee3c403c65bb85517e10fb1eeac3148';

abstract class _$IncludeHiddenController
    extends BuildlessAutoDisposeNotifier<bool> {
  late final String id;

  bool build({
    required String id,
  });
}

/// See also [IncludeHiddenController].
@ProviderFor(IncludeHiddenController)
const includeHiddenControllerProvider = IncludeHiddenControllerFamily();

/// See also [IncludeHiddenController].
class IncludeHiddenControllerFamily extends Family<bool> {
  /// See also [IncludeHiddenController].
  const IncludeHiddenControllerFamily();

  /// See also [IncludeHiddenController].
  IncludeHiddenControllerProvider call({
    required String id,
  }) {
    return IncludeHiddenControllerProvider(
      id: id,
    );
  }

  @override
  IncludeHiddenControllerProvider getProviderOverride(
    covariant IncludeHiddenControllerProvider provider,
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
  String? get name => r'includeHiddenControllerProvider';
}

/// See also [IncludeHiddenController].
class IncludeHiddenControllerProvider
    extends AutoDisposeNotifierProviderImpl<IncludeHiddenController, bool> {
  /// See also [IncludeHiddenController].
  IncludeHiddenControllerProvider({
    required String id,
  }) : this._internal(
          () => IncludeHiddenController()..id = id,
          from: includeHiddenControllerProvider,
          name: r'includeHiddenControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$includeHiddenControllerHash,
          dependencies: IncludeHiddenControllerFamily._dependencies,
          allTransitiveDependencies:
              IncludeHiddenControllerFamily._allTransitiveDependencies,
          id: id,
        );

  IncludeHiddenControllerProvider._internal(
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
  bool runNotifierBuild(
    covariant IncludeHiddenController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(IncludeHiddenController Function() create) {
    return ProviderOverride(
      origin: this,
      override: IncludeHiddenControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<IncludeHiddenController, bool>
      createElement() {
    return _IncludeHiddenControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncludeHiddenControllerProvider && other.id == id;
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
mixin IncludeHiddenControllerRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `id` of this provider.
  String get id;
}

class _IncludeHiddenControllerProviderElement
    extends AutoDisposeNotifierProviderElement<IncludeHiddenController, bool>
    with IncludeHiddenControllerRef {
  _IncludeHiddenControllerProviderElement(super.provider);

  @override
  String get id => (origin as IncludeHiddenControllerProvider).id;
}

String _$includeAiEntriesControllerHash() =>
    r'8db4e5da7dbd6f9ba3da50fc5227a5e0e507708a';

abstract class _$IncludeAiEntriesController
    extends BuildlessAutoDisposeNotifier<bool> {
  late final String id;

  bool build({
    required String id,
  });
}

/// See also [IncludeAiEntriesController].
@ProviderFor(IncludeAiEntriesController)
const includeAiEntriesControllerProvider = IncludeAiEntriesControllerFamily();

/// See also [IncludeAiEntriesController].
class IncludeAiEntriesControllerFamily extends Family<bool> {
  /// See also [IncludeAiEntriesController].
  const IncludeAiEntriesControllerFamily();

  /// See also [IncludeAiEntriesController].
  IncludeAiEntriesControllerProvider call({
    required String id,
  }) {
    return IncludeAiEntriesControllerProvider(
      id: id,
    );
  }

  @override
  IncludeAiEntriesControllerProvider getProviderOverride(
    covariant IncludeAiEntriesControllerProvider provider,
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
  String? get name => r'includeAiEntriesControllerProvider';
}

/// See also [IncludeAiEntriesController].
class IncludeAiEntriesControllerProvider
    extends AutoDisposeNotifierProviderImpl<IncludeAiEntriesController, bool> {
  /// See also [IncludeAiEntriesController].
  IncludeAiEntriesControllerProvider({
    required String id,
  }) : this._internal(
          () => IncludeAiEntriesController()..id = id,
          from: includeAiEntriesControllerProvider,
          name: r'includeAiEntriesControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$includeAiEntriesControllerHash,
          dependencies: IncludeAiEntriesControllerFamily._dependencies,
          allTransitiveDependencies:
              IncludeAiEntriesControllerFamily._allTransitiveDependencies,
          id: id,
        );

  IncludeAiEntriesControllerProvider._internal(
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
  bool runNotifierBuild(
    covariant IncludeAiEntriesController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(IncludeAiEntriesController Function() create) {
    return ProviderOverride(
      origin: this,
      override: IncludeAiEntriesControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<IncludeAiEntriesController, bool>
      createElement() {
    return _IncludeAiEntriesControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncludeAiEntriesControllerProvider && other.id == id;
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
mixin IncludeAiEntriesControllerRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `id` of this provider.
  String get id;
}

class _IncludeAiEntriesControllerProviderElement
    extends AutoDisposeNotifierProviderElement<IncludeAiEntriesController, bool>
    with IncludeAiEntriesControllerRef {
  _IncludeAiEntriesControllerProviderElement(super.provider);

  @override
  String get id => (origin as IncludeAiEntriesControllerProvider).id;
}

String _$newestLinkedIdControllerHash() =>
    r'61d42af166607a4262d284b86caa40eec3caa728';

abstract class _$NewestLinkedIdController
    extends BuildlessAutoDisposeAsyncNotifier<String?> {
  late final String? id;

  FutureOr<String?> build({
    required String? id,
  });
}

/// See also [NewestLinkedIdController].
@ProviderFor(NewestLinkedIdController)
const newestLinkedIdControllerProvider = NewestLinkedIdControllerFamily();

/// See also [NewestLinkedIdController].
class NewestLinkedIdControllerFamily extends Family<AsyncValue<String?>> {
  /// See also [NewestLinkedIdController].
  const NewestLinkedIdControllerFamily();

  /// See also [NewestLinkedIdController].
  NewestLinkedIdControllerProvider call({
    required String? id,
  }) {
    return NewestLinkedIdControllerProvider(
      id: id,
    );
  }

  @override
  NewestLinkedIdControllerProvider getProviderOverride(
    covariant NewestLinkedIdControllerProvider provider,
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
  String? get name => r'newestLinkedIdControllerProvider';
}

/// See also [NewestLinkedIdController].
class NewestLinkedIdControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<NewestLinkedIdController,
        String?> {
  /// See also [NewestLinkedIdController].
  NewestLinkedIdControllerProvider({
    required String? id,
  }) : this._internal(
          () => NewestLinkedIdController()..id = id,
          from: newestLinkedIdControllerProvider,
          name: r'newestLinkedIdControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$newestLinkedIdControllerHash,
          dependencies: NewestLinkedIdControllerFamily._dependencies,
          allTransitiveDependencies:
              NewestLinkedIdControllerFamily._allTransitiveDependencies,
          id: id,
        );

  NewestLinkedIdControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String? id;

  @override
  FutureOr<String?> runNotifierBuild(
    covariant NewestLinkedIdController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(NewestLinkedIdController Function() create) {
    return ProviderOverride(
      origin: this,
      override: NewestLinkedIdControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<NewestLinkedIdController, String?>
      createElement() {
    return _NewestLinkedIdControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NewestLinkedIdControllerProvider && other.id == id;
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
mixin NewestLinkedIdControllerRef
    on AutoDisposeAsyncNotifierProviderRef<String?> {
  /// The parameter `id` of this provider.
  String? get id;
}

class _NewestLinkedIdControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<NewestLinkedIdController,
        String?> with NewestLinkedIdControllerRef {
  _NewestLinkedIdControllerProviderElement(super.provider);

  @override
  String? get id => (origin as NewestLinkedIdControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
