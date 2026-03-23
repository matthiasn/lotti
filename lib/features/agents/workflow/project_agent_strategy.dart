import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// [ConversationStrategy] implementation for the Project Agent.
///
/// Handles two immediate tools locally:
/// - `update_project_report` — accumulates the project report markdown.
/// - `record_observations` — accumulates private observation notes.
///
/// Deferred tools (`recommend_next_steps`, `update_project_status`,
/// `create_task`) are accumulated as JSON entries for later persistence
/// and user review.
///
/// Each message is persisted to `agent.sqlite` as an [AgentMessageEntity].
class ProjectAgentStrategy extends ConversationStrategy {
  ProjectAgentStrategy({
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.projectId,
  });

  /// Sync-aware write service for persisting messages.
  final AgentSyncService syncService;

  /// The agent's stable ID.
  final String agentId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

  /// The project entity ID this agent is working on.
  final String projectId;

  String? _reportContent;
  String? _reportTldr;
  String? _reportHealthBand;
  String? _reportHealthRationale;
  double? _reportHealthConfidence;
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
        args = _parseToolArguments(call.function.arguments);
      } catch (e) {
        developer.log(
          'Failed to parse tool call arguments for $toolName: $e',
          name: 'ProjectAgentStrategy',
        );
        final errorMsg =
            'Error: invalid arguments format — expected a JSON object. '
            'Detail: $e';
        manager.addToolResponse(toolCallId: call.id, response: errorMsg);
        await _recordToolResultMessage(
          toolName: toolName,
          errorMessage: errorMsg,
        );
        continue;
      }

      await _recordActionMessage(toolName: toolName, args: args);

      if (toolName == ProjectAgentToolNames.updateProjectReport) {
        await _handleUpdateReport(args, call.id, manager);
        continue;
      }

      if (toolName == ProjectAgentToolNames.recordObservations) {
        await _handleRecordObservations(args, call.id, manager);
        continue;
      }

      // Deferred tools: accumulate for later persistence.
      if (projectDeferredTools.contains(toolName)) {
        _deferredItems.add({
          'toolName': toolName,
          'args': args,
        });
        final response = 'Queued $toolName for user review.';
        manager.addToolResponse(toolCallId: call.id, response: response);
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
    return 'Continue. If you have finished your analysis, call '
        '`update_project_report` with the full updated report.';
  }

  /// Called by the workflow after the conversation loop finishes.
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) {
      _finalResponse = content;
    }
  }

  /// Returns the final assistant text response for thought persistence.
  String? get finalResponse => _finalResponse;

  /// Extracts the report content published via `update_project_report`.
  String extractReportContent() => _reportContent ?? '';

  /// Extracts the TLDR published via `update_project_report`.
  String? extractReportTldr() => _reportTldr;

  /// Extracts the health band published via `update_project_report`.
  String? extractReportHealthBand() => _reportHealthBand;

  /// Extracts the health rationale published via `update_project_report`.
  String? extractReportHealthRationale() => _reportHealthRationale;

  /// Extracts the optional health confidence from `update_project_report`.
  double? extractReportHealthConfidence() => _reportHealthConfidence;

  /// Returns observations accumulated from `record_observations` calls.
  List<ObservationRecord> extractObservations() =>
      List.unmodifiable(_observations);

  /// Returns deferred tool items accumulated during the conversation.
  List<Map<String, dynamic>> extractDeferredItems() =>
      List.unmodifiable(_deferredItems);

  // ── Report handling ────────────────────────────────────────────────────────

  Future<void> _handleUpdateReport(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final markdownValue = args[ProjectAgentReportToolArgs.markdown];
    final markdown = markdownValue is String ? markdownValue.trim() : '';
    final tldrValue = args[ProjectAgentReportToolArgs.tldr];
    final tldr = tldrValue is String ? tldrValue.trim() : null;
    final healthBandValue = args[ProjectAgentReportToolArgs.healthBand];
    final healthBand = healthBandValue is String ? healthBandValue.trim() : '';
    final healthRationaleValue =
        args[ProjectAgentReportToolArgs.healthRationale];
    final healthRationale = healthRationaleValue is String
        ? healthRationaleValue.trim()
        : '';
    final healthConfidence = _parseHealthConfidence(
      args[ProjectAgentReportToolArgs.healthConfidence],
    );

    if (markdown.isEmpty) {
      const errorMsg =
          'Error: "markdown" field is required and must not '
          'be empty.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: ProjectAgentToolNames.updateProjectReport,
        errorMessage: errorMsg,
      );
      return;
    }

    if (tldr == null || tldr.isEmpty) {
      const errorMsg =
          'Error: "tldr" field is required and must not '
          'be empty.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: ProjectAgentToolNames.updateProjectReport,
        errorMessage: errorMsg,
      );
      return;
    }

    if (!ProjectAgentHealthBandValues.values.contains(healthBand)) {
      const errorMsg =
          'Error: "health_band" is required and must be one of '
          '`surviving`, `on_track`, `watch`, `at_risk`, or `blocked`.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: ProjectAgentToolNames.updateProjectReport,
        errorMessage: errorMsg,
      );
      return;
    }

    if (healthRationale.isEmpty) {
      const errorMsg =
          'Error: "health_rationale" field is required and must not '
          'be empty.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: ProjectAgentToolNames.updateProjectReport,
        errorMessage: errorMsg,
      );
      return;
    }

    if (args.containsKey(ProjectAgentReportToolArgs.healthConfidence) &&
        healthConfidence == null) {
      const errorMsg =
          'Error: "health_confidence" must be a number between 0 and 1.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: ProjectAgentToolNames.updateProjectReport,
        errorMessage: errorMsg,
      );
      return;
    }

    _reportContent = markdown;
    _reportTldr = tldr;
    _reportHealthBand = healthBand;
    _reportHealthRationale = healthRationale;
    _reportHealthConfidence = healthConfidence;

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Report updated successfully.',
    );
    await _recordToolResultMessage(
      toolName: ProjectAgentToolNames.updateProjectReport,
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
      const errorMsg = 'Error: "observations" must be a non-empty array.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: ProjectAgentToolNames.recordObservations,
        errorMessage: errorMsg,
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

        final priority = _parseObservationPriority(
          item['priority'] is String ? item['priority'] as String : null,
        );
        final category = _parseObservationCategory(
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
      toolName: ProjectAgentToolNames.recordObservations,
    );
  }

  double? _parseHealthConfidence(Object? value) {
    if (value == null) return null;
    final parsed = switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text.trim()),
      _ => null,
    };
    if (parsed == null || parsed < 0 || parsed > 1) return null;
    return parsed;
  }

  ObservationPriority _parseObservationPriority(String? raw) {
    if (raw == null) return ObservationPriority.routine;
    final normalized = raw.trim().toLowerCase();
    for (final value in ObservationPriority.values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    return ObservationPriority.routine;
  }

  ObservationCategory _parseObservationCategory(String? raw) {
    if (raw == null) return ObservationCategory.operational;
    final normalized = raw.trim().replaceAll('_', '').toLowerCase();
    for (final value in ObservationCategory.values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    return ObservationCategory.operational;
  }

  // ── JSON argument parsing ──────────────────────────────────────────────────

  Map<String, dynamic> _parseToolArguments(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '{}') return {};

    // Try direct parse first.
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // Handle markdown-wrapped JSON.
    final markdownRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = markdownRegex.firstMatch(trimmed);
    if (match != null) {
      final inner = match.group(1)!.trim();
      final decoded = jsonDecode(inner);
      if (decoded is Map<String, dynamic>) return decoded;
    }

    throw FormatException('Cannot parse tool arguments: $trimmed');
  }

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
        'Failed to persist assistant message: $e',
        name: 'ProjectAgentStrategy',
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
        'Failed to persist action message: $e',
        name: 'ProjectAgentStrategy',
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
        'Failed to persist tool result message: $e',
        name: 'ProjectAgentStrategy',
      );
    }
  }
}
