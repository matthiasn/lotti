import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';

ProjectListData buildProjectListDetailMockData() {
  final workCategory = _category(
    id: 'work',
    name: 'Work',
    color: '#4AB6E8',
    icon: CategoryIcon.work,
  );
  final mealsCategory = _category(
    id: 'meals',
    name: 'Meals',
    color: '#7AB889',
    icon: CategoryIcon.cooking,
  );
  final studyCategory = _category(
    id: 'study',
    name: 'Study',
    color: '#FBA337',
    icon: CategoryIcon.school,
  );

  final deviceSync = _project(
    id: 'device-sync',
    categoryId: workCategory.id,
    title: 'Device Sync',
    description:
        'Device Sync establishes real-time synchronisation across all user devices — ensuring journal entries, tasks and daily plans remain consistent and available anywhere. Covers sync engine design, conflict resolution and offline cache support.',
    status: _projectActive(DateTime(2026, 4, 2, 9)),
    targetDate: DateTime(2026, 4, 15),
  );
  final apiMigration = _project(
    id: 'api-migration',
    categoryId: workCategory.id,
    title: 'API Migration',
    description:
        'Move the remaining task endpoints to the consolidated API surface while keeping mobile clients compatible during rollout.',
    status: _projectActive(DateTime(2026, 3, 28, 10)),
    targetDate: DateTime(2026, 6, 30),
  );
  final ciCdPipeline = _project(
    id: 'ci-cd-pipeline',
    categoryId: workCategory.id,
    title: 'CI/CD Pipeline',
    description:
        'Refresh the build, release, and signing pipeline so releases can be produced with fewer manual steps.',
    status: _projectCompleted(DateTime(2026, 3, 20, 8)),
    targetDate: DateTime(2026, 5, 20),
  );
  final weeklyMealPrep = _project(
    id: 'weekly-meal-prep',
    categoryId: mealsCategory.id,
    title: 'Weekly Meal Prep',
    description:
        'Plan and batch-cook weekday lunches, ingredients, and shopping lists for predictable nutrition during the week.',
    status: _projectActive(DateTime(2026, 4, 1, 18)),
    targetDate: null,
  );
  final reactCourse = _project(
    id: 'react-course',
    categoryId: studyCategory.id,
    title: 'React Course',
    description:
        'Finish the remaining lessons on concurrent rendering, routing, and advanced state management patterns.',
    status: _projectArchived(DateTime(2026, 3, 30, 20)),
    targetDate: DateTime(2026, 3, 30),
  );
  final designSystemBook = _project(
    id: 'design-system-book',
    categoryId: studyCategory.id,
    title: 'Design System Book',
    description:
        'Wrap up the final chapters on component inventories, tokens, and rollout strategy for multi-platform systems.',
    status: _projectCompleted(DateTime(2026, 3, 28, 20)),
    targetDate: DateTime(2026, 3, 28),
  );

  final currentTime = DateTime(2026, 4, 2, 9, 30);

  return ProjectListData(
    categories: [
      workCategory,
      mealsCategory,
      studyCategory,
    ],
    currentTime: currentTime,
    projects: [
      ProjectRecord(
        project: deviceSync,
        category: workCategory,
        healthScore: 78,
        healthMetrics: const ProjectHealthMetrics(
          band: ProjectHealthBand.watch,
          rationale:
              'Offline mode implementation is behind and one critical task is blocked.',
        ),
        reportNextWakeAt: currentTime.add(
          const Duration(minutes: 2, seconds: 15),
        ),
        completedTaskCount: 3,
        totalTaskCount: 5,
        blockedTaskCount: 1,
        aiSummary:
            'Device Sync is progressing well. The sync engine core is complete and conflict resolution is in testing. Main risk: offline mode implementation is behind by ~3 days. Recommend prioritizing the offline cache task this week.',
        reportContent: '''
## 📋 TLDR
Device Sync is progressing well. The sync engine core is complete and conflict resolution is in testing. Main risk: offline mode implementation is behind by ~3 days.

## Risks
- Offline cache parity remains blocked by conflict merge edge cases.
- Release confidence depends on additional integration coverage.

## Next steps
- Prioritize offline cache implementation.
- Schedule sync protocol review with the backend team.
- Add integration tests for conflict resolution.
''',
        recommendations: const [
          'Prioritize offline cache implementation',
          'Schedule sync protocol review with backend team',
          'Add integration tests for conflict resolution',
        ],
        reportUpdatedAt: DateTime(2026, 4, 2, 7, 30),
        highlightedTasksTotalDuration: const Duration(minutes: 11, seconds: 38),
        highlightedTaskSummaries: [
          TaskSummary(
            task: _task(
              id: 'sync-engine-task',
              title: 'Implement sync engine',
              status: _taskOpen(DateTime(2026, 4, 1, 9)),
              due: DateTime(2026, 4, 8),
            ),
            estimatedDuration: const Duration(hours: 2, minutes: 30),
          ),
          TaskSummary(
            task: _task(
              id: 'offline-cache-task',
              title: 'Offline cache parity',
              status: _taskBlocked(
                DateTime(2026, 4, 2, 9),
                'Conflict merge edge cases still unresolved.',
              ),
              due: DateTime(2026, 4, 10),
            ),
            estimatedDuration: const Duration(hours: 1, minutes: 10),
          ),
        ],
        reviewSessions: const [
          ReviewSession(
            id: 'review-1',
            summaryLabel: 'Week 11 · Mar 10',
            rating: 4,
            expanded: true,
            metrics: [
              ReviewMetric(
                type: ReviewMetricType.communication,
                rating: 4,
              ),
              ReviewMetric(
                type: ReviewMetricType.usefulness,
                rating: 4,
              ),
              ReviewMetric(
                type: ReviewMetricType.accuracy,
                rating: 4,
              ),
            ],
            note:
                '"Good week overall. Offline cache work needs prioritising next sprint."',
          ),
          ReviewSession(
            id: 'review-2',
            summaryLabel: 'Week 10 · Mar 3',
            rating: 5,
          ),
        ],
      ),
      ProjectRecord(
        project: apiMigration,
        category: workCategory,
        healthScore: 89,
        healthMetrics: const ProjectHealthMetrics(
          band: ProjectHealthBand.onTrack,
          rationale:
              'The auth adapter landed and the migration is back on plan.',
        ),
        reportNextWakeAt: null,
        completedTaskCount: 2,
        totalTaskCount: 3,
        blockedTaskCount: 0,
        aiSummary:
            'API Migration is on track after the auth adapter landed. The biggest remaining work is deprecating the legacy webhook bridge.',
        reportContent: '''
## 📋 TLDR
API Migration is on track after the auth adapter landed.

## Focus
- Deprecate the legacy webhook bridge.
''',
        recommendations: const [
          'Finalize the webhook bridge migration plan',
        ],
        reportUpdatedAt: DateTime(2026, 4, 1, 16),
        highlightedTaskSummaries: const [],
        reviewSessions: const [],
        highlightedTasksTotalDuration: Duration.zero,
      ),
      ProjectRecord(
        project: ciCdPipeline,
        category: workCategory,
        healthScore: 95,
        healthMetrics: const ProjectHealthMetrics(
          band: ProjectHealthBand.onTrack,
          rationale: 'The refreshed pipeline is stable and fully automated.',
        ),
        reportNextWakeAt: null,
        completedTaskCount: 8,
        totalTaskCount: 8,
        blockedTaskCount: 0,
        aiSummary:
            'The refreshed pipeline is stable. Release signing, smoke tests, and notarization all run automatically now.',
        reportContent:
            'The refreshed pipeline is stable. Release signing, smoke tests, and notarization all run automatically now.',
        recommendations: const [],
        reportUpdatedAt: DateTime(2026, 3, 20, 18),
        highlightedTaskSummaries: const [],
        reviewSessions: const [],
        highlightedTasksTotalDuration: Duration.zero,
      ),
      ProjectRecord(
        project: weeklyMealPrep,
        category: mealsCategory,
        healthScore: 62,
        healthMetrics: const ProjectHealthMetrics(
          band: ProjectHealthBand.surviving,
          rationale:
              'The work is active, but shopping and prep windows keep slipping.',
        ),
        reportNextWakeAt: null,
        completedTaskCount: 1,
        totalTaskCount: 4,
        blockedTaskCount: 0,
        aiSummary:
            'Weekly Meal Prep is active but drifting because shopping and prep windows keep slipping into evenings.',
        reportContent:
            'Weekly Meal Prep is active but drifting because shopping and prep windows keep slipping into evenings.',
        recommendations: const [
          'Lock the shopping list 24 hours earlier',
        ],
        reportUpdatedAt: DateTime(2026, 4, 2, 8),
        highlightedTaskSummaries: const [],
        reviewSessions: const [],
        highlightedTasksTotalDuration: Duration.zero,
      ),
      ProjectRecord(
        project: reactCourse,
        category: studyCategory,
        healthScore: 45,
        healthMetrics: const ProjectHealthMetrics(
          band: ProjectHealthBand.atRisk,
          rationale:
              'The course is archived after priorities shifted elsewhere.',
        ),
        reportNextWakeAt: null,
        completedTaskCount: 1,
        totalTaskCount: 6,
        blockedTaskCount: 0,
        aiSummary:
            'React Course is archived after priorities shifted to delivery work.',
        reportContent:
            'React Course is archived after priorities shifted to delivery work.',
        recommendations: const [],
        reportUpdatedAt: DateTime(2026, 3, 30, 21),
        highlightedTaskSummaries: const [],
        reviewSessions: const [],
        highlightedTasksTotalDuration: Duration.zero,
      ),
      ProjectRecord(
        project: designSystemBook,
        category: studyCategory,
        healthScore: 88,
        healthMetrics: const ProjectHealthMetrics(
          band: ProjectHealthBand.onTrack,
          rationale:
              'The project is complete and the takeaways are already in use.',
        ),
        reportNextWakeAt: null,
        completedTaskCount: 2,
        totalTaskCount: 2,
        blockedTaskCount: 0,
        aiSummary:
            'Design System Book is complete and the main takeaways have already been folded into current UI work.',
        reportContent:
            'Design System Book is complete and the main takeaways have already been folded into current UI work.',
        recommendations: const [],
        reportUpdatedAt: DateTime(2026, 3, 28, 21),
        highlightedTaskSummaries: const [],
        reviewSessions: const [],
        highlightedTasksTotalDuration: Duration.zero,
      ),
    ],
  );
}

CategoryDefinition _category({
  required String id,
  required String name,
  required String color,
  required CategoryIcon icon,
}) {
  final timestamp = DateTime(2026, 3, 20, 9);
  return EntityDefinition.categoryDefinition(
        id: id,
        createdAt: timestamp,
        updatedAt: timestamp,
        name: name,
        vectorClock: null,
        private: false,
        active: true,
        color: color,
        icon: icon,
      )
      as CategoryDefinition;
}

ProjectEntry _project({
  required String id,
  required String categoryId,
  required String title,
  required String description,
  required ProjectStatus status,
  required DateTime? targetDate,
}) {
  final createdAt = DateTime(2026, 3, 20, 9);
  return JournalEntity.project(
        meta: Metadata(
          id: id,
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt,
          categoryId: categoryId,
        ),
        data: ProjectData(
          title: title,
          status: status,
          dateFrom: createdAt,
          dateTo: createdAt,
          targetDate: targetDate,
        ),
        entryText: EntryText(plainText: description),
      )
      as ProjectEntry;
}

Task _task({
  required String id,
  required String title,
  required TaskStatus status,
  required DateTime due,
}) {
  final createdAt = DateTime(2026, 4, 1, 9);
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt,
        ),
        data: TaskData(
          title: title,
          status: status,
          statusHistory: const [],
          dateFrom: createdAt,
          dateTo: createdAt,
          due: due,
        ),
      )
      as Task;
}

ProjectStatus _projectActive(DateTime createdAt) => ProjectStatus.active(
  id: 'project-active-${createdAt.millisecondsSinceEpoch}',
  createdAt: createdAt,
  utcOffset: 0,
);

ProjectStatus _projectCompleted(DateTime createdAt) => ProjectStatus.completed(
  id: 'project-completed-${createdAt.millisecondsSinceEpoch}',
  createdAt: createdAt,
  utcOffset: 0,
);

ProjectStatus _projectArchived(DateTime createdAt) => ProjectStatus.archived(
  id: 'project-archived-${createdAt.millisecondsSinceEpoch}',
  createdAt: createdAt,
  utcOffset: 0,
);

TaskStatus _taskOpen(DateTime createdAt) => TaskStatus.open(
  id: 'task-open-${createdAt.millisecondsSinceEpoch}',
  createdAt: createdAt,
  utcOffset: 0,
);

TaskStatus _taskBlocked(DateTime createdAt, String reason) =>
    TaskStatus.blocked(
      id: 'task-blocked-${createdAt.millisecondsSinceEpoch}',
      createdAt: createdAt,
      utcOffset: 0,
      reason: reason,
    );
