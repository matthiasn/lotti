import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Default CSS hex colour used when a category has no colour assigned.
const defaultCategoryColorHex = '#4AB6E8';

/// Presentation model for a project record displayed in the project
/// list/detail layout.
class ProjectRecord {
  const ProjectRecord({
    required this.project,
    required this.category,
    required this.healthScore,
    required this.completedTaskCount,
    required this.totalTaskCount,
    required this.blockedTaskCount,
    required this.aiSummary,
    required this.recommendations,
    required this.reportUpdatedAt,
    required this.highlightedTaskSummaries,
    required this.reviewSessions,
    required this.highlightedTasksTotalDuration,
  });

  final ProjectEntry project;
  final CategoryDefinition category;
  final int healthScore;
  final int completedTaskCount;
  final int totalTaskCount;
  final int blockedTaskCount;
  final String aiSummary;
  final List<String> recommendations;
  final DateTime reportUpdatedAt;
  final List<TaskSummary> highlightedTaskSummaries;
  final List<ReviewSession> reviewSessions;
  final Duration highlightedTasksTotalDuration;
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

/// A named group of projects (typically one per category).
class ProjectGroup {
  const ProjectGroup({
    required this.label,
    required this.projects,
  });

  final String label;
  final List<ProjectRecord> projects;
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
}
