import 'package:lotti/features/agents/model/agent_domain_entity.dart';

enum PendingWakeType {
  pending,
  scheduled,
}

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
