import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_focus_controller.g.dart';

enum TaskFocusTarget {
  entry,
  suggestions,
}

/// Intent to focus a specific surface within a task.
class TaskFocusIntent {
  TaskFocusIntent({
    required this.taskId,
    required String this.entryId,
    this.alignment = 0.0,
  }) : target = TaskFocusTarget.entry;

  TaskFocusIntent.suggestions({
    required this.taskId,
    this.alignment = 0.1,
  }) : target = TaskFocusTarget.suggestions,
       entryId = null;

  /// The task ID containing the entry
  final String taskId;

  /// The task detail surface to focus.
  final TaskFocusTarget target;

  /// The entry ID to scroll to
  final String? entryId;

  /// The alignment of the target (0.0 = top, 0.5 = center, 1.0 = bottom)
  final double alignment;

  @override
  String toString() {
    return switch (target) {
      TaskFocusTarget.entry =>
        'TaskFocusIntent(taskId: $taskId, entryId: $entryId, alignment: $alignment)',
      TaskFocusTarget.suggestions =>
        'TaskFocusIntent.suggestions(taskId: $taskId, alignment: $alignment)',
    };
  }
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

  /// Publish a focus intent for the task-agent suggestions section.
  void publishSuggestionFocus({double alignment = 0.1}) {
    state = TaskFocusIntent.suggestions(
      taskId: id,
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
  ref
      .read(taskFocusControllerProvider(id: taskId).notifier)
      .publishTaskFocus(
        entryId: entryId,
        alignment: alignment,
      );
}

/// Helper function to publish a task-suggestions focus intent.
void publishTaskSuggestionFocus({
  required String taskId,
  required WidgetRef ref,
  double alignment = 0.1,
}) {
  ref
      .read(taskFocusControllerProvider(id: taskId).notifier)
      .publishSuggestionFocus(alignment: alignment);
}
