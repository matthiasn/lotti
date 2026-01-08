// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_tasks_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing the LinkedTasks section UI state.

@ProviderFor(LinkedTasksController)
final linkedTasksControllerProvider = LinkedTasksControllerFamily._();

/// Controller for managing the LinkedTasks section UI state.
final class LinkedTasksControllerProvider
    extends $NotifierProvider<LinkedTasksController, LinkedTasksState> {
  /// Controller for managing the LinkedTasks section UI state.
  LinkedTasksControllerProvider._(
      {required LinkedTasksControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'linkedTasksControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$linkedTasksControllerHash();

  @override
  String toString() {
    return r'linkedTasksControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LinkedTasksController create() => LinkedTasksController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkedTasksState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkedTasksState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedTasksControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linkedTasksControllerHash() =>
    r'e7206ded96d7a406b69ef535e4368d89c4b8fb69';

/// Controller for managing the LinkedTasks section UI state.

final class LinkedTasksControllerFamily extends $Family
    with
        $ClassFamilyOverride<LinkedTasksController, LinkedTasksState,
            LinkedTasksState, LinkedTasksState, String> {
  LinkedTasksControllerFamily._()
      : super(
          retry: null,
          name: r'linkedTasksControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Controller for managing the LinkedTasks section UI state.

  LinkedTasksControllerProvider call({
    required String taskId,
  }) =>
      LinkedTasksControllerProvider._(argument: taskId, from: this);

  @override
  String toString() => r'linkedTasksControllerProvider';
}

/// Controller for managing the LinkedTasks section UI state.

abstract class _$LinkedTasksController extends $Notifier<LinkedTasksState> {
  late final _$args = ref.$arg as String;
  String get taskId => _$args;

  LinkedTasksState build({
    required String taskId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LinkedTasksState, LinkedTasksState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<LinkedTasksState, LinkedTasksState>,
        LinkedTasksState,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              taskId: _$args,
            ));
  }
}
