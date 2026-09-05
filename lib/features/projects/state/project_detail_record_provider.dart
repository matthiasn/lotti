// ignore_for_file: specify_nonobvious_property_types

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_groups.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Composes the read-model ([ProjectRecord]) that `ProjectDetailsPage` renders.
///
/// Joins the editable project from [projectDetailControllerProvider] with the
/// category, the latest project-agent report/state (health band, AI summary,
/// next scheduled wake), and the linked tasks — sorted by [compareTasksByActionability] and
/// decorated with their per-task one-liners and a rolled-up estimate total.
/// Recommendation UI watches its own provider separately. Returns `null` when
/// the project no longer exists. Because this provider watches the controller,
/// edits and background DB notifications recompute the record automatically.
final projectDetailRecordProvider = FutureProvider.autoDispose
    .family<ProjectRecord?, String>((
      ref,
      projectId,
    ) async {
      final detailState = ref.watch(projectDetailControllerProvider(projectId));
      final project = detailState.project;
      if (project == null) {
        return null;
      }

      final cache = getIt<EntitiesCacheService>();
      final category = cache.getCategoryById(project.meta.categoryId);
      final linkedTasks = [...detailState.linkedTasks]
        ..sort(compareTasksByActionability);
      final agentRepository = ref.watch(agentRepositoryProvider);
      final taskReportsFuture = linkedTasks.isEmpty
          ? Future.value(const <String, AgentReportEntity>{})
          : agentRepository.getLatestTaskReportsForTaskIds(
              linkedTasks.map((task) => task.id).toList(growable: false),
            );

      final (metrics, agent, taskReportsByTaskId) = await (
        ref.watch(projectHealthMetricsProvider(projectId).future),
        ref.watch(projectAgentProvider(projectId).future),
        taskReportsFuture,
      ).wait;

      final identity = agent?.mapOrNull(agent: (value) => value);
      final reportEntity = identity == null
          ? null
          : await ref.watch(agentReportProvider(identity.agentId).future);
      final report = reportEntity?.mapOrNull(agentReport: (value) => value);
      final agentState = identity == null
          ? null
          : await ref.watch(agentStateProvider(identity.agentId).future);
      final nextWakeAt = agentState?.mapOrNull(
        agentState: (value) => value.nextWakeAt ?? value.scheduledWakeAt,
      );

      final aiSummary = _resolveAiSummary(report);

      final completedTaskCount = linkedTasks.where(_isCompletedTask).length;
      final blockedTaskCount = linkedTasks.where(_isBlockedTask).length;

      return ProjectRecord(
        project: project,
        category: category,
        healthMetrics: metrics,
        reportNextWakeAt: nextWakeAt,
        completedTaskCount: completedTaskCount,
        totalTaskCount: linkedTasks.length,
        blockedTaskCount: blockedTaskCount,
        aiSummary: aiSummary,
        reportContent: report?.content.trim() ?? '',
        reportUpdatedAt: report?.createdAt,
        highlightedTaskSummaries: linkedTasks
            .map(
              (task) => TaskSummary(
                task: task,
                estimatedDuration: task.data.estimate ?? Duration.zero,
                oneLiner: switch (taskReportsByTaskId[task.id]?.oneLiner
                    ?.trim()) {
                  final value? when value.isNotEmpty => value,
                  _ => null,
                },
              ),
            )
            .toList(growable: false),
        highlightedTasksTotalDuration: linkedTasks.fold(
          Duration.zero,
          (sum, task) => sum + (task.data.estimate ?? Duration.zero),
        ),
      );
    });

String _resolveAiSummary(AgentReportEntity? report) {
  final summary = report?.tldr?.trim();
  return summary == null || summary.isEmpty ? '' : summary;
}

bool _isCompletedTask(Task task) => switch (task.data.status) {
  TaskDone() => true,
  _ => false,
};

bool _isBlockedTask(Task task) => switch (task.data.status) {
  TaskBlocked() => true,
  _ => false,
};

/// Injectable "current time" source for the detail UI (relative "updated X ago"
/// labels and countdowns). Defaults to `clock.now`; override in tests for
/// deterministic timestamps.
final projectDetailNowProvider = Provider<DateTime Function()>(
  (_) => clock.now,
);
