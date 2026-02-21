import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart';
import 'package:lotti/features/ai/functions/task_estimate_handler.dart';
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Task Agent wake cycle.
///
/// ## Lifecycle
///
/// 1. Load agent identity, state, current report, and agentJournal observations.
/// 2. Build task context from journal domain via [AiInputRepository].
/// 3. Resolve a Gemini inference provider from the AI config database.
/// 4. Create a [ConversationRepository] conversation with tool definitions.
/// 5. Run the conversation loop via [TaskAgentStrategy].
/// 6. Extract updated report and new observations from the LLM response.
/// 7. Persist report, observations, and updated state to `agent.sqlite`.
/// 8. Clean up the in-memory conversation in a `finally` block.
class TaskAgentWorkflow {
  TaskAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiInputRepository,
    required this.aiConfigRepository,
    required this.journalDb,
    required this.cloudInferenceRepository,
    required this.journalRepository,
    required this.checklistRepository,
  });

  final AgentRepository agentRepository;
  final ConversationRepository conversationRepository;
  final AiInputRepository aiInputRepository;
  final AiConfigRepository aiConfigRepository;
  final JournalDb journalDb;
  final CloudInferenceRepository cloudInferenceRepository;
  final JournalRepository journalRepository;
  final ChecklistRepository checklistRepository;

  static const _uuid = Uuid();

  /// The hardcoded model ID for MVP.
  static const _modelId = 'models/gemini-3.1-pro-preview';

  /// Execute a full wake cycle for the given agent.
  ///
  /// [agentIdentity] is the agent's identity entity.
  /// [runKey] is the deterministic run key for this wake cycle.
  /// [triggerTokens] is the set of entity IDs that triggered this wake.
  /// [threadId] is the conversation thread ID for this wake.
  ///
  /// Returns the set of mutated entity IDs and their vector clocks, for
  /// self-notification suppression by the orchestrator.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.id;

    developer.log(
      'Starting wake for agent $agentId (runKey: $runKey, '
      'triggers: ${triggerTokens.length})',
      name: 'TaskAgentWorkflow',
    );

    // 1. Load current state + both memory types.
    final state = await agentRepository.getAgentState(agentId);
    if (state == null) {
      developer.log(
        'No agent state found for $agentId — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final taskId = state.slots.activeTaskId;
    if (taskId == null) {
      developer.log(
        'No active task ID in agent state for $agentId — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(success: false, error: 'No active task ID');
    }

    final lastReport =
        await agentRepository.getLatestReport(agentId, 'current');
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 2. Build task context from journal domain.
    final taskDetailsJson =
        await aiInputRepository.buildTaskDetailsJson(id: taskId);
    final linkedTasksJson =
        await aiInputRepository.buildLinkedTasksJson(taskId);

    if (taskDetailsJson == null) {
      developer.log(
        'Task $taskId not found in journal — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(success: false, error: 'Task not found');
    }

    // 3. Resolve a Gemini inference provider.
    final provider = await _resolveGeminiProvider();
    if (provider == null) {
      developer.log(
        'No Gemini provider configured — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(
        success: false,
        error: 'No Gemini provider configured',
      );
    }

    // 4. Assemble conversation context.
    const systemPrompt = taskAgentSystemPrompt;
    final userMessage = await _buildUserMessage(
      lastReport: lastReport,
      journalObservations: journalObservations,
      taskDetailsJson: taskDetailsJson,
      linkedTasksJson: linkedTasksJson,
      triggerTokens: triggerTokens,
    );

    // 5. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    try {
      final executor = AgentToolExecutor(
        repository: agentRepository,
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
        runKey: runKey,
        agentId: agentId,
        threadId: threadId,
      );

      final strategy = TaskAgentStrategy(
        executor: executor,
        repository: agentRepository,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        taskId: taskId,
        resolveCategoryId: (entityId) async {
          final entity = await journalDb.journalEntityById(entityId);
          return entity?.categoryId;
        },
        readVectorClock: (entityId) async {
          final entity = await journalDb.journalEntityById(entityId);
          return entity?.meta.vectorClock;
        },
        executeToolHandler: (toolName, args, manager) =>
            _executeToolHandler(toolName, args, taskId),
      );

      final tools = _buildToolDefinitions();
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
      );

      await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: _modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.3,
        strategy: strategy,
      );

      // Capture the final assistant response from the conversation manager.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      strategy.recordFinalResponse(finalContent);

      final now = DateTime.now();

      // 6. Persist the final assistant response as a thought message.
      final thoughtText = strategy.finalResponse;
      if (thoughtText != null) {
        final thoughtPayloadId = _uuid.v4();
        await agentRepository.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: thoughtPayloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': thoughtText},
          ),
        );
        await agentRepository.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: _uuid.v4(),
            agentId: agentId,
            threadId: threadId,
            kind: AgentMessageKind.thought,
            createdAt: now,
            vectorClock: null,
            contentEntryId: thoughtPayloadId,
            metadata: AgentMessageMetadata(runKey: runKey),
          ),
        );
      }

      // 7. Extract and persist updated report (from update_report tool call).
      //    The agent contract requires calling update_report exactly once per
      //    wake. Log a warning when it's missing so we can detect non-compliance.
      final reportContent = strategy.extractReportContent();
      if (reportContent.isEmpty) {
        developer.log(
          'Agent $agentId did not publish a report during this wake '
          '(runKey: $runKey). This violates the "must call update_report" '
          'contract.',
          name: 'TaskAgentWorkflow',
        );
      }
      if (reportContent.isNotEmpty) {
        final reportId = _uuid.v4();

        await agentRepository.upsertEntity(
          AgentDomainEntity.agentReport(
            id: reportId,
            agentId: agentId,
            scope: 'current',
            createdAt: now,
            vectorClock: null,
            content: reportContent,
          ),
        );

        // Update the report head pointer.
        final existingHead =
            await agentRepository.getReportHead(agentId, 'current');
        final headId = existingHead?.id ?? _uuid.v4();

        await agentRepository.upsertEntity(
          AgentDomainEntity.agentReportHead(
            id: headId,
            agentId: agentId,
            scope: 'current',
            reportId: reportId,
            updatedAt: now,
            vectorClock: null,
          ),
        );
      }

      // 8. Persist new observation notes (agentJournal entries).
      final observations = strategy.extractObservations();
      for (final note in observations) {
        final payloadId = _uuid.v4();
        await agentRepository.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': note},
          ),
        );

        await agentRepository.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: _uuid.v4(),
            agentId: agentId,
            threadId: threadId,
            kind: AgentMessageKind.observation,
            createdAt: now,
            vectorClock: null,
            contentEntryId: payloadId,
            metadata: AgentMessageMetadata(runKey: runKey),
          ),
        );
      }

      // 9. Update state.
      await agentRepository.upsertEntity(
        state.copyWith(
          revision: state.revision + 1,
          lastWakeAt: now,
          updatedAt: now,
          consecutiveFailureCount: 0,
          wakeCounter: state.wakeCounter + 1,
        ),
      );

      developer.log(
        'Wake completed for agent $agentId: '
        '${observations.length} observations, '
        '${executor.mutatedEntries.length} mutations',
        name: 'TaskAgentWorkflow',
      );

      return WakeResult(
        success: true,
        mutatedEntries: executor.mutatedEntries,
      );
    } catch (e, s) {
      developer.log(
        'Wake failed for agent $agentId',
        name: 'TaskAgentWorkflow',
        error: e,
        stackTrace: s,
      );

      // Update failure count in state.
      try {
        await agentRepository.upsertEntity(
          state.copyWith(
            revision: state.revision + 1,
            updatedAt: DateTime.now(),
            consecutiveFailureCount: state.consecutiveFailureCount + 1,
          ),
        );
      } catch (stateError) {
        developer.log(
          'Failed to update failure count for agent $agentId',
          name: 'TaskAgentWorkflow',
          error: stateError,
        );
      }

      return WakeResult(success: false, error: e.toString());
    } finally {
      // 9. Clean up in-memory conversation to prevent resource leaks.
      conversationRepository.deleteConversation(conversationId);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Resolves the Gemini inference provider for the agent's model.
  ///
  /// Looks up the configured [AiConfigModel] whose `providerModelId` matches
  /// [_modelId], then resolves the associated inference provider. This ensures
  /// the agent uses the correct provider even when multiple Gemini providers
  /// are configured.
  ///
  /// Returns `null` if the model is not configured, the provider is missing,
  /// or the provider has no API key set.
  Future<AiConfigInferenceProvider?> _resolveGeminiProvider() async {
    final models =
        await aiConfigRepository.getConfigsByType(AiConfigType.model);

    // Find the configured model matching our hardcoded model ID.
    final matchingModel = models.whereType<AiConfigModel>().where(
          (m) => m.providerModelId == _modelId,
        );

    if (matchingModel.isEmpty) {
      developer.log(
        'Model $_modelId not found in configured models',
        name: 'TaskAgentWorkflow',
      );
      return null;
    }

    // Resolve the inference provider associated with this model.
    final providerId = matchingModel.first.inferenceProviderId;
    final provider = await aiConfigRepository.getConfigById(providerId);

    if (provider is! AiConfigInferenceProvider) {
      developer.log(
        'Provider $providerId for model $_modelId is not an inference provider',
        name: 'TaskAgentWorkflow',
      );
      return null;
    }

    if (provider.apiKey.isEmpty) {
      developer.log(
        'Provider $providerId has no API key configured',
        name: 'TaskAgentWorkflow',
      );
      return null;
    }

    return provider;
  }

  /// System prompt for the Task Agent, extracted as a constant for easier
  /// iteration and testing.
  static const taskAgentSystemPrompt = '''
You are a Task Agent — a persistent assistant that maintains a summary report
for a single task. Your job is to:

1. Analyze the current task state and any changes since your last wake.
2. Call tools when appropriate to update task metadata (estimates, due dates,
   priorities, checklist items, title, labels).
3. Publish an updated report via the `update_report` tool.
4. Record observations worth remembering for future wakes.

## Report

You MUST call `update_report` exactly once at the end of every wake with the
full updated report as markdown. The format is free-form — use whatever
headings, lists, and structure best describe the task's current state. A
typical report might include sections like TLDR, Goal, Status, Achieved,
Remaining, and Learnings, but you are free to add, remove, or rename
sections as needed. The report format can evolve naturally over time.

Example report markdown:

```
# Implement authentication module

**Status:** in_progress | **Priority:** P1 | **Estimate:** 4h | **Due:** 2026-02-25

OAuth2 integration 60% complete. Login UI done, logout and tests remaining.

## Achieved
- Set up OAuth provider configuration
- Implemented token refresh logic
- Built login UI with error handling

## Remaining
- Add logout flow with token revocation
- Write integration tests for auth endpoints
```

## Tool Usage Guidelines

- Only call tools when you have sufficient confidence in the change.
- Do not call tools speculatively or redundantly.
- When a tool call fails, note the failure in observations and move on.
- Each tool call is audited and must stay within the task's category scope.
- Use `record_observations` to record private notes worth remembering for
  future wakes (patterns, insights, failure notes). Do NOT embed observations
  in the report text — always use the tool.
- **Title**: Only set the title when the task has no title yet. Do not
  change an existing title unless the user explicitly asks for it.
- **Estimates**: Only set or update an estimate when the user explicitly
  requests it, or when no estimate exists and you have high confidence.
  Do not retroactively adjust estimates based on time already spent
  unless specifically asked to do so.

## Important

- You observe journal-domain data but do not own it.
- Your report and observations are your persistent memory across wakes.
- Be concise. Focus on what changed and what matters.
''';

  /// Builds the user message for a wake cycle.
  Future<String> _buildUserMessage({
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> journalObservations,
    required String taskDetailsJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
  }) async {
    final buffer = StringBuffer();

    if (lastReport != null && lastReport.content.isNotEmpty) {
      buffer
        ..writeln('## Current Report')
        ..writeln(lastReport.content)
        ..writeln();
    } else {
      buffer
        ..writeln(
          '## First Wake — No prior report exists. '
          'Produce an initial report.',
        )
        ..writeln();
    }

    if (journalObservations.isNotEmpty) {
      buffer.writeln('## Your Prior Observations');
      // Cap to most recent 20 to prevent unbounded context growth.
      // journalObservations is ordered newest-first from the DB query.
      final recentObs = journalObservations.length > 20
          ? journalObservations.sublist(0, 20)
          : journalObservations;
      for (final obs in recentObs) {
        final text = await _resolveObservationText(obs);
        buffer.writeln('- [${obs.createdAt.toIso8601String()}] $text');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('## Current Task Context')
      ..writeln('```json')
      ..writeln(taskDetailsJson)
      ..writeln('```')
      ..writeln();

    if (linkedTasksJson.isNotEmpty && linkedTasksJson != '{}') {
      buffer
        ..writeln('## Linked Tasks')
        ..writeln('```json')
        ..writeln(linkedTasksJson)
        ..writeln('```')
        ..writeln();
    }

    if (triggerTokens.isNotEmpty) {
      buffer
        ..writeln('## Changed Since Last Wake')
        ..writeln(
          'The following entity IDs changed: ${triggerTokens.join(", ")}',
        )
        ..writeln();
    }

    buffer.writeln(
      'Analyze the current state, call tools if needed, then call '
      '`update_report` with the full updated report. '
      'Add observations if warranted.',
    );

    return buffer.toString();
  }

  /// Resolves the text content of an observation message.
  ///
  /// Looks up the [AgentMessagePayloadEntity] via the message's
  /// `contentEntryId` and extracts the `text` field from its content map.
  /// Falls back to a placeholder when the payload is missing or malformed.
  Future<String> _resolveObservationText(AgentMessageEntity obs) async {
    final payloadId = obs.contentEntryId;
    if (payloadId == null) return '(no content)';

    final payload = await agentRepository.getEntity(payloadId);
    if (payload is AgentMessagePayloadEntity) {
      final text = payload.content['text'];
      if (text is String && text.isNotEmpty) return text;
    }
    return '(no content)';
  }

  /// Converts [AgentToolRegistry.taskAgentTools] to OpenAI-compatible
  /// [ChatCompletionTool] objects.
  List<ChatCompletionTool> _buildToolDefinitions() {
    return AgentToolRegistry.taskAgentTools.map((def) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: def.name,
          description: def.description,
          parameters: def.parameters,
        ),
      );
    }).toList();
  }

  /// Executes a tool handler by delegating to the appropriate existing
  /// journal-domain handler.
  ///
  /// Each tool call returns a [ToolExecutionResult] that the
  /// [AgentToolExecutor] wraps with audit logging and policy enforcement.
  Future<ToolExecutionResult> _executeToolHandler(
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    developer.log(
      'Dispatching tool handler: $toolName',
      name: 'TaskAgentWorkflow',
    );

    // Load the task fresh for each tool call so handlers see the latest state.
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
    if (titleArg is! String || titleArg.isEmpty) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a non-empty string, '
            'got ${titleArg.runtimeType}',
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
    // caller (_executeToolHandler).
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
      success: count > 0,
      output: handler.createToolResponse(parseResult),
      mutatedEntityId: count > 0 ? taskId : null,
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
    return ToolExecutionResult(
      // Return success=true as long as parsing succeeded — a count of 0
      // just means all items were already in the requested state (no-op).
      success: true,
      output: handler.createToolResponse(parseResult),
      mutatedEntityId: count > 0 ? taskId : null,
    );
  }

  /// Extracts the final assistant text content from the conversation manager.
  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;

    // Walk backwards through messages to find the last assistant message
    // with text content (not a tool-call-only message).
    for (final message in manager.messages.reversed) {
      if (message
          case ChatCompletionMessage(
            role: ChatCompletionMessageRole.assistant
          )) {
        final content = message.mapOrNull(
          assistant: (m) => m.content,
        );
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }
}

/// Result of a wake cycle execution.
class WakeResult {
  const WakeResult({
    required this.success,
    this.mutatedEntries = const {},
    this.error,
  });

  /// Whether the wake completed successfully.
  final bool success;

  /// Map of journal entity IDs mutated during this wake to their post-mutation
  /// vector clocks. Used by the orchestrator for self-notification suppression.
  final Map<String, VectorClock> mutatedEntries;

  /// Error description when [success] is false.
  final String? error;
}
