import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/front_agent/runtime/front_runtime_maintenance.dart';
import 'package:lotti/features/front_agent/service/front_agent_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_door_walker.dart';
import 'package:lotti/features/front_agent/service/front_owner_titles.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_model_resolution.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';

/// The routing index over the journal and the agent store.
final frontRoutingIndexBuilderProvider = Provider<FrontRoutingIndexBuilder>(
  (ref) => FrontRoutingIndexBuilder(
    journalDb: ref.watch(journalDbProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
    // A host without a full-text index simply has no corpus match.
    fts5Db: ref.watch(fts5DbProvider),
  ),
  name: 'frontRoutingIndexBuilderProvider',
);

/// One routing turn per wake.
final frontAgentWorkflowProvider = Provider<FrontAgentWorkflow>(
  (ref) => FrontAgentWorkflow(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    indexBuilder: ref.watch(frontRoutingIndexBuilderProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontAgentWorkflowProvider',
);

/// The one front agent, created on first use.
final frontAgentServiceProvider = Provider<FrontAgentService>(
  (ref) => FrontAgentService(
    agentService: ref.watch(agentServiceProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  ),
  name: 'frontAgentServiceProvider',
);

/// Which turns are still unanswered.
final frontChatHistoryServiceProvider = Provider<FrontChatHistoryService>(
  (ref) => FrontChatHistoryService(
    repository: ref.watch(agentRepositoryProvider),
  ),
  name: 'frontChatHistoryServiceProvider',
);

/// Durable user-authored turns (the goal-chat pattern, with recovery).
final frontChatServiceProvider = Provider<FrontChatService>(
  (ref) => FrontChatService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    notifications: ref.watch(updateNotificationsProvider),
    historyService: ref.watch(frontChatHistoryServiceProvider),
  ),
  name: 'frontChatServiceProvider',
);

/// The front agent's contribution to `agentRuntimeMaintenanceProvider`:
/// the recovery of an unanswered turn, on every device, every pass.
final frontRuntimeMaintenanceProvider = Provider<FrontRuntimeMaintenance>(
  (ref) => FrontRuntimeMaintenance(
    chatService: ref.watch(frontChatServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontRuntimeMaintenanceProvider',
);

/// The front agent's contribution to `agentResolvedSetupResolversProvider`:
/// its own setup, never a template's and never a category's.
Future<ResolvedAgentSetup?> resolveFrontAgentSetup(
  Ref ref,
  String agentId,
) async {
  final identity = await ref.watch(agentRepositoryProvider).getEntity(agentId);
  if (identity is! AgentIdentityEntity) return null;
  final resolved = await resolveFrontAgentModel(
    agentIdentity: identity,
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
  return resolved?.setup;
}

/// Owner titles for the door records.
final frontOwnerTitlesProvider = Provider<FrontOwnerTitles>(
  (ref) => FrontOwnerTitles(
    journalDb: ref.watch(journalDbProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
  ),
  name: 'frontOwnerTitlesProvider',
);

/// The door walker: the query pipeline for a task or project question, a
/// goal's or person's own chat for theirs.
final frontDoorWalkerProvider = Provider<FrontDoorWalker>(
  (ref) => FrontDoorWalker(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    queryBuilderFactory: ref.watch(queryBuilderFactoryProvider),
    taskAgentFor: ref.watch(taskAgentServiceProvider).getTaskAgentForTask,
    projectAgentFor: ref
        .watch(projectAgentServiceProvider)
        .getProjectAgentForProject,
    goalChat: ref.watch(goalChatServiceProvider),
    personChat: ref.watch(relationshipChatServiceProvider),
    ownerTitles: ref.watch(frontOwnerTitlesProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'frontDoorWalkerProvider',
);

/// The front agent's contribution to `agentWakeRunnersProvider` — merged in
/// `app_bootstrap.dart`, never left to the silent task-agent fallback in
/// `agent_wiring.dart` (pinned by `test/app_bootstrap_test.dart`).
///
/// Only a chat token enters the model: the front agent has no scheduled or
/// subscription wakes, so any other token is a no-op success. A turn that
/// is already routed, asked about or replied to — a recovery wake arriving
/// after the author's own run — is not routed again (the goal runner's
/// rule); its doors are still walked, which the claims make idempotent, so a
/// walk that died with its device is finished here.
final frontAgentWakeRunnersProvider = Provider<Map<String, AgentWakeRunner>>(
  (ref) => <String, AgentWakeRunner>{
    AgentKinds.frontAgent:
        ({
          required agentIdentity,
          required runKey,
          required triggerTokens,
          required threadId,
        }) async {
          final messageId = frontChatMessageIdFromTriggerTokens(triggerTokens);
          if (messageId == null) return const WakeResult(success: true);
          final unrouted = await ref
              .read(frontChatHistoryServiceProvider)
              .unroutedMessageIds();
          var result = const WakeResult(success: true);
          if (unrouted.contains(messageId)) {
            result = await ref
                .read(frontAgentWorkflowProvider)
                .executeUserMessage(
                  agentIdentity: agentIdentity,
                  runKey: runKey,
                  triggerTokens: triggerTokens,
                  threadId: threadId,
                  messageId: messageId,
                );
            if (!result.success) return result;
          }
          await ref.read(frontDoorWalkerProvider).walk(messageId);
          return result;
        },
  },
  name: 'frontAgentWakeRunnersProvider',
);
