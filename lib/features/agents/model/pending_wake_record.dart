import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// How a not-yet-run wake came to be scheduled.
///
/// [pending] is a wake the agent itself requested for a future time (its
/// `AgentState.nextWakeAt`); [scheduled] is a system/planner pre-warm fixed to
/// a clock time (`scheduledWakeAt` or a workspace-scoped `ScheduledWakeEntity`).
enum PendingWakeType {
  pending,
  scheduled,
}

/// A single upcoming wake to render in the pending-wakes list: the agent, its
/// current state, why it is due ([type]), and when ([dueAt]). Built by
/// `pendingWakeRecordsProvider` by merging state-derived and workspace-scoped
/// scheduled wakes into one timeline-sorted view.
class PendingWakeRecord {
  const PendingWakeRecord({
    required this.agent,
    required this.state,
    required this.type,
    required this.dueAt,
    this.subjectLabel,
  });

  final AgentIdentityEntity agent;
  final AgentStateEntity state;
  final PendingWakeType type;
  final DateTime dueAt;

  /// Pre-resolved subject line for wakes whose subject is a workspace rather
  /// than a linked task/project — e.g. a planner day pre-warm sourced from a
  /// [ScheduledWakeEntity], where the day id (from the record's `workspaceKey`)
  /// is the meaningful subject. `null` for state-derived wakes, which resolve
  /// their subject from the agent's slots instead.
  final String? subjectLabel;

  String get id =>
      '${agent.agentId}:${type.name}:${dueAt.toIso8601String()}'
      '${subjectLabel == null ? '' : ':$subjectLabel'}';
}
