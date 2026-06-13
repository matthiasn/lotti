import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';

/// Shared agent-identity resolution for the capture/corpus/triage
/// collaborators. Extracting it lets the corpus and triage collaborators
/// resolve the planner identity without depending on each other.
class DayAgentCaptureReads {
  /// Creates the shared capture reads collaborator.
  DayAgentCaptureReads({required this.agentRepository});

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Resolve the agent identity, throwing when it is missing.
  Future<AgentIdentityEntity> requireIdentity(String agentId) async {
    final entity = await agentRepository.getEntity(agentId);
    if (entity is AgentIdentityEntity) return entity;
    throw DayAgentCaptureException('agent $agentId not found');
  }
}
