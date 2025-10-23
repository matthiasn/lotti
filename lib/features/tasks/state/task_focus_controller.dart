import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_focus_controller.g.dart';

/// Intent to focus on a specific entry within a task
class TaskFocusIntent {
  TaskFocusIntent({
    required this.taskId,
    required this.entryId,
    this.alignment = 0.0,
  });

  /// The task ID containing the entry
  final String taskId;

  /// The entry ID to scroll to
  final String entryId;

  /// The alignment of the target (0.0 = top, 0.5 = center, 1.0 = bottom)
  final double alignment;

  @override
  String toString() =>
      'TaskFocusIntent(taskId: $taskId, entryId: $entryId, alignment: $alignment)';
}

@riverpod
class TaskFocusController extends _$TaskFocusController {
  TaskFocusController();

  @override
  TaskFocusIntent? build({required String id}) {
    ref.keepAlive();
    return null;
  }

  /// Publish a focus intent for a specific entry
  void publishTaskFocus({
    required String entryId,
    double alignment = 0.0,
  }) {
    state = TaskFocusIntent(
      taskId: id,
      entryId: entryId,
      alignment: alignment,
    );
  }

  /// Clear the current intent (called after consumption to enable re-triggering)
  void clearIntent() {
    state = null;
  }
}

/// Helper function to publish a task focus intent
void publishTaskFocus({
  required String taskId,
  required String entryId,
  required WidgetRef ref,
  double alignment = 0.0,
}) {
  ref.read(taskFocusControllerProvider(id: taskId).notifier).publishTaskFocus(
        entryId: entryId,
        alignment: alignment,
      );
}
