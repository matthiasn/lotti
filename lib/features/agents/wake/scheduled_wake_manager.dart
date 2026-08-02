import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';

/// Manages scheduled wakes for agents that need to wake on a time-based
/// schedule (e.g., daily project digests, weekly one-on-one rituals).
///
/// On startup and then hourly, queries for agents with overdue
/// `scheduledWakeAt`. Dormant project agents (no pending activity since
/// last report) are fast-forwarded to the next future time slot without
/// executing, avoiding unnecessary LLM calls after prolonged app absence.
/// Non-project agents (e.g., improver agents) are always enqueued.
class ScheduledWakeManager {
  ScheduledWakeManager({
    required this._repository,
    required this._orchestrator,
    required this._syncService,
    this.checkInterval = const Duration(hours: 1),
    this.domainLogger,
    this.onPersistedStateChanged,
    this.requiresLease,
    this.localHostId,
    this.leaseSettle = const Duration(minutes: 3),
    this.leaseDuration = const Duration(minutes: 30),
  });

  final AgentRepository _repository;
  final WakeOrchestrator _orchestrator;
  final AgentSyncService _syncService;
  final DomainLogger? domainLogger;
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

  Future<void> _checkAndEnqueue() async {
    if (_isChecking) return;
    _isChecking = true;
    // Captured before the first await: `stop()` may land while this pass is
    // waiting on the repository, the host lookup or the claim write, and the
    // continuation must not then arm a timer the stop could never cancel.
    final generation = _generation;
    try {
      final now = clock.now();
      final dueStates = await _repository.getDueScheduledAgentStates(now);

      var enqueued = 0;
      var fastForwarded = 0;
      var skippedArchived = 0;

      for (final state in dueStates) {
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
          _logError(
            'failed to process ${DomainLogger.sanitizeId(state.agentId)}',
            error: e,
            stackTrace: s,
          );
        }
      }

      final recordsEnqueued = await _processDueRecords(now, generation);

      if (dueStates.isNotEmpty || recordsEnqueued > 0) {
        _log(
          'processed ${dueStates.length} due agents: '
          '$enqueued enqueued, $fastForwarded fast-forwarded, '
          '$skippedArchived archived skipped; '
          '$recordsEnqueued scheduled-wake record(s) fired',
        );
      }
    } catch (e, s) {
      _logError('error checking scheduled wakes', error: e, stackTrace: s);
    } finally {
      _isChecking = false;
    }
  }

  /// Fire pending [ScheduledWakeEntity] records that are due (ADR 0022).
  ///
  /// Each record carries its own workspace key and trigger tokens, so the
  /// enqueued wake restores full day context — unlike the context-less
  /// `scheduledWakeAt` path. After enqueuing, the record is flipped to
  /// [ScheduledWakeStatus.consumed] in place (not hard-deleted) so a
  /// concurrent device's flip converges via LWW instead of resurrecting it.
  Future<int> _processDueRecords(DateTime now, int generation) async {
    final dueRecords = await _repository.getDueScheduledWakeRecords(now);
    var enqueued = 0;
    for (final record in dueRecords) {
      try {
        final approved = await _leaseApprovedRecord(record, now, generation);
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
        _orchestrator.enqueueManualWake(
          agentId: record.agentId,
          reason: record.reason,
          triggerTokens: record.triggerTokens.toSet(),
          workspaceKey: record.workspaceKey,
        );
        await _syncService.upsertEntity(
          record.copyWith(
            status: ScheduledWakeStatus.consumed,
            consumedAt: now,
            updatedAt: now,
          ),
        );
        onPersistedStateChanged?.call(record.agentId);
        enqueued++;
      } catch (e, s) {
        _logError(
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
  Future<ScheduledWakeEntity?> _leaseApprovedRecord(
    ScheduledWakeEntity due,
    DateTime now,
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

    final until = record.leaseUntil;
    final held = until != null && until.isAfter(now);

    if (held && record.leaseHostId != hostId) {
      _log(
        'digest lease held elsewhere for '
        '${DomainLogger.sanitizeId(record.id)}',
      );
      // Take over the moment the foreign lease lapses. Without this, a
      // claimant that crashed would hold the window until the next hourly
      // tick — up to an hour late on top of the 30-minute lease.
      _scheduleRecheck(until.difference(now), generation);
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
      final waited = now.toUtc().difference(claimedAt);
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
        leaseUntil: now.toUtc().add(leaseDuration),
        updatedAt: now,
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

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomain.agentRuntime,
        error ?? message,
        message: error != null ? message : null,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ' (errorType=${error.runtimeType})' : ''}',
        name: 'ScheduledWakeManager',
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }
}
