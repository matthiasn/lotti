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
  });

  final AgentIdentityEntity agent;
  final AgentStateEntity state;
  final PendingWakeType type;
  final DateTime dueAt;

  String get id => '${agent.agentId}:${type.name}:${dueAt.toIso8601String()}';
}
