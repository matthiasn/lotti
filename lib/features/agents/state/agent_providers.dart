import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_providers.g.dart';

/// The agent database instance (lazy singleton).
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  return AgentDatabase();
}

/// The agent repository wrapping the database.
@Riverpod(keepAlive: true)
AgentRepository agentRepository(Ref ref) {
  return AgentRepository(ref.watch(agentDatabaseProvider));
}

/// The in-memory wake queue.
@Riverpod(keepAlive: true)
WakeQueue wakeQueue(Ref ref) {
  return WakeQueue();
}

/// The single-flight wake runner.
@Riverpod(keepAlive: true)
WakeRunner wakeRunner(Ref ref) {
  return WakeRunner();
}

/// The wake orchestrator (notification listener + subscription matching).
@Riverpod(keepAlive: true)
WakeOrchestrator wakeOrchestrator(Ref ref) {
  return WakeOrchestrator(
    repository: ref.watch(agentRepositoryProvider),
    queue: ref.watch(wakeQueueProvider),
    runner: ref.watch(wakeRunnerProvider),
  );
}

/// The high-level agent service.
@Riverpod(keepAlive: true)
AgentService agentService(Ref ref) {
  return AgentService(
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  );
}

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> agentReport(
  Ref ref,
  String agentId,
) async {
  final service = ref.watch(agentServiceProvider);
  return service.getAgentReport(agentId);
}

/// Fetch agent state for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> agentState(
  Ref ref,
  String agentId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  return repository.getAgentState(agentId);
}

/// Fetch agent identity by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> agentIdentity(
  Ref ref,
  String agentId,
) async {
  final service = ref.watch(agentServiceProvider);
  return service.getAgent(agentId);
}

/// Fetch recent messages for an agent by [agentId].
///
/// Returns up to 50 of the most recent message entities (all kinds),
/// ordered most-recent first. Each element is an [AgentDomainEntity] of
/// variant [AgentMessageEntity].
@riverpod
Future<List<AgentDomainEntity>> agentRecentMessages(
  Ref ref,
  String agentId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  final entities = await repository.getEntitiesByAgentId(
    agentId,
    type: 'agentMessage',
  );
  final messages = entities.whereType<AgentMessageEntity>().toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  const limit = 50;
  if (messages.length > limit) {
    return messages.sublist(0, limit).cast<AgentDomainEntity>();
  }
  return messages.cast<AgentDomainEntity>();
}
