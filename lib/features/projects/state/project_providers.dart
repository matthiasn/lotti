// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
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

class ProjectsFilterController extends Notifier<ProjectsFilter> {
  @override
  ProjectsFilter build() => const ProjectsFilter();

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

  void setTextQuery(String textQuery) {
    final normalizedQuery = textQuery.trim();
    state = state.copyWith(
      textQuery: textQuery,
      searchMode: normalizedQuery.isEmpty
          ? ProjectsSearchMode.disabled
          : ProjectsSearchMode.localText,
    );
  }

  void setSearchMode(ProjectsSearchMode searchMode) {
    state = state.copyWith(searchMode: searchMode);
  }

  void clear() {
    state = const ProjectsFilter();
  }
}

/// Raw grouped projects snapshot for the top-level tab.
final projectsOverviewProvider =
    StreamProvider.autoDispose<ProjectsOverviewSnapshot>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      return repository.watchProjectsOverview(query: const ProjectsQuery());
    });

/// Applies the provider-layer filtering model to the raw snapshot.
final visibleProjectGroupsProvider =
    Provider.autoDispose<AsyncValue<List<ProjectCategoryGroup>>>((ref) {
      final overviewAsync = ref.watch(projectsOverviewProvider);
      final filter = ref.watch(projectsFilterControllerProvider);

      return overviewAsync.whenData(
        (overview) => applyProjectsFilter(overview, filter),
      );
    });
