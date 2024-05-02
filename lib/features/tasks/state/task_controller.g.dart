// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$entityByIdHash() => r'97a8a64b584436ce2d4798d4eac959e82f7e8e04';

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

/// See also [entityById].
@ProviderFor(entityById)
const entityByIdProvider = EntityByIdFamily();

/// See also [entityById].
class EntityByIdFamily extends Family<AsyncValue<JournalEntity?>> {
  /// See also [entityById].
  const EntityByIdFamily();

  /// See also [entityById].
  EntityByIdProvider call({
    required String id,
  }) {
    return EntityByIdProvider(
      id: id,
    );
  }

  @override
  EntityByIdProvider getProviderOverride(
    covariant EntityByIdProvider provider,
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
  String? get name => r'entityByIdProvider';
}

/// See also [entityById].
class EntityByIdProvider extends AutoDisposeStreamProvider<JournalEntity?> {
  /// See also [entityById].
  EntityByIdProvider({
    required String id,
  }) : this._internal(
          (ref) => entityById(
            ref as EntityByIdRef,
            id: id,
          ),
          from: entityByIdProvider,
          name: r'entityByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$entityByIdHash,
          dependencies: EntityByIdFamily._dependencies,
          allTransitiveDependencies:
              EntityByIdFamily._allTransitiveDependencies,
          id: id,
        );

  EntityByIdProvider._internal(
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
  Override overrideWith(
    Stream<JournalEntity?> Function(EntityByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EntityByIdProvider._internal(
        (ref) => create(ref as EntityByIdRef),
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
  AutoDisposeStreamProviderElement<JournalEntity?> createElement() {
    return _EntityByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EntityByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin EntityByIdRef on AutoDisposeStreamProviderRef<JournalEntity?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _EntityByIdProviderElement
    extends AutoDisposeStreamProviderElement<JournalEntity?>
    with EntityByIdRef {
  _EntityByIdProviderElement(super.provider);

  @override
  String get id => (origin as EntityByIdProvider).id;
}

String _$taskControllerHash() => r'46504936a08e1f98b565f835d4cc57f48a30f242';

abstract class _$TaskController
    extends BuildlessAutoDisposeAsyncNotifier<Task?> {
  late final String id;

  FutureOr<Task?> build({
    required String id,
  });
}

/// See also [TaskController].
@ProviderFor(TaskController)
const taskControllerProvider = TaskControllerFamily();

/// See also [TaskController].
class TaskControllerFamily extends Family<AsyncValue<Task?>> {
  /// See also [TaskController].
  const TaskControllerFamily();

  /// See also [TaskController].
  TaskControllerProvider call({
    required String id,
  }) {
    return TaskControllerProvider(
      id: id,
    );
  }

  @override
  TaskControllerProvider getProviderOverride(
    covariant TaskControllerProvider provider,
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
  String? get name => r'taskControllerProvider';
}

/// See also [TaskController].
class TaskControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<TaskController, Task?> {
  /// See also [TaskController].
  TaskControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskController()..id = id,
          from: taskControllerProvider,
          name: r'taskControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskControllerHash,
          dependencies: TaskControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskControllerProvider._internal(
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
  FutureOr<Task?> runNotifierBuild(
    covariant TaskController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TaskController, Task?>
      createElement() {
    return _TaskControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TaskControllerRef on AutoDisposeAsyncNotifierProviderRef<Task?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaskController, Task?>
    with TaskControllerRef {
  _TaskControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskControllerProvider).id;
}

String _$taskController1Hash() => r'4e377ad419bf0feb6623062aec41cb4fa4b814b3';

abstract class _$TaskController1
    extends BuildlessAutoDisposeAsyncNotifier<Task?> {
  late final String id;

  FutureOr<Task?> build({
    required String id,
  });
}

/// See also [TaskController1].
@ProviderFor(TaskController1)
const taskController1Provider = TaskController1Family();

/// See also [TaskController1].
class TaskController1Family extends Family<AsyncValue<Task?>> {
  /// See also [TaskController1].
  const TaskController1Family();

  /// See also [TaskController1].
  TaskController1Provider call({
    required String id,
  }) {
    return TaskController1Provider(
      id: id,
    );
  }

  @override
  TaskController1Provider getProviderOverride(
    covariant TaskController1Provider provider,
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
  String? get name => r'taskController1Provider';
}

/// See also [TaskController1].
class TaskController1Provider
    extends AutoDisposeAsyncNotifierProviderImpl<TaskController1, Task?> {
  /// See also [TaskController1].
  TaskController1Provider({
    required String id,
  }) : this._internal(
          () => TaskController1()..id = id,
          from: taskController1Provider,
          name: r'taskController1Provider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskController1Hash,
          dependencies: TaskController1Family._dependencies,
          allTransitiveDependencies:
              TaskController1Family._allTransitiveDependencies,
          id: id,
        );

  TaskController1Provider._internal(
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
  FutureOr<Task?> runNotifierBuild(
    covariant TaskController1 notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskController1 Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskController1Provider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TaskController1, Task?>
      createElement() {
    return _TaskController1ProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskController1Provider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TaskController1Ref on AutoDisposeAsyncNotifierProviderRef<Task?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskController1ProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaskController1, Task?>
    with TaskController1Ref {
  _TaskController1ProviderElement(super.provider);

  @override
  String get id => (origin as TaskController1Provider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
