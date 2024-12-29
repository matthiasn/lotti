// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_progress_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskProgressControllerHash() =>
    r'a535a21107af5ba64be7f71363e997df9a9eafba';

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

abstract class _$TaskProgressController
    extends BuildlessAutoDisposeAsyncNotifier<TaskProgressState?> {
  late final String id;

  FutureOr<TaskProgressState?> build({
    required String id,
  });
}

/// See also [TaskProgressController].
@ProviderFor(TaskProgressController)
const taskProgressControllerProvider = TaskProgressControllerFamily();

/// See also [TaskProgressController].
class TaskProgressControllerFamily
    extends Family<AsyncValue<TaskProgressState?>> {
  /// See also [TaskProgressController].
  const TaskProgressControllerFamily();

  /// See also [TaskProgressController].
  TaskProgressControllerProvider call({
    required String id,
  }) {
    return TaskProgressControllerProvider(
      id: id,
    );
  }

  @override
  TaskProgressControllerProvider getProviderOverride(
    covariant TaskProgressControllerProvider provider,
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
  String? get name => r'taskProgressControllerProvider';
}

/// See also [TaskProgressController].
class TaskProgressControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<TaskProgressController,
        TaskProgressState?> {
  /// See also [TaskProgressController].
  TaskProgressControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskProgressController()..id = id,
          from: taskProgressControllerProvider,
          name: r'taskProgressControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskProgressControllerHash,
          dependencies: TaskProgressControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskProgressControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskProgressControllerProvider._internal(
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
  FutureOr<TaskProgressState?> runNotifierBuild(
    covariant TaskProgressController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskProgressController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskProgressControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TaskProgressController,
      TaskProgressState?> createElement() {
    return _TaskProgressControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskProgressControllerProvider && other.id == id;
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
mixin TaskProgressControllerRef
    on AutoDisposeAsyncNotifierProviderRef<TaskProgressState?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskProgressControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaskProgressController,
        TaskProgressState?> with TaskProgressControllerRef {
  _TaskProgressControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskProgressControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
