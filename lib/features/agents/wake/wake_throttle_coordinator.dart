import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Manages throttle timing with deferred drains and deadlines.
///
/// Ensures that subscription-triggered wakes for the same agent are spaced
/// at least [throttleWindow] apart. Persists the `nextWakeAt` timestamp
/// to the agent's state entity so the UI can show a countdown timer.
class WakeThrottleCoordinator {
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
  final DomainLogger? domainLogger;

  final _throttleDeadlines = <String, DateTime>{};
  final _deferredDrainTimers = <String, Timer>{};

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(LogDomains.agentRuntime, message, subDomain: subDomain);
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomains.agentRuntime,
        message,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ': $error' : ''}',
        name: 'WakeThrottleCoordinator',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool isThrottled(String agentId) {
    final deadline = _throttleDeadlines[agentId];
    if (deadline == null) return false;
    if (clock.now().isBefore(deadline)) return true;
    _throttleDeadlines.remove(agentId);
    return false;
  }

  DateTime? deadlineFor(String agentId) => _throttleDeadlines[agentId];

  /// Fix A: Schedule the deferred drain timer BEFORE persisting to DB.
  ///
  /// Previously, `_scheduleDeferredDrain` was called after the async DB write.
  /// If the DB write failed or hung, the timer was never scheduled and the
  /// queued job would sit until the safety net (60s) fired. Now the timer
  /// is scheduled first (synchronous), then the DB write is best-effort.
  Future<void> setDeadline(String agentId) async {
    final deadline = clock.now().add(throttleWindow);
    _throttleDeadlines[agentId] = deadline;

    // Schedule the deferred drain FIRST (synchronous) so the timer is always
    // created regardless of whether the DB write succeeds.
    _scheduleDeferredDrain(agentId, deadline);

    // Then persist (best-effort, non-blocking).
    // Write directly to repository (bypassing AgentSyncService) because
    // throttle state is per-device and should NOT be synced to other devices.
    // Each device maintains its own wake cooldown window independently.
    try {
      final state = await repository.getAgentState(agentId);
      if (state != null) {
        await repository.upsertEntity(
          state.copyWith(nextWakeAt: deadline, updatedAt: clock.now()),
        );
        onPersistedStateChanged?.call(agentId);
      }
    } catch (e, s) {
      _logError(
        'failed to persist throttle deadline '
        'for ${DomainLogger.sanitizeId(agentId)}',
        error: e,
        stackTrace: s,
      );
    }
  }

  void setDeadlineFromHydration(String agentId, DateTime deadline) {
    if (deadline.isBefore(clock.now())) return;
    _throttleDeadlines[agentId] = deadline;
    _scheduleDeferredDrain(agentId, deadline);
  }

  void clearThrottle(String agentId) {
    _throttleDeadlines.remove(agentId);
    _deferredDrainTimers[agentId]?.cancel();
    _deferredDrainTimers.remove(agentId);
    _log(
      'throttle cleared for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'throttle',
    );
    unawaited(_clearPersistedThrottle(agentId));
  }

  void dispose() {
    for (final timer in _deferredDrainTimers.values) {
      timer.cancel();
    }
    _deferredDrainTimers.clear();
  }

  /// Clears the persisted `nextWakeAt` on the agent's state entity.
  ///
  /// Writes directly to repository (bypassing AgentSyncService) because
  /// throttle state is per-device and should NOT be synced to other devices.
  Future<void> _clearPersistedThrottle(String agentId) async {
    try {
      if (_throttleDeadlines.containsKey(agentId)) return;

      final state = await repository.getAgentState(agentId);

      if (_throttleDeadlines.containsKey(agentId)) return;

      if (state != null && state.nextWakeAt != null) {
        await repository.upsertEntity(
          state.copyWith(nextWakeAt: null, updatedAt: clock.now()),
        );
        onPersistedStateChanged?.call(agentId);
      }
    } catch (e, s) {
      _logError(
        'failed to clear persisted throttle '
        'for ${DomainLogger.sanitizeId(agentId)}',
        error: e,
        stackTrace: s,
      );
    }
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
