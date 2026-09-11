import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_message_recording.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/agents/workflow/project_proposal_reconciler.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';

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
class ProjectAgentStrategy extends ConversationStrategy
    with ObservationRecordParsing, AgentMessageRecording {
  ProjectAgentStrategy({
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    this.projectId,
    this.currentProjectStatus,
    this.retractionService,
  });

  /// Sync-aware write service for persisting messages.
  @override
  final AgentSyncService syncService;

  /// The agent's stable ID.
  @override
  final String agentId;

  /// The conversation thread ID for the current wake.
  @override
  final String threadId;

  /// The run key for the current wake cycle.
  @override
  final String runKey;

  /// The project this wake is about. Required for `retract_suggestions`,
  /// which addresses change sets by their target entity.
  final String? projectId;

  /// The project's status at wake start. When supplied, an
  /// `update_project_status` call that would change nothing is refused with an
  /// explanation instead of being queued — the model learns inside the wake,
  /// and the band never grows a row that does nothing when applied.
  final ProjectStatus? currentProjectStatus;

  /// Withdraws the agent's own open proposals. `null` leaves
  /// `retract_suggestions` unwired, and a call to it reports that.
  final SuggestionRetractionService? retractionService;

  final _stagedRetractions = <StagedRetraction>[];
  final _stagedRetractionKeys = <String>{};

  String? _reportContent;
  String? _reportTldr;
  String? _reportOneLiner;
  String? _reportHealthBand;
  String? _reportHealthRationale;
  double? _reportHealthConfidence;
  String? _finalResponse;
  final _observations = <ObservationRecord>[];
  final _deferredItems = <Map<String, dynamic>>[];

  @override
  Future<ConversationAction> processToolCalls({
    required List<LottiToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    // Persist the assistant message that requested tool calls.
    await recordAssistantMessage();

    for (final call in toolCalls) {
      final toolName = call.name;

      Map<String, dynamic> args;
      try {
        args = parseAgentToolArguments(call.arguments);
      } catch (e) {
        final rawBytes = utf8.encode(call.arguments).length;
        developer.log(
          'Failed to parse tool call arguments for $toolName '
          '(rawBytes=$rawBytes, errorType=${e.runtimeType})',
          name: 'ProjectAgentStrategy',
        );
        final errorMsg =
            'Error: invalid arguments format — expected a JSON object. '
            'Detail: ${e.runtimeType}';
        manager.addToolResponse(toolCallId: call.id, response: errorMsg);
        await recordToolResultMessage(
          toolName: toolName,
          errorMessage: errorMsg,
        );
        continue;
      }

      await recordActionMessage(toolName: toolName);

      if (toolName == ProjectAgentToolNames.updateProjectReport) {
        await _handleUpdateReport(args, call.id, manager);
        continue;
      }

      if (toolName == ProjectAgentToolNames.recordObservations) {
        await _handleRecordObservations(args, call.id, manager);
        continue;
      }

      if (toolName == ProjectAgentToolNames.retractSuggestions) {
        await _handleRetractSuggestions(args, call.id, manager);
        continue;
      }

      // Deferred tools: accumulate for later persistence.
      if (projectDeferredTools.contains(toolName)) {
        // A status the project already has is not queued: applying it is a
        // no-op, so the row would sit in the band forever doing nothing.
        // Telling the model now also stops it burning the next turn
        // re-proposing the same thing.
        //
        // Reported as an ordinary tool result, not an error — the guard
        // working is not a failure, and `errorMessage` renders in the agent's
        // activity log in the error colour. The task agent reports its own
        // redundancy checks the same way (`ChangeProposalFilter`).
        final status = currentProjectStatus;
        if (toolName == ProjectAgentToolNames.updateProjectStatus &&
            status != null &&
            projectStatusProposalIsRedundant(current: status, args: args)) {
          manager.addToolResponse(
            toolCallId: call.id,
            response:
                'Skipped: the project is already ${status.label}, so this '
                'would change nothing. Do not propose it again.',
          );
          await recordToolResultMessage(toolName: toolName);
          continue;
        }
        _deferredItems.add({
          'toolName': toolName,
          // Canonicalized here, where the model's word enters: a status alias
          // renders and applies as its canonical status, so storing the alias
          // would make two identical-looking proposals compare as different
          // everywhere downstream.
          'args': normalizeProjectProposalArgs(toolName, args),
        });
        final response = 'Queued $toolName for user review.';
        manager.addToolResponse(toolCallId: call.id, response: response);
        await recordToolResultMessage(toolName: toolName);
        continue;
      }

      // Unknown tool — tell the LLM.
      final errorMsg = 'Error: unknown tool "$toolName".';
      manager.addToolResponse(toolCallId: call.id, response: errorMsg);
      await recordToolResultMessage(
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

  /// Extracts the one-liner published via `update_project_report`.
  String? extractReportOneLiner() => _reportOneLiner;

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

  /// The retractions this wake staged, for the workflow to apply at the end
  /// of the wake — in the same transaction as the new proposals, so the band
  /// never reads empty between a withdrawal and its replacement.
  List<StagedRetraction> extractStagedRetractions() =>
      List.unmodifiable(_stagedRetractions);

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
    final rawOneLiner = args[ProjectAgentReportToolArgs.oneLiner];
    final oneLiner = (rawOneLiner is String && rawOneLiner.trim().isNotEmpty)
        ? rawOneLiner.trim()
        : null;
    final healthBandValue = args[ProjectAgentReportToolArgs.healthBand];
    final healthBand = healthBandValue is String ? healthBandValue.trim() : '';
    final healthRationaleValue =
        args[ProjectAgentReportToolArgs.healthRationale];
    final healthRationale = healthRationaleValue is String
        ? healthRationaleValue.trim()
        : '';
    final healthConfidence = parseHealthConfidence(
      args[ProjectAgentReportToolArgs.healthConfidence],
    );

    final validations = [
      (
        markdown.isEmpty,
        'Error: "markdown" field is required and must not be empty.',
      ),
      (
        tldr == null || tldr.isEmpty,
        'Error: "tldr" field is required and must not be empty.',
      ),
      (
        !ProjectAgentHealthBandValues.values.contains(healthBand),
        'Error: "health_band" is required and must be one of '
            '`surviving`, `on_track`, `watch`, `at_risk`, or `blocked`.',
      ),
      (
        healthRationale.isEmpty,
        'Error: "health_rationale" field is required and must not be empty.',
      ),
      (
        args.containsKey(ProjectAgentReportToolArgs.healthConfidence) &&
            healthConfidence == null,
        'Error: "health_confidence" must be a number between 0 and 1.',
      ),
    ];

    for (final (failed, errorMsg) in validations) {
      if (failed) {
        await _rejectToolCall(
          callId: callId,
          toolName: ProjectAgentToolNames.updateProjectReport,
          errorMsg: errorMsg,
          manager: manager,
        );
        return;
      }
    }

    _reportContent = markdown;
    _reportTldr = tldr;
    _reportOneLiner = oneLiner;
    _reportHealthBand = healthBand;
    _reportHealthRationale = healthRationale;
    _reportHealthConfidence = healthConfidence;

    manager.addToolResponse(
      toolCallId: callId,
      response: 'Report updated successfully.',
    );
    await recordToolResultMessage(
      toolName: ProjectAgentToolNames.updateProjectReport,
    );
  }

  // ── Retraction handling ────────────────────────────────────────────────────

  /// Handles `retract_suggestions`: validates the requested fingerprints
  /// against the project's open proposals, stages the matches for end-of-wake
  /// application, and reports the per-entry outcome back to the model.
  ///
  /// Nothing is written here. Staging until the end of the wake is what keeps
  /// the "Proposed changes" band from flashing empty between a withdrawal and
  /// the replacement this same wake is about to propose.
  Future<void> _handleRetractSuggestions(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final service = retractionService;
    final targetId = projectId;
    if (service == null || targetId == null) {
      await _rejectToolCall(
        callId: callId,
        toolName: ProjectAgentToolNames.retractSuggestions,
        errorMsg: 'Error: retract_suggestions is not wired up for this agent.',
        manager: manager,
      );
      return;
    }

    final rawProposals = args['proposals'];
    if (rawProposals is! List || rawProposals.isEmpty) {
      await _rejectToolCall(
        callId: callId,
        toolName: ProjectAgentToolNames.retractSuggestions,
        errorMsg:
            'Error: "proposals" must be a non-empty array of '
            '{fingerprint, reason} objects.',
        manager: manager,
      );
      return;
    }

    final requests = <RetractionRequest>[];
    final parseErrors = <String>[];
    for (var i = 0; i < rawProposals.length; i++) {
      final entry = rawProposals[i];
      if (entry is! Map) {
        parseErrors.add('proposals[$i] is not an object');
        continue;
      }
      final fingerprint = entry['fingerprint'];
      final reason = entry['reason'];
      if (fingerprint is! String || fingerprint.trim().isEmpty) {
        parseErrors.add('proposals[$i].fingerprint missing or empty');
        continue;
      }
      if (reason is! String || reason.trim().isEmpty) {
        parseErrors.add('proposals[$i].reason missing or empty');
        continue;
      }
      requests.add(
        RetractionRequest(
          fingerprint: fingerprint.trim(),
          reason: reason.trim(),
        ),
      );
    }

    if (requests.isEmpty) {
      await _rejectToolCall(
        callId: callId,
        toolName: ProjectAgentToolNames.retractSuggestions,
        errorMsg:
            'Error: no valid proposals to retract. ${parseErrors.join('; ')}',
        manager: manager,
      );
      return;
    }

    // `plan` reads the pending change sets and the proposal ledger. A failed
    // read must not take the wake down with it: retraction is the least
    // valuable thing a wake produces, and losing the report, the
    // observations and the next steps with it would be wildly
    // disproportionate — the same reason the workflow's own ledger read is
    // non-fatal. Report it and let the conversation continue.
    final RetractionPlan plan;
    try {
      plan = await service.plan(
        agentId: agentId,
        taskId: targetId,
        requests: requests,
        alreadyStagedKeys: _stagedRetractionKeys,
      );
    } catch (e) {
      developer.log(
        'retract_suggestions could not read open proposals '
        '(errorType=${e.runtimeType})',
        name: 'ProjectAgentStrategy',
      );
      await _rejectToolCall(
        callId: callId,
        toolName: ProjectAgentToolNames.retractSuggestions,
        errorMsg:
            'Error: your open proposals could not be read, so nothing was '
            'retracted. Continue without retracting.',
        manager: manager,
      );
      return;
    }
    for (final retraction in plan.staged) {
      _stagedRetractions.add(retraction);
      _stagedRetractionKeys.add(retraction.key);
    }

    final response = StringBuffer('Retraction results:');
    for (final result in plan.results) {
      final label = switch (result.outcome) {
        RetractionOutcome.retracted => 'retracted',
        RetractionOutcome.notOpen => 'not_open (already resolved)',
        RetractionOutcome.notFound => 'not_found',
      };
      final summary = result.humanSummary?.trim();
      final detail = (summary != null && summary.isNotEmpty)
          ? ' — "$summary"'
          : (result.toolName != null ? ' — ${result.toolName}' : '');
      response.writeln('\n- [fp=${result.fingerprint}] $label$detail');
    }
    if (parseErrors.isNotEmpty) {
      response
        ..writeln()
        ..writeln('Skipped malformed entries: ${parseErrors.join('; ')}');
    }

    manager.addToolResponse(
      toolCallId: callId,
      response: response.toString().trim(),
    );
    await recordToolResultMessage(
      toolName: ProjectAgentToolNames.retractSuggestions,
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
        toolName: ProjectAgentToolNames.recordObservations,
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
    await recordToolResultMessage(
      toolName: ProjectAgentToolNames.recordObservations,
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
    await recordToolResultMessage(toolName: toolName, errorMessage: errorMsg);
  }
}
