import 'dart:developer' as developer;

import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
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

  // Filter to message entities and sort most-recent first.
  final messages = entities.whereType<AgentMessageEntity>().toList()
    ..sort(
      (AgentMessageEntity a, AgentMessageEntity b) =>
          b.createdAt.compareTo(a.createdAt),
    );

  const limit = 50;
  if (messages.length > limit) {
    return messages.sublist(0, limit);
  }
  return messages;
}

/// Initializes the agent infrastructure when the `enableAgents` config flag
/// is enabled.
///
/// This provider:
/// 1. Watches the `enableAgents` config flag.
/// 2. When enabled, starts the [WakeOrchestrator] listening to
///    `UpdateNotifications.updateStream`.
/// 3. Restores task agent subscriptions from persisted state.
///
/// Must be watched (e.g. from a top-level widget or app initialization) to
/// take effect.
@Riverpod(keepAlive: true)
Future<void> agentInitialization(Ref ref) async {
  final enableAgents = ref.watch(configFlagProvider(enableAgentsFlag));
  final isEnabled = enableAgents.value ?? false;

  if (!isEnabled) {
    developer.log(
      'Agents disabled, skipping initialization',
      name: 'agentInitialization',
    );
    return;
  }

  developer.log(
    'Agents enabled, starting wake orchestrator',
    name: 'agentInitialization',
  );

  final orchestrator = ref.watch(wakeOrchestratorProvider);
  final updateNotifications = getIt<UpdateNotifications>();
  orchestrator.start(updateNotifications.updateStream);

  final taskAgentService = ref.watch(taskAgentServiceProvider);
  await taskAgentService.restoreSubscriptions();

  ref.onDispose(() {
    developer.log(
      'Stopping wake orchestrator',
      name: 'agentInitialization',
    );
    orchestrator.stop();
  });
}
