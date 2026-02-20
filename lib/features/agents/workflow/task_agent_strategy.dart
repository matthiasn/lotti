import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Callback that resolves a journal entity's category ID from its entity ID.
typedef ResolveCategoryId = Future<String?> Function(String entityId);

/// Callback that reads the current vector clock of a journal entity.
typedef ReadVectorClock = Future<VectorClock?> Function(String entityId);

/// Callback that executes a tool handler and returns a [ToolExecutionResult].
///
/// The callback receives the tool name, decoded arguments map, and the
/// [ConversationManager] (so the handler can add tool responses to the
/// conversation history). It must return a [ToolExecutionResult] with at
/// minimum the [ToolExecutionResult.success] and [ToolExecutionResult.output]
/// fields populated.
typedef ExecuteToolHandler = Future<ToolExecutionResult> Function(
  String toolName,
  Map<String, dynamic> args,
  ConversationManager manager,
);

/// [ConversationStrategy] implementation for the Task Agent.
///
/// Dispatches tool calls to existing journal-domain handlers wrapped by
/// [AgentToolExecutor] for category enforcement, audit logging, and
/// self-notification suppression. Each message (assistant response, tool call,
/// tool result) is persisted to `agent.sqlite` as an [AgentMessageEntity].
///
/// After the conversation completes, callers use [extractReportContent] and
/// [extractObservations] to obtain the LLM's structured output.
class TaskAgentStrategy extends ConversationStrategy {
  TaskAgentStrategy({
    required this.executor,
    required this.repository,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.taskId,
    required this.resolveCategoryId,
    required this.readVectorClock,
    required this.executeToolHandler,
  });

  /// The [AgentToolExecutor] that wraps handler calls with enforcement and
  /// audit logging.
  final AgentToolExecutor executor;

  /// Agent-domain repository for persisting messages.
  final AgentRepository repository;

  /// The agent's stable ID.
  final String agentId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

  /// The journal-domain task ID this agent is working on.
  final String taskId;

  /// Resolves a journal entity's category ID.
  final ResolveCategoryId resolveCategoryId;

  /// Reads the current vector clock of a journal entity.
  final ReadVectorClock readVectorClock;

  /// Executes a named tool handler with arguments.
  final ExecuteToolHandler executeToolHandler;

  final _assistantResponses = <String>[];
  static const _uuid = Uuid();

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    // Persist the assistant message (the one that requested tool calls).
    await _recordAssistantMessage(toolCalls: toolCalls);

    for (final call in toolCalls) {
      final toolName = call.function.name;

      Map<String, dynamic> args;
      try {
        args = (jsonDecode(call.function.arguments) as Map<String, dynamic>?) ??
            <String, dynamic>{};
      } catch (e) {
        developer.log(
          'Failed to parse tool call arguments for $toolName: $e',
          name: 'TaskAgentStrategy',
        );
        const errorMsg = 'Error: invalid JSON in tool call arguments';
        manager.addToolResponse(toolCallId: call.id, response: errorMsg);
        await _recordToolResultMessage(
          toolName: toolName,
          errorMessage: errorMsg,
        );
        continue;
      }

      developer.log(
        'Processing tool call: $toolName with args: $args',
        name: 'TaskAgentStrategy',
      );

      // Delegate to the executor which handles category enforcement, audit
      // logging, saga tracking, and vector-clock capture.
      final result = await executor.execute(
        toolName: toolName,
        args: args,
        targetEntityId: taskId,
        resolveCategoryId: resolveCategoryId,
        executeHandler: () => executeToolHandler(toolName, args, manager),
        readVectorClock: readVectorClock,
      );

      // Feed the result back to the conversation so the LLM sees it on
      // the next turn.
      manager.addToolResponse(
        toolCallId: call.id,
        response: result.output,
      );
    }

    // After processing all tool calls, let the conversation loop continue
    // so the LLM can inspect results and either call more tools or produce
    // its final response.
    return ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) {
    return manager.canContinue();
  }

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    // No explicit continuation prompt needed — the tool results already
    // appeared in the conversation via addToolResponse. The LLM will see
    // them and decide whether to call more tools or produce its final
    // response.
    return null;
  }

  /// Called by the workflow after the conversation loop finishes to capture
  /// the assistant's final text response.
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) {
      _assistantResponses.add(content);
    }
  }

  /// Extracts the updated report content from the LLM's final response.
  ///
  /// The LLM is instructed to produce a JSON block with a `report` key.
  /// If parsing fails, the raw text is returned as the report body.
  Map<String, Object?> extractReportContent() {
    if (_assistantResponses.isEmpty) {
      return <String, Object?>{'error': 'No assistant response received'};
    }

    final lastResponse = _assistantResponses.last;

    // Try to parse as JSON first — the LLM is instructed to output structured
    // JSON containing `report` and `observations` keys.
    try {
      final parsed = jsonDecode(lastResponse) as Map<String, dynamic>;
      final report = parsed['report'];
      if (report is Map<String, dynamic>) {
        return report;
      }
      // If the entire response is the report (no wrapper), use it directly.
      return parsed;
    } catch (_) {
      // Fall back to wrapping the raw text.
      return <String, Object?>{'rawText': lastResponse};
    }
  }

  /// Extracts new observation notes (agentJournal entries) from the LLM's
  /// final response.
  ///
  /// The LLM is instructed to produce a JSON block with an `observations`
  /// array. Returns an empty list when parsing fails or no observations are
  /// present.
  List<String> extractObservations() {
    if (_assistantResponses.isEmpty) return [];

    final lastResponse = _assistantResponses.last;

    try {
      final parsed = jsonDecode(lastResponse) as Map<String, dynamic>;
      final observations = parsed['observations'];
      if (observations is List) {
        return observations.whereType<String>().toList();
      }
    } catch (_) {
      // No structured observations available.
    }

    return [];
  }

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Records an assistant message (with or without tool calls) to the agent
  /// message log.
  Future<void> _recordAssistantMessage({
    List<ChatCompletionMessageToolCall>? toolCalls,
  }) async {
    final now = DateTime.now();
    final toolNames =
        toolCalls?.map((tc) => tc.function.name).toList() ?? <String>[];

    await repository.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.thought,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolNames.isNotEmpty ? toolNames.join(',') : null,
        ),
      ),
    );
  }

  /// Records a tool result message to the agent message log.
  Future<void> _recordToolResultMessage({
    required String toolName,
    String? errorMessage,
  }) async {
    final now = DateTime.now();
    await repository.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.toolResult,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolName,
          errorMessage: errorMessage,
        ),
      ),
    );
  }
}
