import 'dart:async';

import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/goals/repository/goal_repository.dart';
import 'package:lotti/services/db_notification.dart';

/// Notices when a goal's check-in changes and tells the agent its standing
/// report is out of date.
///
/// **Stale, not a wake.** Three check-ins in one morning would otherwise be
/// three inference runs. Marking the report stale lets the existing cadence —
/// or an explicit "Update now" — consume everything the user said at once,
/// which is both cheaper and a better read.
///
/// Listens to the journal's update stream rather than owning a poll: a
/// recording arrives, and later its transcript lands as a second update to the
/// same id, and both should refresh the goal.
class GoalCheckInNotifier {
  GoalCheckInNotifier({
    required GoalRepository goalRepository,
    required AgentService agentService,
    required UpdateNotifications updateNotifications,
  }) : _goals = goalRepository,
       _agents = agentService,
       _updates = updateNotifications;

  final GoalRepository _goals;
  final AgentService _agents;
  final UpdateNotifications _updates;

  StreamSubscription<Set<String>>? _subscription;

  /// Watches [agentIds] — the active goals — for check-in activity.
  ///
  /// Resolving each goal's id up front keeps the hot path a set lookup: the
  /// journal update stream is busy, and this must not query per notification.
  void start(Iterable<String> agentIds) {
    stop();
    final byGoalId = <String, String>{
      for (final agentId in agentIds) _goals.goalIdForAgent(agentId): agentId,
    };
    if (byGoalId.isEmpty) return;

    _subscription = _updates.updateStream.listen((affectedIds) async {
      // A goal's own id is emitted for its check-ins because the entries are
      // linked to it; a linked write notifies both ends.
      for (final goalId in affectedIds.intersection(byGoalId.keys.toSet())) {
        final agentId = byGoalId[goalId];
        if (agentId == null) continue;
        try {
          await _agents.markReportStale(agentId);
        } on Object {
          // One goal failing to be marked must not silence the others, and a
          // missed mark is recovered by the next check-in or the cadence.
          continue;
        }
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
