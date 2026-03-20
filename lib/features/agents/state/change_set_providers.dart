import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/project_accepted_recommendation.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'change_set_providers.g.dart';

/// Fetches pending (and partially resolved) change sets for a given task.
///
/// Resolves the task's agent via [taskAgentProvider], then watches the
/// [agentUpdateStreamProvider] for reactive invalidation, and finally
/// queries the repository.
@riverpod
Future<List<AgentDomainEntity>> pendingChangeSets(
  Ref ref,
  String taskId,
) async {
  final agent = ref
      .watch(taskAgentProvider(taskId))
      .value
      ?.mapOrNull(agent: (a) => a);

  if (agent == null) return [];

  // Watch the agent's update stream so this provider rebuilds when the
  // agent's data changes (e.g., after a wake produces new change sets).
  ref.watch(agentUpdateStreamProvider(agent.agentId));

  final repo = ref.watch(agentRepositoryProvider);
  final sets = await repo.getPendingChangeSets(agent.agentId, taskId: taskId);
  return _deduplicateChangeSets(sets);
}

/// Deduplicates change sets that have identical pending-item fingerprints.
///
/// When two wake cycles race, they may produce genuinely duplicate
/// [ChangeSetEntity] records in the DB. This collapses them at the
/// provider level by fingerprinting each set's pending items (toolName +
/// args) and keeping only the newest set per fingerprint.
List<AgentDomainEntity> _deduplicateChangeSets(
  List<AgentDomainEntity> sets,
) {
  if (sets.length <= 1) return sets;

  final seen = <String, AgentDomainEntity>{};

  for (final entity in sets) {
    if (entity is! ChangeSetEntity) {
      seen[entity.id] = entity;
      continue;
    }

    final fingerprint =
        entity.items
            .where((i) => i.status == ChangeItemStatus.pending)
            .map(ChangeItem.fingerprint)
            .toList()
          ..sort();

    // Sets with no pending items are fully resolved — keep each one
    // individually (keyed by entity ID) to avoid collapsing unrelated sets.
    final key = fingerprint.isEmpty ? entity.id : fingerprint.join('|');

    final existing = seen[key];
    if (existing == null) {
      seen[key] = entity;
    } else if (existing is ChangeSetEntity &&
        entity.createdAt.isAfter(existing.createdAt)) {
      seen[key] = entity;
    }
  }

  return seen.values.toList();
}

/// Fetches pending (and partially resolved) change sets for a given project.
final projectPendingChangeSetsProvider = FutureProvider.autoDispose
    .family<List<AgentDomainEntity>, String>((ref, projectId) async {
      final agent = await ref.watch(projectAgentProvider(projectId).future);
      final identity = agent?.mapOrNull(agent: (a) => a);
      if (identity == null) return [];

      ref.watch(agentUpdateStreamProvider(identity.agentId));

      final repo = ref.watch(agentRepositoryProvider);
      // Project-targeted change sets still persist their target entity ID in
      // the historical `taskId` field.
      final sets = await repo.getPendingChangeSets(
        identity.agentId,
        taskId: projectId,
      );
      return _deduplicateChangeSets(sets);
    });

/// Fetches accepted project recommendations that were explicitly confirmed.
final projectAcceptedRecommendationsProvider = FutureProvider.autoDispose
    .family<List<ProjectAcceptedRecommendation>, String>((
      ref,
      projectId,
    ) async {
      final agent = await ref.watch(projectAgentProvider(projectId).future);
      final identity = agent?.mapOrNull(agent: (a) => a);
      if (identity == null) return const [];

      ref.watch(agentUpdateStreamProvider(identity.agentId));

      final repo = ref.watch(agentRepositoryProvider);
      // Change decisions share the same historical `taskId` storage field for
      // both task and project targets.
      final decisions = await repo.getRecentDecisions(
        identity.agentId,
        taskId: projectId,
        limit: 20,
      );

      return _extractAcceptedRecommendations(decisions);
    });

List<ProjectAcceptedRecommendation> _extractAcceptedRecommendations(
  Iterable<ChangeDecisionEntity> decisions,
) {
  final recommendations = <ProjectAcceptedRecommendation>[];

  for (final decision in decisions) {
    if (decision.verdict != ChangeDecisionVerdict.confirmed ||
        decision.toolName != ProjectAgentToolNames.recommendNextSteps) {
      continue;
    }

    final rawSteps = decision.args?['steps'];
    if (rawSteps is! List) continue;

    for (final rawStep in rawSteps) {
      if (rawStep is! Map) continue;

      final title = rawStep['title'];
      if (title is! String || title.trim().isEmpty) continue;

      final rationale = rawStep['rationale'];
      final priority = rawStep['priority'];

      recommendations.add(
        ProjectAcceptedRecommendation(
          title: title.trim(),
          rationale: rationale is String && rationale.trim().isNotEmpty
              ? rationale.trim()
              : null,
          priority: priority is String && priority.trim().isNotEmpty
              ? priority.trim().toUpperCase()
              : null,
        ),
      );
    }
  }

  return recommendations;
}

/// Provides a [ChangeSetConfirmationService] with all dependencies resolved.
@riverpod
ChangeSetConfirmationService changeSetConfirmationService(Ref ref) {
  final labelsRepository = ref.watch(labelsRepositoryProvider);
  final logger = ref.watch(domainLoggerProvider);
  return ChangeSetConfirmationService(
    syncService: ref.watch(agentSyncServiceProvider),
    toolDispatcher: TaskToolDispatcher(
      journalDb: ref.watch(journalDbProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      checklistRepository: ref.watch(checklistRepositoryProvider),
      labelsRepository: labelsRepository,
      persistenceLogic: getIt<PersistenceLogic>(),
      timeService: getIt<TimeService>(),
      domainLogger: logger,
      taskAgentService: ref.watch(taskAgentServiceProvider),
    ),
    labelsRepository: labelsRepository,
    domainLogger: logger,
  );
}

/// Project-scoped confirmation service for confirmed project-agent proposals.
final projectChangeSetConfirmationServiceProvider =
    Provider<ChangeSetConfirmationService>((ref) {
      final labelsRepository = ref.watch(labelsRepositoryProvider);
      final logger = ref.watch(domainLoggerProvider);
      return ChangeSetConfirmationService(
        syncService: ref.watch(agentSyncServiceProvider),
        toolDispatcher: ProjectToolDispatcher(
          projectRepository: ref.watch(projectRepositoryProvider),
          persistenceLogic: getIt<PersistenceLogic>(),
          entitiesCacheService: getIt<EntitiesCacheService>(),
          domainLogger: logger,
          taskAgentService: ref.watch(taskAgentServiceProvider),
        ),
        labelsRepository: labelsRepository,
        domainLogger: logger,
      );
    });
