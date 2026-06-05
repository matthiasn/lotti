import 'dart:convert';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/services/domain_logging.dart';

/// Reconstructs a wake's full prompt from a v2 prompt record (ADR 0020):
/// `head + <re-derived log block> + tail`, where the log block is the
/// checkpoint pinned by the record's marker plus the visible events up to its
/// boundary — a pure function of the synced log, so it never needed storing.
///
/// Inline events are re-derived generically: resolved proposal verdicts (when
/// the agent has a task link) and submitted day captures — agents that lack
/// one kind simply contribute none. Retractions are append-only, not
/// suppressing: a later retraction does not redact earlier content from a
/// reconstruction (it renders as its own marker line when inside the
/// boundary). A reconstruction
/// reflects the CONVERGED log: a late-synced event with a position inside the
/// boundary appears even though the original device had not seen it —
/// semantically auditable rather than forensically byte-exact.
class WakePromptReconstructor {
  /// Creates the reconstructor over the agent log.
  WakePromptReconstructor({required this.syncService, this.domainLogger});

  /// Repository access (reads only).
  final AgentSyncService syncService;

  /// Optional structured logger.
  final DomainLogger? domainLogger;

  AgentRepository get _repository => syncService.repository;

  /// Reconstructs the full prompt text for a payload [content] persisted by
  /// a wake of [agentId]. Returns null when [content] is not a v2 prompt
  /// record (callers fall back to the legacy `text` field).
  Future<String?> reconstruct({
    required String agentId,
    required Map<String, Object?> content,
  }) async {
    final record = decodePromptRecord(content);
    if (record == null) return null;

    final inlineEvents = <InputEvent>[
      ...await _decisionEvents(agentId),
      ...await _captureEvents(agentId),
    ];

    final compactor = AgentLogCompactor(
      syncService: syncService,
      inlineEvents: inlineEvents,
    );
    final log = await compactor.assembleContextAsOf(
      agentId,
      summaryId: record.summaryId,
      until: record.until,
    );

    return switch (record.wrap) {
      promptRecordWrapDayLogJsonLine =>
        '${record.head}  "dayLog": ${jsonEncode(log)},\n${record.tail}',
      _ => record.head + log + record.tail,
    };
  }

  Future<List<InputEvent>> _decisionEvents(String agentId) async {
    try {
      final taskLinks = await _repository.getLinksFrom(
        agentId,
        type: AgentLinkTypes.agentTask,
      );
      if (taskLinks.isEmpty) return const [];
      final ledger = await _repository.getProposalLedger(
        agentId,
        taskId: taskLinks.first.toId,
        resolvedLimit: TaskAgentWorkflow.resolvedDecisionWindow,
      );
      return decisionEventsFromLedger(ledger.resolved);
    } catch (e) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message: 'prompt reconstruction: decision events unavailable',
      );
      return const [];
    }
  }

  Future<List<InputEvent>> _captureEvents(String agentId) async {
    try {
      final captures = await _repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.capture,
      );
      return dayCaptureEvents(captures.whereType<CaptureEntity>());
    } catch (e) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message: 'prompt reconstruction: capture events unavailable',
      );
      return const [];
    }
  }
}
