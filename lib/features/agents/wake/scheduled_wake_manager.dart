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

  /// Check all agents for due scheduled wakes and enqueue them.
  Future<void> _checkAndEnqueue() async {
    try {
      final now = clock.now();
      final identities = await _repository.getAllAgentIdentities();

      for (final identity in identities) {
        final state = await _repository.getAgentState(identity.agentId);
        if (state == null) continue;

        final scheduledAt = state.scheduledWakeAt;
        if (scheduledAt == null) continue;

        if (!scheduledAt.isAfter(now)) {
          _orchestrator.enqueueManualWake(
            agentId: identity.agentId,
            reason: WakeReason.scheduled.name,
          );

          developer.log(
            'Enqueued scheduled wake for ${identity.agentId} '
            '(was due at $scheduledAt)',
            name: 'ScheduledWakeManager',
          );
        }
      }
    } catch (e, s) {
      developer.log(
        'Error checking scheduled wakes: $e',
        name: 'ScheduledWakeManager',
        error: e,
        stackTrace: s,
      );
    }
  }
}
