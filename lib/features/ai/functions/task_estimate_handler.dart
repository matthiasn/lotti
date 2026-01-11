import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Result of processing an estimate update tool call.
///
/// Contains detailed information about the outcome for testing and logging.
class TaskEstimateResult {
  const TaskEstimateResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.requestedMinutes,
    this.reason,
    this.confidence,
    this.error,
  });

  /// Whether the estimate was successfully updated.
  final bool success;

  /// Human-readable message describing the outcome.
  final String message;

  /// The updated task if successful, null otherwise.
  final Task? updatedTask;

  /// The minutes value requested by the AI.
  final int? requestedMinutes;

  /// The AI's explanation for why this estimate was detected.
  final String? reason;

  /// The AI's confidence level ('high', 'medium', 'low').
  final String? confidence;

  /// Error message if the operation failed.
  final String? error;

  /// Whether the update was skipped (not an error, just not applied).
  bool get wasSkipped => !success && error == null;
}

/// Handler for updating task time estimates via AI function calls.
///
/// This handler processes `update_task_estimate` tool calls from the AI,
/// converting natural language duration expressions (e.g., "2 hours",
/// "half a day") into structured task estimates.
///
/// ## Behavior
///
/// - **Only sets if not already set**: If the task already has a non-zero
///   estimate, the update is skipped to preserve manual edits. Zero-duration
///   estimates are treated as "not set".
///
/// - **Validates input**: Rejects negative or zero minute values from the AI.
///
/// - **Updates task state**: On success, updates the task in the database and
///   notifies listeners via the [onTaskUpdated] callback.
///
/// ## Example
///
/// ```dart
/// final handler = TaskEstimateHandler(
///   task: myTask,
///   journalRepository: repo,
///   onTaskUpdated: (updated) => print('Task updated: ${updated.data.estimate}'),
/// );
///
/// final result = await handler.processToolCall(toolCall, manager);
/// if (result.success) {
///   print('Estimate set to ${result.requestedMinutes} minutes');
/// }
/// ```
///
/// ## Testing
///
/// The handler is designed for easy unit testing:
/// - Constructor injection of all dependencies
/// - Pure result object with detailed outcome information
/// - Optional [ConversationManager] for response handling
///
/// See also:
/// - `TaskDueDateHandler` for due date updates
/// - `TaskFunctions` for function definitions
class TaskEstimateHandler {
  /// Creates a handler for processing task estimate updates.
  ///
  /// Parameters:
  /// - [task]: The task to potentially update. Mutable to track state changes.
  /// - [journalRepository]: Repository for persisting task updates.
  /// - [onTaskUpdated]: Optional callback invoked when the task is updated.
  ///   Use this to sync state across multiple handlers.
  TaskEstimateHandler({
    required this.task,
    required this.journalRepository,
    this.onTaskUpdated,
  });

  /// The task being processed.
  ///
  /// This field is intentionally mutable (not `final`) because it is updated
  /// after successful operations to reflect the latest state. This ensures
  /// subsequent operations in the same session see the updated estimate.
  Task task;

  /// Repository for persisting task updates to the database.
  final JournalRepository journalRepository;

  /// Optional callback invoked when the task is successfully updated.
  ///
  /// Use this to synchronize state across multiple handlers or UI components.
  final void Function(Task)? onTaskUpdated;

  /// Processes an `update_task_estimate` tool call from the AI.
  ///
  /// Parses the tool call arguments, validates the input, and updates the
  /// task estimate if appropriate.
  ///
  /// Parameters:
  /// - [call]: The tool call containing the estimate data in JSON format.
  ///   Expected format: `{"minutes": 120, "reason": "...", "confidence": "high"}`
  /// - [manager]: Optional conversation manager for sending tool responses
  ///   back to the AI. If null, responses are not sent (useful for testing).
  ///
  /// Returns a [TaskEstimateResult] with detailed outcome information.
  ///
  /// The method handles these cases:
  /// 1. **Invalid JSON**: Returns error result
  /// 2. **Invalid minutes** (null, zero, negative): Returns error result
  /// 3. **Existing estimate**: Returns skipped result (preserves manual edits)
  /// 4. **Success**: Updates task and returns success result
  /// 5. **Repository error**: Returns error result, logs exception
  Future<TaskEstimateResult> processToolCall(
    ChatCompletionMessageToolCall call, [
    ConversationManager? manager,
  ]) async {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final minutes = args['minutes'] as int?;
      final confidence = args['confidence'] as String?;
      final reason = args['reason'] as String?;

      developer.log(
        'Processing update_task_estimate: $minutes min '
        '(confidence: $confidence, reason: $reason)',
        name: 'TaskEstimateHandler',
      );

      // Validate minutes value
      if (minutes == null || minutes <= 0) {
        const message = 'Invalid estimate: minutes must be a positive integer.';
        _sendResponse(call.id, message, manager);
        return TaskEstimateResult(
          success: false,
          message: message,
          requestedMinutes: minutes,
          reason: reason,
          confidence: confidence,
          error: message,
        );
      }

      // Check if estimate already exists (treat zero as "not set")
      final currentEstimate = task.data.estimate;
      final hasExistingEstimate =
          currentEstimate != null && currentEstimate.inMinutes > 0;

      if (hasExistingEstimate) {
        final message =
            'Estimate already set to ${currentEstimate.inMinutes} minutes. Skipped.';
        developer.log(
          'Task already has estimate: ${currentEstimate.inMinutes} minutes',
          name: 'TaskEstimateHandler',
        );
        _sendResponse(call.id, message, manager);
        return TaskEstimateResult(
          success: false,
          message: message,
          requestedMinutes: minutes,
          reason: reason,
          confidence: confidence,
        );
      }

      // Update the task
      final newEstimate = Duration(minutes: minutes);
      final updatedTask = task.copyWith(
        data: task.data.copyWith(estimate: newEstimate),
      );

      try {
        await journalRepository.updateJournalEntity(updatedTask);

        // Update local state
        task = updatedTask;
        onTaskUpdated?.call(updatedTask);

        final message = 'Task estimate updated to $minutes minutes.';
        developer.log(
          'Successfully set task estimate to $minutes minutes',
          name: 'TaskEstimateHandler',
        );
        _sendResponse(call.id, message, manager);

        return TaskEstimateResult(
          success: true,
          message: message,
          updatedTask: updatedTask,
          requestedMinutes: minutes,
          reason: reason,
          confidence: confidence,
        );
      } catch (e) {
        const message =
            'Failed to set estimate. Continuing without estimate update.';
        developer.log(
          'Failed to update task estimate',
          name: 'TaskEstimateHandler',
          error: e,
        );
        _sendResponse(call.id, message, manager);
        return TaskEstimateResult(
          success: false,
          message: message,
          requestedMinutes: minutes,
          reason: reason,
          confidence: confidence,
          error: e.toString(),
        );
      }
    } catch (e) {
      const message = 'Error processing task estimate update.';
      developer.log(
        'Error processing update_task_estimate: $e',
        name: 'TaskEstimateHandler',
        error: e,
      );
      _sendResponse(call.id, message, manager);
      return TaskEstimateResult(
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
