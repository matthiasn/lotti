import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';

/// What one logical check sequence has already acted on, so its coalesced
/// re-runs and an in-flight restart handoff do not act on the same row twice.
///
/// Scoped to the sequence, not the manager: later independent checks must
/// re-read genuinely due rows, while a restart arriving before the old pass
/// releases the single-flight guard is still part of that pass's handoff.
class _HandledCheckSequence {
  final agentIds = <String>{};
  final recordIds = <String>{};
}

/// Manages scheduled wakes for agents that need to wake on a time-based
/// schedule (e.g., daily project digests, weekly one-on-one rituals).
///
/// On startup and then hourly, queries for agents with overdue
/// `scheduledWakeAt`. Dormant project agents (no pending activity since
/// last report) are fast-forwarded to the next future time slot without
/// executing, avoiding unnecessary LLM calls after prolonged app absence.
/// Non-project agents (e.g., improver agents) are always enqueued.
class ScheduledWakeManager with AgentErrorLogging {
  ScheduledWakeManager({
    required this._repository,
    required this._orchestrator,
    required this._syncService,
    this.checkInterval = const Duration(hours: 1),
    this.domainLogger,
    this.onPersistedStateChanged,
    this.requiresLease,
    this.localHostId,
    this.beforeCheck,
    this.leaseSettle = const Duration(minutes: 3),
    this.leaseDuration = const Duration(minutes: 30),
  });

  final AgentRepository _repository;
  final WakeOrchestrator _orchestrator;
  final AgentSyncService _syncService;
  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;
  final void Function(String agentId)? onPersistedStateChanged;

  final Duration checkInterval;

  /// Whether a due record's work must run on exactly one device.
  ///
  /// Most scheduled wakes are device-local and every device firing its own is
  /// correct. A few are not: the coordinator's morning digest is one shared
  /// record whose work produces the same output whichever device runs it, so N
  /// devices firing it means N inferences billed for one result.
  final bool Function(ScheduledWakeEntity record)? requiresLease;

  /// This device's sync host id — the claimant identity written into a lease.
  ///
  /// Leasing is skipped when this is absent, which keeps every existing caller
  /// on the unleased path. It is also skipped when the lookup yields null: a
  /// device with no sync host has no peers to race, so firing is correct and
  /// blocking would mean never running the digest at all.
  final Future<String?> Function()? localHostId;

  /// Repair work that must precede every due-record pass, not just the first.
  ///
  /// Retiring finished day agents is the caller this exists for: retirement
  /// decides which identities may still wake, so running it after a pass would
  /// let a day agent fire on the very tick that was about to retire it. Wiring
  /// it here rather than only at start-up is what covers a session left open
  /// across the handover boundary — the boundary arrives on a tick, and the
  /// tick now retires before it fires.
  ///
  /// A failure is logged and the pass continues: stale retirement costs a
  /// wake, but skipping the pass would strand every genuinely due record.
  final Future<void> Function()? beforeCheck;

  /// How long a claimant waits before confirming its claim.
  ///
  /// The wait is what makes the election work: the record is a last-write-wins
  /// register, so concurrent claims converge to one surviving host, and a
  /// claimant only proceeds if the survivor is still itself. It must exceed
  /// normal sync propagation; a few minutes at 06:00 costs nobody anything.
  final Duration leaseSettle;

  /// How long a claim stands before any device may take it over. Must exceed
  /// [leaseSettle], or a claim would lapse before it could be confirmed.
  final Duration leaseDuration;

  Timer? _timer;
  Timer? _settleTimer;

  /// Incremented by [stop]. A check that was already in flight — awaiting the
  /// host lookup or the claim write — compares against this before arming or
  /// running a settle timer, so a stopped manager cannot resurrect itself and
  /// race a restarted one for the same digest.
  int _generation = 0;
  bool _isChecking = false;

  /// Set when a trigger arrives while a pass is already running, so that pass
  /// runs once more instead of the trigger being lost. See [_checkAndEnqueue].
  bool _rerunRequested = false;

  /// The generation [_rerunRequested] was raised under. A request from a newer
  /// generation belongs to a restarted manager, not to the pass in flight.
  int _rerunGeneration = 0;

  /// Runs one scan pass now (single-flighted with the periodic timer).
  ///
  /// For callers that just persisted an immediately-due record — e.g. a
  /// goal Phase A arming an escalation — and must not wait out the hourly
  /// poll on the arming device.
  void requestCheck() {
    unawaited(_checkAndEnqueue());
  }

  /// Start periodic checking. Also immediately checks for missed wakes.
  void start() {
    unawaited(_checkAndEnqueue());

    _timer?.cancel();
    _timer = Timer.periodic(checkInterval, (_) {
      unawaited(_checkAndEnqueue());
    });

    _log('started (interval: ${checkInterval.inMinutes}min)');
  }

  /// Stop periodic checking.
  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    _log('stopped');
  }

  /// Arms a one-shot re-check [delay] from now, unless the manager was stopped
  /// while the caller was awaiting.
  ///
  /// The periodic tick is hourly, so every branch that returns "not yet" owes
  /// the record a wake-up of its own — otherwise a 06:00 digest waits for the
  /// 07:00 tick.
  void _scheduleRecheck(Duration delay, int generation) {
    if (generation != _generation) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (generation != _generation) return;
      unawaited(_checkAndEnqueue());
    });
  }

  /// Runs a due-record pass, coalescing any trigger that arrives during it.
  ///
  /// Dropping the overlapping trigger would lose it outright: the re-checks
  /// armed by [_scheduleRecheck] are one-shot timers, so a foreign lease
  /// expiring while another pass is in flight would wait for the next hourly
  /// tick before any device could take it over. Re-running once afterwards
  /// costs one extra query and answers every trigger, however many arrived.
  ///
  /// The re-run re-reads everything and skips only what this invocation has
  /// already acted on. It has to re-read: the wake clears `scheduledWakeAt`
  /// and the record flips to `consumed`, and neither has necessarily landed
  /// when the re-run starts — a consume-write can even have failed outright.
  /// Acting twice would be billed twice, because `enqueueManualWake`
  /// supersedes only work still queued, not a run already under way. Skipping
  /// the whole path instead of the handled rows would lose a state that became
  /// due *during* a long pass, which is the case the re-run exists for.
  Future<void> _checkAndEnqueue([
    _HandledCheckSequence? inheritedHandled,
  ]) async {
    if (_isChecking) {
      _rerunRequested = true;
      _rerunGeneration = _generation;
      return;
    }
    _isChecking = true;
    final entryGeneration = _generation;
    final handled = inheritedHandled ?? _HandledCheckSequence();
    try {
      do {
        _rerunRequested = false;
        await _runPass(handled);
        // A `stop()` during the pass ends the schedule this loop belongs to;
        // anything raised since then is the next generation's business.
      } while (_rerunRequested && _generation == entryGeneration);
    } finally {
      _isChecking = false;
      // A trigger from a *newer* generation is a restart's immediate check
      // arriving while this pass was still winding down. Dropping it would
      // leave the restarted manager waiting a full interval for its first
      // scan, so hand it to a fresh invocation now that the guard is clear.
      final restarted = _rerunRequested && _rerunGeneration == _generation;
      _rerunRequested = false;
      if (restarted) unawaited(_checkAndEnqueue(handled));
    }
  }

  Future<void> _runPass(_HandledCheckSequence handled) async {
    // Captured before the first await: `stop()` may land while this pass is
    // waiting on the repository, the host lookup or the claim write, and the
    // continuation must not then arm a timer the stop could never cancel.
    final generation = _generation;
    try {
      final before = beforeCheck;
      if (before != null) {
        final startedOn = clock.now();
        await _runPreCheck(before);
        // The repair keys on the calendar day — retirement's handover cutoff
        // does — while the due query below uses a `now` read after it. A pass
        // that starts just before local midnight and finishes the repair just
        // after would decide those two on different days, leaving an agent
        // active for exactly the pass that should have retired it. Repeating
        // the repair under the new day is cheaper than reasoning about it.
        if (!_sameLocalDay(startedOn, clock.now())) {
          await _runPreCheck(before);
        }
      }
      // A `stop()` that landed while the pre-check was awaiting ends this
      // pass here. Its replacement manager owns the schedule now, and a
      // disposed pass that kept going would enqueue against it.
      if (generation != _generation) return;
      // Read after the pre-check: it can await sync writes, and a `now`
      // captured before them would age across the pass it is meant to time.
      final now = clock.now();
      final dueStates = await _repository.getDueScheduledAgentStates(now);
      if (generation != _generation) return;

      var enqueued = 0;
      var fastForwarded = 0;
      var skippedArchived = 0;

      for (final state in dueStates) {
        // Re-checked per item: each iteration awaits the identity lookup and
        // its own writes, so a `stop()` can land mid-loop.
        if (generation != _generation) return;
        // Already acted on by an earlier pass of this same invocation; the
        // wake it enqueued has not necessarily cleared `scheduledWakeAt` yet.
        // Marked before the work, not after: a partial failure must not let a
        // re-run enqueue the same agent again. It stays due for the next
        // invocation.
        if (!handled.agentIds.add(state.agentId)) continue;
        try {
          // Defense-in-depth (ADR 0022): the due query filters on
          // `scheduledWakeAt` only — not lifecycle — so an archived or missing
          // identity could still surface here. An archived agent must never
          // wake, and clearing its stale `scheduledWakeAt` self-heals the
          // legacy-migration gap where a peer that never ran the migration
          // (e.g. a never-synced local `day_agent`) kept a live wake that would
          // otherwise re-fire and fail every cycle.
          if (!await _isActiveAgent(state.agentId)) {
            await _clearStaleScheduledWake(state, now);
            skippedArchived++;
            continue;
          }

          if (_canFastForward(state)) {
            await _fastForwardSchedule(state, now);
            fastForwarded++;
            continue;
          }

          _orchestrator.enqueueManualWake(
            agentId: state.agentId,
            reason: WakeReason.scheduled.name,
          );
          enqueued++;
        } catch (e, s) {
          logError(
            'failed to process ${DomainLogger.sanitizeId(state.agentId)}',
            error: e,
            stackTrace: s,
          );
        }
      }

      final recordsEnqueued = await _processDueRecords(
        now,
        generation,
        handled,
      );

      if (dueStates.isNotEmpty || recordsEnqueued > 0) {
        _log(
          'processed ${dueStates.length} due agents: '
          '$enqueued enqueued, $fastForwarded fast-forwarded, '
          '$skippedArchived archived skipped; '
          '$recordsEnqueued scheduled-wake record(s) fired',
        );
      }
    } catch (e, s) {
      logError('error checking scheduled wakes', error: e, stackTrace: s);
    }
  }

  /// Runs [before], logging a failure rather than aborting the pass: stale
  /// repair costs a wake, while skipping the pass strands every due record.
  Future<void> _runPreCheck(Future<void> Function() before) async {
    try {
      await before();
    } catch (e, s) {
      logError(
        'pre-check repair failed; continuing with the due-record pass',
        error: e,
        stackTrace: s,
      );
    }
  }

  static bool _sameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Fire pending [ScheduledWakeEntity] records that are due (ADR 0022).
  ///
  /// Each record carries its own workspace key and trigger tokens, so the
  /// enqueued wake restores full day context — unlike the context-less
  /// `scheduledWakeAt` path. After enqueuing, the record is flipped to
  /// [ScheduledWakeStatus.consumed] in place (not hard-deleted) so a
  /// concurrent device's flip converges via LWW instead of resurrecting it.
  Future<int> _processDueRecords(
    DateTime now,
    int generation,
    _HandledCheckSequence handled,
  ) async {
    final dueRecords = await _repository.getDueScheduledWakeRecords(now);
    var enqueued = 0;
    for (final record in dueRecords) {
      // As in the due-states loop: a `stop()` can land while this loop awaits
      // the identity lookup, the host lookup or the claim write.
      if (generation != _generation) return enqueued;
      // Skipped only once this invocation has *acted* on it. A record the
      // lease deferred armed a one-shot re-check, and that timer is precisely
      // what the coalesced re-run is answering — marking it here would make
      // the re-run skip the record it was woken for, so confirmation or
      // takeover would wait for the next hourly tick.
      if (handled.recordIds.contains(record.id)) continue;
      try {
        // Same guard as the due-*states* loop above, and for the same reason:
        // `getDueScheduledWakeRecords` filters on the deadline, not lifecycle.
        // A retired per-day agent still holding a `set_next_wake` record would
        // otherwise keep firing — the record path is the one per-day agents
        // actually use for pre-warms, so without this retirement does nothing.
        final identity = await _repository.getEntity(record.agentId);
        if (identity == null) {
          // Not "inactive" — *unknown*. Sync can deliver a wake record before
          // the identity it belongs to, and consuming is terminal, so a
          // record that arrived first would be destroyed rather than delayed.
          // Leave it pending; it fires once the identity lands.
          continue;
        }
        final lifecycle = identity.mapOrNull(agent: (e) => e.lifecycle);
        if (lifecycle != AgentLifecycle.active) {
          handled.recordIds.add(record.id);
          await _consumeStaleWakeRecord(record, now);
          continue;
        }
        final approved = await _leaseApprovedRecord(record, generation);
        if (approved == null) continue;
        // `stop()` can land while the lease check is awaiting the host lookup.
        // Firing afterwards would enqueue through a disposed manager, and if
        // the provider has already rebuilt one, both instances would fire the
        // same record — the duplicate the lease exists to prevent.
        if (generation != _generation) continue;
        // Re-read before firing. `_holdsLease` awaits the host lookup, and
        // sync can apply a `consumed` version in that window — on a
        // cold-start reconnect especially. The concurrent resolver already
        // ran when that version landed, so the in-memory `record` is simply
        // stale, and firing from it bills a second digest for a window the
        // database already says is finished.
        // Ownership too, not just status: a peer's crossing claim leaves the
        // record pending while moving `leaseHostId` or the deadline, and
        // firing on that would be this device acting on a lease it lost.
        final current = await _repository.getEntity(record.id);
        if (current is ScheduledWakeEntity &&
            (current.status != ScheduledWakeStatus.pending ||
                current.leaseHostId != approved.leaseHostId ||
                current.leaseUntil != approved.leaseUntil ||
                !current.scheduledAt.isAtSameMomentAs(approved.scheduledAt))) {
          continue;
        }
        // Marked before the enqueue, not after: if the consume-write below
        // fails the record is still pending, and a re-run microseconds later
        // would fire it a second time — a transient write error must not
        // become a second billed wake. It stays due for the next invocation.
        handled.recordIds.add(record.id);
        // The pass-level `now` can age across due-state processing, lease
        // settlement, and repository reads. Stamp when this record actually
        // reaches the enqueue boundary so recovery assigns it to the day whose
        // digest the executor will produce, including a pass crossing midnight.
        final firedAt = clock.now();
        _orchestrator.enqueueManualWake(
          agentId: record.agentId,
          reason: record.reason,
          triggerTokens: record.triggerTokens.toSet(),
          workspaceKey: record.workspaceKey,
        );
        await _syncService.upsertEntity(
          record.copyWith(
            status: ScheduledWakeStatus.consumed,
            consumedAt: firedAt,
            updatedAt: firedAt,
          ),
        );
        onPersistedStateChanged?.call(record.agentId);
        enqueued++;
      } catch (e, s) {
        logError(
          'failed to fire scheduled-wake record '
          '${DomainLogger.sanitizeId(record.id)}',
          error: e,
          stackTrace: s,
        );
      }
    }
    return enqueued;
  }

  /// The record this device may fire now, or null when it may not.
  ///
  /// Always true for the ordinary device-local records. For a leased record it
  /// runs one round of claim–settle–confirm:
  ///
  /// ```mermaid
  /// stateDiagram-v2
  ///   [*] --> Unclaimed: record due
  ///   Unclaimed --> Claimed: write leaseHostId = me
  ///   Claimed --> Claimed: settle not elapsed — wait
  ///   Claimed --> Fires: survivor is me after the settle
  ///   Claimed --> Skips: survivor is another host
  ///   Claimed --> Unclaimed: leaseUntil passed — claimant went away
  ///   Fires --> [*]: record consumed, every device stops
  /// ```
  ///
  /// The claim is a write to one synced last-write-wins register, so crossing
  /// claims converge to a single surviving host — that convergence is the
  /// election, and no separate coordinator is needed. Confirming after
  /// [leaseSettle] rather than immediately is what gives that convergence time
  /// to happen. A lease that lapses without the record being consumed is a
  /// claimant that crashed or went offline, and any device may take over, so a
  /// window is delayed rather than lost.
  /// Takes no `now`: the clock is read *after* the repository and host
  /// lookups, since either can stall across `leaseUntil` and a value captured
  /// before them would approve an already-expired claim.
  Future<ScheduledWakeEntity?> _leaseApprovedRecord(
    ScheduledWakeEntity due,
    int generation,
  ) async {
    final needsLease = requiresLease?.call(due) ?? false;
    final hostIdOf = localHostId;
    if (!needsLease || hostIdOf == null) return due;

    final hostId = await hostIdOf();
    if (hostId == null) return due;

    // Re-read after the host lookup: sync can apply a crossing claim, a
    // `consumed` version, or the next window's re-arm while that await is
    // outstanding. Deciding — or worse, writing a claim — from the snapshot
    // the due query returned would overwrite a newer local row with older
    // lease fields.
    final refreshed = await _repository.getEntity(due.id);
    if (refreshed is! ScheduledWakeEntity) return null;
    if (refreshed.status != ScheduledWakeStatus.pending) return null;
    if (!refreshed.scheduledAt.isAtSameMomentAs(due.scheduledAt)) return null;
    final record = refreshed;

    final at = clock.now();

    final until = record.leaseUntil;
    final held = until != null && until.isAfter(at);

    if (held && record.leaseHostId != hostId) {
      _log(
        'digest lease held elsewhere for '
        '${DomainLogger.sanitizeId(record.id)}',
      );
      // Take over the moment the foreign lease lapses. Without this, a
      // claimant that crashed would hold the window until the next hourly
      // tick — up to an hour late on top of the 30-minute lease.
      _scheduleRecheck(until.difference(at), generation);
      return null;
    }
    if (held && record.leaseHostId == hostId) {
      // Claim time is derived from the deadline rather than read off
      // updatedAt: `leaseUntil` is written in UTC and so means the same
      // instant on every device, whereas updatedAt is serialized without an
      // offset and a peer would re-read its components in its own zone. A
      // peer's later crossing claim moves the deadline forward too, so this
      // still restarts the settle for both sides.
      final claimedAt = until.subtract(leaseDuration);
      final waited = at.toUtc().difference(claimedAt);
      if (waited < leaseSettle) {
        // A restart inside the settle window loses the original timer, and the
        // hourly tick would not come back before the lease expired — the
        // device would then reclaim its own record and delay the briefing by
        // about an hour. Arm the remainder instead.
        _scheduleRecheck(leaseSettle - waited, generation);
        return null;
      }
      return record;
    }

    await _syncService.upsertEntity(
      record.copyWith(
        leaseHostId: hostId,
        // UTC, deliberately. `toIso8601String()` on a local DateTime emits no
        // offset, so a peer's `DateTime.parse` would read the same wall-clock
        // components in its own zone: a west-to-east claim would look already
        // expired and be taken over immediately — both devices firing, which
        // is the duplicate this lease exists to prevent — while the reverse
        // direction would stretch a 30-minute lease by hours.
        leaseUntil: at.toUtc().add(leaseDuration),
        updatedAt: at,
      ),
    );
    _scheduleRecheck(leaseSettle, generation);
    return null;
  }

  /// Whether [agentId]'s identity is live (lifecycle `active`). A missing,
  /// dormant, or destroyed identity must never wake on a schedule — mirroring
  /// the restore path, which only re-subscribes active agents.
  Future<bool> _isActiveAgent(String agentId) async {
    final identity = await _repository.getEntity(agentId);
    return identity?.mapOrNull(agent: (e) => e.lifecycle) ==
        AgentLifecycle.active;
  }

  /// Marks a due record for a non-active agent consumed, so it stops
  /// surfacing. Mirrors the stale-wake clearing on the state path.
  Future<void> _consumeStaleWakeRecord(
    ScheduledWakeEntity record,
    DateTime now,
  ) async {
    await _syncService.upsertEntity(
      record.copyWith(
        status: ScheduledWakeStatus.consumed,
        consumedAt: now,
        updatedAt: now,
      ),
    );
    // The pending-wakes surface refreshes from the shared notification, not
    // from the sync write, so without this the record lingers on screen.
    onPersistedStateChanged?.call(record.agentId);
  }

  /// Clears an archived agent's stale `scheduledWakeAt` so the due query stops
  /// returning it every cycle (synced upsert, LWW-convergent).
  Future<void> _clearStaleScheduledWake(
    AgentStateEntity state,
    DateTime now,
  ) async {
    if (state.scheduledWakeAt == null) return;
    await _syncService.upsertEntity(
      state.copyWith(scheduledWakeAt: null, updatedAt: now),
    );
    onPersistedStateChanged?.call(state.agentId);
    _log(
      'cleared stale scheduledWakeAt for archived '
      '${DomainLogger.sanitizeId(state.agentId)}',
    );
  }

  /// Whether this agent can be fast-forwarded instead of fully woken.
  /// Only applies to project agents (identified by `activeProjectId`)
  /// that have been woken before and have no pending activity.
  bool _canFastForward(AgentStateEntity state) {
    final isProjectAgent = state.slots.activeProjectId != null;
    if (!isProjectAgent) return false;

    final hasPendingActivity = state.slots.pendingProjectActivityAt != null;
    return !hasPendingActivity && state.lastWakeAt != null;
  }

  /// Advance `scheduledWakeAt` to the next future time slot without
  /// executing a full wake cycle. Used for dormant project agents with
  /// no pending activity — avoids unnecessary LLM calls.
  Future<void> _fastForwardSchedule(
    AgentStateEntity state,
    DateTime now,
  ) async {
    final scheduled = state.scheduledWakeAt!;
    var nextWake = DateTime(
      now.year,
      now.month,
      now.day,
      scheduled.hour,
      scheduled.minute,
    );
    if (!nextWake.isAfter(now)) {
      nextWake = DateTime(
        now.year,
        now.month,
        now.day + 1,
        scheduled.hour,
        scheduled.minute,
      );
    }

    await _syncService.upsertEntity(
      state.copyWith(
        scheduledWakeAt: nextWake,
        updatedAt: now,
      ),
    );
    onPersistedStateChanged?.call(state.agentId);

    _log(
      'fast-forwarded ${DomainLogger.sanitizeId(state.agentId)} '
      'to $nextWake (no pending activity)',
    );
  }

  void _log(String message) {
    domainLogger?.log(LogDomain.agentRuntime, message, subDomain: 'schedule');
  }
}
