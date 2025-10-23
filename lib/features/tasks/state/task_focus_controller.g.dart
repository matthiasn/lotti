// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_focus_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskFocusControllerHash() =>
    r'a29a8be4ed291c2794716612c161eb675855a50a';

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

abstract class _$TaskFocusController
    extends BuildlessAutoDisposeAsyncNotifier<TaskFocusIntent?> {
  late final String id;

  FutureOr<TaskFocusIntent?> build({
    required String id,
  });
}

/// See also [TaskFocusController].
@ProviderFor(TaskFocusController)
const taskFocusControllerProvider = TaskFocusControllerFamily();

/// See also [TaskFocusController].
class TaskFocusControllerFamily extends Family<AsyncValue<TaskFocusIntent?>> {
  /// See also [TaskFocusController].
  const TaskFocusControllerFamily();

  /// See also [TaskFocusController].
  TaskFocusControllerProvider call({
    required String id,
  }) {
    return TaskFocusControllerProvider(
      id: id,
    );
  }

  @override
  TaskFocusControllerProvider getProviderOverride(
    covariant TaskFocusControllerProvider provider,
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
  String? get name => r'taskFocusControllerProvider';
}

/// See also [TaskFocusController].
class TaskFocusControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TaskFocusController, TaskFocusIntent?> {
  /// See also [TaskFocusController].
  TaskFocusControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskFocusController()..id = id,
          from: taskFocusControllerProvider,
          name: r'taskFocusControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskFocusControllerHash,
          dependencies: TaskFocusControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskFocusControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskFocusControllerProvider._internal(
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
  FutureOr<TaskFocusIntent?> runNotifierBuild(
    covariant TaskFocusController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskFocusController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskFocusControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TaskFocusController, TaskFocusIntent?>
      createElement() {
    return _TaskFocusControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskFocusControllerProvider && other.id == id;
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
mixin TaskFocusControllerRef
    on AutoDisposeAsyncNotifierProviderRef<TaskFocusIntent?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskFocusControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaskFocusController,
        TaskFocusIntent?> with TaskFocusControllerRef {
  _TaskFocusControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskFocusControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
