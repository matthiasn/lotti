import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
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
  });

  final AgentRepository agentRepository;
  final ConversationRepository conversationRepository;
  final AiInputRepository aiInputRepository;
  final AiConfigRepository aiConfigRepository;
  final JournalDb journalDb;
  final CloudInferenceRepository cloudInferenceRepository;

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
    final systemPrompt = _buildSystemPrompt();
    final userMessage = _buildUserMessage(
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
            _executeToolHandler(toolName, args, manager, taskId),
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

      // 6. Extract and persist updated report.
      final now = DateTime.now();
      final reportContent = strategy.extractReportContent();
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

      // 7. Persist new observation notes (agentJournal entries).
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

      // 8. Update state.
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

  /// Builds the system prompt for the Task Agent.
  String _buildSystemPrompt() {
    return '''
You are a Task Agent — a persistent assistant that maintains a summary report
for a single task. Your job is to:

1. Analyze the current task state and any changes since your last wake.
2. Call tools when appropriate to update task metadata (estimates, due dates,
   priorities, checklist items, title, labels).
3. Produce an updated report summarizing the task's current state.
4. Record observations worth remembering for future wakes.

## Output Format

You MUST respond with a JSON object containing exactly two keys:

```json
{
  "report": {
    "title": "Short task title",
    "tldr": "One-sentence summary of current state",
    "goal": "What the task aims to achieve",
    "status": "not_started | in_progress | blocked | completed",
    "priority": "P1 | P2 | P3 | P4",
    "estimate": "Time estimate if known",
    "dueDate": "ISO 8601 date if known",
    "achieved": ["List of completed items"],
    "remaining": ["List of remaining items"],
    "learnings": ["Notable patterns or insights"],
    "checklistProgress": {"total": 0, "completed": 0},
    "lastUpdated": "ISO 8601 timestamp"
  },
  "observations": [
    "Private notes about patterns or changes worth remembering"
  ]
}
```

## Tool Usage Guidelines

- Only call tools when you have sufficient confidence in the change.
- Do not call tools speculatively or redundantly.
- When a tool call fails, note the failure in observations and move on.
- Each tool call is audited and must stay within the task's category scope.

## Important

- You observe journal-domain data but do not own it.
- Your report and observations are your persistent memory across wakes.
- Be concise. Focus on what changed and what matters.
''';
  }

  /// Builds the user message for a wake cycle.
  String _buildUserMessage({
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> journalObservations,
    required String taskDetailsJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
  }) {
    final buffer = StringBuffer();

    if (lastReport != null) {
      buffer
        ..writeln('## Current Report')
        ..writeln('```json')
        ..writeln(lastReport.content)
        ..writeln('```')
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
      for (final obs in journalObservations) {
        buffer.writeln('- [${obs.createdAt.toIso8601String()}] '
            '${obs.contentEntryId ?? "(no content)"}');
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
      'Update the report based on the current state. '
      'Add observations if warranted. Call tools if needed.',
    );

    return buffer.toString();
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
  /// For MVP, this uses a simple dispatch table. Each tool call returns a
  /// [ToolExecutionResult] that the [AgentToolExecutor] wraps with audit
  /// logging and policy enforcement.
  Future<ToolExecutionResult> _executeToolHandler(
    String toolName,
    Map<String, dynamic> args,
    ConversationManager manager,
    String taskId,
  ) async {
    developer.log(
      'Dispatching tool handler: $toolName',
      name: 'TaskAgentWorkflow',
    );

    // For MVP, tool handler execution is a placeholder that returns the tool
    // name and args as confirmation. The actual handler wiring (connecting to
    // TaskEstimateHandler, TaskDueDateHandler, etc.) will be completed when
    // the wake orchestrator integrates with the workflow layer.
    //
    // Each handler follows the same pattern:
    //   1. Load the task from journalDb.
    //   2. Apply the mutation via the handler's processToolCall method.
    //   3. Return a ToolExecutionResult with the outcome.
    //
    // The dispatch is intentionally kept as a simple switch so that adding
    // new tools requires only a new case branch.
    switch (toolName) {
      case 'set_task_title':
      case 'update_task_estimate':
      case 'update_task_due_date':
      case 'update_task_priority':
      case 'add_multiple_checklist_items':
      case 'update_checklist_items':
        return ToolExecutionResult(
          success: true,
          output: 'Tool $toolName acknowledged with args: $args. '
              'Handler integration pending.',
          mutatedEntityId: taskId,
        );

      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage: 'Tool $toolName is not registered for the Task Agent',
        );
    }
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
  final Map<String, dynamic> mutatedEntries;

  /// Error description when [success] is false.
  final String? error;
}
