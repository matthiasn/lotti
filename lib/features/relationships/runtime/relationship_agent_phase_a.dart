import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';

/// Local hour at which the daily cadence tick fires — offset from the goal
/// tick (`goalCadenceHour` is 6) so the two families never wake as one
/// morning burst.
const relationshipCadenceHour = 7;

/// The cadence applied when `RelationshipData.checkInCadenceDays` is unset
/// (ADR 0039 Decision 2).
const relationshipDefaultCadenceDays = 30;

/// One deterministic derivation of the cadence facts — shared by
/// [RelationshipAgentPhaseA.execute] (which persists the register and arms
/// the escalation from it) and, in Phase 5, by the LLM tier's facts
/// renderer, so the two tiers can never disagree about what a wake is
/// about.
typedef RelationshipCadenceDerivation = ({
  RelationshipCadenceStatus status,
  RelationshipCadenceStatus? previousStatus,
  int cadenceDays,

  /// UTC — see the normalization note in `deriveCadenceFacts`.
  DateTime referenceAt,

  /// UTC — see the normalization note in `deriveCadenceFacts`.
  DateTime? lastCheckInAt,

  /// UTC calendar day the cadence lapses, as a midnight-UTC instant.
  /// Zone-free by construction — it is the episode key every device must
  /// agree on (see `deriveCadenceFacts`).
  DateTime dueDayUtc,

  /// The workspace-key day component (`2026-08-16`) of [dueDayUtc].
  String dueDayKey,
});

/// Phase A of the relationship-agent wake (ADR 0059 Decision 2, the
/// ADR 0054 deterministic tier): model-free, idempotent, €0 — the tier that
/// runs on every tick, on every device.
///
/// One execution: resolve the watched relationship via the agent link →
/// stop for good when the person is gone → re-arm the daily cadence tick →
/// gate on eligibility (`important`, `active` — the ADR 0039 consent rule) →
/// derive the cadence facts → recompute the ONE `relationshipHealth`
/// register row → arm the per-episode, lease-elected escalation when the
/// cadence NEWLY lapsed. Every write is skipped when it would change
/// nothing, so an uneventful tick is a true no-write no-op.
class RelationshipAgentPhaseA {
  const RelationshipAgentPhaseA({
    required this._repository,
    required this._syncService,
    required this._relationshipRepository,
    this._onEscalationArmed,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final RelationshipRepository _relationshipRepository;

  /// Nudges the scheduled-wake manager after an escalation is armed, so a
  /// local transition is processed promptly instead of waiting out the
  /// hourly poll. Sync-received records still ride the poll (by design).
  final void Function()? _onEscalationArmed;

  /// The `AgentWakeRunner`-shaped entry point.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();

    final relationshipId = await watchedRelationshipId(agentId);
    if (relationshipId == null) {
      // No link yet: creation writes the link before the first wake can
      // fire, so this is a benign race, not an error.
      return const WakeResult(success: true);
    }

    // Unfiltered: a private person's agent must derive the same register on
    // every device, whatever each one's private-entry display preference is.
    final relationship = await _relationshipRepository
        .getRelationshipByIdUnfiltered(relationshipId);
    if (relationship == null || relationship.meta.deletedAt != null) {
      // Terminal: the person is gone. Re-arming here would keep the orphaned
      // agent waking forever when the teardown never ran — a delete through
      // the generic journal path, or one whose best-effort agent leg failed.
      // `RelationshipRuntimeMaintenance.beforeWakeScan` reaps the identity.
      return const WakeResult(success: true);
    }

    await _rearmCadence(agentId, now);

    if (!relationship.data.important ||
        relationship.data.status is! RelationshipActive) {
      // Not tracked: `important` is the single consent switch for
      // proactive behavior, and dormant/archived people are deliberately
      // excluded (ADR 0039 Decision 2). The cadence tick above keeps
      // checking, so flipping the switch needs no re-wiring.
      return const WakeResult(success: true);
    }

    final derivation = await deriveCadenceFacts(
      agentId: agentId,
      relationship: relationship,
      now: now,
    );

    // The briefing is stale when evidence arrived after it was written —
    // one of the escalation facts (ADR 0059 Decision 2: "check-in saved
    // since last report"). Per-episode idempotence bounds this to one
    // briefing per due day: each check-in moves the due day, minting a
    // fresh episode.
    final report = await _repository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final reportStale =
        derivation.lastCheckInAt != null &&
        (report == null || derivation.lastCheckInAt!.isAfter(report.createdAt));

    await _syncService.runInTransaction(() async {
      await _sweepNudges(agentId, derivation, now);
      await _upsertRegister(
        agentId: agentId,
        relationshipId: relationshipId,
        derivation: derivation,
        now: now,
      );
      final newlyDue =
          derivation.status == RelationshipCadenceStatus.due &&
          derivation.previousStatus != RelationshipCadenceStatus.due;
      if (newlyDue) {
        // Per-episode idempotence is the deliberate anti-nag ceiling
        // (ADR 0039): one escalation — one briefing, at most one banner —
        // per due day. An ignored banner expires and the agent stays quiet
        // until a check-in moves the due day and mints a fresh episode.
        final armed = await _armEscalation(
          relationshipEscalationWake(agentId, derivation, updatedAt: now),
        );
        if (armed) _onEscalationArmed?.call();
      } else if (reportStale) {
        // A lapse escalation regenerates the briefing anyway, so the
        // refresh episode arms only when no lapse is arming this tick. Its
        // own episode key: consuming the lapse key early would let
        // per-episode idempotence suppress the real lapse escalation.
        final armed = await _armEscalation(
          relationshipReportRefreshEscalationWake(
            agentId,
            derivation,
            updatedAt: now,
          ),
        );
        if (armed) _onEscalationArmed?.call();
      }
    });

    return const WakeResult(success: true);
  }

  /// Deterministic banner maintenance (the goal Phase A sweep, ADR 0055):
  /// an active banner past its staleAt is terminally EXPIRED (the
  /// render-side filter already hides it, but the row must record the
  /// clock's verdict or every later wake re-reads it as live), and when
  /// the cadence is satisfied again — a check-in landed — the agent
  /// RETIRES its still-active banners rather than letting an obsolete
  /// "check in" chide run out its deadline. Idempotent; read and write in
  /// the caller's transaction so a concurrent dismissal is never clobbered.
  Future<void> _sweepNudges(
    String agentId,
    RelationshipCadenceDerivation derivation,
    DateTime now,
  ) async {
    final nudges = (await _repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.relationshipNudge,
    )).whereType<RelationshipNudgeEntity>();
    for (final nudge in nudges) {
      if (nudge.deletedAt != null || nudge.status != NudgeStatus.active) {
        continue;
      }
      final staleAt = nudge.staleAt;
      if (staleAt != null && !staleAt.isAfter(now)) {
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: NudgeStatus.expired,
            // The deterministic deadline, not this device's wall clock —
            // concurrent sweeps converge (terminal dominance does the rest).
            expiredAt: staleAt.toUtc(),
            updatedAt: now,
          ),
        );
      } else if (derivation.status == RelationshipCadenceStatus.ok) {
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: NudgeStatus.retired,
            retiredAt: now.toUtc(),
            updatedAt: now,
          ),
        );
      }
    }
  }

  /// The relationship this agent watches, via its `agentRelationship` link.
  Future<String?> watchedRelationshipId(String agentId) async {
    final links = await _repository.getLinksFrom(
      agentId,
      type: AgentLinkTypes.agentRelationship,
    );
    return links.isEmpty ? null : links.first.toId;
  }

  /// One deterministic derivation pass over the journal-side truth.
  ///
  /// The check-in read is deliberately NOT display-filtered: a private
  /// check-in still resets the cadence, both because hiding an entry is a
  /// display preference (not a request to be nagged) and because devices
  /// with different display settings must converge on the same register.
  ///
  /// Every derived day is a UTC calendar day for the same convergence
  /// reason — see the comment on the due-day arithmetic below.
  Future<RelationshipCadenceDerivation> deriveCadenceFacts({
    required String agentId,
    required RelationshipEntry relationship,
    required DateTime now,
  }) async {
    final checkIns = await _relationshipRepository
        .getAllCheckInsForRelationship(relationship.meta.id);
    DateTime? lastCheckInAt;
    for (final checkIn in checkIns) {
      final at = checkIn.meta.dateFrom;
      if (lastCheckInAt == null || at.isAfter(lastCheckInAt)) {
        lastCheckInAt = at;
      }
    }
    // Baseline: the newest check-in, or tracking start (ADR 0039 — the
    // first reminder fires one cadence after marking, never suppressed
    // waiting for a first check-in).
    final referenceAt = lastCheckInAt ?? relationship.meta.dateFrom;
    final cadenceDays =
        relationship.data.checkInCadenceDays ?? relationshipDefaultCadenceDays;

    // Calendar-component arithmetic in UTC — never Duration math (which
    // would drift the lapse day across a DST transition) and never the
    // device's local calendar. The due day IS the episode key: two devices
    // in different timezones deriving it from their own calendars would
    // disagree, and the disagreement is not cosmetic — `_upsertRegister`
    // would see a changed `dueAt` on every sync and the two would rewrite
    // the register forever, while `relationshipEscalationWake` would mint
    // one episode per timezone and pay for the same lapse twice. UTC has no
    // DST, so `day + cadenceDays` is exactly that many days later.
    final referenceDayUtc = GoalWindow.dayUtc(referenceAt.toUtc());
    final dueDayUtc = DateTime.utc(
      referenceDayUtc.year,
      referenceDayUtc.month,
      referenceDayUtc.day + cadenceDays,
    );
    final status = GoalWindow.dayUtc(now.toUtc()).isBefore(dueDayUtc)
        ? RelationshipCadenceStatus.ok
        : RelationshipCadenceStatus.due;

    final existing = await _repository.getEntity(relationshipHealthId(agentId));
    // UTC instants, normalized HERE rather than at the write site: the
    // register row rides sync, and a local instant serializes without an
    // offset (`toIso8601String` drops the zone), so a peer would parse a
    // shifted instant. Normalizing in the derivation keeps `_upsertRegister`'s
    // unchanged-check comparing like against like — a round-tripped row and a
    // fresh derivation carry the same isUtc flag.
    return (
      status: status,
      previousStatus: existing is RelationshipHealthEntity
          ? existing.status
          : null,
      cadenceDays: cadenceDays,
      referenceAt: referenceAt.toUtc(),
      lastCheckInAt: lastCheckInAt?.toUtc(),
      dueDayUtc: dueDayUtc,
      dueDayKey: const GoalWindow.day().periodKey(dueDayUtc),
    );
  }

  /// Recompute-never-accumulate: the ONE register row is rewritten
  /// wholesale, so N devices deriving the same facts converge on identical
  /// content — and an unchanged derivation writes nothing at all.
  Future<void> _upsertRegister({
    required String agentId,
    required String relationshipId,
    required RelationshipCadenceDerivation derivation,
    required DateTime now,
  }) async {
    final id = relationshipHealthId(agentId);
    final existing = await _repository.getEntity(id);
    final current = existing is RelationshipHealthEntity ? existing : null;
    final unchanged =
        current != null &&
        current.deletedAt == null &&
        current.relationshipId == relationshipId &&
        current.status == derivation.status &&
        current.cadenceDays == derivation.cadenceDays &&
        current.referenceAt == derivation.referenceAt &&
        current.dueAt == derivation.dueDayUtc &&
        current.lastCheckInAt == derivation.lastCheckInAt;
    if (unchanged) return;
    await _syncService.upsertEntity(
      AgentDomainEntity.relationshipHealth(
        id: id,
        agentId: agentId,
        relationshipId: relationshipId,
        status: derivation.status,
        cadenceDays: derivation.cadenceDays,
        referenceAt: derivation.referenceAt,
        dueAt: derivation.dueDayUtc,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
        // Carry the row we read: dropping it would make this recompute
        // causally CONCURRENT with the peer value it is based on, letting
        // wall-clock LWW revert fresh state.
        vectorClock: current?.vectorClock,
        lastCheckInAt: derivation.lastCheckInAt,
      ),
    );
  }

  /// Recurrence by re-arm: every run schedules the next cadence tick (and
  /// `RelationshipRuntimeMaintenance.beforeWakeScan` self-heals a missing
  /// record). Skipped when the pending record already targets the same
  /// instant, so an uneventful tick stays write-free.
  Future<void> _rearmCadence(String agentId, DateTime now) async {
    final next = relationshipCadenceWake(agentId, now);
    final existing = await _repository.getEntity(next.id);
    if (existing is ScheduledWakeEntity &&
        existing.status == ScheduledWakeStatus.pending &&
        existing.scheduledAt == (next as ScheduledWakeEntity).scheduledAt) {
      return;
    }
    await _syncService.upsertEntity(next);
  }

  /// An escalation is a scheduled wake due immediately: the manager's lease
  /// election guarantees exactly one device runs it, and an armer that
  /// dies is picked up remotely within the hourly poll (ADR 0054). The
  /// per-episode id makes arming idempotent — a consumed episode is never
  /// re-armed by a later tick of the same episode. Returns whether a new
  /// record was written.
  Future<bool> _armEscalation(AgentDomainEntity wake) async {
    if (await _repository.getEntity(wake.id) != null) return false;
    await _syncService.upsertEntity(wake);
    return true;
  }
}

/// The next cadence tick for [agentId] as of [now]: today at
/// [relationshipCadenceHour] local if still ahead, else tomorrow.
/// Deterministic id → re-arming overwrites (LWW) instead of accumulating.
AgentDomainEntity relationshipCadenceWake(String agentId, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, relationshipCadenceHour);
  // Calendar components, not a Duration: adding 24 elapsed hours across a
  // DST transition would shift the fixed local cadence hour.
  final next = now.isBefore(today)
      ? today
      : DateTime(now.year, now.month, now.day + 1, relationshipCadenceHour);
  return AgentDomainEntity.scheduledWake(
    id: scheduledWakeRecordId(
      agentId,
      workspaceKey: relationshipCadenceWorkspaceKey,
    ),
    agentId: agentId,
    scheduledAt: next,
    status: ScheduledWakeStatus.pending,
    reason: WakeReason.scheduled.name,
    updatedAt: now,
    vectorClock: null,
    workspaceKey: relationshipCadenceWorkspaceKey,
  );
}

/// The cadence-lapse escalation wake, due immediately, scoped to its
/// episode.
///
/// The deadline is DERIVED FROM THE EPISODE (the due day's UTC key), not
/// from the arming instant: every device arming the same logical
/// `(agentId, dueDayKey)` escalation must write an identical deadline, or
/// the scheduled-wake resolver would let a partitioned peer's later copy
/// resurrect an escalation another device already consumed (the goal
/// precedent). Armed only on the newly-due transition, so the due day is
/// never in the future and the wake is immediately due — a stale briefing
/// inside the cadence arms [relationshipReportRefreshEscalationWake]
/// instead.
AgentDomainEntity relationshipEscalationWake(
  String agentId,
  RelationshipCadenceDerivation derivation, {
  required DateTime updatedAt,
}) => AgentDomainEntity.scheduledWake(
  id: scheduledWakeRecordId(
    agentId,
    workspaceKey: relationshipEscalationWorkspaceKey(derivation.dueDayKey),
  ),
  agentId: agentId,
  scheduledAt: derivation.dueDayUtc,
  status: ScheduledWakeStatus.pending,
  reason: WakeReason.scheduled.name,
  updatedAt: updatedAt,
  vectorClock: null,
  workspaceKey: relationshipEscalationWorkspaceKey(derivation.dueDayKey),
  // The workspace key doubles as a trigger token: the runner signature
  // carries no workspaceKey, so this token is how the wake router will
  // enter the LLM tier (Phase 5). The baseline token carries the
  // PRE-transition status — Phase A's own register write hides it from
  // any later re-derivation.
  triggerTokens: [
    relationshipEscalationWorkspaceKey(derivation.dueDayKey),
    if (derivation.previousStatus != null)
      relationshipEscalationBaselineToken(derivation.previousStatus!.name),
  ],
);

/// The report-refresh escalation wake — armed when a check-in landed after
/// the current briefing was written (ADR 0059 Decision 2's "check-in saved
/// since the last report" fact), due immediately.
///
/// The deadline is the newest check-in's own instant: synced journal
/// truth, so every device arming for the same evidence writes an
/// identical, already-past deadline (the same resolver argument as the
/// lapse episode's due-day deadline). The episode key is scoped to that
/// check-in's UTC day, bounding the spend to one refresh per day of new
/// evidence; a same-day follow-up check-in re-derives into the consumed
/// episode and waits for the next day or the next lapse.
AgentDomainEntity relationshipReportRefreshEscalationWake(
  String agentId,
  RelationshipCadenceDerivation derivation, {
  required DateTime updatedAt,
}) {
  final lastCheckInAt = derivation.lastCheckInAt!;
  final workspaceKey = relationshipReportRefreshEscalationWorkspaceKey(
    _utcDayKey(lastCheckInAt),
  );
  return AgentDomainEntity.scheduledWake(
    id: scheduledWakeRecordId(agentId, workspaceKey: workspaceKey),
    agentId: agentId,
    scheduledAt: lastCheckInAt.toUtc(),
    status: ScheduledWakeStatus.pending,
    reason: WakeReason.scheduled.name,
    updatedAt: updatedAt,
    vectorClock: null,
    workspaceKey: workspaceKey,
    triggerTokens: [
      workspaceKey,
      if (derivation.previousStatus != null)
        relationshipEscalationBaselineToken(derivation.previousStatus!.name),
    ],
  );
}

/// The UTC calendar day of [instant] as a `yyyy-MM-dd` key — deliberately
/// UTC, never local: the key must be identical on devices in different
/// timezones.
String _utcDayKey(DateTime instant) {
  final utc = instant.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}
