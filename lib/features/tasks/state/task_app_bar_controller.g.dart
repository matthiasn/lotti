// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_app_bar_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskAppBarControllerHash() =>
    r'289e5d61c6f3928fb98d0f83cfcd4cf3255e7a6a';

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

abstract class _$TaskAppBarController
    extends BuildlessAutoDisposeAsyncNotifier<double> {
  late final String id;

  FutureOr<double> build({
    required String id,
  });
}

/// See also [TaskAppBarController].
@ProviderFor(TaskAppBarController)
const taskAppBarControllerProvider = TaskAppBarControllerFamily();

/// See also [TaskAppBarController].
class TaskAppBarControllerFamily extends Family<AsyncValue<double>> {
  /// See also [TaskAppBarController].
  const TaskAppBarControllerFamily();

  /// See also [TaskAppBarController].
  TaskAppBarControllerProvider call({
    required String id,
  }) {
    return TaskAppBarControllerProvider(
      id: id,
    );
  }

  @override
  TaskAppBarControllerProvider getProviderOverride(
    covariant TaskAppBarControllerProvider provider,
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
  String? get name => r'taskAppBarControllerProvider';
}

/// See also [TaskAppBarController].
class TaskAppBarControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<TaskAppBarController, double> {
  /// See also [TaskAppBarController].
  TaskAppBarControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskAppBarController()..id = id,
          from: taskAppBarControllerProvider,
          name: r'taskAppBarControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskAppBarControllerHash,
          dependencies: TaskAppBarControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskAppBarControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskAppBarControllerProvider._internal(
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
  FutureOr<double> runNotifierBuild(
    covariant TaskAppBarController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskAppBarController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskAppBarControllerProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<TaskAppBarController, double>
      createElement() {
    return _TaskAppBarControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskAppBarControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TaskAppBarControllerRef on AutoDisposeAsyncNotifierProviderRef<double> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskAppBarControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TaskAppBarController,
        double> with TaskAppBarControllerRef {
  _TaskAppBarControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskAppBarControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
