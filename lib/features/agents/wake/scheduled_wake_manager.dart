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
    required AgentRepository repository,
    required WakeOrchestrator orchestrator,
    required AgentSyncService syncService,
    this.checkInterval = const Duration(hours: 1),
    this.domainLogger,
    this.onPersistedStateChanged,
  }) : _repository = repository,
       _orchestrator = orchestrator,
       _syncService = syncService;

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

      for (final state in dueStates) {
        try {
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

      if (dueStates.isNotEmpty) {
        _log(
          'processed ${dueStates.length} due agents: '
          '$enqueued enqueued, $fastForwarded fast-forwarded',
        );
      }
    } catch (e, s) {
      _logError('error checking scheduled wakes', error: e, stackTrace: s);
    } finally {
      _isChecking = false;
    }
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
    domainLogger?.log(LogDomains.agentRuntime, message, subDomain: 'schedule');
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
        message,
        name: 'ScheduledWakeManager',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
