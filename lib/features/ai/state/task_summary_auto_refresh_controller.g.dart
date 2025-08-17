// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_auto_refresh_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskSummaryAutoRefreshControllerHash() =>
    r'ca695b61c2b47f537ffd254e61e0d031a048de2f';

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

abstract class _$TaskSummaryAutoRefreshController
    extends BuildlessAutoDisposeNotifier<void> {
  late final String taskId;

  void build({
    required String taskId,
  });
}

/// See also [TaskSummaryAutoRefreshController].
@ProviderFor(TaskSummaryAutoRefreshController)
const taskSummaryAutoRefreshControllerProvider =
    TaskSummaryAutoRefreshControllerFamily();

/// See also [TaskSummaryAutoRefreshController].
class TaskSummaryAutoRefreshControllerFamily extends Family<void> {
  /// See also [TaskSummaryAutoRefreshController].
  const TaskSummaryAutoRefreshControllerFamily();

  /// See also [TaskSummaryAutoRefreshController].
  TaskSummaryAutoRefreshControllerProvider call({
    required String taskId,
  }) {
    return TaskSummaryAutoRefreshControllerProvider(
      taskId: taskId,
    );
  }

  @override
  TaskSummaryAutoRefreshControllerProvider getProviderOverride(
    covariant TaskSummaryAutoRefreshControllerProvider provider,
  ) {
    return call(
      taskId: provider.taskId,
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
  String? get name => r'taskSummaryAutoRefreshControllerProvider';
}

/// See also [TaskSummaryAutoRefreshController].
class TaskSummaryAutoRefreshControllerProvider
    extends AutoDisposeNotifierProviderImpl<TaskSummaryAutoRefreshController,
        void> {
  /// See also [TaskSummaryAutoRefreshController].
  TaskSummaryAutoRefreshControllerProvider({
    required String taskId,
  }) : this._internal(
          () => TaskSummaryAutoRefreshController()..taskId = taskId,
          from: taskSummaryAutoRefreshControllerProvider,
          name: r'taskSummaryAutoRefreshControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskSummaryAutoRefreshControllerHash,
          dependencies: TaskSummaryAutoRefreshControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskSummaryAutoRefreshControllerFamily._allTransitiveDependencies,
          taskId: taskId,
        );

  TaskSummaryAutoRefreshControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final String taskId;

  @override
  void runNotifierBuild(
    covariant TaskSummaryAutoRefreshController notifier,
  ) {
    return notifier.build(
      taskId: taskId,
    );
  }

  @override
  Override overrideWith(TaskSummaryAutoRefreshController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskSummaryAutoRefreshControllerProvider._internal(
        () => create()..taskId = taskId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<TaskSummaryAutoRefreshController, void>
      createElement() {
    return _TaskSummaryAutoRefreshControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskSummaryAutoRefreshControllerProvider &&
        other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TaskSummaryAutoRefreshControllerRef
    on AutoDisposeNotifierProviderRef<void> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _TaskSummaryAutoRefreshControllerProviderElement
    extends AutoDisposeNotifierProviderElement<TaskSummaryAutoRefreshController,
        void> with TaskSummaryAutoRefreshControllerRef {
  _TaskSummaryAutoRefreshControllerProviderElement(super.provider);

  @override
  String get taskId =>
      (origin as TaskSummaryAutoRefreshControllerProvider).taskId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
