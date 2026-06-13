import 'dart:convert';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/attention_request_handler.dart';
import 'package:lotti/features/agents/tools/checklist_migration_handler.dart';
import 'package:lotti/features/agents/tools/follow_up_task_handler.dart';
import 'package:lotti/features/agents/tools/running_timer_update_handler.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/tools/task_language_handler.dart';
import 'package:lotti/features/agents/tools/task_status_handler.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:lotti/features/agents/tools/time_entry_handler.dart';
import 'package:lotti/features/agents/tools/time_entry_update_handler.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart';
import 'package:lotti/features/ai/functions/task_estimate_handler.dart';
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Per-tool handlers for [TaskToolDispatcher]: each `_handle*` method applies
/// one Task-Agent tool call to the journal domain. Split from the main file
/// into its own library; the dispatcher imports it.
extension TaskToolHandlers on TaskToolDispatcher {
  Future<ToolExecutionResult> handleSetTaskTitle(
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

    // Note: we deliberately do NOT short-circuit on a populated existing
    // title here. User-confirmed renames route through this dispatcher
    // too, and the user already explicitly approved them — blocking
    // those would contradict the "existing title goes through
    // confirmation" contract. The "agent auto-apply must never overwrite
    // a non-empty title" invariant is enforced one layer up, in
    // `TaskAgentStrategy._shouldAutoApplyInitialTitle`, with a fresh
    // resolver re-read immediately before dispatch.
    final handler = TaskTitleHandler(
      task: task,
      journalRepository: journalRepository,
    );
    final result = await handler.handle(titleArg);
    return ToolExecutionResult.fromHandlerResult(
      success: result.success,
      message: result.message,
      didWrite: result.didWrite,
      error: result.error,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> handleProcessToolCall(
    Task task,
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    // Validate the expected string argument for string-typed tools.
    final expectedStringKey = switch (toolName) {
      TaskAgentToolNames.updateTaskDueDate => 'dueDate',
      TaskAgentToolNames.updateTaskPriority => 'priority',
      _ => null,
    };
    if (expectedStringKey != null) {
      final value = args[expectedStringKey];
      if (value is! String || value.isEmpty) {
        return ToolExecutionResult(
          success: false,
          output:
              'Error: "$expectedStringKey" must be a non-empty string, '
              'got ${value.runtimeType}',
          errorMessage: 'Type validation failed for $expectedStringKey',
        );
      }
    }

    // Validate minutes for estimate tool — accept int, double, or numeric
    // string since the handler's parseMinutes() handles all three. Only
    // reject null / clearly wrong types up front.
    if (toolName == TaskAgentToolNames.updateTaskEstimate) {
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
      case TaskAgentToolNames.updateTaskEstimate:
        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: journalRepository,
        );
        // Omit the optional manager parameter — the strategy layer adds the
        // tool response with the real call ID. Passing a manager here would
        // cause the handler to emit a duplicate response with the synthetic ID.
        final result = await handler.processToolCall(toolCall);
        return ToolExecutionResult.fromHandlerResult(
          success: result.success,
          message: result.message,
          didWrite: result.didWrite,
          error: result.error,
          entityId: taskId,
        );

      case TaskAgentToolNames.updateTaskDueDate:
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: journalRepository,
        );
        final result = await handler.processToolCall(toolCall);
        return ToolExecutionResult.fromHandlerResult(
          success: result.success,
          message: result.message,
          didWrite: result.didWrite,
          error: result.error,
          entityId: taskId,
        );

      case TaskAgentToolNames.updateTaskPriority:
        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: journalRepository,
        );
        final result = await handler.processToolCall(toolCall);
        return ToolExecutionResult.fromHandlerResult(
          success: result.success,
          message: result.message,
          didWrite: result.didWrite,
          error: result.error,
          entityId: taskId,
        );

      default:
        throw StateError(
          'Unexpected tool $toolName routed to handleProcessToolCall',
        );
    }
  }

  Future<ToolExecutionResult> handleAssignLabels(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final labels = args['labels'];
    if (labels is! List) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "labels" must be an array, '
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
    return ToolExecutionResult.fromHandlerResult(
      success: result.success,
      message: result.message,
      didWrite: result.didWrite,
      error: result.error,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> handleSetLanguage(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final languageCode = args['languageCode'];
    if (languageCode is! String) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "languageCode" must be a string, '
            'got ${languageCode.runtimeType}',
        errorMessage: 'Type validation failed for languageCode',
      );
    }

    final handler = TaskLanguageHandler(
      task: task,
      journalRepository: journalRepository,
    );
    final result = await handler.handle(languageCode);
    return ToolExecutionResult.fromHandlerResult(
      success: result.success,
      message: result.message,
      didWrite: result.didWrite,
      error: result.error,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> handleSetStatus(
    Task task,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final status = args['status'];
    if (status is! String) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "status" must be a string, '
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
    return ToolExecutionResult.fromHandlerResult(
      success: result.success,
      message: result.message,
      didWrite: result.didWrite,
      error: result.error,
      entityId: taskId,
    );
  }

  Future<ToolExecutionResult> handleBatchChecklist(
    Task task,
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final items = args['items'];
    if (items is! List || items.isEmpty) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "items" must be a non-empty array, '
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
      // handleChecklistUpdate and prevents redundant LLM retries.
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

  Future<ToolExecutionResult> handleChecklistUpdate(
    Task task,
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final items = args['items'];
    if (items is! List || items.isEmpty) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "items" must be a non-empty array, '
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
    final hasRealFailures =
        count == 0 &&
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

  Future<ToolExecutionResult> handleCreateFollowUpTask(
    Map<String, dynamic> args,
    String sourceTaskId,
  ) async {
    final handler = FollowUpTaskHandler(
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      domainLogger: domainLogger,
      taskAgentService: taskAgentService,
      projectRepository: projectRepository,
    );
    return handler.handle(sourceTaskId, args);
  }

  Future<ToolExecutionResult> handleMigrateChecklistItem(
    Map<String, dynamic> args,
    String sourceTaskId,
  ) async {
    final handler = ChecklistMigrationHandler(
      checklistRepository: checklistRepository,
      journalDb: journalDb,
      domainLogger: domainLogger,
    );
    return handler.handle(sourceTaskId, args);
  }

  Future<ToolExecutionResult> handleCreateTimeEntry(
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final handler = TimeEntryHandler(
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      timeService: timeService,
      domainLogger: domainLogger,
    );
    return handler.handle(taskId, args);
  }

  Future<ToolExecutionResult> handleUpdateRunningTimer(
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final handler = RunningTimerUpdateHandler(
      persistenceLogic: persistenceLogic,
      timeService: timeService,
      domainLogger: domainLogger,
    );
    return handler.handle(taskId, args);
  }

  Future<ToolExecutionResult> handleUpdateTimeEntry(
    Map<String, dynamic> args,
    String taskId,
  ) async {
    final handler = TimeEntryUpdateHandler(
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      timeService: timeService,
      domainLogger: domainLogger,
    );
    return handler.handle(taskId, args);
  }

  Future<ToolExecutionResult> handleRequestAttention(
    Task task,
    Map<String, dynamic> args,
  ) async {
    final repository = agentRepository;
    final sync = syncService;
    final agentId = requestingAgentId;
    if (repository == null || sync == null || agentId == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: request_attention is not configured.',
        errorMessage: 'request_attention is not configured',
      );
    }

    final handler = AttentionRequestHandler(
      agentRepository: repository,
      syncService: sync,
      requestingAgentId: agentId,
    );
    return handler.handle(task, args);
  }

  Future<ToolExecutionResult> handleResolveAttentionRequest(
    Task task,
    Map<String, dynamic> args,
  ) async {
    final repository = agentRepository;
    final sync = syncService;
    final agentId = requestingAgentId;
    if (repository == null || sync == null || agentId == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: resolve_attention_request is not configured.',
        errorMessage: 'resolve_attention_request is not configured',
      );
    }

    final handler = AttentionRequestHandler(
      agentRepository: repository,
      syncService: sync,
      requestingAgentId: agentId,
    );
    return handler.resolve(task, args);
  }
}
