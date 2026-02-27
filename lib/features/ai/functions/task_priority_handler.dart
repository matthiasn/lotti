import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Result of processing a priority update tool call.
///
/// Contains detailed information about the outcome for testing and logging.
class TaskPriorityResult {
  const TaskPriorityResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.requestedPriority,
    this.reason,
    this.confidence,
    this.error,
    this.didWrite = false,
  });

  /// Whether the priority was successfully updated.
  final bool success;

  /// Human-readable message describing the outcome.
  final String message;

  /// The updated task if successful, null otherwise.
  final Task? updatedTask;

  /// The priority value requested by the AI.
  final TaskPriority? requestedPriority;

  /// The AI's explanation for why this priority was detected.
  final String? reason;

  /// The AI's confidence level ('high', 'medium', 'low').
  final String? confidence;

  /// Error message if the operation failed.
  final String? error;

  /// Whether a database write actually occurred.
  ///
  /// False when the operation was a no-op (e.g., setting P2 on a task that
  /// already has P2 as the default). This allows callers to distinguish
  /// between "success with actual change" and "success with no change needed".
  final bool didWrite;

  /// Whether the update was skipped (not an error, just not applied).
  ///
  /// True when the update was not applied because the task already had an
  /// explicit priority set (non-default value).
  bool get wasSkipped => !success && error == null;

  /// Whether this was a no-op (success without DB write).
  ///
  /// True when the requested priority equals the current priority,
  /// so no actual change was needed.
  bool get wasNoOp => success && !didWrite;
}

/// Handler for updating task priority via AI function calls.
///
/// This handler processes `update_task_priority` tool calls from the AI,
/// converting natural language priority expressions (e.g., "urgent",
/// "high priority") into structured task priority levels.
///
/// ## Behavior
///
/// - **Only sets if not already set**: If the task has a non-default priority
///   (anything other than p2Medium), the update is skipped to preserve manual
///   edits. The default p2Medium is treated as "not explicitly set".
///
/// - **Validates input**: Rejects invalid priority values from the AI.
///
/// - **Updates task state**: On success, updates the task in the database and
///   notifies listeners via the [onTaskUpdated] callback.
///
/// See also:
/// - `TaskEstimateHandler` for time estimate updates
/// - `TaskDueDateHandler` for due date updates
/// - `TaskFunctions` for function definitions
class TaskPriorityHandler {
  /// Creates a handler for processing task priority updates.
  ///
  /// Parameters:
  /// - [task]: The task to potentially update. Mutable to track state changes.
  /// - [journalRepository]: Repository for persisting task updates.
  /// - [onTaskUpdated]: Optional callback invoked when the task is updated.
  ///   Use this to sync state across multiple handlers.
  TaskPriorityHandler({
    required this.task,
    required this.journalRepository,
    this.onTaskUpdated,
  });

  /// Parses a priority string from AI input to TaskPriority enum.
  ///
  /// Handles P0, P1, P2, P3 strings (case-insensitive). Returns null if
  /// parsing fails.
  static TaskPriority? parsePriority(dynamic value) {
    if (value == null) return null;
    if (value is! String) return null;

    final normalized = value.trim().toUpperCase();
    return switch (normalized) {
      'P0' => TaskPriority.p0Urgent,
      'P1' => TaskPriority.p1High,
      'P2' => TaskPriority.p2Medium,
      'P3' => TaskPriority.p3Low,
      _ => null,
    };
  }

  /// The task being processed.
  ///
  /// This field is intentionally mutable (not `final`) because it is updated
  /// after successful operations to reflect the latest state. This ensures
  /// subsequent operations in the same session see the updated priority.
  Task task;

  /// Repository for persisting task updates to the database.
  final JournalRepository journalRepository;

  /// Optional callback invoked when the task is successfully updated.
  ///
  /// Use this to synchronize state across multiple handlers or UI components.
  final void Function(Task)? onTaskUpdated;

  /// Processes an `update_task_priority` tool call from the AI.
  ///
  /// Parses the tool call arguments, validates the input, and updates the
  /// task priority if appropriate.
  ///
  /// Parameters:
  /// - [call]: The tool call containing the priority data in JSON format.
  ///   Expected format: `{"priority": "P1", "reason": "...", "confidence": "high"}`
  /// - [manager]: Optional conversation manager for sending tool responses
  ///   back to the AI. If null, responses are not sent (useful for testing).
  ///
  /// Returns a [TaskPriorityResult] with detailed outcome information.
  ///
  /// The method handles these cases:
  /// 1. **Invalid JSON**: Returns error result
  /// 2. **Invalid priority** (null, unknown value): Returns error result
  /// 3. **Existing non-default priority**: Returns skipped result (preserves manual edits)
  /// 4. **Success**: Updates task and returns success result
  /// 5. **Repository error**: Returns error result, logs exception
  Future<TaskPriorityResult> processToolCall(
    ChatCompletionMessageToolCall call, [
    ConversationManager? manager,
  ]) async {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;

      // Extract and normalize values using shared utility
      final rawPriority = TaskFunctionArgs.normalizeToString(args['priority']);
      final (:reason, :confidence) =
          TaskFunctionArgs.extractReasonAndConfidence(args);

      final priority = TaskPriorityHandler.parsePriority(rawPriority);

      developer.log(
        'Processing update_task_priority: raw=$rawPriority, parsed=$priority '
        '(confidence: $confidence, reason: $reason)',
        name: 'TaskPriorityHandler',
      );

      // Validate priority value
      if (priority == null) {
        final message = 'Invalid priority: must be P0, P1, P2, or P3. '
            'Received: $rawPriority';
        _sendResponse(call.id, message, manager);
        return TaskPriorityResult(
          success: false,
          message: message,
          reason: reason,
          confidence: confidence,
          error: message,
        );
      }

      // No-op if requested priority equals current value.
      final currentPriority = task.data.priority;
      if (priority == currentPriority) {
        final message = 'Priority already ${priority.short}. No change needed.';
        developer.log(
          'Priority unchanged: ${priority.short}',
          name: 'TaskPriorityHandler',
        );
        _sendResponse(call.id, message, manager);
        return TaskPriorityResult(
          success: true,
          message: message,
          updatedTask: task,
          requestedPriority: priority,
          reason: reason,
          confidence: confidence,
        );
      }

      // Update the task
      final updatedTask = task.copyWith(
        data: task.data.copyWith(priority: priority),
      );

      try {
        await journalRepository.updateJournalEntity(updatedTask);

        // Update local state
        task = updatedTask;
        onTaskUpdated?.call(updatedTask);

        final message = 'Task priority updated to ${priority.short}.';
        developer.log(
          'Successfully set task priority to ${priority.short}',
          name: 'TaskPriorityHandler',
        );
        _sendResponse(call.id, message, manager);

        return TaskPriorityResult(
          success: true,
          message: message,
          updatedTask: updatedTask,
          requestedPriority: priority,
          reason: reason,
          confidence: confidence,
          didWrite: true,
        );
      } catch (e, s) {
        const message =
            'Failed to set priority. Continuing without priority update.';
        developer.log(
          'Failed to update task priority',
          name: 'TaskPriorityHandler',
          error: e,
          stackTrace: s,
        );
        _sendResponse(call.id, message, manager);
        return TaskPriorityResult(
          success: false,
          message: message,
          requestedPriority: priority,
          reason: reason,
          confidence: confidence,
          error: e.toString(),
        );
      }
    } catch (e, s) {
      const message = 'Error processing task priority update.';
      developer.log(
        'Error processing update_task_priority: $e',
        name: 'TaskPriorityHandler',
        error: e,
        stackTrace: s,
      );
      _sendResponse(call.id, message, manager);
      return TaskPriorityResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }

  /// Sends a tool response to the conversation manager if provided.
  void _sendResponse(
    String toolCallId,
    String response,
    ConversationManager? manager,
  ) {
    manager?.addToolResponse(
      toolCallId: toolCallId,
      response: response,
    );
  }
}
