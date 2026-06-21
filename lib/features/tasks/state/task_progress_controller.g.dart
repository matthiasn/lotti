// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_progress_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live time-spent / estimate state for a single task, keyed by task `id`.
///
/// On build it loads the task's progress via [TaskProgressRepository] and then
/// keeps it fresh from two sources:
/// - [UpdateNotifications]: re-fetches when any subscribed entity (the task or
///   one of its linked entries) changes.
/// - [TimeService]: while a timer is running *for this task*, the 1Hz ticker
///   updates the live entity's range in-memory so the displayed total grows
///   smoothly without a DB round-trip.
///
/// [_fetch] deliberately preserves that live range across re-fetches because
/// the persisted `dateTo` of a running timer is stale; see the inline comment
/// there for why clobbering it caused the recorded time to blip back to zero.

@ProviderFor(TaskProgressController)
final taskProgressControllerProvider = TaskProgressControllerFamily._();

/// Live time-spent / estimate state for a single task, keyed by task `id`.
///
/// On build it loads the task's progress via [TaskProgressRepository] and then
/// keeps it fresh from two sources:
/// - [UpdateNotifications]: re-fetches when any subscribed entity (the task or
///   one of its linked entries) changes.
/// - [TimeService]: while a timer is running *for this task*, the 1Hz ticker
///   updates the live entity's range in-memory so the displayed total grows
///   smoothly without a DB round-trip.
///
/// [_fetch] deliberately preserves that live range across re-fetches because
/// the persisted `dateTo` of a running timer is stale; see the inline comment
/// there for why clobbering it caused the recorded time to blip back to zero.
final class TaskProgressControllerProvider
    extends $AsyncNotifierProvider<TaskProgressController, TaskProgressState?> {
  /// Live time-spent / estimate state for a single task, keyed by task `id`.
  ///
  /// On build it loads the task's progress via [TaskProgressRepository] and then
  /// keeps it fresh from two sources:
  /// - [UpdateNotifications]: re-fetches when any subscribed entity (the task or
  ///   one of its linked entries) changes.
  /// - [TimeService]: while a timer is running *for this task*, the 1Hz ticker
  ///   updates the live entity's range in-memory so the displayed total grows
  ///   smoothly without a DB round-trip.
  ///
  /// [_fetch] deliberately preserves that live range across re-fetches because
  /// the persisted `dateTo` of a running timer is stale; see the inline comment
  /// there for why clobbering it caused the recorded time to blip back to zero.
  TaskProgressControllerProvider._({
    required TaskProgressControllerFamily super.from,
    required String super.argument,
  }) : super(
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
    r'4e831bc4e71f2bea3fdae70284c63154165ef0dc';

/// Live time-spent / estimate state for a single task, keyed by task `id`.
///
/// On build it loads the task's progress via [TaskProgressRepository] and then
/// keeps it fresh from two sources:
/// - [UpdateNotifications]: re-fetches when any subscribed entity (the task or
///   one of its linked entries) changes.
/// - [TimeService]: while a timer is running *for this task*, the 1Hz ticker
///   updates the live entity's range in-memory so the displayed total grows
///   smoothly without a DB round-trip.
///
/// [_fetch] deliberately preserves that live range across re-fetches because
/// the persisted `dateTo` of a running timer is stale; see the inline comment
/// there for why clobbering it caused the recorded time to blip back to zero.

final class TaskProgressControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskProgressController,
          AsyncValue<TaskProgressState?>,
          TaskProgressState?,
          FutureOr<TaskProgressState?>,
          String
        > {
  TaskProgressControllerFamily._()
    : super(
        retry: null,
        name: r'taskProgressControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live time-spent / estimate state for a single task, keyed by task `id`.
  ///
  /// On build it loads the task's progress via [TaskProgressRepository] and then
  /// keeps it fresh from two sources:
  /// - [UpdateNotifications]: re-fetches when any subscribed entity (the task or
  ///   one of its linked entries) changes.
  /// - [TimeService]: while a timer is running *for this task*, the 1Hz ticker
  ///   updates the live entity's range in-memory so the displayed total grows
  ///   smoothly without a DB round-trip.
  ///
  /// [_fetch] deliberately preserves that live range across re-fetches because
  /// the persisted `dateTo` of a running timer is stale; see the inline comment
  /// there for why clobbering it caused the recorded time to blip back to zero.

  TaskProgressControllerProvider call({required String id}) =>
      TaskProgressControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'taskProgressControllerProvider';
}

/// Live time-spent / estimate state for a single task, keyed by task `id`.
///
/// On build it loads the task's progress via [TaskProgressRepository] and then
/// keeps it fresh from two sources:
/// - [UpdateNotifications]: re-fetches when any subscribed entity (the task or
///   one of its linked entries) changes.
/// - [TimeService]: while a timer is running *for this task*, the 1Hz ticker
///   updates the live entity's range in-memory so the displayed total grows
///   smoothly without a DB round-trip.
///
/// [_fetch] deliberately preserves that live range across re-fetches because
/// the persisted `dateTo` of a running timer is stale; see the inline comment
/// there for why clobbering it caused the recorded time to blip back to zero.

abstract class _$TaskProgressController
    extends $AsyncNotifier<TaskProgressState?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<TaskProgressState?> build({required String id});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<TaskProgressState?>, TaskProgressState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskProgressState?>, TaskProgressState?>,
              AsyncValue<TaskProgressState?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(id: _$args));
  }
}
