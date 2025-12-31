// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_count_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TasksCountController)
final tasksCountControllerProvider = TasksCountControllerProvider._();

final class TasksCountControllerProvider
    extends $AsyncNotifierProvider<TasksCountController, int> {
  TasksCountControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tasksCountControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tasksCountControllerHash();

  @$internal
  @override
  TasksCountController create() => TasksCountController();
}

String _$tasksCountControllerHash() =>
    r'a7cc57ed4336e653426833adef504cccc9e6033c';

abstract class _$TasksCountController extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<int>, int>, AsyncValue<int>, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
