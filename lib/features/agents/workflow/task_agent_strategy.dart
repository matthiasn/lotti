import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
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
/// self-notification suppression. Two tools are handled locally:
///
/// - `update_report` — the LLM publishes its report via this tool call;
///   the markdown is accumulated and retrieved via [extractReportContent].
/// - `record_observations` — private notes for future wakes; accumulated
///   and retrieved via [extractObservations].
///
/// Each message (assistant response, tool call, tool result) is persisted to
/// `agent.sqlite` as an [AgentMessageEntity].
///
/// After the conversation completes, callers use [extractReportContent] and
/// [extractObservations] to obtain the LLM's output. The final assistant text
/// response (which may contain `<think>` tags or other reasoning) is captured
/// separately via [recordFinalResponse] and can be persisted as a thought.
class TaskAgentStrategy extends ConversationStrategy {
  TaskAgentStrategy({
    required this.executor,
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.taskId,
    required this.resolveCategoryId,
    required this.readVectorClock,
    required this.executeToolHandler,
    this.changeSetBuilder,
  });

  /// The [AgentToolExecutor] that wraps handler calls with enforcement and
  /// audit logging.
  final AgentToolExecutor executor;

  /// Sync-aware write service for persisting messages. All writes go through
  /// this so they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

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

  /// Optional builder for accumulating deferred tool calls into a change set.
  ///
  /// When provided, tools listed in [AgentToolRegistry.deferredTools] are
  /// routed to the builder instead of being executed immediately. The change
  /// set is persisted at the end of the wake via [ChangeSetBuilder.build].
  final ChangeSetBuilder? changeSetBuilder;

  String? _reportMarkdown;
  String? _finalResponse;
  final _observations = <String>[];
  static const _uuid = Uuid();

  /// Tool name for the report publishing tool.
  static const String reportToolName = TaskAgentToolNames.updateReport;

  /// Tool name for the observation recording tool.
  static const String observationToolName =
      TaskAgentToolNames.recordObservations;

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
        final decoded = jsonDecode(call.function.arguments);
        if (decoded is Map<String, dynamic>) {
          args = decoded;
        } else {
          // Handles null, arrays, and other non-object JSON values.
          throw FormatException(
            'Expected a JSON object, got ${decoded.runtimeType}',
          );
        }
      } catch (e) {
        developer.log(
          'Failed to parse tool call arguments for $toolName: $e',
          name: 'TaskAgentStrategy',
        );
        const errorMsg =
            'Error: invalid arguments format — expected a JSON object.';
        manager.addToolResponse(toolCallId: call.id, response: errorMsg);
        await _recordToolResultMessage(
          toolName: toolName,
          errorMessage: '$errorMsg Detail: $e',
        );
        continue;
      }

      final argsBytes = utf8.encode(jsonEncode(args)).length;
      developer.log(
        'Processing tool call: $toolName ($argsBytes bytes)',
        name: 'TaskAgentStrategy',
      );

      // Handle update_report and record_observations locally — they don't
      // modify journal entities so they don't need category enforcement,
      // but we still persist audit messages for completeness.
      if (toolName == reportToolName) {
        await _handleUpdateReport(args, call.id, manager);
        continue;
      }
      if (toolName == observationToolName) {
        await _handleRecordObservations(args, call.id, manager);
        continue;
      }

      // Route deferred tools to the change set builder when available.
      final csBuilder = changeSetBuilder;
      if (csBuilder != null &&
          AgentToolRegistry.deferredTools.contains(toolName)) {
        final response = await _addToChangeSet(csBuilder, toolName, args);
        manager.addToolResponse(
          toolCallId: call.id,
          response: response,
        );
        continue;
      }

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
    if (_reportMarkdown != null) {
      // Report already submitted — no further turns needed.
      return null;
    }
    return 'Continue. If you have finished your analysis, call `update_report` '
        'with the full updated report.';
  }

  /// Called by the workflow after the conversation loop finishes to capture
  /// the assistant's final text response (for thought persistence).
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) {
      _finalResponse = content;
    }
  }

  /// Returns the raw final assistant response for thought persistence.
  ///
  /// This may contain `<think>` tags or other reasoning — it is NOT the
  /// report. The report is captured via the `update_report` tool call.
  String? get finalResponse => _finalResponse;

  /// Extracts the report content published via the `update_report` tool call.
  ///
  /// Returns the markdown string, or empty string if the LLM never called
  /// `update_report`.
  String extractReportContent() => _reportMarkdown ?? '';

  /// Returns observations accumulated from `record_observations` tool calls.
  ///
  /// The LLM calls the `record_observations` tool during the conversation
  /// to record private notes for future wakes. Each call may contain
  /// multiple observation strings, all of which are accumulated here.
  List<String> extractObservations() => List.unmodifiable(_observations);

  // ── Internal handlers ──────────────────────────────────────────────────

  /// Handles the `update_report` tool call by capturing the markdown content
  /// and sending an acknowledgement back to the conversation.
  /// Handles the `update_report` tool call.
  ///
  /// If the LLM calls this more than once per wake, the last call wins — the
  /// previous content is silently replaced. This is by design: the agent
  /// contract requires exactly one call, so multiple calls indicate an LLM
  /// error and the latest version is the most refined.
  Future<void> _handleUpdateReport(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final markdown = args['markdown'];
    if (markdown is String && markdown.trim().isNotEmpty) {
      _reportMarkdown = markdown.trim();

      developer.log(
        'Report updated (${_reportMarkdown!.length} chars)',
        name: 'TaskAgentStrategy',
      );

      manager.addToolResponse(
        toolCallId: callId,
        response: 'Report updated.',
      );

      await _recordToolResultMessage(toolName: reportToolName);
    } else {
      const errorMsg = 'Error: "markdown" must be a non-empty string.';
      manager.addToolResponse(
        toolCallId: callId,
        response: errorMsg,
      );

      await _recordToolResultMessage(
        toolName: reportToolName,
        errorMessage: errorMsg,
      );
    }
  }

  /// Handles the `record_observations` tool call by accumulating observations
  /// and sending an acknowledgement back to the conversation.
  Future<void> _handleRecordObservations(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawList = args['observations'];
    if (rawList is List) {
      final notes =
          rawList.whereType<String>().where((s) => s.trim().isNotEmpty);
      _observations.addAll(notes);

      developer.log(
        'Recorded ${notes.length} observations',
        name: 'TaskAgentStrategy',
      );

      manager.addToolResponse(
        toolCallId: callId,
        response: 'Recorded ${notes.length} observation(s).',
      );

      await _recordToolResultMessage(toolName: observationToolName);
    } else {
      const errorMsg = 'Error: "observations" must be an array of strings.';
      manager.addToolResponse(
        toolCallId: callId,
        response: errorMsg,
      );

      await _recordToolResultMessage(
        toolName: observationToolName,
        errorMessage: errorMsg,
      );
    }
  }

  // ── Change set helpers ──────────────────────────────────────────────────

  /// Route a deferred tool call to the change set builder.
  ///
  /// Batch tools (listed in [AgentToolRegistry.explodedBatchTools]) are
  /// exploded into individual items; all others are added as a single item.
  ///
  /// Returns a response string for the LLM. For batch tools with skipped
  /// items, the response includes a warning.
  Future<String> _addToChangeSet(
    ChangeSetBuilder csBuilder,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final batchKey = AgentToolRegistry.explodedBatchTools[toolName];
    String response;
    if (batchKey != null) {
      final result = await csBuilder.addBatchItem(
        toolName: toolName,
        args: args,
        summaryPrefix: _humanToolPrefix(toolName),
      );
      if (result.skipped > 0) {
        response = 'Proposal queued for user review '
            '(${result.added} item(s) queued, '
            '${result.skipped} malformed item(s) skipped).';
      } else {
        response = 'Proposal queued for user review.';
      }
    } else {
      csBuilder.addItem(
        toolName: toolName,
        args: args,
        humanSummary: _generateHumanSummary(toolName, args),
      );
      response = 'Proposal queued for user review.';
    }

    developer.log(
      'Deferred tool $toolName to change set '
      '(${csBuilder.items.length} items total)',
      name: 'TaskAgentStrategy',
    );

    return response;
  }

  /// Generate a human-readable summary for a single (non-batch) tool call.
  static String _generateHumanSummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    return switch (toolName) {
      TaskAgentToolNames.setTaskTitle =>
        'Set title to "${args['title'] ?? ''}"',
      TaskAgentToolNames.updateTaskEstimate =>
        'Set estimate to ${args['minutes'] ?? '?'} minutes',
      TaskAgentToolNames.updateTaskDueDate =>
        'Set due date to ${args['dueDate'] ?? '?'}',
      TaskAgentToolNames.updateTaskPriority =>
        'Set priority to ${args['priority'] ?? '?'}',
      TaskAgentToolNames.setTaskStatus =>
        'Set status to ${args['status'] ?? '?'}',
      TaskAgentToolNames.assignTaskLabels => () {
          final labels = args['labels'];
          final count = labels is List ? labels.length : 0;
          return 'Assign $count label(s)';
        }(),
      _ => '$toolName(${args.keys.join(", ")})',
    };
  }

  /// Generate a human-readable prefix for batch tool explosion summaries.
  static String _humanToolPrefix(String toolName) {
    return switch (toolName) {
      TaskAgentToolNames.addMultipleChecklistItems => 'Checklist',
      TaskAgentToolNames.updateChecklistItems => 'Checklist update',
      _ => toolName,
    };
  }

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Records an assistant message (with or without tool calls) to the agent
  /// message log.
  Future<void> _recordAssistantMessage({
    List<ChatCompletionMessageToolCall>? toolCalls,
  }) async {
    final now = clock.now();
    final toolNames =
        toolCalls?.map((tc) => tc.function.name).toList() ?? <String>[];

    await syncService.upsertEntity(
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
    final now = clock.now();
    await syncService.upsertEntity(
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
