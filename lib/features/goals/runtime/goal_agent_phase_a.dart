import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_progress_models.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/notification_producer.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/evaluation/goal_track_policy.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';

/// Local hour at which the daily cadence tick fires.
const goalCadenceHour = 6;

/// How far after a consumed escalation the next one of the same period is
/// due. Any positive step orders the windows in the concurrent resolver;
/// a millisecond keeps the serialized deadline in the same three-digit
/// form every other one has.
const goalEscalationWindowStep = Duration(milliseconds: 1);

/// How many prior daily register rows feed the grace-period check.
const goalPriorLookbackDays = 3;

/// What the off-track alert needs from the goal: the agent the alert is
/// linked to and routed by, and the title its copy names.
typedef GoalOffTrackSubject = ({String agentId, String goalTitle});

/// The OS-alert seam (ADR 0073): the shared producer contract, bound to the
/// goal's subject and its wake derivation.
///
/// Named here, next to the derivation it consumes, so the dependency runs one
/// way: `GoalOffTrackAlertService` implements this and imports Phase A, while
/// Phase A stays unaware of `features/notifications` entirely. `arm` is
/// called on the tick whose status transitioned into a slip; `clearFor` on
/// one that transitioned out of it, and when the goal is deleted.
typedef GoalOffTrackSink =
    NotificationEpisodeSink<GoalOffTrackSubject, GoalWakeDerivation>;

/// What [GoalAgentPhaseA.persistDerivation] did with a derivation.
enum GoalPersistOutcome {
  /// The register (and any escalation) was written.
  persisted,

  /// A spec revision or deletion committed since the derivation read the
  /// head; the revision's own tick judges again.
  fenced,

  /// The day's register row or today's report changed since the derivation
  /// read them — a peer's row synced in mid-run, or a report was published.
  /// Writing would build on state this derivation never saw; derive again
  /// instead.
  stale,
}

/// How often one Phase A run re-derives after its register moved under it
/// before it leaves the write to the next trigger.
const goalPersistAttempts = 3;

/// The Phase A run in flight for each goal on this device.
///
/// Process-wide on purpose: the wake orchestrator, the sync dispatcher and
/// Phase B's report refresh each hold their own [GoalAgentPhaseA] path into
/// the same register, and they must take turns on one device.
final _exclusiveRuns = <String, Future<void>>{};

/// Phase A of the goal-agent wake (ADR 0054): deterministic, model-free,
/// idempotent — the tier that runs on every tick, on every device, and
/// costs €0.
///
/// One execution: load the spec head → re-arm the cadence wake → read
/// signals → evaluate → derive the track status → upsert the day's
/// `goalProgress` register row → mark the report stale and queue a coalesced
/// refresh if something is LLM-worthy. The deferred refresh re-enters this
/// tier to arm the synced, lease-elected Phase B wake.
class GoalAgentPhaseA {
  const GoalAgentPhaseA({
    required this._repository,
    required this._syncService,
    required this._signalReader,
    this._evaluator = const GoalProgressEvaluator(),
    this._policy = const GoalTrackPolicy(),
    this._onEscalationArmed,
    this._onReportStale,
    this._onReportRefreshNeeded,
    this._offTrackAlerts,
  });

  /// Projects a status transition onto the OS alert channel — see
  /// [_projectOffTrackAlert]. Optional so the tier keeps working, and stays
  /// testable, without the notification stack.
  final GoalOffTrackSink? _offTrackAlerts;

  /// Nudges the scheduled-wake manager after an escalation is armed, so a
  /// local transition is processed promptly instead of waiting out the
  /// hourly poll. Sync-received records still ride the poll (by design).
  final void Function()? _onEscalationArmed;

  /// Advances the durable report-stale watermark when a tick's derivation
  /// materially differs from today's already-persisted register — new
  /// evidence arrived after the standing report was written, so the agent
  /// is dirty even when the coarse status did not transition.
  final Future<void> Function(String agentId)? _onReportStale;

  /// Queues the expensive report refresh behind the shared agent countdown.
  /// Phase A has already persisted current progress when this fires.
  final Future<void> Function(String agentId)? _onReportRefreshNeeded;

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final GoalSignalReader _signalReader;
  final GoalProgressEvaluator _evaluator;
  final GoalTrackPolicy _policy;

  /// Runs [body] once no other derive-and-persist for [agentId] is in
  /// flight on this device, and holds every later one back until it ends.
  ///
  /// A run derives from the journal, then re-reads the register as the base
  /// of its write, so that write dominates whatever it read. Two interleaved
  /// runs let the one that derived FIRST commit LAST: a sync-triggered run
  /// commits a fresh check-off, then a local run that read the journal
  /// before it lands on top, and nothing re-triggers — the day's row settles
  /// without the check-off on every device (`specs/tla/GoalRegister.tla`,
  /// `Lock = "none"`). Taking turns makes each derivation see every earlier
  /// commit.
  static Future<T> runExclusive<T>(
    String agentId,
    Future<T> Function() body,
  ) async {
    final previous = _exclusiveRuns[agentId];
    final done = Completer<void>();
    final mine = done.future;
    _exclusiveRuns[agentId] = mine;
    try {
      if (previous != null) await previous;
      return await body();
    } finally {
      done.complete();
      _exclusiveRuns.removeWhere(
        (key, run) => key == agentId && identical(run, mine),
      );
    }
  }

  /// The `AgentWakeRunner`-shaped entry point. Runs exclusively per goal
  /// ([runExclusive]).
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) => runExclusive(
    agentIdentity.agentId,
    () => _execute(agentIdentity: agentIdentity, triggerTokens: triggerTokens),
  );

  Future<WakeResult> _execute({
    required AgentIdentityEntity agentIdentity,
    required Set<String> triggerTokens,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();
    final deferredReportRefresh =
        goalDeferredReportRefreshRequested(triggerTokens) &&
        (agentIdentity.config.automaticUpdatesEnabled ?? true);

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

    final automaticUpdates =
        agentIdentity.config.automaticUpdatesEnabled ?? true;
    late GoalWakeDerivation derivation;
    late bool replacementEligible;
    late bool shouldRefreshReport;
    late bool armed;
    var outcome = GoalPersistOutcome.stale;
    for (
      var attempt = 0;
      attempt < goalPersistAttempts && outcome == GoalPersistOutcome.stale;
      attempt++
    ) {
      derivation = await deriveWakeFacts(
        agentId: agentId,
        version: version,
        now: now,
        includeTimeEntryEvidence: false,
      );
      final facts = derivation.facts;
      // The sweep runs AFTER derivation so an active banner minted from
      // evidence that has since changed (a new measurement, a habit
      // check-off) is recognized as data-stale. Only ad-eligible goals
      // expire on a digest mismatch: the same eligibility guarantees the
      // escalation below replaces the copy instead of leaving the goal
      // silently bannerless.
      replacementEligible = automaticGoalAdEligible(
        facts,
        derivation.priors,
      );
      final activeAdExpired = await _expireStaleNudges(
        agentId,
        now,
        activeVersionId: version.id,
        currentFactsDigest: replacementEligible
            ? goalFactsDigest(
                facts,
                criteria: version.criteria,
                evaluationReference: now,
              )
            : null,
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
          goalRegisterDigest(derivation.existingToday!) !=
              goalAggregateFactsDigest(facts);

      shouldRefreshReport = needsEscalation || registerChanged;
      // A status the standing report does not state is armed with the
      // register, in one transaction: the lease-elected wake is synced, so a
      // device that dies after this commit cannot take the escalation with
      // it (`specs/tla/GoalRegister.tla`, ArmAt = "commit"). Evidence that
      // leaves the status alone still coalesces behind the local countdown.
      armed = deferredReportRefresh || (needsEscalation && automaticUpdates);
      outcome = await persistDerivation(
        agentId: agentId,
        derivation: derivation,
        now: now,
        armEscalation: armed,
        forceReportRefresh: armed,
      );
    }
    final persisted = outcome == GoalPersistOutcome.persisted;
    final facts = derivation.facts;
    if (persisted && shouldRefreshReport) {
      await _onReportStale?.call(agentId);
    }
    if (armed && persisted) {
      _onEscalationArmed?.call();
    } else if (shouldRefreshReport && persisted) {
      await _onReportRefreshNeeded?.call(agentId);
    }

    // Deliberately AFTER the transaction, the relationship reminder's
    // ordering: the alert row lives in notifications.sqlite behind its own
    // vector-clock scope and outbox enqueue, and it is a projection of the
    // register this tick just made durable. Only a persisted transition
    // projects — an unchanged slip must not re-alert, and a fenced write
    // means the revision's own tick will judge again.
    if (persisted && facts.statusTransitioned) {
      await _projectOffTrackAlert(
        agentId: agentId,
        goalTitle: version.title,
        derivation: derivation,
        slipped: replacementEligible,
      );
    }

    return const WakeResult(success: true);
  }

  /// A slip arms the alert for its episode — the transition day, so a goal
  /// that stays behind is alerted once per slip — and anything else clears
  /// every open alert for the goal, because "off track" has stopped being
  /// true. Eligibility is the banner's own predicate
  /// (`automaticGoalAdEligible`), so the two channels never disagree about
  /// what a slip is. The sink never throws (its contract), so a
  /// notification-store failure cannot fail the wake that already committed.
  Future<void> _projectOffTrackAlert({
    required String agentId,
    required String goalTitle,
    required GoalWakeDerivation derivation,
    required bool slipped,
  }) async {
    final alerts = _offTrackAlerts;
    if (alerts == null) return;
    if (slipped) {
      await alerts.arm(
        subject: (agentId: agentId, goalTitle: goalTitle),
        derivation: derivation,
      );
    } else {
      await alerts.clearFor(agentId);
    }
  }

  /// Persists one already-derived deterministic register snapshot.
  ///
  /// The explicit report-refresh path uses this without arming another Phase
  /// B wake, so **Update now** advances health/register surfaces from the same
  /// evidence snapshot that its prose report describes.
  ///
  /// A write only ever builds on the row its derivation read: the register
  /// write carries that row's clock, so it dominates it, and a derivation
  /// that read the journal before a peer's row synced in would otherwise
  /// replace that row with an older picture. Such a run reports
  /// [GoalPersistOutcome.stale] and writes nothing (`specs/tla/
  /// GoalRegister.tla`, Validate = "rederive").
  Future<GoalPersistOutcome> persistDerivation({
    required String agentId,
    required GoalWakeDerivation derivation,
    required DateTime now,
    bool armEscalation = false,
    bool forceReportRefresh = false,
  }) async {
    var outcome = GoalPersistOutcome.persisted;
    await _syncService.runInTransaction(() async {
      // A revision committing after derivation must fence BOTH writes: an old
      // register would overwrite today's row under the new spec, and an old
      // escalation would arm Phase B after the revision sweep already ran.
      final headNow = await _repository.getEntity(goalSpecHeadId(agentId));
      if (headNow is! GoalSpecHeadEntity ||
          headNow.versionId != derivation.version.id) {
        outcome = GoalPersistOutcome.fenced;
        return;
      }
      final rowNow = await _repository.getEntity(
        goalProgressId(agentId, derivation.periodKey),
      );
      // The escalation decision read today's report too: one published or
      // synced since would decide it differently.
      if ((rowNow is GoalProgressEntity ? rowNow : null) !=
              derivation.existingToday ||
          await _reportedStatus(
                agentId,
                periodKey: derivation.periodKey,
                versionId: derivation.version.id,
              ) !=
              derivation.facts.reportedStatus) {
        outcome = GoalPersistOutcome.stale;
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
          forceReportRefresh: forceReportRefresh,
        );
      }
    });
    return outcome;
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
        if (nudge.deletedAt != null || nudge.status != NudgeStatus.active) {
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
                status: NudgeStatus.superseded,
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
            status: NudgeStatus.expired,
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
    bool includeTimeEntryEvidence = true,
    DateTime? timeEntryEvidenceStart,
    DateTime? timeEntryEndExclusive,
  }) async {
    final signals = await _signalReader.read(
      criteria: version.criteria,
      reference: now,
      shortTermDays: _policy.shortTermDays,
      includeTimeEntryEvidence: includeTimeEntryEvidence,
      timeEntryEvidenceStart: timeEntryEvidenceStart,
      timeEntryEndExclusive: timeEntryEndExclusive,
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
    final reportedStatus = await _reportedStatus(
      agentId,
      periodKey: periodKey,
      versionId: version.id,
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
        quantitativeObservationsByType: signals.quantitativeObservationsByType,
        categoryTimeSessionsByCategory: signals.categoryTimeSessionsByCategory,
        labelTimeEntriesByCriterion: signals.labelTimeEntriesByCriterion,
        categoryTimeEvidenceStart: signals.categoryTimeEvidenceStart,
        categoryTimeEvidenceEnd: signals.categoryTimeEvidenceEnd,
        labelTimeEvidenceStart: signals.labelTimeEvidenceStart,
        labelTimeEvidenceEnd: signals.labelTimeEvidenceEnd,
        hasActiveCategoryTimer: signals.hasActiveCategoryTimer,
        hasActiveLabelTimer: signals.hasActiveLabelTimer,
        reportedStatus: reportedStatus,
      ),
      periodKey: periodKey,
      priors: priors,
      existingToday: existingToday is GoalProgressEntity ? existingToday : null,
    );
  }

  /// The status today's standing report states for [versionId], or null
  /// when the current report is for another day or spec, or states none.
  Future<GoalTrackStatus?> _reportedStatus(
    String agentId, {
    required String periodKey,
    required String versionId,
  }) async {
    final report = await _repository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    if (report == null ||
        report.provenance['periodKey'] != periodKey ||
        report.provenance['specVersionId'] != versionId) {
      return null;
    }
    final name = report.provenance['trackStatus'];
    return GoalTrackStatus.values
        .where((status) => status.name == name)
        .firstOrNull;
  }

  /// Recurrence by re-arm: every run schedules the next cadence tick, and
  /// `GoalRuntimeMaintenance.beforeWakeScan` self-heals a missing record.
  ///
  /// A record already pending for that tick is left alone: rewriting it
  /// would stamp a new clock and sync a change that is not one.
  Future<void> _rearmCadence(String agentId, DateTime now) async {
    final wake = goalCadenceWake(agentId, now) as ScheduledWakeEntity;
    final existing = await _repository.getEntity(wake.id);
    if (existing is ScheduledWakeEntity &&
        existing.deletedAt == null &&
        existing.status == ScheduledWakeStatus.pending &&
        existing.scheduledAt == wake.scheduledAt) {
      return;
    }
    await _syncService.upsertEntity(wake);
  }

  /// Escalation is a scheduled wake due immediately: the manager's lease
  /// election guarantees exactly one device runs it, and an armer that
  /// dies is picked up remotely within the hourly poll (ADR 0054).
  ///
  /// The record id is per period, so a second escalation the same day
  /// finds the first one's row, and what it writes depends on that row
  /// (ADR 0069, `specs/tla/ScheduledWakeLease.tla`):
  ///
  /// * **Pending** — this escalation has not run yet, so arming again
  ///   joins it. The row is left alone, claim and all; rewriting it would
  ///   drop a peer's lease mid-election and the baseline it carries.
  /// * **Consumed** — this opens the next window. It carries the consumed
  ///   row's vector clock, so it causally follows the consumption, and is
  ///   due one millisecond after it, so it outranks any version of the
  ///   consumed window a peer still holds. A row rebuilt from a null clock
  ///   at the period's fixed instant was concurrent with the peers'
  ///   consumed copy, lost to it everywhere but here, and so ran on the
  ///   arming device only — or on none, if that device died.
  Future<void> _armEscalation(
    String agentId,
    DateTime now,
    String periodKey,
    GoalTrackStatus? previousStatus, {
    bool forceReportRefresh = false,
  }) async {
    final wake =
        goalEscalationWake(
              agentId,
              now,
              periodKey,
              baseline: previousStatus,
              forceReportRefresh: forceReportRefresh,
            )
            as ScheduledWakeEntity;
    final existing = await _repository.getEntity(wake.id);
    if (existing is ScheduledWakeEntity && existing.deletedAt == null) {
      if (existing.status == ScheduledWakeStatus.pending) return;
      await _syncService.upsertEntity(
        wake.copyWith(
          scheduledAt: existing.scheduledAt.add(goalEscalationWindowStep),
          vectorClock: existing.vectorClock,
        ),
      );
      return;
    }
    await _syncService.upsertEntity(wake);
  }

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
    // The derivation's row can be minutes old (a report refresh derives
    // before its inference). Re-read it in this transaction: a same-ordinal
    // twin's row that synced in since would otherwise be judged concurrent
    // with this recompute, and the goal-progress resolver's id order could
    // put the twin's evaluation back (ADR 0068 addendum). A row computed
    // under a NEWER spec ordinal is the next spec arriving before its head:
    // this recompute must not build on it, so the resolver's higher-ordinal
    // rule keeps it here and on every peer.
    final current = await _repository.getEntity(id);
    final row = current is GoalProgressEntity ? current : existing;
    final rowOrdinal = row == null
        ? null
        : specVersionOrdinal(row.specVersionId);
    final base = rowOrdinal != null && rowOrdinal > version.version
        ? null
        : row;
    final next =
        AgentDomainEntity.goalProgress(
              id: id,
              agentId: agentId,
              periodKey: periodKey,
              trackStatus: facts.trackStatus,
              attainment: evaluation.attainment,
              dataCoverage: evaluation.dataCoverage,
              satisfied: evaluation.satisfied,
              specVersionId: version.id,
              createdAt: base?.createdAt ?? now,
              updatedAt: now,
              // Carry the row we read: dropping it would make this recompute
              // causally CONCURRENT with the peer value it is based on, letting
              // wall-clock LWW revert fresh progress.
              vectorClock: base?.vectorClock,
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
            )
            as GoalProgressEntity;
    // Recompute-never-accumulate, and write-only-on-change: a row whose
    // content this run would reproduce exactly is left as it is. Rewriting
    // it would stamp a new clock and sync a change that is not one.
    if (base != null &&
        base.deletedAt == null &&
        next.copyWith(
              createdAt: base.createdAt,
              updatedAt: base.updatedAt,
              vectorClock: base.vectorClock,
            ) ==
            base) {
      return;
    }
    await _syncService.upsertEntity(next);
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
/// for the day being evaluated, so the wake is immediately due. A later
/// escalation of the same period, armed over the consumed one, is due
/// [goalEscalationWindowStep] after it — again the same on every device.
AgentDomainEntity goalEscalationWake(
  String agentId,
  DateTime now,
  String periodKey, {
  GoalTrackStatus? baseline,
  bool forceReportRefresh = false,
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
    if (forceReportRefresh) goalReportRefreshTriggerToken,
  ],
);
