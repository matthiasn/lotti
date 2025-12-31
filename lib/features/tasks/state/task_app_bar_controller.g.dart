// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_app_bar_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskAppBarController)
final taskAppBarControllerProvider = TaskAppBarControllerFamily._();

final class TaskAppBarControllerProvider
    extends $AsyncNotifierProvider<TaskAppBarController, double> {
  TaskAppBarControllerProvider._(
      {required TaskAppBarControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'taskAppBarControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskAppBarControllerHash();

  @override
  String toString() {
    return r'taskAppBarControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskAppBarController create() => TaskAppBarController();

  @override
  bool operator ==(Object other) {
    return other is TaskAppBarControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskAppBarControllerHash() =>
    r'289e5d61c6f3928fb98d0f83cfcd4cf3255e7a6a';

final class TaskAppBarControllerFamily extends $Family
    with
        $ClassFamilyOverride<TaskAppBarController, AsyncValue<double>, double,
            FutureOr<double>, String> {
  TaskAppBarControllerFamily._()
      : super(
          retry: null,
          name: r'taskAppBarControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  TaskAppBarControllerProvider call({
    required String id,
  }) =>
      TaskAppBarControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'taskAppBarControllerProvider';
}

abstract class _$TaskAppBarController extends $AsyncNotifier<double> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<double> build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<double>, double>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<double>, double>,
        AsyncValue<double>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}
