import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';

/// Presentation model for a project record displayed in the project
/// list/detail layout.
class ProjectRecord {
  const ProjectRecord({
    required this.project,
    required this.category,
    required this.healthScore,
    required this.healthMetrics,
    required this.reportNextWakeAt,
    required this.completedTaskCount,
    required this.totalTaskCount,
    required this.blockedTaskCount,
    required this.aiSummary,
    required this.reportContent,
    required this.recommendations,
    required this.reportUpdatedAt,
    required this.highlightedTaskSummaries,
    required this.reviewSessions,
    required this.highlightedTasksTotalDuration,
  });

  final ProjectEntry project;
  final CategoryDefinition? category;
  final int healthScore;
  final ProjectHealthMetrics? healthMetrics;
  final DateTime? reportNextWakeAt;
  final int completedTaskCount;
  final int totalTaskCount;
  final int blockedTaskCount;
  final String aiSummary;
  final String reportContent;
  final List<String> recommendations;
  final DateTime reportUpdatedAt;
  final List<TaskSummary> highlightedTaskSummaries;
  final List<ReviewSession> reviewSessions;
  final Duration highlightedTasksTotalDuration;

  ProjectListItemData get overviewListItem => ProjectListItemData(
    project: project,
    category: category,
    taskRollup: ProjectTaskRollupData(
      totalTaskCount: totalTaskCount,
      completedTaskCount: completedTaskCount,
      blockedTaskCount: blockedTaskCount,
    ),
  );
}

/// A task together with its estimated duration for display in project panels.
class TaskSummary {
  const TaskSummary({
    required this.task,
    required this.estimatedDuration,
  });

  final Task task;
  final Duration estimatedDuration;
}

/// The type of metric recorded in a review session.
enum ReviewMetricType {
  communication,
  usefulness,
  accuracy,
}

/// A single rated metric inside a [ReviewSession].
class ReviewMetric {
  const ReviewMetric({
    required this.type,
    required this.rating,
  });

  final ReviewMetricType type;
  final int rating;
}

/// A review session with an overall rating, optional per-metric breakdown,
/// and an optional note.
class ReviewSession {
  const ReviewSession({
    required this.id,
    required this.summaryLabel,
    required this.rating,
    this.metrics = const [],
    this.note,
    this.expanded = false,
  });

  final String id;
  final String summaryLabel;
  final int rating;
  final List<ReviewMetric> metrics;
  final String? note;
  final bool expanded;
}

/// Top-level container for the data powering the project list/detail layout.
class ProjectListData {
  const ProjectListData({
    required this.categories,
    required this.projects,
    required this.currentTime,
  });

  final List<CategoryDefinition> categories;
  final List<ProjectRecord> projects;
  final DateTime currentTime;

  ProjectsOverviewSnapshot get overviewSnapshot {
    final recordsByCategory = <String, List<ProjectRecord>>{};
    for (final record in projects) {
      (recordsByCategory[record.category.id] ??= <ProjectRecord>[]).add(record);
    }

    return ProjectsOverviewSnapshot(
      groups: [
        for (final category in categories)
          if (recordsByCategory[category.id]?.isNotEmpty ?? false)
            ProjectCategoryGroup(
              categoryId: category.id,
              category: category,
              projects: recordsByCategory[category.id]!
                  .map((record) => record.overviewListItem)
                  .toList(growable: false),
            ),
      ],
    );
  }
}
