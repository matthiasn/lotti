// ignore_for_file: specify_nonobvious_property_types

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

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
      final linkedTasks = [...detailState.linkedTasks]..sort(_compareTasks);

      final (metrics, agent, recommendations) = await (
        ref.watch(projectHealthMetricsProvider(projectId).future),
        ref.watch(projectAgentProvider(projectId).future),
        ref.watch(projectRecommendationsProvider(projectId).future),
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
        agentState: (value) => value.nextWakeAt,
      );

      final aiSummary = _resolveAiSummary(project, report);

      final completedTaskCount = linkedTasks.where(_isCompletedTask).length;
      final blockedTaskCount = linkedTasks.where(_isBlockedTask).length;

      return ProjectRecord(
        project: project,
        category: category,
        healthScore: _healthScoreFromMetrics(metrics),
        healthMetrics: metrics,
        reportNextWakeAt: nextWakeAt,
        completedTaskCount: completedTaskCount,
        totalTaskCount: linkedTasks.length,
        blockedTaskCount: blockedTaskCount,
        aiSummary: aiSummary,
        reportContent: report?.content.trim() ?? aiSummary,
        recommendations: recommendations.map((item) => item.title).toList(),
        reportUpdatedAt: report?.createdAt ?? project.meta.updatedAt,
        highlightedTaskSummaries: linkedTasks
            .map(
              (task) => TaskSummary(
                task: task,
                estimatedDuration: task.data.estimate ?? Duration.zero,
              ),
            )
            .toList(growable: false),
        reviewSessions: const [],
        highlightedTasksTotalDuration: linkedTasks.fold(
          Duration.zero,
          (sum, task) => sum + (task.data.estimate ?? Duration.zero),
        ),
      );
    });

String _resolveAiSummary(ProjectEntry project, AgentReportEntity? report) {
  final candidates = [
    report?.tldr,
    project.entryText?.plainText,
  ];

  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }

  return '';
}

bool _isCompletedTask(Task task) => switch (task.data.status) {
  TaskDone() => true,
  _ => false,
};

bool _isBlockedTask(Task task) => switch (task.data.status) {
  TaskBlocked() => true,
  _ => false,
};

int _compareTasks(Task left, Task right) {
  final statusOrder = _taskStatusRank(left.data.status).compareTo(
    _taskStatusRank(right.data.status),
  );
  if (statusOrder != 0) {
    return statusOrder;
  }

  final leftDue = left.data.due;
  final rightDue = right.data.due;
  if (leftDue != null || rightDue != null) {
    if (leftDue == null) return 1;
    if (rightDue == null) return -1;
    final dueOrder = leftDue.compareTo(rightDue);
    if (dueOrder != 0) {
      return dueOrder;
    }
  }

  final leftEstimate = left.data.estimate ?? Duration.zero;
  final rightEstimate = right.data.estimate ?? Duration.zero;
  final estimateOrder = rightEstimate.compareTo(leftEstimate);
  if (estimateOrder != 0) {
    return estimateOrder;
  }

  return left.data.title.toLowerCase().compareTo(
    right.data.title.toLowerCase(),
  );
}

int _taskStatusRank(TaskStatus status) => switch (status) {
  TaskBlocked() => 0,
  TaskOnHold() => 1,
  TaskInProgress() => 2,
  TaskOpen() => 3,
  TaskGroomed() => 4,
  TaskDone() => 5,
  TaskRejected() => 6,
};

int _healthScoreFromMetrics(ProjectHealthMetrics? metrics) {
  final base = switch (metrics?.band) {
    ProjectHealthBand.onTrack => 90,
    ProjectHealthBand.surviving => 78,
    ProjectHealthBand.watch => 64,
    ProjectHealthBand.atRisk => 42,
    ProjectHealthBand.blocked => 18,
    null => 0,
  };
  final adjustment = switch (metrics?.confidence) {
    final double confidence => ((confidence - 0.5) * 12).round(),
    null => 0,
  };

  return (base + adjustment).clamp(0, 100);
}

final projectDetailNowProvider = Provider<DateTime Function()>(
  (_) => clock.now,
);
