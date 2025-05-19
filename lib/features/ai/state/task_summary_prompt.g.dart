// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskSummaryPromptControllerHash() =>
    r'4a7eb0115f0e84bc2caf8dcaaed571befed40d90';

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

abstract class _$TaskSummaryPromptController
    extends BuildlessAutoDisposeAsyncNotifier<String?> {
  late final String id;

  FutureOr<String?> build({
    required String id,
  });
}

/// See also [TaskSummaryPromptController].
@ProviderFor(TaskSummaryPromptController)
const taskSummaryPromptControllerProvider = TaskSummaryPromptControllerFamily();

/// See also [TaskSummaryPromptController].
class TaskSummaryPromptControllerFamily extends Family<AsyncValue<String?>> {
  /// See also [TaskSummaryPromptController].
  const TaskSummaryPromptControllerFamily();

  /// See also [TaskSummaryPromptController].
  TaskSummaryPromptControllerProvider call({
    required String id,
  }) {
    return TaskSummaryPromptControllerProvider(
      id: id,
    );
  }

  @override
  TaskSummaryPromptControllerProvider getProviderOverride(
    covariant TaskSummaryPromptControllerProvider provider,
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
  String? get name => r'taskSummaryPromptControllerProvider';
}

/// See also [TaskSummaryPromptController].
class TaskSummaryPromptControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<TaskSummaryPromptController,
        String?> {
  /// See also [TaskSummaryPromptController].
  TaskSummaryPromptControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskSummaryPromptController()..id = id,
          from: taskSummaryPromptControllerProvider,
          name: r'taskSummaryPromptControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskSummaryPromptControllerHash,
          dependencies: TaskSummaryPromptControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskSummaryPromptControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskSummaryPromptControllerProvider._internal(
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
  FutureOr<String?> runNotifierBuild(
    covariant TaskSummaryPromptController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskSummaryPromptController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskSummaryPromptControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TaskSummaryPromptController, String?>
      createElement() {
    return _TaskSummaryPromptControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskSummaryPromptControllerProvider && other.id == id;
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
mixin TaskSummaryPromptControllerRef
    on AutoDisposeAsyncNotifierProviderRef<String?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskSummaryPromptControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaskSummaryPromptController,
        String?> with TaskSummaryPromptControllerRef {
  _TaskSummaryPromptControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskSummaryPromptControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
