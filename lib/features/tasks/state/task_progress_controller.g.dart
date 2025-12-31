// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_progress_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskProgressController)
final taskProgressControllerProvider = TaskProgressControllerFamily._();

final class TaskProgressControllerProvider
    extends $AsyncNotifierProvider<TaskProgressController, TaskProgressState?> {
  TaskProgressControllerProvider._(
      {required TaskProgressControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'taskProgressControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskProgressControllerHash();

  @override
  String toString() {
    return r'taskProgressControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskProgressController create() => TaskProgressController();

  @override
  bool operator ==(Object other) {
    return other is TaskProgressControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskProgressControllerHash() =>
    r'024b90c38fcec6227648261a467d902fc8c5a3b2';

final class TaskProgressControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            TaskProgressController,
            AsyncValue<TaskProgressState?>,
            TaskProgressState?,
            FutureOr<TaskProgressState?>,
            String> {
  TaskProgressControllerFamily._()
      : super(
          retry: null,
          name: r'taskProgressControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  TaskProgressControllerProvider call({
    required String id,
  }) =>
      TaskProgressControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'taskProgressControllerProvider';
}

abstract class _$TaskProgressController
    extends $AsyncNotifier<TaskProgressState?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<TaskProgressState?> build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<TaskProgressState?>, TaskProgressState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<TaskProgressState?>, TaskProgressState?>,
        AsyncValue<TaskProgressState?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}
