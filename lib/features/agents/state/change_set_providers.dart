import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
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
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
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
final FutureProviderFamily<List<AgentDomainEntity>, String>
projectPendingChangeSetsProvider = FutureProvider.autoDispose
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

final projectRecommendationServiceProvider =
    Provider<ProjectRecommendationService>(
      (ref) {
        final notifications =
            ref.watch(maybeUpdateNotificationsProvider) ??
            UpdateNotifications();
        return ProjectRecommendationService(
          syncService: ref.watch(agentSyncServiceProvider),
          notifications: notifications,
          domainLogger: ref.watch(domainLoggerProvider),
        );
      },
    );

/// Fetches active project recommendations for a given project agent.
final FutureProviderFamily<List<ProjectRecommendationEntity>, String>
projectRecommendationsProvider = FutureProvider.autoDispose
    .family<List<ProjectRecommendationEntity>, String>((ref, projectId) async {
      final agent = await ref.watch(projectAgentProvider(projectId).future);
      final identity = agent?.mapOrNull(agent: (a) => a);
      if (identity == null) return const [];

      ref.watch(agentUpdateStreamProvider(identity.agentId));

      final repo = ref.watch(agentRepositoryProvider);
      final entities = await repo.getEntitiesByAgentId(
        identity.agentId,
        type: AgentEntityTypes.projectRecommendation,
      );

      final recommendations =
          entities
              .whereType<ProjectRecommendationEntity>()
              .where(
                (recommendation) =>
                    recommendation.projectId == projectId &&
                    recommendation.status == ProjectRecommendationStatus.active,
              )
              .toList()
            ..sort((a, b) {
              final updatedAtOrder = b.updatedAt.compareTo(a.updatedAt);
              if (updatedAtOrder != 0) {
                return updatedAtOrder;
              }
              return a.position.compareTo(b.position);
            });

      return recommendations;
    });

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
      projectRepository: ref.watch(projectRepositoryProvider),
    ).dispatch,
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
        ).dispatch,
        labelsRepository: labelsRepository,
        domainLogger: logger,
        onConfirmedDecision:
            ({
              required changeSet,
              required item,
              required decision,
            }) async {
              if (item.toolName != ProjectAgentToolNames.recommendNextSteps) {
                return;
              }

              await ref
                  .read(projectRecommendationServiceProvider)
                  .recordConfirmedRecommendations(
                    changeSet: changeSet,
                    decision: decision,
                  );
            },
      );
    });
