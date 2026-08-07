import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_audio_entry_context_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;

/// The Daily OS day-agent workflow with all dependencies resolved.
///
/// Lives here rather than beside the other workflow providers in
/// `features/agents`: the day agent is Daily OS's agent, and wiring it from the
/// runtime's own provider file is what previously made `features/agents` import
/// this feature. The runtime reaches it through [agentWakeRunnersProvider].
final dayAgentWorkflowProvider = Provider<DayAgentWorkflow>(
  dayAgentWorkflow,
  name: 'dayAgentWorkflowProvider',
);
DayAgentWorkflow dayAgentWorkflow(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentWorkflow(
    agentRepository: ref.watch(agentRepositoryProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    captureService: ref.watch(dayAgentCaptureServiceProvider),
    planService: ref.watch(dayAgentPlanServiceProvider),
    knowledgeService: ref.watch(dayAgentKnowledgeServiceProvider),
    weekContextService: ref.watch(dayAgentWeekContextServiceProvider),
    directiveService: ref.watch(dayAgentDirectiveServiceProvider),
    dependencyResolver: ref.watch(taskDependencyResolverProvider),
    soulDocumentService: ref.watch(soulDocumentServiceProvider),
    dayAudioEntryContextService: DayAudioEntryContextService(
      journalDb: ref.watch(journalDbProvider),
      assetRoot: getIt(),
    ),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
    logSummarizer: AgentLogLlmSummarizer(
      inferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    ),
    // No input capture service: the day agent's durable inputs (capture
    // transcripts, observations) are already synced log entities, projected as
    // inline events.
  );
}

/// Daily OS's contribution to [agentWakeRunnersProvider]: the `day_agent` kind.
final dayAgentWakeRunnersProvider = Provider<Map<String, AgentWakeRunner>>(
  (ref) => <String, AgentWakeRunner>{
    AgentKinds.dayAgent:
        ({
          required agentIdentity,
          required runKey,
          required triggerTokens,
          required threadId,
        }) => ref
            .read(dayAgentWorkflowProvider)
            .execute(
              agentIdentity: agentIdentity,
              runKey: runKey,
              triggerTokens: triggerTokens,
              threadId: threadId,
            ),
  },
  name: 'dayAgentWakeRunnersProvider',
);
