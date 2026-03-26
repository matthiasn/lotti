// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/services/db_notification.dart';

/// Sort options for category-scoped project health overviews.
enum ProjectHealthOverviewSort {
  worstBandFirst,
  bestBandFirst,
  title,
}

/// Aggregated project-health state for a single project.
@immutable
class ProjectHealthSnapshot {
  const ProjectHealthSnapshot({
    required this.projectId,
    required this.metrics,
    required this.summary,
    required this.recommendations,
  });

  final String projectId;
  final ProjectHealthMetrics? metrics;
  final ProjectAgentSummaryState? summary;
  final List<ProjectRecommendationEntity> recommendations;

  ProjectHealthBand? get healthBand => metrics?.band;
  bool get isSummaryOutdated => summary?.isSummaryOutdated ?? false;
  DateTime? get scheduledWakeAt => summary?.scheduledWakeAt;
}

/// Category list entry that pairs a project with its aggregated health state.
@immutable
class ProjectHealthOverviewEntry {
  const ProjectHealthOverviewEntry({
    required this.project,
    required this.snapshot,
  });

  final ProjectEntry project;
  final ProjectHealthSnapshot snapshot;

  ProjectHealthBand? get healthBand => snapshot.healthBand;
}

/// Filters and sorts project health overview entries for dashboard surfaces.
List<ProjectHealthOverviewEntry> queryProjectHealthOverviewEntries(
  Iterable<ProjectHealthOverviewEntry> entries, {
  Set<ProjectHealthBand> includedBands = const {},
  ProjectHealthOverviewSort sort = ProjectHealthOverviewSort.worstBandFirst,
  bool includeWithoutHealth = true,
}) {
  final filtered = entries.where((entry) {
    final band = entry.healthBand;
    if (band == null) {
      return includeWithoutHealth;
    }
    return includedBands.isEmpty || includedBands.contains(band);
  }).toList();

  int tieBreak(
    ProjectHealthOverviewEntry left,
    ProjectHealthOverviewEntry right,
  ) {
    final titleOrder = left.project.data.title.toLowerCase().compareTo(
      right.project.data.title.toLowerCase(),
    );
    if (titleOrder != 0) return titleOrder;
    return left.project.meta.id.compareTo(right.project.meta.id);
  }

  filtered.sort((left, right) {
    final order = switch (sort) {
      ProjectHealthOverviewSort.worstBandFirst => compareProjectHealthBands(
        left.healthBand,
        right.healthBand,
      ),
      ProjectHealthOverviewSort.bestBandFirst => compareProjectHealthBands(
        left.healthBand,
        right.healthBand,
        worstFirst: false,
      ),
      ProjectHealthOverviewSort.title =>
        left.project.data.title.toLowerCase().compareTo(
          right.project.data.title.toLowerCase(),
        ),
    };

    return order == 0 ? tieBreak(left, right) : order;
  });

  return filtered;
}

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

/// Provider that returns the number of tasks linked to a project.
final projectTaskCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, projectId) async {
    final repository = ref.watch(projectRepositoryProvider);

    final sub = repository.updateStream
        .where(
          (ids) => ids.contains(projectId) || ids.contains(projectNotification),
        )
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);

    final tasks = await repository.getTasksForProject(projectId);
    return tasks.length;
  },
);

/// Provider that returns the latest agent-authored health snapshot.
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

/// Provider that aggregates the project health band, stale state, and active
/// recommendations for a single project.
final projectHealthSnapshotProvider = FutureProvider.autoDispose
    .family<ProjectHealthSnapshot, String>((ref, projectId) async {
      final (metrics, summary, recommendations) = await (
        ref.watch(projectHealthMetricsProvider(projectId).future),
        ref.watch(projectAgentSummaryProvider(projectId).future),
        ref.watch(projectRecommendationsProvider(projectId).future),
      ).wait;

      return ProjectHealthSnapshot(
        projectId: projectId,
        metrics: metrics,
        summary: summary,
        recommendations: recommendations,
      );
    });

/// Provider that prepares all health-dashboard data for projects in a category.
///
/// Results are sorted worst-band-first by default so the most urgent projects
/// rise to the top for future dashboard surfaces.
final projectHealthOverviewEntriesProvider = FutureProvider.autoDispose
    .family<List<ProjectHealthOverviewEntry>, String>((ref, categoryId) async {
      final projects = await ref.watch(
        projectsForCategoryProvider(categoryId).future,
      );

      final snapshots = await Future.wait(
        projects.map(
          (project) => ref.watch(
            projectHealthSnapshotProvider(project.meta.id).future,
          ),
        ),
      );

      return queryProjectHealthOverviewEntries([
        for (final entry in projects.indexed)
          ProjectHealthOverviewEntry(
            project: entry.$2,
            snapshot: snapshots[entry.$1],
          ),
      ]);
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

  void setSelectedCategoryIds(Set<String> categoryIds) {
    state = state.copyWith(selectedCategoryIds: categoryIds);
  }

  void setTextQuery(String textQuery) {
    state = state.copyWith(textQuery: textQuery);
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
        (overview) => _applyProjectsFilter(overview, filter),
      );
    });

List<ProjectCategoryGroup> _applyProjectsFilter(
  ProjectsOverviewSnapshot overview,
  ProjectsFilter filter,
) {
  final selectedCategoryIds = filter.selectedCategoryIds;
  final normalizedQuery = filter.textQuery.trim().toLowerCase();
  final shouldApplyTextQuery =
      normalizedQuery.isNotEmpty &&
      filter.searchMode == ProjectsSearchMode.localText;

  return overview.groups
      .where(
        (group) =>
            selectedCategoryIds.isEmpty ||
            (group.categoryId != null &&
                selectedCategoryIds.contains(group.categoryId)),
      )
      .map((group) {
        if (!shouldApplyTextQuery) {
          return group;
        }

        final filteredProjects = group.projects
            .where(
              (project) => project.searchableText.toLowerCase().contains(
                normalizedQuery,
              ),
            )
            .toList(growable: false);
        return group.copyWith(projects: filteredProjects);
      })
      .where((group) => group.projects.isNotEmpty)
      .toList(growable: false);
}
