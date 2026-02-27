import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/tools/task_language_handler.dart';
import 'package:lotti/features/agents/tools/task_status_handler.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart'
    show TaskAgentWorkflow;
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart';
import 'package:lotti/features/ai/functions/task_estimate_handler.dart';
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Dispatches tool calls from the Task Agent to the appropriate journal-domain
/// handlers.
///
/// Extracted from [TaskAgentWorkflow] to reduce file size and improve
/// testability of tool dispatch logic independently of the wake cycle.
class TaskToolDispatcher {
  TaskToolDispatcher({
    required this.journalDb,
    required this.journalRepository,
    required this.checklistRepository,
    required this.labelsRepository,
  });

  final JournalDb journalDb;
  final JournalRepository journalRepository;
  final ChecklistRepository checklistRepository;
  final LabelsRepository labelsRepository;

  static const _uuid = Uuid();

  /// Executes a tool handler by delegating to the appropriate existing
  /// journal-domain handler.
  ///
  /// Each tool call returns a [ToolExecutionResult] that the
  /// [AgentToolExecutor] wraps with audit logging and policy enforcement.
  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    developer.log(
      'Dispatching tool handler: $toolName',
      name: 'TaskToolDispatcher',
    );

    // Deliberately reload the task from the database on every tool call.
    // This guarantees each handler sees the committed state left by the
    // previous handler (e.g. a title change is visible to the next tool).
    // A local SQLite read by primary key is negligible cost, and caching
    // in memory would add complexity with risk of stale state.
    final taskEntity = await journalDb.journalEntityById(taskId);
    if (taskEntity is! Task) {
      return ToolExecutionResult(
        success: false,
        output: 'Task $taskId not found or is not a Task entity',
        errorMessage: 'Task lookup failed',
      );
    }

    switch (toolName) {
      case 'set_task_title':
        return _handleSetTaskTitle(taskEntity, args, taskId);

      case 'update_task_estimate':
        return _handleProcessToolCall(taskEntity, toolName, args, taskId);

      case 'update_task_due_date':
        return _handleProcessToolCall(taskEntity, toolName, args, taskId);

      case 'update_task_priority':
        return _handleProcessToolCall(taskEntity, toolName, args, taskId);

      case 'add_multiple_checklist_items':
        return _handleBatchChecklist(taskEntity, toolName, args, taskId);

      case 'update_checklist_items':
        return _handleChecklistUpdate(taskEntity, toolName, args, taskId);

      case 'assign_task_labels':
        return _handleAssignLabels(taskEntity, args, taskId);

      case 'set_task_language':
        return _handleSetLanguage(taskEntity, args, taskId);

      case 'set_task_status':
        return _handleSetStatus(taskEntity, args, taskId);

      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage: 'Tool $toolName is not registered for the Task Agent',
        );
    }
  }

  Future<ToolExecutionResult> _handleSetTaskTitle(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final titleArg = args['title'];
    // Type guard only — emptiness is validated by TaskTitleHandler.handle.
    if (titleArg is! String) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a string, got ${titleArg.runtimeType}',
        errorMessage: 'Type validation failed for title',
      );
    }

    final handler = TaskTitleHandler(
      task: task,
      journalRepository: journalRepository,
    );
    final result = await handler.handle(titleArg);
    return TaskTitleHandler.toToolExecutionResult(result, entityId: taskId);
  }

  Future<ToolExecutionResult> _handleProcessToolCall(
    Task task,
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    // Validate the expected string argument for string-typed tools.
    final expectedStringKey = switch (toolName) {
      'update_task_due_date' => 'dueDate',
      'update_task_priority' => 'priority',
      _ => null,
    };
    if (expectedStringKey != null) {
      final value = args[expectedStringKey];
      if (value is! String || value.isEmpty) {
        return ToolExecutionResult(
          success: false,
          output: 'Error: "$expectedStringKey" must be a non-empty string, '
              'got ${value.runtimeType}',
          errorMessage: 'Type validation failed for $expectedStringKey',
        );
      }
    }

    // Validate minutes for estimate tool — accept int, double, or numeric
    // string since the handler's parseMinutes() handles all three. Only
    // reject null / clearly wrong types up front.
    if (toolName == 'update_task_estimate') {
      final value = args['minutes'];
      if (value == null) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: "minutes" is required',
          errorMessage: 'Missing minutes parameter',
        );
      }
    }

    final toolCall = ChatCompletionMessageToolCall(
      id: 'agent_${toolName}_${_uuid.v4()}',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: toolName,
        arguments: jsonEncode(args),
      ),
    );

    // Only estimate, due date, and priority tools are routed here by the
    // caller (dispatch).
    switch (toolName) {
      case 'update_task_estimate':
        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: journalRepository,
        );
        // Omit the optional manager parameter — the strategy layer adds the
        // tool response with the real call ID. Passing a manager here would
        // cause the handler to emit a duplicate response with the synthetic ID.
        final result = await handler.processToolCall(toolCall);
        return ToolExecutionResult(
          success: result.success,
          output: result.message,
          mutatedEntityId: result.didWrite ? taskId : null,
          errorMessage: result.error,
        );

      case 'update_task_due_date':
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: journalRepository,
        );
        final result = await handler.processToolCall(toolCall);
        return ToolExecutionResult(
          success: result.success,
          output: result.message,
          mutatedEntityId: result.didWrite ? taskId : null,
          errorMessage: result.error,
        );

      case 'update_task_priority':
        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: journalRepository,
        );
        final result = await handler.processToolCall(toolCall);
        return ToolExecutionResult(
          success: result.success,
          output: result.message,
          mutatedEntityId: result.didWrite ? taskId : null,
          errorMessage: result.error,
        );

      default:
        throw StateError(
          'Unexpected tool $toolName routed to _handleProcessToolCall',
        );
    }
  }

  Future<ToolExecutionResult> _handleAssignLabels(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final labels = args['labels'];
    if (labels is! List) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "labels" must be an array, '
            'got ${labels.runtimeType}',
        errorMessage: 'Type validation failed for labels',
      );
    }

    final processor = LabelAssignmentProcessor(
      db: journalDb,
      repository: labelsRepository,
    );
    final handler = TaskLabelHandler(
      task: task,
      processor: processor,
    );
    final result = await handler.handle(args);
    return TaskLabelHandler.toToolExecutionResult(
      result,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> _handleSetLanguage(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final languageCode = args['languageCode'];
    if (languageCode is! String) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "languageCode" must be a string, '
            'got ${languageCode.runtimeType}',
        errorMessage: 'Type validation failed for languageCode',
      );
    }

    final handler = TaskLanguageHandler(
      task: task,
      journalRepository: journalRepository,
    );
    final result = await handler.handle(languageCode);
    return TaskLanguageHandler.toToolExecutionResult(
      result,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> _handleSetStatus(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final status = args['status'];
    if (status is! String) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "status" must be a string, '
            'got ${status.runtimeType}',
        errorMessage: 'Type validation failed for status',
      );
    }

    final reason = args['reason'];
    final handler = TaskStatusHandler(
      task: task,
      journalRepository: journalRepository,
    );
    final result = await handler.handle(
      status,
      reason: reason is String ? reason : null,
    );
    return TaskStatusHandler.toToolExecutionResult(
      result,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> _handleBatchChecklist(
    Task task,
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final items = args['items'];
    if (items is! List || items.isEmpty) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "items" must be a non-empty array, '
            'got ${items.runtimeType}',
        errorMessage: 'Type validation failed for items',
      );
    }

    final autoChecklistService = AutoChecklistService(
      checklistRepository: checklistRepository,
    );

    final handler = LottiBatchChecklistHandler(
      task: task,
      autoChecklistService: autoChecklistService,
      checklistRepository: checklistRepository,
    );

    final toolCall = ChatCompletionMessageToolCall(
      id: 'agent_${toolName}_${_uuid.v4()}',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: toolName,
        arguments: jsonEncode(args),
      ),
    );

    final parseResult = handler.processFunctionCall(toolCall);
    if (!parseResult.success) {
      return ToolExecutionResult(
        success: false,
        output: parseResult.error ?? 'Failed to parse checklist items',
        errorMessage: parseResult.error,
      );
    }

    final count = await handler.createBatchItems(parseResult);
    return ToolExecutionResult(
      // Return success=true as long as parsing succeeded — a count of 0
      // just means no items were created (no-op). This mirrors
      // _handleChecklistUpdate and prevents redundant LLM retries.
      success: true,
      output: handler.createToolResponse(parseResult),
      mutatedEntityId: count > 0 ? taskId : null,
      // Surface creation failures so monitoring/auditing can detect them
      // without failing the LLM call.
      errorMessage: handler.failedItems.isNotEmpty
          ? '${handler.failedItems.length} item(s) failed to be created'
          : null,
    );
  }

  Future<ToolExecutionResult> _handleChecklistUpdate(
    Task task,
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final items = args['items'];
    if (items is! List || items.isEmpty) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "items" must be a non-empty array, '
            'got ${items.runtimeType}',
        errorMessage: 'Type validation failed for items',
      );
    }

    final handler = LottiChecklistUpdateHandler(
      task: task,
      checklistRepository: checklistRepository,
    );

    final toolCall = ChatCompletionMessageToolCall(
      id: 'agent_${toolName}_${_uuid.v4()}',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: toolName,
        arguments: jsonEncode(args),
      ),
    );

    final parseResult = handler.processFunctionCall(toolCall);
    if (!parseResult.success) {
      return ToolExecutionResult(
        success: false,
        output: parseResult.error ?? 'Failed to parse checklist updates',
        errorMessage: parseResult.error,
      );
    }

    final count = await handler.executeUpdates(parseResult);
    final hasRealFailures = count == 0 &&
        handler.skippedItems.any(
          (s) => s.reason != 'No changes detected',
        );
    return ToolExecutionResult(
      // Return success=true as long as parsing succeeded — a count of 0
      // just means all items were already in the requested state (no-op).
      success: true,
      output: handler.createToolResponse(parseResult),
      mutatedEntityId: count > 0 ? taskId : null,
      // Surface real failures (not found, wrong task, DB error) so
      // monitoring/auditing can detect them without failing the LLM call.
      errorMessage: hasRealFailures
          ? 'All ${handler.skippedItems.length} item(s) skipped or failed'
          : null,
    );
  }
}
