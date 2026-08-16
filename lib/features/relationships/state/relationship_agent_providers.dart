import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/helpers/profile_locality.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_workflow.dart';

/// The deterministic tier of the relationship agent (ADR 0059 Decision 2).
final relationshipAgentPhaseAProvider = Provider<RelationshipAgentPhaseA>(
  (ref) => RelationshipAgentPhaseA(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    relationshipRepository: ref.watch(relationshipRepositoryProvider),
    // A locally armed escalation is processed promptly instead of waiting
    // out the hourly poll (the goal Phase A pattern).
    onEscalationArmed: () =>
        ref.read(scheduledWakeManagerProvider).requestCheck(),
  ),
  name: 'relationshipAgentPhaseAProvider',
);

/// Lazy creation, subscriptions, and the deletion cascade's agent leg.
final relationshipAgentServiceProvider = Provider<RelationshipAgentService>(
  (ref) => RelationshipAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  ),
  name: 'relationshipAgentServiceProvider',
);

/// Phase B — the lease-elected LLM tier (briefing, banner, chat).
final relationshipAgentWorkflowProvider = Provider<RelationshipAgentWorkflow>(
  (ref) => RelationshipAgentWorkflow(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    phaseA: ref.watch(relationshipAgentPhaseAProvider),
    relationshipRepository: ref.watch(relationshipRepositoryProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'relationshipAgentWorkflowProvider',
);

/// Durable user-authored chat turns (the `GoalChatService` pattern).
final relationshipChatServiceProvider = Provider<RelationshipChatService>(
  (ref) => RelationshipChatService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  ),
  name: 'relationshipChatServiceProvider',
);

/// The relationships contribution to `agentWakeRunnersProvider` — merged
/// in `app_bootstrap.dart`, NEVER left to the silent task-agent fallback
/// in `agent_wiring.dart` (the documented ADR 0054 trap; pinned by
/// regression test).
final relationshipAgentWakeRunnersProvider =
    Provider<Map<String, AgentWakeRunner>>(
      (ref) => <String, AgentWakeRunner>{
        AgentKinds.relationshipAgent:
            ({
              required agentIdentity,
              required runKey,
              required triggerTokens,
              required threadId,
            }) {
              // The goal router shape: a chat token enters the LLM tier
              // with its durable source turn; an escalation or explicit
              // Brief me enters it fact-gated; everything else stays on
              // the €0 deterministic tier.
              final chatMessageId = relationshipChatMessageIdFromTriggerTokens(
                triggerTokens,
              );
              if (chatMessageId != null) {
                return ref
                    .read(relationshipAgentWorkflowProvider)
                    .executeUserMessage(
                      agentIdentity: agentIdentity,
                      runKey: runKey,
                      triggerTokens: triggerTokens,
                      threadId: threadId,
                      messageId: chatMessageId,
                    );
              }
              return relationshipEscalationDueDayFromTriggerTokens(
                            triggerTokens,
                          ) !=
                          null ||
                      relationshipReportRefreshRequested(triggerTokens)
                  ? ref
                        .read(relationshipAgentWorkflowProvider)
                        .execute(
                          agentIdentity: agentIdentity,
                          runKey: runKey,
                          triggerTokens: triggerTokens,
                          threadId: threadId,
                        )
                  : ref
                        .read(relationshipAgentPhaseAProvider)
                        .execute(
                          agentIdentity: agentIdentity,
                          runKey: runKey,
                          triggerTokens: triggerTokens,
                          threadId: threadId,
                        );
            },
      },
      name: 'relationshipAgentWakeRunnersProvider',
    );

/// The relationships contribution to `agentRuntimeMaintenanceProvider`.
final relationshipRuntimeMaintenanceProvider =
    Provider<RelationshipRuntimeMaintenance>(
      (ref) => RelationshipRuntimeMaintenance(
        agentService: ref.watch(agentServiceProvider),
        repository: ref.watch(agentRepositoryProvider),
        syncService: ref.watch(agentSyncServiceProvider),
        relationshipAgentService: ref.watch(relationshipAgentServiceProvider),
        domainLogger: ref.watch(domainLoggerProvider),
      ),
      name: 'relationshipRuntimeMaintenanceProvider',
    );

/// The inference-provider name to disclose before a cloud-bound "Brief
/// me", or null when the resolved route is local (ADR 0037 / ADR 0059
/// Decision 7: the trigger surface names the provider first, and the
/// locality check fails closed). Routes through the SAME resolution chain
/// as Phase B (`resolveRelationshipAgentModel`) so the dialog can never
/// name a provider other than the one inference actually uses.
final FutureProviderFamily<String?, String>
relationshipBriefingDisclosureProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, relationshipId) async {
      final aiConfigRepository = ref.watch(aiConfigRepositoryProvider);
      final relationship = await ref
          .watch(relationshipRepositoryProvider)
          .getRelationshipById(relationshipId);
      final identity = await ref
          .watch(agentRepositoryProvider)
          .getEntity(relationshipAgentIdFor(relationshipId));
      final resolved = await resolveRelationshipAgentModel(
        relationship: relationship,
        agentIdentity: identity is AgentIdentityEntity ? identity : null,
        aiConfigRepository: aiConfigRepository,
      );
      if (resolved == null) return null;
      final profileId = resolved.profileId;
      if (profileId != null) {
        final config = await aiConfigRepository.getConfigById(profileId);
        if (config is AiConfigInferenceProfile &&
            await profileIsLocal(config, aiConfigRepository)) {
          return null;
        }
      }
      return resolved.provider.name;
    }, name: 'relationshipBriefingDisclosureProvider');
