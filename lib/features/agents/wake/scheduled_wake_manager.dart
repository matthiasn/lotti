import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';

/// Manages scheduled wakes for agents that need to wake on a time-based
/// schedule (e.g., weekly one-on-one rituals).
///
/// Periodically checks for agents with a `scheduledWakeAt` in the past and
/// enqueues manual wakes for them via the [WakeOrchestrator].
class ScheduledWakeManager {
  ScheduledWakeManager({
    required AgentRepository repository,
    required WakeOrchestrator orchestrator,
    this.checkInterval = const Duration(hours: 1),
  })  : _repository = repository,
        _orchestrator = orchestrator;

  final AgentRepository _repository;
  final WakeOrchestrator _orchestrator;

  /// How often the manager checks for due agents.
  final Duration checkInterval;

  Timer? _timer;
  bool _isChecking = false;

  /// Start periodic checking. Also immediately checks for missed wakes.
  void start() {
    // Check immediately for any missed wakes (e.g., app was closed).
    unawaited(_checkAndEnqueue());

    _timer?.cancel();
    _timer = Timer.periodic(checkInterval, (_) {
      unawaited(_checkAndEnqueue());
    });

    developer.log(
      'Started scheduled wake manager '
      '(interval: ${checkInterval.inMinutes}min)',
      name: 'ScheduledWakeManager',
    );
  }

  /// Stop periodic checking.
  void stop() {
    _timer?.cancel();
    _timer = null;

    developer.log(
      'Stopped scheduled wake manager',
      name: 'ScheduledWakeManager',
    );
  }

  /// Check for agents with a due `scheduledWakeAt` and enqueue them.
  ///
  /// Uses a single DB query instead of fetching each agent's state
  /// individually, avoiding an N+1 query pattern.
  Future<void> _checkAndEnqueue() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final now = clock.now();
      final dueStates = await _repository.getDueScheduledAgentStates(now);

      for (final state in dueStates) {
        _orchestrator.enqueueManualWake(
          agentId: state.agentId,
          reason: WakeReason.scheduled.name,
        );

        developer.log(
          'Enqueued scheduled wake for ${state.agentId} '
          '(was due at ${state.scheduledWakeAt})',
          name: 'ScheduledWakeManager',
        );
      }
    } catch (e, s) {
      developer.log(
        'Error checking scheduled wakes: $e',
        name: 'ScheduledWakeManager',
        error: e,
        stackTrace: s,
      );
    } finally {
      _isChecking = false;
    }
  }
}
