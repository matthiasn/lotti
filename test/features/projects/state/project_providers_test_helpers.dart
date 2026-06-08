import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

AgentDomainEntity hMakeProjectAgent(String agentId) {
  return AgentDomainEntity.agent(
    id: agentId,
    agentId: agentId,
    kind: 'project_agent',
    displayName: 'Project Agent',
    lifecycle: AgentLifecycle.active,
    mode: AgentInteractionMode.autonomous,
    allowedCategoryIds: const {},
    currentStateId: 'state-1',
    config: const AgentConfig(),
    createdAt: DateTime(2026, 4, 2, 9),
    updatedAt: DateTime(2026, 4, 2, 9),
    vectorClock: null,
  );
}
