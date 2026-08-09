import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_progress_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/evaluation/goal_track_policy.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';

/// Workspace key of the recurring deterministic tick (re-armed on every
/// run — recurrence by re-arm, no schema change; ADR 0054 Decision 3).
const goalCadenceWorkspaceKey = 'goal-cadence';

/// Workspace key of the immediate escalation wake Phase A arms when a tick
/// is LLM-worthy; the scheduled-wake manager's lease election picks exactly
/// one device to run it (ADR 0054 Decision 5).
const goalEscalationWorkspaceKey = 'goal-escalation';

/// Local hour at which the daily cadence tick fires.
const goalCadenceHour = 6;

/// How many prior daily register rows feed the grace-period check.
const goalPriorLookbackDays = 3;

/// Phase A of the goal-agent wake (ADR 0054): deterministic, model-free,
/// idempotent — the tier that runs on every tick, on every device, and
/// costs €0.
///
/// One execution: load the spec head → re-arm the cadence wake → read
/// signals → evaluate → derive the track status → upsert the day's
/// `goalProgress` register row → arm an escalation wake if (and only if)
/// something is LLM-worthy. Phase B (PR 3) consumes the escalation; until
/// it lands, an escalation wake firing re-runs this tier, which is a
/// harmless no-op thanks to the keyed register.
class GoalAgentPhaseA {
  const GoalAgentPhaseA({
    required this._repository,
    required this._syncService,
    required this._signalReader,
    this._evaluator = const GoalProgressEvaluator(),
    this._policy = const GoalTrackPolicy(),
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final GoalSignalReader _signalReader;
  final GoalProgressEvaluator _evaluator;
  final GoalTrackPolicy _policy;

  /// The `AgentWakeRunner`-shaped entry point.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();

    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) {
      // No spec yet: nothing to evaluate, nothing to schedule. Not an
      // error — creation writes the spec before the first wake can fire.
      return const WakeResult(success: true);
    }
    final version = await _repository.getEntity(head.versionId);
    if (version is! GoalSpecVersionEntity) {
      return WakeResult(
        success: false,
        error: 'goal spec head ${head.versionId} points at nothing',
      );
    }

    await _rearmCadence(agentId, now);

    final signals = await _signalReader.read(
      criteria: version.criteria,
      reference: now,
      shortTermDays: _policy.shortTermDays,
    );
    final evaluation = _evaluator.evaluate(version.criteria, signals, now);
    final shortTerm = _evaluator.shortTermAttainment(
      version.criteria,
      signals,
      now,
      days: _policy.shortTermDays,
    );

    final priors = await _priorRegisterRows(agentId, now);
    final targetDate = version.targetDate;
    final trackStatus = _policy.derive(
      evaluation: evaluation,
      shortTermAttainment: shortTerm,
      priorAttainments: [for (final row in priors) row.attainment],
      targetDatePassed:
          targetDate != null &&
          GoalWindow.dayUtc(now).isAfter(GoalWindow.dayUtc(targetDate)),
    );

    final facts = GoalWakeFacts(
      trackStatus: trackStatus,
      previousStatus: priors.isEmpty ? null : priors.first.trackStatus,
      evaluation: evaluation,
      shortTermAttainment: shortTerm,
    );

    await _upsertRegister(
      agentId: agentId,
      version: version,
      evaluation: evaluation,
      facts: facts,
      now: now,
    );

    if (facts.needsEscalation) {
      await _armEscalation(agentId, now);
    }

    return const WakeResult(success: true);
  }

  /// Recurrence by re-arm: every run schedules the next cadence tick, and
  /// `GoalRuntimeMaintenance.beforeWakeScan` self-heals a missing record.
  Future<void> _rearmCadence(String agentId, DateTime now) =>
      _syncService.upsertEntity(goalCadenceWake(agentId, now));

  /// Escalation is a scheduled wake due immediately: the manager's lease
  /// election guarantees exactly one device runs it, and an armer that
  /// dies is picked up remotely within the hourly poll (ADR 0054).
  Future<void> _armEscalation(String agentId, DateTime now) =>
      _syncService.upsertEntity(goalEscalationWake(agentId, now));

  /// Most-recent-first register rows for the trailing
  /// [goalPriorLookbackDays] days before the evaluation day.
  Future<List<GoalProgressEntity>> _priorRegisterRows(
    String agentId,
    DateTime now,
  ) async {
    const day = GoalWindow.day();
    final rows = <GoalProgressEntity>[];
    for (var back = 1; back <= goalPriorLookbackDays; back++) {
      final key = day.periodKey(now.subtract(Duration(days: back)));
      final row = await _repository.getEntity(goalProgressId(agentId, key));
      if (row is GoalProgressEntity) rows.add(row);
    }
    return rows;
  }

  /// Recompute-never-accumulate: the day's row is rewritten wholesale, so
  /// N devices evaluating the same day converge on identical content.
  Future<void> _upsertRegister({
    required String agentId,
    required GoalSpecVersionEntity version,
    required GoalEvaluation evaluation,
    required GoalWakeFacts facts,
    required DateTime now,
  }) async {
    final periodKey = const GoalWindow.day().periodKey(now);
    final id = goalProgressId(agentId, periodKey);
    final existing = await _repository.getEntity(id);
    await _syncService.upsertEntity(
      AgentDomainEntity.goalProgress(
        id: id,
        agentId: agentId,
        periodKey: periodKey,
        trackStatus: facts.trackStatus,
        attainment: evaluation.attainment,
        dataCoverage: evaluation.dataCoverage,
        satisfied: evaluation.satisfied,
        specVersionId: version.id,
        createdAt: existing is GoalProgressEntity ? existing.createdAt : now,
        updatedAt: now,
        vectorClock: null,
        criterionResults: [
          for (final result in evaluation.results.values)
            GoalCriterionProgress(
              criterionId: result.criterionId,
              actual: result.actual,
              target: result.target,
              ratio: result.ratio,
              satisfied: result.satisfied,
              sampleCount: result.sampleCount,
              paceFeasible: result.paceFeasible,
            ),
        ],
        paceFeasible: evaluation.paceFeasible,
        shortTermAttainment: facts.shortTermAttainment,
      ),
    );
  }
}

/// The next cadence tick for [agentId] as of [now]: today at
/// [goalCadenceHour] local if still ahead, else tomorrow. Deterministic id
/// → re-arming overwrites (LWW) instead of accumulating.
AgentDomainEntity goalCadenceWake(String agentId, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, goalCadenceHour);
  final next = now.isBefore(today) ? today : today.add(const Duration(days: 1));
  return AgentDomainEntity.scheduledWake(
    id: scheduledWakeRecordId(agentId, workspaceKey: goalCadenceWorkspaceKey),
    agentId: agentId,
    scheduledAt: next,
    status: ScheduledWakeStatus.pending,
    reason: WakeReason.scheduled.name,
    updatedAt: now,
    vectorClock: null,
    workspaceKey: goalCadenceWorkspaceKey,
  );
}

/// An escalation wake due immediately (see `_armEscalation`).
AgentDomainEntity goalEscalationWake(String agentId, DateTime now) =>
    AgentDomainEntity.scheduledWake(
      id: scheduledWakeRecordId(
        agentId,
        workspaceKey: goalEscalationWorkspaceKey,
      ),
      agentId: agentId,
      scheduledAt: now,
      status: ScheduledWakeStatus.pending,
      reason: WakeReason.scheduled.name,
      updatedAt: now,
      vectorClock: null,
      workspaceKey: goalEscalationWorkspaceKey,
    );
