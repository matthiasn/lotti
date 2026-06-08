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
  });

  final AgentRepository _repository;
  final WakeOrchestrator _orchestrator;
  final AgentSyncService _syncService;
  final DomainLogger? domainLogger;
  final void Function(String agentId)? onPersistedStateChanged;

  final Duration checkInterval;

  Timer? _timer;
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
    _timer?.cancel();
    _timer = null;
    _log('stopped');
  }

  Future<void> _checkAndEnqueue() async {
    if (_isChecking) return;
    _isChecking = true;
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

      final recordsEnqueued = await _processDueRecords(now);

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
  Future<int> _processDueRecords(DateTime now) async {
    final dueRecords = await _repository.getDueScheduledWakeRecords(now);
    var enqueued = 0;
    for (final record in dueRecords) {
      try {
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
