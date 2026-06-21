import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// [ConversationStrategy] implementation for the Event Agent.
///
/// Two tools are handled immediately and locally:
/// - `update_report` — accumulates the event recap (oneLiner / tldr / content).
/// - `record_observations` — accumulates private observation notes.
///
/// One tool is **deferred** (accumulated for user accept/reject, not applied
/// in-conversation):
/// - `suggest_follow_up_task` — see [eventDeferredTools]; surfaced as a pending
///   change set and applied by `EventToolDispatcher` only on accept.
///
/// There is deliberately no rating/cover tool — those are human-only. Each
/// message is persisted to `agent.sqlite` as an [AgentMessageEntity], mirroring
/// `ProjectAgentStrategy`.
class EventAgentStrategy extends ConversationStrategy
    with ObservationRecordParsing {
  EventAgentStrategy({
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
  });

  /// Sync-aware write service for persisting messages.
  final AgentSyncService syncService;

  /// The agent's stable ID.
  final String agentId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

  String? _reportContent;
  String? _reportTldr;
  String? _reportOneLiner;
  String? _finalResponse;
  final _observations = <ObservationRecord>[];
  final _deferredItems = <Map<String, dynamic>>[];

  static const _uuid = Uuid();

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    // Persist the assistant message that requested tool calls.
    await _recordAssistantMessage();

    for (final call in toolCalls) {
      final toolName = call.function.name;

      Map<String, dynamic> args;
      try {
        args = parseAgentToolArguments(call.function.arguments);
      } catch (e) {
        final rawBytes = utf8.encode(call.function.arguments).length;
        developer.log(
          'Failed to parse tool call arguments for $toolName '
          '(rawBytes=$rawBytes, errorType=${e.runtimeType})',
          name: 'EventAgentStrategy',
        );
        final errorMsg =
            'Error: invalid arguments format — expected a JSON object. '
            'Detail: ${e.runtimeType}';
        manager.addToolResponse(toolCallId: call.id, response: errorMsg);
        await _recordToolResultMessage(
          toolName: toolName,
          errorMessage: errorMsg,
        );
        continue;
      }

      await _recordActionMessage(toolName: toolName, args: args);

      if (toolName == EventAgentToolNames.updateReport) {
        await _handleUpdateReport(args, call.id, manager);
        continue;
      }

      if (toolName == EventAgentToolNames.recordObservations) {
        await _handleRecordObservations(args, call.id, manager);
        continue;
      }

      // Deferred tools: accumulate for later persistence + user review.
      if (eventDeferredTools.contains(toolName)) {
        _deferredItems.add({'toolName': toolName, 'args': args});
        manager.addToolResponse(
          toolCallId: call.id,
          response: 'Queued $toolName for user review.',
        );
        await _recordToolResultMessage(toolName: toolName);
        continue;
      }

      // Unknown tool — tell the LLM.
      final errorMsg = 'Error: unknown tool "$toolName".';
      manager.addToolResponse(toolCallId: call.id, response: errorMsg);
      await _recordToolResultMessage(
        toolName: toolName,
        errorMessage: errorMsg,
      );
    }

    return ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) {
    return manager.canContinue();
  }

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (_reportContent != null) return null;
    return 'Continue. If you have finished the recap, call `update_report` '
        'with the full updated event recap.';
  }

  /// Called by the workflow after the conversation loop finishes.
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) {
      _finalResponse = content;
    }
  }

  /// Returns the final assistant text response for thought persistence.
  String? get finalResponse => _finalResponse;

  /// Extracts the recap content published via `update_report`.
  String extractReportContent() => _reportContent ?? '';

  /// Extracts the TLDR published via `update_report`.
  String? extractReportTldr() => _reportTldr;

  /// Extracts the one-liner published via `update_report`.
  String? extractReportOneLiner() => _reportOneLiner;

  /// Returns observations accumulated from `record_observations` calls.
  List<ObservationRecord> extractObservations() =>
      List.unmodifiable(_observations);

  /// Returns deferred tool items accumulated during the conversation, for
  /// persistence as a pending change set the user can accept or reject.
  List<Map<String, dynamic>> extractDeferredItems() =>
      List.unmodifiable(_deferredItems);

  // ── Report handling ────────────────────────────────────────────────────────

  Future<void> _handleUpdateReport(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final contentValue = args[EventAgentReportToolArgs.content];
    final content = contentValue is String ? contentValue.trim() : '';
    final tldrValue = args[EventAgentReportToolArgs.tldr];
    final tldr = tldrValue is String ? tldrValue.trim() : '';
    final oneLinerValue = args[EventAgentReportToolArgs.oneLiner];
    final oneLiner = oneLinerValue is String ? oneLinerValue.trim() : '';

    final validations = [
      (
        content.isEmpty,
        'Error: "content" field is required and must not be empty.',
      ),
      (
        tldr.isEmpty,
        'Error: "tldr" field is required and must not be empty.',
      ),
      (
        oneLiner.isEmpty,
        'Error: "oneLiner" field is required and must not be empty.',
      ),
    ];

    for (final (failed, errorMsg) in validations) {
      if (failed) {
        await _rejectToolCall(
          callId: callId,
          toolName: EventAgentToolNames.updateReport,
          errorMsg: errorMsg,
          manager: manager,
        );
        return;
      }
    }

    _reportContent = content;
    _reportTldr = tldr;
    _reportOneLiner = oneLiner;

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Recap updated successfully.',
    );
    await _recordToolResultMessage(
      toolName: EventAgentToolNames.updateReport,
    );
  }

  // ── Observation handling ───────────────────────────────────────────────────

  Future<void> _handleRecordObservations(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawList = args['observations'];
    if (rawList is! List || rawList.isEmpty) {
      await _rejectToolCall(
        callId: callId,
        toolName: EventAgentToolNames.recordObservations,
        errorMsg: 'Error: "observations" must be a non-empty array.',
        manager: manager,
      );
      return;
    }

    var accepted = 0;
    for (final item in rawList) {
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          _observations.add(ObservationRecord(text: trimmed));
          accepted++;
        }
      } else if (item is Map<String, dynamic>) {
        final textValue = item['text'];
        final text = textValue is String ? textValue.trim() : '';
        if (text.isEmpty) continue;

        final priority = parseObservationPriority(
          item['priority'] is String ? item['priority'] as String : null,
        );
        final category = parseObservationCategory(
          item['category'] is String ? item['category'] as String : null,
        );

        _observations.add(
          ObservationRecord(
            text: text,
            priority: priority,
            category: category,
          ),
        );
        accepted++;
      }
    }

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Recorded $accepted observation(s).',
    );
    await _recordToolResultMessage(
      toolName: EventAgentToolNames.recordObservations,
    );
  }

  // ── Error helpers ──────────────────────────────────────────────────────────

  Future<void> _rejectToolCall({
    required String callId,
    required String toolName,
    required String errorMsg,
    required ConversationManager manager,
  }) async {
    manager.addToolResponse(toolCallId: callId, response: errorMsg);
    await _recordToolResultMessage(toolName: toolName, errorMessage: errorMsg);
  }

  /// Test seam for the shared JSON/markdown argument parser.
  @visibleForTesting
  Map<String, dynamic> debugParseToolArguments(String raw) =>
      parseAgentToolArguments(raw);

  // ── Message persistence ────────────────────────────────────────────────────

  Future<void> _recordAssistantMessage() async {
    try {
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.thought,
          createdAt: clock.now(),
          vectorClock: null,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e) {
      developer.log(
        'Failed to persist assistant message (errorType=${e.runtimeType})',
        name: 'EventAgentStrategy',
      );
    }
  }

  Future<void> _recordActionMessage({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.action,
          createdAt: clock.now(),
          vectorClock: null,
          metadata: AgentMessageMetadata(
            runKey: runKey,
            toolName: toolName,
          ),
        ),
      );
    } catch (e) {
      developer.log(
        'Failed to persist action message (errorType=${e.runtimeType})',
        name: 'EventAgentStrategy',
      );
    }
  }

  Future<void> _recordToolResultMessage({
    required String toolName,
    String? errorMessage,
  }) async {
    try {
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.toolResult,
          createdAt: clock.now(),
          vectorClock: null,
          metadata: AgentMessageMetadata(
            runKey: runKey,
            toolName: toolName,
            errorMessage: errorMessage,
          ),
        ),
      );
    } catch (e) {
      developer.log(
        'Failed to persist tool result message (errorType=${e.runtimeType})',
        name: 'EventAgentStrategy',
      );
    }
  }
}
