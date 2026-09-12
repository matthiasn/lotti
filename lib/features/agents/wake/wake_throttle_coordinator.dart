import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/services/domain_logging.dart';

/// Manages throttle timing with deferred drains and deadlines.
///
/// Ensures that subscription-triggered wakes for the same agent are spaced
/// at least [throttleWindow] apart. Persists the `nextWakeAt` timestamp
/// to the agent's state entity so the UI can show a countdown timer.
class WakeThrottleCoordinator with AgentErrorLogging {
  WakeThrottleCoordinator({
    required this.repository,
    required this.onDrainRequested,
    required this.throttleWindow,
    this.onPersistedStateChanged,
    this.domainLogger,
  });

  final AgentRepository repository;
  final Future<void> Function() onDrainRequested;
  final void Function(String agentId)? onPersistedStateChanged;
  final Duration throttleWindow;
  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;

  final _throttleDeadlines = <String, DateTime>{};
  final _deferredDrainTimers = <String, Timer>{};
  final _pendingClears = <String, Future<void>>{};
  final _queuedClears = <({String agentId, Completer<void> completion})>[];
  bool _clearWorkerScheduled = false;

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(LogDomain.agentRuntime, message, subDomain: subDomain);
  }

  /// Whether [agentId] is still inside its cooldown window. Evicts the
  /// deadline as a side effect once it has elapsed, so a stale entry never
  /// keeps reporting `true`.
  bool isThrottled(String agentId) {
    final deadline = _throttleDeadlines[agentId];
    if (deadline == null) return false;
    if (clock.now().isBefore(deadline)) return true;
    _throttleDeadlines.remove(agentId);
    return false;
  }

  /// The active cooldown deadline for [agentId], or `null` if it isn't
  /// throttled. Backs the UI countdown timer.
  DateTime? deadlineFor(String agentId) => _throttleDeadlines[agentId];

  /// Fix A: Schedule the deferred drain timer BEFORE persisting to DB.
  ///
  /// Previously, `_scheduleDeferredDrain` was called after the async DB write.
  /// If the DB write failed or hung, the timer was never scheduled and the
  /// queued job would sit until the safety net (60s) fired. Now the timer
  /// is scheduled first (synchronous), then the DB write is best-effort.
  ///
  /// [customDeadline], when non-null, overrides the default
  /// `now + throttleWindow`. Used by the orchestrator to defer
  /// propagated subscription matches (parent fan-out, link-side-effects)
  /// to the next 06:00 instead of the standard 120-second cooldown. A
  /// custom deadline that is in the past is silently ignored — the
  /// caller's intent was clearly "schedule for later", and a stale
  /// timestamp would otherwise fire the drain immediately.
  Future<void> setDeadline(String agentId, {DateTime? customDeadline}) async {
    final now = clock.now();
    if (customDeadline != null && !customDeadline.isAfter(now)) {
      return;
    }
    final deadline = customDeadline ?? now.add(throttleWindow);
    // A new deadline starts a new generation: a later clear must run after
    // its persistence, even if the previous generation is still clearing.
    unawaited(_pendingClears.remove(agentId));
    _throttleDeadlines[agentId] = deadline;

    // Schedule the deferred drain FIRST (synchronous) so the timer is always
    // created regardless of whether the DB write succeeds.
    _scheduleDeferredDrain(agentId, deadline);

    // Then persist (best-effort, non-blocking).
    // Write directly to repository (bypassing AgentSyncService) because
    // throttle state is per-device and should NOT be synced to other devices.
    // Each device maintains its own wake cooldown window independently.
    try {
      var changed = false;
      await repository.runInTransaction(() async {
        final state = await repository.getAgentState(agentId);
        if (state == null) return;
        await repository.upsertEntity(
          state.copyWith(nextWakeAt: deadline, updatedAt: clock.now()),
        );
        changed = true;
      });
      if (changed) onPersistedStateChanged?.call(agentId);
    } catch (e, s) {
      logError(
        'failed to persist throttle deadline '
        'for ${DomainLogger.sanitizeId(agentId)}',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Restores an in-memory deadline (and its drain timer) from a persisted
  /// `nextWakeAt` at startup, without re-persisting it. A deadline already in
  /// the past is ignored so a stale timestamp doesn't fire a drain immediately.
  void setDeadlineFromHydration(String agentId, DateTime deadline) {
    if (deadline.isBefore(clock.now())) return;
    // A new deadline starts a new generation: a later clear must run after
    // its persistence, even if the previous generation is still clearing.
    unawaited(_pendingClears.remove(agentId));
    _throttleDeadlines[agentId] = deadline;
    _scheduleDeferredDrain(agentId, deadline);
  }

  /// Cancels [agentId]'s cooldown: drops the in-memory deadline, cancels the
  /// deferred drain timer, and clears the persisted `nextWakeAt`. Used when a
  /// wake is forced (e.g. manual re-analysis) and the countdown is moot.
  /// Concurrent clears share a bulk read and transaction. Repeated clears for
  /// one agent share their completion until that deadline generation changes.
  /// Even unhydrated persisted deadlines are retired.
  void clearThrottle(String agentId) {
    _throttleDeadlines.remove(agentId);
    _deferredDrainTimers[agentId]?.cancel();
    _deferredDrainTimers.remove(agentId);
    domainLogger?.logSampled(
      LogDomain.agentRuntime,
      'throttle cleared for ${DomainLogger.sanitizeId(agentId)}',
      sampleKey: 'throttle.clear',
      subDomain: 'throttle',
    );
    unawaited(_clearPersistedThrottle(agentId));
  }

  /// Cancels all outstanding deferred-drain timers. Call on teardown so
  /// pending timers don't fire after the coordinator is gone.
  void dispose() {
    for (final timer in _deferredDrainTimers.values) {
      timer.cancel();
    }
    _deferredDrainTimers.clear();
  }

  /// Queues device-local clears for one bulk read per burst. The worker keeps
  /// at most one clear transaction in flight; new requests join the next batch.
  Future<void> _clearPersistedThrottle(String agentId) {
    final pending = _pendingClears[agentId];
    if (pending != null) return pending;
    final completion = Completer<void>();
    _pendingClears[agentId] = completion.future;
    _queuedClears.add((agentId: agentId, completion: completion));
    if (!_clearWorkerScheduled) {
      _clearWorkerScheduled = true;
      scheduleMicrotask(() => unawaited(_flushPersistedClears()));
    }
    return completion.future;
  }

  Future<void> _flushPersistedClears() async {
    while (_queuedClears.isNotEmpty) {
      final batch = List.of(_queuedClears);
      _queuedClears.clear();
      final agentIds = batch
          .map((request) => request.agentId)
          .toSet()
          .where((id) => !_throttleDeadlines.containsKey(id))
          .toList();
      try {
        final changed = <String>[];
        if (agentIds.isNotEmpty) {
          // Read and write inside the same transaction as other partial state
          // writers. Only pending rows are decoded; idle agents cost no writes.
          await repository.runInTransaction(() async {
            final states = agentIds.length == 1
                ? {
                    agentIds.single: await repository.getAgentState(
                      agentIds.single,
                    ),
                  }
                : await repository.getAgentStatesWithPendingWakes(agentIds);
            for (final agentId in agentIds) {
              final state = states[agentId];
              if (_throttleDeadlines.containsKey(agentId) ||
                  state == null ||
                  state.nextWakeAt == null) {
                continue;
              }
              await repository.upsertEntity(
                state.copyWith(nextWakeAt: null, updatedAt: clock.now()),
              );
              changed.add(agentId);
            }
          });
        }
        final onChanged = onPersistedStateChanged;
        if (onChanged != null) changed.forEach(onChanged);
      } catch (e, s) {
        logError(
          'failed to clear persisted throttle batch (${agentIds.length} agents)',
          error: e,
          stackTrace: s,
        );
      } finally {
        for (final request in batch) {
          // A newly armed deadline can queue another clear while this batch
          // awaits storage. Completing the older batch must not evict it.
          if (identical(
            _pendingClears[request.agentId],
            request.completion.future,
          )) {
            unawaited(_pendingClears.remove(request.agentId));
          }
          request.completion.complete();
        }
      }
    }
    _clearWorkerScheduled = false;
  }

  void _scheduleDeferredDrain(String agentId, DateTime deadline) {
    _deferredDrainTimers[agentId]?.cancel();
    final remaining = deadline.difference(clock.now());
    if (remaining <= Duration.zero) {
      _deferredDrainTimers.remove(agentId);
      _throttleDeadlines.remove(agentId);
      unawaited(_clearPersistedThrottle(agentId));
      scheduleMicrotask(() => unawaited(onDrainRequested()));
      return;
    }
    _log(
      'deferred drain scheduled in ${remaining.inSeconds}s '
      'for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'timer',
    );
    _deferredDrainTimers[agentId] = Timer(remaining, () {
      _log(
        'deferred drain timer fired '
        'for ${DomainLogger.sanitizeId(agentId)}',
        subDomain: 'timer',
      );
      _deferredDrainTimers.remove(agentId);
      _throttleDeadlines.remove(agentId);
      unawaited(_clearPersistedThrottle(agentId));
      unawaited(onDrainRequested());
    });
  }
}
