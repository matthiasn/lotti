// ignore_for_file: specify_nonobvious_property_types

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
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

/// Provider that returns a computed health snapshot for a project.
final projectHealthMetricsProvider = FutureProvider.autoDispose
    .family<ProjectHealthMetrics?, String>((
      ref,
      projectId,
    ) async {
      final repository = ref.watch(projectRepositoryProvider);

      final sub = repository.updateStream
          .where(
            (ids) =>
                ids.contains(projectId) || ids.contains(projectNotification),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);

      final (project, tasks) = await (
        repository.getProjectById(projectId),
        repository.getTasksForProject(projectId),
      ).wait;
      if (project == null) return null;
      final summary = await ref.watch(
        projectAgentSummaryProvider(projectId).future,
      );

      return computeProjectHealthMetrics(
        project: project,
        linkedTasks: tasks,
        agentSummary: summary,
        now: clock.now(),
      );
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
