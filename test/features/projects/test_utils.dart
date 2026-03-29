import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/utils/file_utils.dart';

import '../../features/categories/test_utils.dart';

/// Shared test factory for creating [ProjectEntry] instances.
///
/// All parameters have sensible defaults to keep call sites concise.
ProjectEntry makeTestProject({
  String? id,
  String title = 'Test Project',
  ProjectStatus? status,
  String? categoryId,
  DateTime? targetDate,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2024, 3, 15);
  return JournalEntity.project(
        meta: Metadata(
          id: id ?? uuid.v1(),
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
          categoryId: categoryId,
        ),
        data: ProjectData(
          title: title,
          status:
              status ??
              ProjectStatus.open(
                id: uuid.v1(),
                createdAt: now,
                utcOffset: 0,
              ),
          dateFrom: now,
          dateTo: now,
          targetDate: targetDate,
        ),
      )
      as ProjectEntry;
}

/// Shared test factory for creating [Task] instances.
///
/// All parameters have sensible defaults to keep call sites concise.
Task makeTestTask({
  String? id,
  String title = 'Test Task',
  String? projectId,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2024, 3, 15);
  return JournalEntity.task(
        meta: Metadata(
          id: id ?? uuid.v1(),
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
        data: TaskData(
          title: title,
          status: TaskStatus.open(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: ''),
      )
      as Task;
}

/// Shared test factory for creating [ProjectHealthMetrics] instances.
ProjectHealthMetrics makeTestProjectHealthMetrics({
  ProjectHealthBand band = ProjectHealthBand.onTrack,
  String rationale = 'The project is moving in the right direction.',
  double? confidence,
}) {
  return ProjectHealthMetrics(
    band: band,
    rationale: rationale,
    confidence: confidence,
  );
}

/// Creates a [ProjectRecord] presentation model for testing.
ProjectRecord makeTestProjectRecord({
  ProjectEntry? project,
  CategoryDefinition? category,
  int healthScore = 78,
  ProjectHealthMetrics? healthMetrics,
  DateTime? reportNextWakeAt,
  int completedTaskCount = 3,
  int totalTaskCount = 5,
  int blockedTaskCount = 1,
  String aiSummary = 'Test AI summary.',
  String? reportContent,
  List<String> recommendations = const ['Recommendation A'],
  DateTime? reportUpdatedAt,
  List<TaskSummary> highlightedTaskSummaries = const [],
  List<ReviewSession> reviewSessions = const [],
  Duration highlightedTasksTotalDuration = Duration.zero,
}) {
  final cat =
      category ??
      CategoryTestUtils.createTestCategory(
        id: 'cat-1',
        name: 'Work',
        color: '#4AB6E8',
      );
  return ProjectRecord(
    project:
        project ??
        makeTestProject(
          id: 'project-1',
          categoryId: cat.id,
        ),
    category: cat,
    healthScore: healthScore,
    healthMetrics: healthMetrics,
    reportNextWakeAt: reportNextWakeAt,
    completedTaskCount: completedTaskCount,
    totalTaskCount: totalTaskCount,
    blockedTaskCount: blockedTaskCount,
    aiSummary: aiSummary,
    reportContent: reportContent ?? aiSummary,
    recommendations: recommendations,
    reportUpdatedAt: reportUpdatedAt ?? DateTime(2026, 4, 2, 7, 30),
    highlightedTaskSummaries: highlightedTaskSummaries,
    reviewSessions: reviewSessions,
    highlightedTasksTotalDuration: highlightedTasksTotalDuration,
  );
}

/// Creates a [ProjectListItemData] for the shared projects overview/list UI.
ProjectListItemData makeTestProjectListItemData({
  ProjectEntry? project,
  CategoryDefinition? category,
  int completedTaskCount = 3,
  int totalTaskCount = 5,
  int blockedTaskCount = 1,
}) {
  final record = makeTestProjectRecord(
    project: project,
    category: category,
    completedTaskCount: completedTaskCount,
    totalTaskCount: totalTaskCount,
    blockedTaskCount: blockedTaskCount,
  );
  return record.overviewListItem;
}

/// Creates a [TaskSummary] for testing.
TaskSummary makeTestTaskSummary({
  Task? task,
  Duration estimatedDuration = const Duration(hours: 2),
  String? oneLiner = 'Implementation phase done, release next',
}) {
  return TaskSummary(
    task: task ?? makeTestTask(id: 'task-1'),
    estimatedDuration: estimatedDuration,
    oneLiner: oneLiner,
  );
}

/// Creates a [ReviewSession] for testing.
ReviewSession makeTestReviewSession({
  String id = 'review-1',
  String summaryLabel = 'Week 11 · Mar 10',
  int rating = 4,
  List<ReviewMetric> metrics = const [],
  String? note,
  bool expanded = false,
}) {
  return ReviewSession(
    id: id,
    summaryLabel: summaryLabel,
    rating: rating,
    metrics: metrics,
    note: note,
    expanded: expanded,
  );
}

/// Creates a [ProjectListData] for testing with two categories and two
/// projects.
ProjectListData makeTestProjectListData({
  List<CategoryDefinition>? categories,
  List<ProjectRecord>? projects,
  DateTime? currentTime,
}) {
  final time = currentTime ?? DateTime(2026, 4, 2, 9, 30);
  final workCat = CategoryTestUtils.createTestCategory(
    id: 'work',
    name: 'Work',
    color: '#4AB6E8',
  );
  final studyCat = CategoryTestUtils.createTestCategory(
    id: 'study',
    name: 'Study',
    color: '#FBA337',
  );

  return ProjectListData(
    categories: categories ?? [workCat, studyCat],
    currentTime: time,
    projects:
        projects ??
        [
          makeTestProjectRecord(
            project: makeTestProject(
              id: 'p1',
              title: 'Project Alpha',
              categoryId: 'work',
            ),
            category: workCat,
          ),
          makeTestProjectRecord(
            project: makeTestProject(
              id: 'p2',
              title: 'Project Beta',
              categoryId: 'study',
            ),
            category: studyCat,
          ),
        ],
  );
}
