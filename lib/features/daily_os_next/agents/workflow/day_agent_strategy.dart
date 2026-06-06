import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Callback used by [DayAgentStrategy] for non-local tool execution.
typedef DayAgentToolHandler =
    Future<DayAgentToolResult> Function(
      String toolName,
      Map<String, dynamic> args,
      ConversationManager manager,
    );

/// Result returned by day-agent tool handlers.
class DayAgentToolResult {
  /// Creates a tool result.
  const DayAgentToolResult({
    required this.success,
    required this.output,
  });

  /// Whether the tool executed successfully.
  final bool success;

  /// User/model-visible tool response.
  final String output;
}

/// Conversation strategy for the Daily OS day agent foundation.
class DayAgentStrategy extends ConversationStrategy {
  /// Creates a strategy for one day-agent wake.
  DayAgentStrategy({
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.executeToolHandler,
    required this.domainLogger,
  });

  /// Sync-aware write service for persisted conversation messages.
  final AgentSyncService syncService;

  /// Stable agent ID.
  final String agentId;

  /// Wake thread ID.
  final String threadId;

  /// Wake run key.
  final String runKey;

  /// Handler for tools that mutate shared agent state.
  final DayAgentToolHandler executeToolHandler;

  /// Structured logger.
  final DomainLogger domainLogger;

  final _observations = <ObservationRecord>[];
  var _didPersistCaptureParse = false;
  var _didPersistDraftDayPlan = false;
  String? _finalResponse;

  static const _uuid = Uuid();

  /// Returns observations accumulated from `record_observations` calls.
  List<ObservationRecord> extractObservations() =>
      List.unmodifiable(_observations);

  /// Whether this wake successfully persisted a plan via `draft_day_plan`.
  bool get didPersistDraftDayPlan => _didPersistDraftDayPlan;

  /// Whether this wake successfully persisted parsed capture items.
  bool get didPersistCaptureParse => _didPersistCaptureParse;

  /// Called by the workflow after the conversation loop finishes.
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) {
      _finalResponse = content;
    }
  }

  /// Final assistant text response captured for private thought persistence.
  String? get finalResponse => _finalResponse;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    await _recordAssistantMessage();

    for (final call in toolCalls) {
      final toolName = call.function.name;
      late final Map<String, dynamic> args;
      try {
        args = _parseToolArguments(call.function.arguments);
      } catch (e) {
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

      if (toolName == DayAgentToolNames.recordObservations) {
        await _handleRecordObservations(args, call.id, manager);
        continue;
      }

      if (DayAgentToolNames.isWorkflowHandlerTool(toolName)) {
        final result = await executeToolHandler(toolName, args, manager);
        if (toolName == DayAgentToolNames.parseCaptureToItems &&
            _didPersistParsedItems(result)) {
          _didPersistCaptureParse = true;
        }
        if (toolName == DayAgentToolNames.draftDayPlan && result.success) {
          _didPersistDraftDayPlan = true;
        }
        manager.addToolResponse(toolCallId: call.id, response: result.output);
        await _recordToolResultMessage(
          toolName: toolName,
          errorMessage: result.success ? null : result.output,
        );
        continue;
      }

      final errorMsg = 'Error: unknown tool "$toolName".';
      manager.addToolResponse(toolCallId: call.id, response: errorMsg);
      await _recordToolResultMessage(
        toolName: toolName,
        errorMessage: errorMsg,
      );
    }

    return ConversationAction.continueConversation;
  }

  bool _didPersistParsedItems(DayAgentToolResult result) {
    if (!result.success) return false;
    try {
      final decoded = jsonDecode(result.output);
      if (decoded is Map) {
        final items = decoded['items'];
        return items is List && items.isNotEmpty;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool shouldContinue(ConversationManager manager) => manager.canContinue();

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    return 'Continue only if you still need to record observations, schedule '
        'the next wake, or finish capture/reconcile tool work. Otherwise '
        'finish with a brief summary.';
  }

  Future<void> _handleRecordObservations(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawList = args['observations'];
    if (rawList is! List || rawList.isEmpty) {
      await _rejectToolCall(
        callId: callId,
        toolName: DayAgentToolNames.recordObservations,
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
        continue;
      }

      if (item is Map<String, dynamic>) {
        final textValue = item['text'];
        final text = textValue is String ? textValue.trim() : '';
        if (text.isEmpty) continue;

        _observations.add(
          ObservationRecord(
            text: text,
            priority: _parseObservationPriority(item['priority']),
            category: _parseObservationCategory(item['category']),
          ),
        );
        accepted++;
      }
    }

    if (accepted == 0) {
      await _rejectToolCall(
        callId: callId,
        toolName: DayAgentToolNames.recordObservations,
        errorMsg: 'Error: no valid observations found.',
        manager: manager,
      );
      return;
    }

    final response = 'Recorded $accepted observation(s).';
    manager.addToolResponse(toolCallId: callId, response: response);
    await _recordToolResultMessage(
      toolName: DayAgentToolNames.recordObservations,
    );
  }

  Future<void> _rejectToolCall({
    required String callId,
    required String toolName,
    required String errorMsg,
    required ConversationManager manager,
  }) async {
    manager.addToolResponse(toolCallId: callId, response: errorMsg);
    await _recordToolResultMessage(
      toolName: toolName,
      errorMessage: errorMsg,
    );
  }

  ObservationPriority _parseObservationPriority(Object? raw) {
    return parseEnumByName(
          ObservationPriority.values,
          raw is String ? raw : null,
        ) ??
        ObservationPriority.routine;
  }

  ObservationCategory _parseObservationCategory(Object? raw) {
    return parseEnumByName(
          ObservationCategory.values,
          raw is String ? raw : null,
        ) ??
        ObservationCategory.operational;
  }

  Map<String, dynamic> _parseToolArguments(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Tool arguments must be a JSON object');
    }
    return decoded.cast<String, dynamic>();
  }

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
    } catch (e, s) {
      _logPersistenceError('assistant/thought', e, s);
    }
  }

  Future<void> _recordActionMessage({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final payloadId = _uuid.v4();
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: clock.now(),
          vectorClock: null,
          content: args,
        ),
      );
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.action,
          createdAt: clock.now(),
          vectorClock: null,
          contentEntryId: payloadId,
          metadata: AgentMessageMetadata(
            runKey: runKey,
            toolName: toolName,
          ),
        ),
      );
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'failed to record day-agent action message '
            'for ${DomainLogger.sanitizeId(agentId)}',
        stackTrace: s,
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
    } catch (e, s) {
      _logPersistenceError('tool-result', e, s);
    }
  }

  void _logPersistenceError(String entityKind, Object error, StackTrace stack) {
    domainLogger.error(
      LogDomain.agentWorkflow,
      error,
      message:
          'failed to record day-agent $entityKind message '
          'for agent=${DomainLogger.sanitizeId(agentId)}, '
          'thread=${DomainLogger.sanitizeId(threadId)}, '
          'run=${DomainLogger.sanitizeId(runKey)}',
      stackTrace: stack,
    );
  }
}
