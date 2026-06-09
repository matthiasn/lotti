part of 'task_tool_dispatcher.dart';

/// Per-tool handlers for [TaskToolDispatcher]: each `_handle*` method applies
/// one Task-Agent tool call to the journal domain. Split from the main file
/// for size; all members are library-private.
extension TaskToolHandlers on TaskToolDispatcher {
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
      journalRepository: this.journalRepository,
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

  Future<ToolExecutionResult> _handleProcessToolCall(
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
          journalRepository: this.journalRepository,
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
          journalRepository: this.journalRepository,
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
          journalRepository: this.journalRepository,
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

  Future<ToolExecutionResult> _handleSetLanguage(
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
      journalRepository: this.journalRepository,
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

  Future<ToolExecutionResult> _handleSetStatus(
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
      journalRepository: this.journalRepository,
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
        output:
            'Error: "items" must be a non-empty array, '
            'got ${items.runtimeType}',
        errorMessage: 'Type validation failed for items',
      );
    }

    final autoChecklistService = AutoChecklistService(
      checklistRepository: this.checklistRepository,
    );

    final handler = LottiBatchChecklistHandler(
      task: task,
      autoChecklistService: autoChecklistService,
      checklistRepository: this.checklistRepository,
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
        output:
            'Error: "items" must be a non-empty array, '
            'got ${items.runtimeType}',
        errorMessage: 'Type validation failed for items',
      );
    }

    final handler = LottiChecklistUpdateHandler(
      task: task,
      checklistRepository: this.checklistRepository,
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

  Future<ToolExecutionResult> _handleCreateFollowUpTask(
    Map<String, dynamic> args,
    String sourceTaskId,
  ) async {
    final handler = FollowUpTaskHandler(
      persistenceLogic: persistenceLogic,
      journalDb: journalDb,
      domainLogger: domainLogger,
      taskAgentService: taskAgentService,
      projectRepository: this.projectRepository,
    );
    return handler.handle(sourceTaskId, args);
  }

  Future<ToolExecutionResult> _handleMigrateChecklistItem(
    Map<String, dynamic> args,
    String sourceTaskId,
  ) async {
    final handler = ChecklistMigrationHandler(
      checklistRepository: this.checklistRepository,
      journalDb: journalDb,
      domainLogger: domainLogger,
    );
    return handler.handle(sourceTaskId, args);
  }

  Future<ToolExecutionResult> _handleCreateTimeEntry(
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

  Future<ToolExecutionResult> _handleUpdateRunningTimer(
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

  Future<ToolExecutionResult> _handleUpdateTimeEntry(
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

  Future<ToolExecutionResult> _handleRequestAttention(
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

  Future<ToolExecutionResult> _handleResolveAttentionRequest(
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
