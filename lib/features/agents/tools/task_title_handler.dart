import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';

/// Result of processing a task title update.
///
/// Contains detailed information about the outcome for testing and logging.
class TaskTitleResult {
  const TaskTitleResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.requestedTitle,
    this.error,
    this.didWrite = false,
  });

  /// Whether the title was successfully updated.
  final bool success;

  /// Human-readable message describing the outcome.
  final String message;

  /// The updated task if the operation succeeded, null otherwise.
  final Task? updatedTask;

  /// The title string requested by the caller.
  final String? requestedTitle;

  /// Error message if the operation failed.
  final String? error;

  /// Whether a database write actually occurred.
  ///
  /// False when the operation was a no-op (requested title equals current
  /// title) or when it failed before reaching the repository.
  final bool didWrite;

  /// Whether this was a no-op (success without a DB write).
  bool get wasNoOp => success && !didWrite;
}

/// Handler for updating the title of a task.
///
/// This handler implements the `set_task_title` tool for the Task Agent. It
/// loads the task from the journal repository, validates the requested title,
/// applies the change, and persists it.
///
/// ## Behavior
///
/// - **Validates input**: Rejects empty or whitespace-only title strings.
/// - **No-op on identical title**: If the requested title matches the current
///   title exactly, the write is skipped and a success result is returned.
/// - **Updates task state**: On a successful write, updates the local [task]
///   field and invokes the optional [onTaskUpdated] callback.
///
/// ## Example
///
/// ```dart
/// final handler = TaskTitleHandler(
///   task: myTask,
///   journalRepository: repo,
///   onTaskUpdated: (updated) => print('Title is now: ${updated.data.title}'),
/// );
///
/// final result = await handler.handle('Refactor the auth module');
/// if (result.success) {
///   print('Title updated');
/// }
/// ```
///
/// See also:
/// - [AgentToolExecutor] for the orchestration layer that wraps this handler.
class TaskTitleHandler {
  /// Creates a handler for processing task title updates.
  ///
  /// Parameters:
  /// - [task]: The task to potentially update. Mutable to track state changes.
  /// - [journalRepository]: Repository for persisting task updates.
  /// - [onTaskUpdated]: Optional callback invoked when the task is updated.
  ///   Use this to synchronise state across multiple handlers.
  TaskTitleHandler({
    required this.task,
    required this.journalRepository,
    this.onTaskUpdated,
  });

  /// The task being processed.
  ///
  /// Mutable so that after a successful update the handler's local reference
  /// reflects the new state (e.g. for the [onTaskUpdated] callback).
  Task task;

  /// Repository for persisting task updates to the database.
  final JournalRepository journalRepository;

  /// Optional callback invoked when the task is successfully updated.
  ///
  /// Use this to synchronise state across multiple handlers or UI components.
  final void Function(Task)? onTaskUpdated;

  /// Updates the task title to [newTitle].
  ///
  /// Returns a [TaskTitleResult] describing the outcome. The method handles
  /// these cases:
  ///
  /// 1. **Empty title**: Returns an error result without writing.
  /// 2. **Identical title**: Returns a success no-op result without writing.
  /// 3. **Success**: Persists the update and returns a success result.
  /// 4. **Repository error**: Returns an error result and logs the exception.
  ///
  /// The result also exposes [ToolExecutionResult]-compatible information via
  /// [toToolExecutionResult] so it can be returned directly from an
  /// [AgentToolExecutor.execute] handler.
  Future<TaskTitleResult> handle(String newTitle) async {
    final trimmed = newTitle.trim();

    developer.log(
      'Processing set_task_title: "${trimmed.isEmpty ? '<empty>' : trimmed}"',
      name: 'TaskTitleHandler',
    );

    // Validate: reject empty titles.
    if (trimmed.isEmpty) {
      const message = 'Invalid title: title must not be empty.';
      developer.log(
        'Rejected empty title',
        name: 'TaskTitleHandler',
      );
      return const TaskTitleResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // No-op: skip write if title is unchanged.
    if (trimmed == task.data.title) {
      final message = 'Title is already "$trimmed". No change needed.';
      developer.log(
        'Title unchanged — skipping write',
        name: 'TaskTitleHandler',
      );
      return TaskTitleResult(
        success: true,
        message: message,
        updatedTask: task,
        requestedTitle: trimmed,
      );
    }

    // Apply the update.
    final updatedTask = task.copyWith(
      data: task.data.copyWith(title: trimmed),
    );

    try {
      final success = await journalRepository.updateJournalEntity(updatedTask);

      if (!success) {
        const message = 'Failed to update title: repository returned false.';
        developer.log(message, name: 'TaskTitleHandler');
        return TaskTitleResult(
          success: false,
          message: message,
          requestedTitle: trimmed,
          error: message,
        );
      }

      // Update local state so subsequent handlers see the new title.
      task = updatedTask;
      onTaskUpdated?.call(updatedTask);

      final message = 'Task title updated to "$trimmed".';
      developer.log(
        'Successfully updated task title to "$trimmed"',
        name: 'TaskTitleHandler',
      );

      return TaskTitleResult(
        success: true,
        message: message,
        updatedTask: updatedTask,
        requestedTitle: trimmed,
        didWrite: true,
      );
    } catch (e, s) {
      const message =
          'Failed to update title. Continuing without title change.';
      developer.log(
        'Failed to update task title',
        name: 'TaskTitleHandler',
        error: e,
        stackTrace: s,
      );

      return TaskTitleResult(
        success: false,
        message: message,
        requestedTitle: trimmed,
        error: e.toString(),
      );
    }
  }

  /// Converts a [TaskTitleResult] into a [ToolExecutionResult] for use with
  /// [AgentToolExecutor.execute].
  static ToolExecutionResult toToolExecutionResult(
    TaskTitleResult result, {
    String? entityId,
  }) {
    return ToolExecutionResult(
      success: result.success,
      output: result.message,
      mutatedEntityId: result.didWrite ? entityId : null,
      errorMessage: result.error,
    );
  }
}
