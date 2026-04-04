import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/workflow/improver_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/project_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_workflow_providers.g.dart';

/// The template evolution workflow with all dependencies resolved.
///
/// Includes the multi-turn session dependencies (AgentTemplateService,
/// AgentSyncService) alongside the legacy single-turn dependencies.
@Riverpod(keepAlive: true)
TemplateEvolutionWorkflow templateEvolutionWorkflow(Ref ref) {
  final improverService = ref.watch(improverAgentServiceProvider);
  return TemplateEvolutionWorkflow(
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    updateNotifications: ref.watch(updateNotificationsProvider),
    onSessionCompleted: (templateId, sessionId) async {
      // Resolve the improver agent for this template and schedule its next
      // ritual. Best-effort: a lookup failure here must not break the
      // approval flow (the callback is already wrapped in try/catch).
      final improver = await improverService.getImproverForTemplate(templateId);
      if (improver != null) {
        await improverService.scheduleNextRitual(improver.agentId);
      }
    },
  );
}

/// The improver agent workflow with all dependencies resolved.
@Riverpod(keepAlive: true)
ImproverAgentWorkflow improverAgentWorkflow(Ref ref) {
  return ImproverAgentWorkflow(
    feedbackService: ref.watch(feedbackExtractionServiceProvider),
    evolutionWorkflow: ref.watch(templateEvolutionWorkflowProvider),
    improverService: ref.watch(improverAgentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}

/// The task agent workflow with all dependencies resolved.
@Riverpod(keepAlive: true)
TaskAgentWorkflow taskAgentWorkflow(Ref ref) {
  // Embedding dependencies are optional — the pipeline may not be available
  // (e.g. ObjectBox initialization failure).
  final embeddingStore = getIt.isRegistered<EmbeddingStore>()
      ? getIt<EmbeddingStore>()
      : null;
  final embeddingRepository = getIt.isRegistered<OllamaEmbeddingRepository>()
      ? getIt<OllamaEmbeddingRepository>()
      : null;

  return TaskAgentWorkflow(
    agentRepository: ref.watch(agentRepositoryProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    aiInputRepository: ref.watch(aiInputRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    journalDb: ref.watch(journalDbProvider),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    checklistRepository: ref.watch(checklistRepositoryProvider),
    labelsRepository: ref.watch(labelsRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    embeddingStore: embeddingStore,
    embeddingRepository: embeddingRepository,
    taskAgentService: ref.watch(taskAgentServiceProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
  );
}

/// The project agent workflow with all dependencies resolved.
@Riverpod(keepAlive: true)
ProjectAgentWorkflow projectAgentWorkflow(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return ProjectAgentWorkflow(
    agentRepository: ref.watch(agentRepositoryProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}
