import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
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

  void start() {
    unawaited(_checkAndEnqueue());

    _timer?.cancel();
    _timer = Timer.periodic(checkInterval, (_) {
      unawaited(_checkAndEnqueue());
    });

    _log('started (interval: ${checkInterval.inMinutes}min)');
  }

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
        final hasPendingActivity = state.slots.pendingProjectActivityAt != null;

        if (!hasPendingActivity && state.lastWakeAt != null) {
          await _fastForwardSchedule(state, now);
          fastForwarded++;
          continue;
        }

        _orchestrator.enqueueManualWake(
          agentId: state.agentId,
          reason: WakeReason.scheduled.name,
        );
        enqueued++;
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

  /// Advance `scheduledWakeAt` to the next future time slot without
  /// executing a full wake cycle. Used for dormant agents with no
  /// pending activity — avoids unnecessary LLM calls.
  Future<void> _fastForwardSchedule(
    AgentStateEntity state,
    DateTime now,
  ) async {
    final nextWake = nextLocalDayAtTime(
      now,
      hour: AgentSchedules.projectDailyDigestHour,
    );

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
    domainLogger?.error(
      LogDomains.agentRuntime,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
