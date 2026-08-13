import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_progress_models.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
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
    this._onEscalationArmed,
    this._onReportStale,
  });

  /// Nudges the scheduled-wake manager after an escalation is armed, so a
  /// local transition is processed promptly instead of waiting out the
  /// hourly poll. Sync-received records still ride the poll (by design).
  final void Function()? _onEscalationArmed;

  /// Advances the durable report-stale watermark when a tick's derivation
  /// materially differs from today's already-persisted register — new
  /// evidence arrived after the standing report was written, so the agent
  /// is dirty even when the coarse status did not transition.
  final void Function(String agentId)? _onReportStale;

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

    final startDate = version.startDate;
    if (startDate != null &&
        GoalWindow.dayUtc(now).isBefore(GoalWindow.dayUtc(startDate))) {
      // The goal has not begun: no register row, no escalation — the
      // cadence tick above keeps checking until the start day arrives.
      // The deadline/superseded sweep still runs (there is no derivation
      // to compare digests against).
      await _expireStaleNudges(agentId, now, activeVersionId: version.id);
      return const WakeResult(success: true);
    }

    final derivation = await deriveWakeFacts(
      agentId: agentId,
      version: version,
      now: now,
      includeCategoryTimeSessions: false,
    );
    final facts = derivation.facts;
    // The sweep runs AFTER derivation so an active banner minted from
    // evidence that has since changed (a new measurement, a habit
    // check-off) is recognized as data-stale. Only ad-eligible goals
    // expire on a digest mismatch: the same eligibility guarantees the
    // escalation below replaces the copy instead of leaving the goal
    // silently bannerless.
    final replacementEligible = automaticGoalAdEligible(
      facts,
      derivation.priors,
    );
    final activeAdExpired = await _expireStaleNudges(
      agentId,
      now,
      activeVersionId: version.id,
      currentFactsDigest: replacementEligible ? goalFactsDigest(facts) : null,
    );
    final needsEscalation =
        facts.needsEscalation || (activeAdExpired && replacementEligible);

    // New evidence after today's earlier tick means the standing report
    // now describes an outdated picture — record the dirty state durably
    // so the detail page shows the out-of-date badge and Update now CTA.
    // A first tick of the day is not "new data" (the window slid), and a
    // status transition already escalates to a fresh report.
    final registerChanged =
        derivation.existingToday != null &&
        goalRegisterDigest(derivation.existingToday!) != goalFactsDigest(facts);

    final persisted = await persistDerivation(
      agentId: agentId,
      derivation: derivation,
      now: now,
      armEscalation: needsEscalation,
    );
    if (persisted && registerChanged) {
      _onReportStale?.call(agentId);
    }
    if (needsEscalation && persisted) {
      _onEscalationArmed?.call();
    }

    return const WakeResult(success: true);
  }

  /// Persists one already-derived deterministic register snapshot.
  ///
  /// The explicit report-refresh path uses this without arming another Phase
  /// B wake, so **Update now** advances health/register surfaces from the same
  /// evidence snapshot that its prose report describes. Returns false when a
  /// concurrent revision or deletion fences the write.
  Future<bool> persistDerivation({
    required String agentId,
    required GoalWakeDerivation derivation,
    required DateTime now,
    bool armEscalation = false,
  }) async {
    var fenced = false;
    await _syncService.runInTransaction(() async {
      // A revision committing after derivation must fence BOTH writes: an old
      // register would overwrite today's row under the new spec, and an old
      // escalation would arm Phase B after the revision sweep already ran.
      final headNow = await _repository.getEntity(goalSpecHeadId(agentId));
      if (headNow is! GoalSpecHeadEntity ||
          headNow.versionId != derivation.version.id) {
        fenced = true;
        return;
      }
      await _upsertRegister(
        agentId: agentId,
        version: derivation.version,
        evaluation: derivation.facts.evaluation,
        facts: derivation.facts,
        now: now,
        periodKey: derivation.periodKey,
        existing: derivation.existingToday,
      );
      if (armEscalation) {
        await _armEscalation(
          agentId,
          now,
          derivation.periodKey,
          derivation.facts.previousStatus,
        );
      }
    });
    return !fenced;
  }

  /// The render-side staleness filter hides an overdue ad immediately,
  /// but the ROW must record the clock's terminal verdict too — else it
  /// sits `active` forever, out of terminal history, and every later
  /// wake re-reads it as a live ad. Deterministic and idempotent:
  /// `expiredAt` is the deadline itself (not this device's wall clock),
  /// and the resolver's terminal dominance makes concurrent sweeps
  /// converge.
  ///
  /// When [currentFactsDigest] is provided, an active banner whose stamped
  /// `factsDigest` provenance no longer matches the current derivation is
  /// expired as data-stale even before its 72 h deadline — the caller only
  /// passes a digest when the goal qualifies for automatic replacement
  /// copy, so this never strips a banner that will not be re-minted.
  /// Banners minted before digests existed carry no stamp and keep the
  /// deadline-only behavior.
  Future<bool> _expireStaleNudges(
    String agentId,
    DateTime now, {
    required String activeVersionId,
    String? currentFactsDigest,
  }) async {
    var activeAdExpired = false;
    // Read and write in ONE transaction: a dismissal landing between a
    // pre-read and the expiry write would be erased by the stale
    // snapshot — and a same-host overwrite carries a newer vector clock,
    // so the concurrent resolver could never recover the quiet-window
    // verdict.
    await _syncService.runInTransaction(() async {
      // Re-read the head HERE: a revision committing after this wake's
      // version load would otherwise make the sweep judge a fresh
      // new-spec banner as foreign and terminally supersede it.
      final headNow = await _repository.getEntity(goalSpecHeadId(agentId));
      if (headNow is GoalSpecHeadEntity &&
          headNow.versionId != activeVersionId) {
        return;
      }
      final nudges = (await _repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      )).whereType<GoalNudgeEntity>();
      for (final nudge in nudges) {
        if (nudge.deletedAt != null || nudge.status != GoalNudgeStatus.active) {
          continue;
        }
        // A banner that synced in AFTER the revision sweep carries the
        // superseded spec in its provenance — sweep it here, the same
        // deterministic maintenance that expires overdue rows. Only when
        // its origin version is PRESENT and itself superseded: partial
        // sync can deliver a NEW spec's banner before that spec's head,
        // and terminally superseding valid copy would be unrecoverable
        // (the provider already hides mismatches until the head lands).
        final originVersion = nudge.provenance['specVersionId'];
        if (originVersion is String && originVersion != activeVersionId) {
          final origin = await _repository.getEntity(originVersion);
          if (origin is GoalSpecVersionEntity &&
              origin.status == GoalSpecVersionStatus.superseded) {
            await _syncService.upsertEntity(
              nudge.copyWith(
                status: GoalNudgeStatus.superseded,
                supersededAt: now.toUtc(),
                updatedAt: now,
              ),
            );
          }
          continue;
        }
        final staleAt = nudge.staleAt;
        final deadlinePassed = staleAt != null && !staleAt.isAfter(now);
        final stampedDigest = nudge.provenance['factsDigest'];
        // Same-day banners are exempt from digest expiry: their automatic
        // replacement would collide with the day's creation id in Phase B
        // and be skipped, leaving the goal bannerless — and one automatic
        // banner per day is the respectful ceiling regardless.
        final activatedDay = GoalWindow.dayUtc(
          nudge.activatedAt ?? nudge.createdAt,
        );
        final dataStale =
            currentFactsDigest != null &&
            stampedDigest is String &&
            stampedDigest != currentFactsDigest &&
            activatedDay.isBefore(GoalWindow.dayUtc(now));
        if (!deadlinePassed && !dataStale) continue;
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: GoalNudgeStatus.expired,
            // Deadline expiry keeps the deterministic deadline timestamp;
            // data-stale expiry records the sweep instant that observed
            // the changed evidence.
            expiredAt: (deadlinePassed ? staleAt : now).toUtc(),
            updatedAt: now,
          ),
        );
        activeAdExpired = true;
      }
    });
    return activeAdExpired;
  }

  /// One deterministic derivation pass: signals → evaluation → policy →
  /// transition facts. Shared by [execute] (which persists the register
  /// and arms escalation from it) and by Phase B's FACTS renderer, so the
  /// two tiers can never disagree about what the wake is about.
  Future<GoalWakeDerivation> deriveWakeFacts({
    required String agentId,
    required GoalSpecVersionEntity version,
    required DateTime now,
    bool includeCategoryTimeSessions = true,
    DateTime? categorySessionEvidenceStart,
    DateTime? categoryTimeEndExclusive,
  }) async {
    final signals = await _signalReader.read(
      criteria: version.criteria,
      reference: now,
      shortTermDays: _policy.shortTermDays,
      includeCategoryTimeSessions: includeCategoryTimeSessions,
      categorySessionEvidenceStart: categorySessionEvidenceStart,
      categoryTimeEndExclusive: categoryTimeEndExclusive,
    );
    final evaluation = _evaluator.evaluate(version.criteria, signals, now);
    final shortTerm = _evaluator.shortTermAttainment(
      version.criteria,
      signals,
      now,
      days: _policy.shortTermDays,
    );

    final periodKey = const GoalWindow.day().periodKey(now);
    final existingToday = await _repository.getEntity(
      goalProgressId(agentId, periodKey),
    );
    final priors = await _priorRegisterRows(agentId, now, version.id);
    final targetDate = version.targetDate;
    final trackStatus = _policy.derive(
      evaluation: evaluation,
      shortTermAttainment: shortTerm,
      priorAttainments: [for (final row in priors) row.attainment],
      targetDatePassed:
          targetDate != null &&
          GoalWindow.dayUtc(now).isAfter(GoalWindow.dayUtc(targetDate)),
    );

    // The transition compares against the LAST PERSISTED status — today's
    // own earlier run first (so an escalation wake re-running Phase A the
    // same day is the documented no-op), yesterday's row otherwise.
    final previousStatus = existingToday is GoalProgressEntity
        ? existingToday.trackStatus
        : priors.isEmpty
        ? null
        : priors.first.trackStatus;
    return GoalWakeDerivation(
      version: version,
      facts: GoalWakeFacts(
        trackStatus: trackStatus,
        previousStatus: previousStatus,
        evaluation: evaluation,
        shortTermAttainment: shortTerm,
        categoryTimeSessionsByCategory: signals.categoryTimeSessionsByCategory,
        categoryTimeEvidenceStart: signals.categoryTimeEvidenceStart,
        categoryTimeEvidenceEnd: signals.categoryTimeEvidenceEnd,
        hasActiveCategoryTimer: signals.hasActiveCategoryTimer,
      ),
      periodKey: periodKey,
      priors: priors,
      existingToday: existingToday is GoalProgressEntity ? existingToday : null,
    );
  }

  /// Recurrence by re-arm: every run schedules the next cadence tick, and
  /// `GoalRuntimeMaintenance.beforeWakeScan` self-heals a missing record.
  Future<void> _rearmCadence(String agentId, DateTime now) =>
      _syncService.upsertEntity(goalCadenceWake(agentId, now));

  /// Escalation is a scheduled wake due immediately: the manager's lease
  /// election guarantees exactly one device runs it, and an armer that
  /// dies is picked up remotely within the hourly poll (ADR 0054).
  Future<void> _armEscalation(
    String agentId,
    DateTime now,
    String periodKey,
    GoalTrackStatus? previousStatus,
  ) => _syncService.upsertEntity(
    goalEscalationWake(agentId, now, periodKey, baseline: previousStatus),
  );

  /// Most-recent-first register rows for the trailing
  /// [goalPriorLookbackDays] days before the evaluation day.
  ///
  /// The policy reads these as a CONSECUTIVE streak, so collection stops
  /// at the first gap (a day the app never evaluated must not compact an
  /// older bad day into "yesterday") and at the first row computed
  /// against a different spec version (a revised goal starts its grace
  /// history fresh). Date math is calendar-component arithmetic — a
  /// Duration would drift across DST transitions.
  Future<List<GoalProgressEntity>> _priorRegisterRows(
    String agentId,
    DateTime now,
    String specVersionId,
  ) async {
    const day = GoalWindow.day();
    final rows = <GoalProgressEntity>[];
    for (var back = 1; back <= goalPriorLookbackDays; back++) {
      final key = day.periodKey(
        DateTime(now.year, now.month, now.day - back),
      );
      final row = await _repository.getEntity(goalProgressId(agentId, key));
      if (row is! GoalProgressEntity) break;
      if (row.specVersionId != specVersionId) break;
      rows.add(row);
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
    required String periodKey,
    required GoalProgressEntity? existing,
  }) async {
    final id = goalProgressId(agentId, periodKey);
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
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        // Carry the row we read: dropping it would make this recompute
        // causally CONCURRENT with the peer value it is based on, letting
        // wall-clock LWW revert fresh progress.
        vectorClock: existing?.vectorClock,
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
        deficit: evaluation.deficit,
        buffer: evaluation.buffer,
      ),
    );
  }
}

/// The next cadence tick for [agentId] as of [now]: today at
/// [goalCadenceHour] local if still ahead, else tomorrow. Deterministic id
/// → re-arming overwrites (LWW) instead of accumulating.
AgentDomainEntity goalCadenceWake(String agentId, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, goalCadenceHour);
  // Calendar components, not a Duration: adding 24 elapsed hours across a
  // DST transition would shift the fixed local cadence hour.
  final next = now.isBefore(today)
      ? today
      : DateTime(now.year, now.month, now.day + 1, goalCadenceHour);
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

/// An escalation wake due immediately, scoped to its evaluation period
/// (see `_armEscalation`).
///
/// The deadline is DERIVED FROM THE PERIOD (its UTC day key), not from
/// the arming instant: every device arming the same logical
/// `(agentId, periodKey)` escalation must write an identical deadline.
/// A wall-clock `now` would differ per device, and the scheduled-wake
/// concurrent resolver prefers the later deadline as a newer wake window
/// — letting a partitioned peer's pending copy resurrect an escalation
/// another device already consumed. Midnight UTC is always in the past
/// for the day being evaluated, so the wake is immediately due.
AgentDomainEntity goalEscalationWake(
  String agentId,
  DateTime now,
  String periodKey, {
  GoalTrackStatus? baseline,
}) => AgentDomainEntity.scheduledWake(
  id: scheduledWakeRecordId(
    agentId,
    workspaceKey: goalEscalationWorkspaceKey(periodKey),
  ),
  agentId: agentId,
  scheduledAt: GoalWindow.dayUtc(now),
  status: ScheduledWakeStatus.pending,
  reason: WakeReason.scheduled.name,
  updatedAt: now,
  vectorClock: null,
  workspaceKey: goalEscalationWorkspaceKey(periodKey),
  // The workspace key doubles as a trigger token: the runner signature
  // carries no workspaceKey, so this token is how the wake router knows
  // to enter Phase B (the day agent's `digest:` prefix precedent). The
  // baseline token carries the PRE-transition status — Phase A's own
  // register write hides it from any later re-derivation.
  triggerTokens: [
    goalEscalationWorkspaceKey(periodKey),
    if (baseline != null) goalEscalationBaselineToken(baseline.name),
  ],
);
