// ignore_for_file: specify_nonobvious_property_types

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/services/db_notification.dart';

/// Provider that fetches projects for a category and auto-rebuilds on changes.
final projectsForCategoryProvider = FutureProvider.autoDispose
    .family<List<ProjectEntry>, String>((ref, categoryId) async {
      final repository = ref.watch(projectRepositoryProvider);

      // Rebuild when any project-related notification fires.
      final sub = repository.updateStream
          .where((ids) => ids.contains(projectNotification))
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);

      return repository.getProjectsForCategory(categoryId);
    });

/// Provider that returns the latest agent-authored health metrics for a
/// project, parsed from its most recent project-agent report.
final projectHealthMetricsProvider = FutureProvider.autoDispose
    .family<ProjectHealthMetrics?, String>((
      ref,
      projectId,
    ) async {
      final agentEntity = await ref.watch(
        projectAgentProvider(projectId).future,
      );
      final identity = switch (agentEntity) {
        final AgentIdentityEntity value => value,
        _ => null,
      };
      if (identity == null) return null;

      final reportEntity = await ref.watch(
        agentReportProvider(identity.agentId).future,
      );
      final report = switch (reportEntity) {
        final AgentReportEntity value => value,
        _ => null,
      };
      if (report == null) return null;

      return projectHealthMetricsFromReport(report);
    });

/// Provider that fetches the project a task belongs to.
final projectForTaskProvider = FutureProvider.autoDispose
    .family<ProjectEntry?, String>((ref, taskId) async {
      final repository = ref.watch(projectRepositoryProvider);

      final sub = repository.updateStream
          .where(
            (ids) => ids.contains(taskId) || ids.contains(projectNotification),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);

      return repository.getProjectForTask(taskId);
    });

/// Keep-alive filter controller for the top-level projects tab.
final projectsFilterControllerProvider =
    NotifierProvider<ProjectsFilterController, ProjectsFilter>(
      ProjectsFilterController.new,
    );

/// Holds the live Projects-tab filter ([ProjectsFilter]) and exposes targeted
/// mutators for the status/category chips, the search field, and the filter
/// sheet.
///
/// The provider is kept alive (not auto-disposed) so filter selections survive
/// navigation away from and back to the tab. [visibleProjectGroupsProvider]
/// re-applies this state to the raw overview snapshot whenever it changes.
class ProjectsFilterController extends Notifier<ProjectsFilter> {
  @override
  ProjectsFilter build() => const ProjectsFilter(
    selectedStatusIds: currentProjectStatusFilterIds,
  );

  ProjectsFilter get filter => state;

  set filter(ProjectsFilter filter) {
    state = filter;
  }

  void setSelectedStatusIds(Set<String> statusIds) {
    state = state.copyWith(selectedStatusIds: statusIds);
  }

  void setSelectedCategoryIds(Set<String> categoryIds) {
    state = state.copyWith(selectedCategoryIds: categoryIds);
  }

  void setSortMode(ProjectsSortMode sortMode) {
    state = state.copyWith(sortMode: sortMode);
  }

  void resetToCurrent() {
    state = const ProjectsFilter(
      selectedStatusIds: currentProjectStatusFilterIds,
    );
  }

  /// Updates the search text and derives the [ProjectsSearchMode]: an empty
  /// (whitespace-only) query disables text matching, otherwise it switches to
  /// in-memory `localText` substring matching.
  void setTextQuery(String textQuery) {
    final normalizedQuery = textQuery.trim();
    state = state.copyWith(
      textQuery: textQuery,
      searchMode: normalizedQuery.isEmpty
          ? ProjectsSearchMode.disabled
          : ProjectsSearchMode.localText,
    );
  }
}

/// Raw grouped projects snapshot for the top-level tab.
final _projectOneLinerCacheProvider = Provider<Map<String, String?>>(
  (ref) => <String, String?>{},
);

final projectsOverviewProvider =
    StreamProvider.autoDispose<ProjectsOverviewSnapshot>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      final agentRepository = ref.watch(agentRepositoryProvider);
      final oneLinerCache = ref.watch(_projectOneLinerCacheProvider);
      ref.watch(agentUpdateStreamProvider(agentNotification));
      return repository
          .watchProjectsOverview(query: const ProjectsQuery())
          .asyncMap(
            (snapshot) async {
              try {
                final enriched = await _attachProjectOneLiners(
                  snapshot,
                  agentRepository,
                );
                _replaceProjectOneLinerCache(oneLinerCache, enriched);
                return enriched;
              } catch (error, stackTrace) {
                // Agent summaries are optional enrichment. A failed sidecar
                // read must not replace the established list with an error.
                developer.log(
                  'Failed to attach project agent one-liners',
                  name: 'projectsOverviewProvider',
                  error: error,
                  stackTrace: stackTrace,
                );
                return _restoreCachedProjectOneLiners(
                  snapshot,
                  oneLinerCache,
                );
              }
            },
          );
    });

void _replaceProjectOneLinerCache(
  Map<String, String?> cache,
  ProjectsOverviewSnapshot snapshot,
) {
  cache
    ..clear()
    ..addEntries(
      snapshot.groups.expand(
        (group) => group.projects.map(
          (item) => MapEntry(item.project.meta.id, item.oneLiner),
        ),
      ),
    );
}

ProjectsOverviewSnapshot _restoreCachedProjectOneLiners(
  ProjectsOverviewSnapshot snapshot,
  Map<String, String?> cache,
) {
  return ProjectsOverviewSnapshot(
    groups: [
      for (final group in snapshot.groups)
        group.copyWith(
          projects: [
            for (final item in group.projects)
              ProjectListItemData(
                project: item.project,
                category: item.category,
                taskRollup: item.taskRollup,
                oneLiner: cache[item.project.meta.id] ?? item.oneLiner,
              ),
          ],
        ),
    ],
  );
}

Future<ProjectsOverviewSnapshot> _attachProjectOneLiners(
  ProjectsOverviewSnapshot snapshot,
  AgentRepository agentRepository,
) async {
  final projectIds = [
    for (final group in snapshot.groups)
      for (final item in group.projects) item.project.meta.id,
  ];
  if (projectIds.isEmpty) return snapshot;

  final linksByProjectId = await agentRepository.getLinksToMultiple(
    projectIds,
    type: AgentLinkTypes.agentProject,
  );
  final agentIdsByProjectId = <String, String>{};
  final agentIds = <String>{};
  for (final entry in linksByProjectId.entries) {
    if (entry.value.isEmpty) continue;
    final agentId = entry.value.selectPrimary().fromId;
    agentIdsByProjectId[entry.key] = agentId;
    agentIds.add(agentId);
  }
  if (agentIds.isEmpty) return snapshot;

  final reportsByAgentId = await agentRepository.getLatestReportsByAgentIds(
    agentIds.toList(growable: false),
    AgentReportScopes.current,
  );
  return ProjectsOverviewSnapshot(
    groups: [
      for (final group in snapshot.groups)
        group.copyWith(
          projects: [
            for (final item in group.projects)
              ProjectListItemData(
                project: item.project,
                category: item.category,
                taskRollup: item.taskRollup,
                oneLiner:
                    reportsByAgentId[agentIdsByProjectId[item.project.meta.id]]
                        ?.oneLiner
                        ?.trim(),
              ),
          ],
        ),
    ],
  );
}

/// Applies the provider-layer filtering model to the raw snapshot.
final visibleProjectGroupsProvider =
    Provider.autoDispose<AsyncValue<List<ProjectCategoryGroup>>>((ref) {
      final overviewAsync = ref.watch(projectsOverviewProvider);
      final filter = ref.watch(projectsFilterControllerProvider);

      return overviewAsync.whenData(
        (overview) => applyProjectsFilter(overview, filter),
      );
    });
