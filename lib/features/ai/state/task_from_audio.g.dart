// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_from_audio.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskFromAudioControllerHash() =>
    r'993d4fc81ecba7d22f0bf967dac68d5f18d9f785';

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

abstract class _$TaskFromAudioController
    extends BuildlessAutoDisposeNotifier<String> {
  late final String id;

  String build({
    required String id,
  });
}

/// See also [TaskFromAudioController].
@ProviderFor(TaskFromAudioController)
const taskFromAudioControllerProvider = TaskFromAudioControllerFamily();

/// See also [TaskFromAudioController].
class TaskFromAudioControllerFamily extends Family<String> {
  /// See also [TaskFromAudioController].
  const TaskFromAudioControllerFamily();

  /// See also [TaskFromAudioController].
  TaskFromAudioControllerProvider call({
    required String id,
  }) {
    return TaskFromAudioControllerProvider(
      id: id,
    );
  }

  @override
  TaskFromAudioControllerProvider getProviderOverride(
    covariant TaskFromAudioControllerProvider provider,
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
  String? get name => r'taskFromAudioControllerProvider';
}

/// See also [TaskFromAudioController].
class TaskFromAudioControllerProvider
    extends AutoDisposeNotifierProviderImpl<TaskFromAudioController, String> {
  /// See also [TaskFromAudioController].
  TaskFromAudioControllerProvider({
    required String id,
  }) : this._internal(
          () => TaskFromAudioController()..id = id,
          from: taskFromAudioControllerProvider,
          name: r'taskFromAudioControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskFromAudioControllerHash,
          dependencies: TaskFromAudioControllerFamily._dependencies,
          allTransitiveDependencies:
              TaskFromAudioControllerFamily._allTransitiveDependencies,
          id: id,
        );

  TaskFromAudioControllerProvider._internal(
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
    covariant TaskFromAudioController notifier,
  ) {
    return notifier.build(
      id: id,
    );
  }

  @override
  Override overrideWith(TaskFromAudioController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TaskFromAudioControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<TaskFromAudioController, String>
      createElement() {
    return _TaskFromAudioControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskFromAudioControllerProvider && other.id == id;
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
mixin TaskFromAudioControllerRef on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `id` of this provider.
  String get id;
}

class _TaskFromAudioControllerProviderElement
    extends AutoDisposeNotifierProviderElement<TaskFromAudioController, String>
    with TaskFromAudioControllerRef {
  _TaskFromAudioControllerProviderElement(super.provider);

  @override
  String get id => (origin as TaskFromAudioControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
