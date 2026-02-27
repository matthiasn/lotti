import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:openai_dart/openai_dart.dart';

/// Pattern for validating date-only format (YYYY-MM-DD).
///
/// We require date-only format to ensure due dates are stored consistently
/// without time/timezone surprises.
final _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Result of processing a due date update tool call.
///
/// Contains detailed information about the outcome for testing and logging.
class TaskDueDateResult {
  const TaskDueDateResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.requestedDate,
    this.reason,
    this.confidence,
    this.error,
    this.didWrite = false,
  });

  /// Whether the due date was successfully updated.
  final bool success;

  /// Human-readable message describing the outcome.
  final String message;

  /// The updated task if successful, null otherwise.
  final Task? updatedTask;

  /// The date value requested by the AI (parsed from ISO 8601 string).
  final DateTime? requestedDate;

  /// The AI's explanation for why this due date was detected.
  final String? reason;

  /// The AI's confidence level ('high', 'medium', 'low').
  final String? confidence;

  /// Error message if the operation failed.
  final String? error;

  /// Whether a database write actually occurred.
  final bool didWrite;

  /// Whether the update was skipped (not an error, just not applied).
  bool get wasSkipped => !success && error == null;

  /// Whether this was a no-op (success without DB write).
  bool get wasNoOp => success && !didWrite;
}

/// Handler for updating task due dates via AI function calls.
///
/// This handler processes `update_task_due_date` tool calls from the AI,
/// converting natural language deadline expressions (e.g., "by Friday",
/// "next week", "January 15th") into structured due dates.
///
/// ## Behavior
///
/// - **Only sets if not already set**: If the task already has a due date,
///   the update is skipped to preserve manual edits.
///
/// - **Validates input**: Rejects empty or malformed date strings. Dates must
///   be in ISO 8601 format (YYYY-MM-DD).
///
/// - **Accepts past dates**: Past due dates are allowed, as users may
///   legitimately set them for tracking purposes.
///
/// - **Updates task state**: On success, updates the task in the database and
///   notifies listeners via the [onTaskUpdated] callback.
///
/// ## Current Date Context
///
/// The AI function definition includes the current date to enable resolution
/// of relative dates. This is injected dynamically when building tools in
/// [TaskFunctions.getTools()]. For example, if today is 2024-01-15 and the
/// user says "due Friday", the AI resolves this to 2024-01-19.
///
/// ## Example
///
/// ```dart
/// final handler = TaskDueDateHandler(
///   task: myTask,
///   journalRepository: repo,
///   onTaskUpdated: (updated) => print('Task updated: ${updated.data.due}'),
/// );
///
/// final result = await handler.processToolCall(toolCall, manager);
/// if (result.success) {
///   print('Due date set to ${result.requestedDate}');
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
/// - `TaskEstimateHandler` for time estimate updates
/// - `TaskFunctions` for function definitions
class TaskDueDateHandler {
  /// Creates a handler for processing task due date updates.
  ///
  /// Parameters:
  /// - [task]: The task to potentially update. Mutable to track state changes.
  /// - [journalRepository]: Repository for persisting task updates.
  /// - [onTaskUpdated]: Optional callback invoked when the task is updated.
  ///   Use this to sync state across multiple handlers.
  TaskDueDateHandler({
    required this.task,
    required this.journalRepository,
    this.onTaskUpdated,
  });

  /// The task being processed.
  ///
  /// This field is intentionally mutable (not `final`) because it is updated
  /// after successful operations to reflect the latest state. This ensures
  /// subsequent operations in the same session see the updated due date.
  Task task;

  /// Repository for persisting task updates to the database.
  final JournalRepository journalRepository;

  /// Optional callback invoked when the task is successfully updated.
  ///
  /// Use this to synchronize state across multiple handlers or UI components.
  final void Function(Task)? onTaskUpdated;

  /// Processes an `update_task_due_date` tool call from the AI.
  ///
  /// Parses the tool call arguments, validates the input, and updates the
  /// task due date if appropriate.
  ///
  /// Parameters:
  /// - [call]: The tool call containing the due date data in JSON format.
  ///   Expected format: `{"dueDate": "2024-01-19", "reason": "...", "confidence": "high"}`
  /// - [manager]: Optional conversation manager for sending tool responses
  ///   back to the AI. If null, responses are not sent (useful for testing).
  ///
  /// Returns a [TaskDueDateResult] with detailed outcome information.
  ///
  /// The method handles these cases:
  /// 1. **Invalid JSON**: Returns error result
  /// 2. **Empty date string**: Returns error result
  /// 3. **Invalid date format**: Returns error result with format guidance
  /// 4. **Existing due date**: Returns skipped result (preserves manual edits)
  /// 5. **Success**: Updates task and returns success result
  /// 6. **Repository error**: Returns error result, logs exception
  Future<TaskDueDateResult> processToolCall(
    ChatCompletionMessageToolCall call, [
    ConversationManager? manager,
  ]) async {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final dueDateStr = args['dueDate'] as String?;

      // Extract and normalize values using shared utility
      final (:reason, :confidence) =
          TaskFunctionArgs.extractReasonAndConfidence(args);

      developer.log(
        'Processing update_task_due_date: $dueDateStr '
        '(confidence: $confidence, reason: $reason)',
        name: 'TaskDueDateHandler',
      );

      // Validate date string is provided
      if (dueDateStr == null || dueDateStr.isEmpty) {
        const message = 'Invalid due date: date string is required.';
        _sendResponse(call.id, message, manager);
        return TaskDueDateResult(
          success: false,
          message: message,
          reason: reason,
          confidence: confidence,
          error: message,
        );
      }

      // Validate date-only format (YYYY-MM-DD) to prevent time/timezone issues
      final isDateOnly = _dateOnlyPattern.hasMatch(dueDateStr);
      final parsed = DateTime.tryParse(dueDateStr);

      if (!isDateOnly || parsed == null) {
        final message = 'Invalid due date format. Use YYYY-MM-DD (e.g., '
            '2024-01-19). Received: $dueDateStr';
        _sendResponse(call.id, message, manager);
        return TaskDueDateResult(
          success: false,
          message: message,
          reason: reason,
          confidence: confidence,
          error: message,
        );
      }

      // Normalize to midnight to ensure consistent storage
      final dueDate = parsed.dayAtMidnight;

      // No-op if due date is already set to the requested value.
      final currentDue = task.data.due;
      if (currentDue != null && currentDue.dayAtMidnight == dueDate) {
        final formattedDate = currentDue.toIso8601String().split('T')[0];
        final message =
            'Due date already set to $formattedDate. No change needed.';
        developer.log(
          'Due date unchanged: $formattedDate',
          name: 'TaskDueDateHandler',
        );
        _sendResponse(call.id, message, manager);
        return TaskDueDateResult(
          success: true,
          message: message,
          requestedDate: dueDate,
          reason: reason,
          confidence: confidence,
        );
      }

      // Update the task
      final updatedTask = task.copyWith(
        data: task.data.copyWith(due: dueDate),
      );

      try {
        await journalRepository.updateJournalEntity(updatedTask);

        // Update local state
        task = updatedTask;
        onTaskUpdated?.call(updatedTask);

        final message = 'Task due date updated to $dueDateStr.';
        developer.log(
          'Successfully set task due date to $dueDateStr',
          name: 'TaskDueDateHandler',
        );
        _sendResponse(call.id, message, manager);

        return TaskDueDateResult(
          success: true,
          message: message,
          updatedTask: updatedTask,
          requestedDate: dueDate,
          reason: reason,
          confidence: confidence,
          didWrite: true,
        );
      } catch (e, s) {
        const message =
            'Failed to set due date. Continuing without due date update.';
        developer.log(
          'Failed to update task due date',
          name: 'TaskDueDateHandler',
          error: e,
          stackTrace: s,
        );
        _sendResponse(call.id, message, manager);
        return TaskDueDateResult(
          success: false,
          message: message,
          requestedDate: dueDate,
          reason: reason,
          confidence: confidence,
          error: e.toString(),
        );
      }
    } catch (e, s) {
      const message = 'Error processing task due date update.';
      developer.log(
        'Error processing update_task_due_date: $e',
        name: 'TaskDueDateHandler',
        error: e,
        stackTrace: s,
      );
      _sendResponse(call.id, message, manager);
      return TaskDueDateResult(
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
