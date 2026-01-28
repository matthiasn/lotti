// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_view_preference_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for persisting task view mode preferences per category.

@ProviderFor(TaskViewPreference)
final taskViewPreferenceProvider = TaskViewPreferenceFamily._();

/// Controller for persisting task view mode preferences per category.
final class TaskViewPreferenceProvider
    extends $AsyncNotifierProvider<TaskViewPreference, TaskViewMode> {
  /// Controller for persisting task view mode preferences per category.
  TaskViewPreferenceProvider._(
      {required TaskViewPreferenceFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'taskViewPreferenceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskViewPreferenceHash();

  @override
  String toString() {
    return r'taskViewPreferenceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskViewPreference create() => TaskViewPreference();

  @override
  bool operator ==(Object other) {
    return other is TaskViewPreferenceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskViewPreferenceHash() =>
    r'665bce1a8a678c1273d5b3fe2fcb58011552ccb6';

/// Controller for persisting task view mode preferences per category.

final class TaskViewPreferenceFamily extends $Family
    with
        $ClassFamilyOverride<TaskViewPreference, AsyncValue<TaskViewMode>,
            TaskViewMode, FutureOr<TaskViewMode>, String> {
  TaskViewPreferenceFamily._()
      : super(
          retry: null,
          name: r'taskViewPreferenceProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Controller for persisting task view mode preferences per category.

  TaskViewPreferenceProvider call({
    required String categoryId,
  }) =>
      TaskViewPreferenceProvider._(argument: categoryId, from: this);

  @override
  String toString() => r'taskViewPreferenceProvider';
}

/// Controller for persisting task view mode preferences per category.

abstract class _$TaskViewPreference extends $AsyncNotifier<TaskViewMode> {
  late final _$args = ref.$arg as String;
  String get categoryId => _$args;

  FutureOr<TaskViewMode> build({
    required String categoryId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TaskViewMode>, TaskViewMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<TaskViewMode>, TaskViewMode>,
        AsyncValue<TaskViewMode>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              categoryId: _$args,
            ));
  }
}
