// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_focus_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskFocusController)
final taskFocusControllerProvider = TaskFocusControllerFamily._();

final class TaskFocusControllerProvider
    extends $NotifierProvider<TaskFocusController, TaskFocusIntent?> {
  TaskFocusControllerProvider._(
      {required TaskFocusControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'taskFocusControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskFocusControllerHash();

  @override
  String toString() {
    return r'taskFocusControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskFocusController create() => TaskFocusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskFocusIntent? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskFocusIntent?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskFocusControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskFocusControllerHash() =>
    r'd4cbbcc43d113e00ba4c15624055e02a56c71d9a';

final class TaskFocusControllerFamily extends $Family
    with
        $ClassFamilyOverride<TaskFocusController, TaskFocusIntent?,
            TaskFocusIntent?, TaskFocusIntent?, String> {
  TaskFocusControllerFamily._()
      : super(
          retry: null,
          name: r'taskFocusControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  TaskFocusControllerProvider call({
    required String id,
  }) =>
      TaskFocusControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'taskFocusControllerProvider';
}

abstract class _$TaskFocusController extends $Notifier<TaskFocusIntent?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  TaskFocusIntent? build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TaskFocusIntent?, TaskFocusIntent?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<TaskFocusIntent?, TaskFocusIntent?>,
        TaskFocusIntent?,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}
