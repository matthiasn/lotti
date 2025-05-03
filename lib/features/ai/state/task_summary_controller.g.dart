// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskSummaryControllerHash() =>
    r'3dfe0c0d1a3272dc7b6ba6ccc08df333597b8675';

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

abstract class _$TaskSummaryController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [TaskSummaryController].
@ProviderFor(TaskSummaryController)
const taskSummaryControllerProvider = TaskSummaryControllerFamily();

/// See also [TaskSummaryController].
class TaskSummaryControllerFamily extends Family<String> {
  /// See also [TaskSummaryController].
  const TaskSummaryControllerFamily();

  /// See also [TaskSummaryController].
  TaskSummaryControllerProvider call({
    required String id,
  }) {
    return TaskSummaryControllerProvider(
      id: id,
    );
  }

  @override
  TaskSummaryControllerProvider getProviderOverride(
    covariant TaskSummaryControllerProvider provider,
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
  String? get name => r'taskSummaryControllerProvider';
}

/// See also [TaskSummaryController].
class TaskSummaryControllerProvider
    extends AutoDisposeNotifierProviderImpl<TaskSummaryController, String> {
  /// See also [TaskSummaryController].
  TaskSummaryControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskSummaryController()..id = id,
          from: taskSummaryControllerProvider,
          name: r'taskSummaryControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskSummaryControllerHash,
          dependencies: TaskSummaryControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskSummaryControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskSummaryControllerProvider._internal(
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
  String runNotifierBuild(
    covariant TaskSummaryController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskSummaryController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskSummaryControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<TaskSummaryController, String>
      createElement() {
    return _TaskSummaryControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskSummaryControllerProvider && other.id == id;
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
mixin TaskSummaryControllerRef on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskSummaryControllerProviderElement
    extends AutoDisposeNotifierProviderElement<TaskSummaryController, String>
    with TaskSummaryControllerRef {
  _TaskSummaryControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskSummaryControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
