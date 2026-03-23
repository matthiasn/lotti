import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';

/// User-facing health bands for project overviews.
enum ProjectHealthBand {
  surviving,
  onTrack,
  watch,
  atRisk,
  blocked,
}

/// Structured explanation for why a project received its current health band.
enum ProjectHealthReasonKind {
  projectCompleted,
  projectOnHold,
  stalledTasks,
  overdueTasks,
  targetDatePassed,
  noRecentProgress,
  summaryOutdated,
  noLinkedTasks,
  steadyProgress,
}

@immutable
class ProjectHealthReason {
  const ProjectHealthReason(
    this.kind, {
    this.count,
    this.days,
  });

  final ProjectHealthReasonKind kind;
  final int? count;
  final int? days;
}

@immutable
class ProjectHealthMetrics {
  const ProjectHealthMetrics({
    required this.band,
    required this.score,
    required this.reason,
    required this.totalTaskCount,
    required this.completedTaskCount,
    required this.stalledTaskCount,
    required this.overdueTaskCount,
    required this.isSummaryOutdated,
    required this.targetDatePassed,
    required this.hasRecentTaskUpdate,
  });

  final ProjectHealthBand band;

  /// Internal score used for future ordering/debugging. Not shown directly.
  final int score;
  final ProjectHealthReason reason;
  final int totalTaskCount;
  final int completedTaskCount;
  final int stalledTaskCount;
  final int overdueTaskCount;
  final bool isSummaryOutdated;
  final bool targetDatePassed;
  final bool hasRecentTaskUpdate;
}

/// Computes deterministic health signals for a project and maps them to a
/// user-facing health band.
ProjectHealthMetrics computeProjectHealthMetrics({
  required ProjectEntry project,
  required List<Task> linkedTasks,
  required DateTime now,
  ProjectAgentSummaryState? agentSummary,
}) {
  final projectIsCompleted = _isProjectCompleted(project.data.status);
  final projectIsOnHold = project.data.status is ProjectOnHold;

  final totalTaskCount = linkedTasks.length;
  final completedTaskCount = linkedTasks.where(_isTaskCompleted).length;
  final stalledTaskCount = linkedTasks.where(_isTaskStalled).length;
  final overdueTaskCount = linkedTasks
      .where((task) => !_isTaskCompleted(task) && _isTaskOverdue(task, now))
      .length;
  final activeTaskCount = totalTaskCount - completedTaskCount;

  final targetDatePassed =
      !projectIsCompleted &&
      project.data.targetDate != null &&
      _isDateBeforeToday(project.data.targetDate!, now);

  final latestTaskUpdateAt = linkedTasks
      .map((task) => task.data.status.createdAt)
      .fold<DateTime?>(null, _laterOf);
  final daysSinceLatestTaskUpdate = latestTaskUpdateAt == null
      ? null
      : now.difference(latestTaskUpdateAt).inDays;
  final hasRecentTaskUpdate =
      daysSinceLatestTaskUpdate != null && daysSinceLatestTaskUpdate <= 7;
  final isSummaryOutdated = agentSummary?.isSummaryOutdated ?? false;

  var score = 86;
  if (projectIsCompleted) {
    score = 92;
  } else {
    if (projectIsOnHold) score -= 70;
    score -= stalledTaskCount * 30;
    score -= overdueTaskCount * 18;
    if (targetDatePassed) score -= 14;
    if (activeTaskCount > 0 && !hasRecentTaskUpdate) score -= 18;
    if (isSummaryOutdated) score -= 10;
    if (totalTaskCount == 0) score -= 8;
    if (completedTaskCount > 0 && completedTaskCount == totalTaskCount) {
      score += 4;
    }
  }
  score = math.max(0, math.min(100, score));

  final ProjectHealthBand band;
  final ProjectHealthReason reason;

  if (projectIsCompleted) {
    band = ProjectHealthBand.onTrack;
    reason = const ProjectHealthReason(
      ProjectHealthReasonKind.projectCompleted,
    );
  } else if (projectIsOnHold) {
    band = ProjectHealthBand.blocked;
    reason = const ProjectHealthReason(ProjectHealthReasonKind.projectOnHold);
  } else if (stalledTaskCount > 0) {
    band = ProjectHealthBand.blocked;
    reason = ProjectHealthReason(
      ProjectHealthReasonKind.stalledTasks,
      count: stalledTaskCount,
    );
  } else if (overdueTaskCount > 0) {
    band = ProjectHealthBand.atRisk;
    reason = ProjectHealthReason(
      ProjectHealthReasonKind.overdueTasks,
      count: overdueTaskCount,
    );
  } else if (targetDatePassed) {
    band = ProjectHealthBand.atRisk;
    reason = const ProjectHealthReason(
      ProjectHealthReasonKind.targetDatePassed,
    );
  } else if (activeTaskCount > 0 && !hasRecentTaskUpdate) {
    band = ProjectHealthBand.watch;
    reason = ProjectHealthReason(
      ProjectHealthReasonKind.noRecentProgress,
      days: daysSinceLatestTaskUpdate,
    );
  } else if (totalTaskCount == 0) {
    band = ProjectHealthBand.surviving;
    reason = const ProjectHealthReason(ProjectHealthReasonKind.noLinkedTasks);
  } else if (isSummaryOutdated) {
    band = ProjectHealthBand.surviving;
    reason = const ProjectHealthReason(
      ProjectHealthReasonKind.summaryOutdated,
    );
  } else {
    band = ProjectHealthBand.onTrack;
    reason = const ProjectHealthReason(ProjectHealthReasonKind.steadyProgress);
  }

  return ProjectHealthMetrics(
    band: band,
    score: score,
    reason: reason,
    totalTaskCount: totalTaskCount,
    completedTaskCount: completedTaskCount,
    stalledTaskCount: stalledTaskCount,
    overdueTaskCount: overdueTaskCount,
    isSummaryOutdated: isSummaryOutdated,
    targetDatePassed: targetDatePassed,
    hasRecentTaskUpdate: hasRecentTaskUpdate,
  );
}

bool _isProjectCompleted(ProjectStatus status) =>
    status is ProjectCompleted || status is ProjectArchived;

bool _isTaskCompleted(Task task) =>
    task.data.status is TaskDone || task.data.status is TaskRejected;

bool _isTaskStalled(Task task) =>
    task.data.status is TaskBlocked || task.data.status is TaskOnHold;

bool _isTaskOverdue(Task task, DateTime now) {
  final due = task.data.due;
  if (due == null) return false;
  return _isDateBeforeToday(due, now);
}

bool _isDateBeforeToday(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(date.year, date.month, date.day);
  return targetDay.isBefore(today);
}

DateTime? _laterOf(DateTime? left, DateTime right) {
  if (left == null || right.isAfter(left)) return right;
  return left;
}
