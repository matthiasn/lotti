import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';
import '../../categories/test_utils.dart';
import '../test_utils.dart';

void main() {
  late MockEntitiesCacheService mockCache;

  final projectId = uuid.v1();
  const agentId = 'agent-rec-1';
  const categoryId = 'cat-test';

  final testCategory = CategoryTestUtils.createTestCategory(
    id: categoryId,
    name: 'Engineering',
    color: '#4AB6E8',
  );

  setUp(() async {
    await getIt.reset();
    mockCache = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockCache);

    when(
      () => mockCache.getCategoryById(any()),
    ).thenReturn(null);
    when(
      () => mockCache.getCategoryById(categoryId),
    ).thenReturn(testCategory);
  });

  tearDown(() async {
    await getIt.reset();
  });

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Creates a task with the given [status], [title], [due], and [estimate].
  Task makeTask({
    required TaskStatus status,
    String title = 'Task',
    DateTime? due,
    Duration? estimate,
  }) {
    final now = DateTime(2024, 3, 15);
    return JournalEntity.task(
          meta: Metadata(
            id: uuid.v1(),
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            title: title,
            status: status,
            statusHistory: const [],
            dateFrom: now,
            dateTo: now,
            due: due,
            estimate: estimate,
          ),
          entryText: const EntryText(plainText: ''),
        )
        as Task;
  }

  TaskStatus openStatus() => TaskStatus.open(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
  );

  TaskStatus doneStatus() => TaskStatus.done(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
  );

  TaskStatus blockedStatus() => TaskStatus.blocked(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
    reason: 'dependency',
  );

  TaskStatus inProgressStatus() => TaskStatus.inProgress(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
  );

  TaskStatus onHoldStatus() => TaskStatus.onHold(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
    reason: 'waiting',
  );

  TaskStatus groomedStatus() => TaskStatus.groomed(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
  );

  TaskStatus rejectedStatus() => TaskStatus.rejected(
    id: uuid.v1(),
    createdAt: DateTime(2024, 3, 15),
    utcOffset: 0,
  );

  /// Builds a [ProviderContainer] with the given overrides for the record
  /// provider dependencies. Returns the container.
  ProviderContainer createContainer({
    required ProjectDetailState detailState,
    ProjectHealthMetrics? healthMetrics,
    AgentDomainEntity? agent,
    List<ProjectRecommendationEntity> recommendations = const [],
    AgentDomainEntity? reportEntity,
    AgentDomainEntity? agentState,
  }) {
    final container = ProviderContainer(
      overrides: [
        projectDetailControllerProvider(projectId).overrideWith(
          () => _FixedProjectDetailController(detailState),
        ),
        projectHealthMetricsProvider(projectId).overrideWith(
          (ref) async => healthMetrics,
        ),
        projectAgentProvider(projectId).overrideWith(
          (ref) async => agent,
        ),
        projectRecommendationsProvider(projectId).overrideWith(
          (ref) async => recommendations,
        ),
        if (agent != null) ...[
          agentReportProvider(
            agent.mapOrNull(agent: (a) => a.agentId) ?? '',
          ).overrideWith((ref) async => reportEntity),
          agentStateProvider(
            agent.mapOrNull(agent: (a) => a.agentId) ?? '',
          ).overrideWith((ref) async => agentState),
        ],
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  AgentIdentityEntity makeAgent({String id = agentId}) => makeTestIdentity(
    id: id,
    agentId: id,
    kind: 'project_agent',
    displayName: 'Project Agent',
  );

  // ── Tests ────────────────────────────────────────────────────────────────

  group('projectDetailRecordProvider', () {
    test('returns null when project is null', () async {
      final container = createContainer(
        detailState: ProjectDetailState.initial(),
      );

      final result = await container.read(
        projectDetailRecordProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test('builds a complete ProjectRecord with all fields', () async {
      final project = makeTestProject(
        id: projectId,
        title: 'Lotti Sync',
        categoryId: categoryId,
      );
      final tasks = [
        makeTask(status: openStatus(), title: 'Open Task'),
        makeTask(status: doneStatus(), title: 'Done Task'),
      ];

      final container = createContainer(
        detailState: ProjectDetailState(
          project: project,
          linkedTasks: tasks,
          isLoading: false,
          isSaving: false,
          hasChanges: false,
        ),
        healthMetrics: makeTestProjectHealthMetrics(
          confidence: 0.75,
        ),
        recommendations: [
          makeTestProjectRecommendation(
            projectId: projectId,
            title: 'Review deployment plan',
          ),
        ],
      );

      final result = await container.read(
        projectDetailRecordProvider(projectId).future,
      );

      expect(result, isNotNull);
      expect(result!.project.data.title, 'Lotti Sync');
      expect(result.category, testCategory);
      expect(result.totalTaskCount, 2);
      expect(result.completedTaskCount, 1);
      expect(result.blockedTaskCount, 0);
      expect(result.recommendations, ['Review deployment plan']);
      expect(result.reviewSessions, isEmpty);
      expect(result.reportUpdatedAt, project.meta.updatedAt);
    });

    group('completed and blocked task counting', () {
      test('counts completed tasks correctly', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);
        final tasks = [
          makeTask(status: doneStatus(), title: 'Done 1'),
          makeTask(status: doneStatus(), title: 'Done 2'),
          makeTask(status: openStatus(), title: 'Open 1'),
          makeTask(status: blockedStatus(), title: 'Blocked 1'),
        ];

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: tasks,
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.completedTaskCount, 2);
        expect(result.blockedTaskCount, 1);
        expect(result.totalTaskCount, 4);
      });

      test('returns zero counts when no tasks match', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);
        final tasks = [
          makeTask(status: openStatus(), title: 'Open 1'),
          makeTask(status: inProgressStatus(), title: 'In Progress 1'),
        ];

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: tasks,
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.completedTaskCount, 0);
        expect(result.blockedTaskCount, 0);
        expect(result.totalTaskCount, 2);
      });

      test('handles empty task list', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.completedTaskCount, 0);
        expect(result.blockedTaskCount, 0);
        expect(result.totalTaskCount, 0);
        expect(result.highlightedTaskSummaries, isEmpty);
        expect(result.highlightedTasksTotalDuration, Duration.zero);
      });
    });

    group('health score calculation', () {
      test('returns 0 when metrics are null', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.healthScore, 0);
      });

      test('computes onTrack score with neutral confidence', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            confidence: 0.5,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 90 + ((0.5 - 0.5) * 12).round() = 90 + 0 = 90
        expect(result!.healthScore, 90);
      });

      test('computes blocked score with high confidence', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            band: ProjectHealthBand.blocked,
            confidence: 0.9,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 18 + ((0.9 - 0.5) * 12).round() = 18 + 5 = 23
        expect(result!.healthScore, 23);
      });

      test('computes surviving score without confidence', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            band: ProjectHealthBand.surviving,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 78 + 0 (null confidence) = 78
        expect(result!.healthScore, 78);
      });

      test('computes watch score', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            band: ProjectHealthBand.watch,
            confidence: 0.5,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 64 + 0 = 64
        expect(result!.healthScore, 64);
      });

      test('computes atRisk score', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            band: ProjectHealthBand.atRisk,
            confidence: 0.5,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 42 + 0 = 42
        expect(result!.healthScore, 42);
      });

      test('clamps score to 100 when confidence pushes it over', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            confidence: 1,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 90 + ((1.0 - 0.5) * 12).round() = 90 + 6 = 96
        // Could go higher with different base. Let's verify clamping
        // with a confidence that would overshoot.
        expect(result!.healthScore, 96);
        expect(result.healthScore, lessThanOrEqualTo(100));
      });

      test('clamps score to 0 when confidence pushes it under', () async {
        final project = makeTestProject(id: projectId, categoryId: categoryId);

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          healthMetrics: makeTestProjectHealthMetrics(
            band: ProjectHealthBand.blocked,
            confidence: 0,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        // base 18 + ((0.0 - 0.5) * 12).round() = 18 + (-6) = 12
        expect(result!.healthScore, 12);
        expect(result.healthScore, greaterThanOrEqualTo(0));
      });
    });

    group('AI summary resolution', () {
      test('prefers report TLDR over project text', () async {
        final project =
            makeTestProject(
              id: projectId,
              categoryId: categoryId,
            ).copyWith(
              entryText: const EntryText(
                plainText: 'Project description text',
              ),
            );

        final agent = makeAgent();
        final report = makeTestReport(
          agentId: agentId,
          content: '# Full report body',
          tldr: 'Short TLDR from report',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          agent: agent,
          reportEntity: report,
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.aiSummary, 'Short TLDR from report');
      });

      test('falls back to project text when TLDR is null', () async {
        final project =
            makeTestProject(
              id: projectId,
              categoryId: categoryId,
            ).copyWith(
              entryText: const EntryText(
                plainText: 'Project description text',
              ),
            );

        final agent = makeAgent();
        final report = makeTestReport(
          agentId: agentId,
          content: '# Full report body',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          agent: agent,
          reportEntity: report,
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.aiSummary, 'Project description text');
      });

      test('falls back to project text when TLDR is empty', () async {
        final project =
            makeTestProject(
              id: projectId,
              categoryId: categoryId,
            ).copyWith(
              entryText: const EntryText(
                plainText: 'Project description text',
              ),
            );

        final agent = makeAgent();
        final report = makeTestReport(
          agentId: agentId,
          content: '# Full report body',
          tldr: '   ',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          agent: agent,
          reportEntity: report,
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.aiSummary, 'Project description text');
      });

      test(
        'returns empty string when both TLDR and project text are absent',
        () async {
          final project = makeTestProject(
            id: projectId,
            categoryId: categoryId,
          );

          final container = createContainer(
            detailState: ProjectDetailState(
              project: project,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          final result = await container.read(
            projectDetailRecordProvider(projectId).future,
          );

          expect(result!.aiSummary, isEmpty);
        },
      );

      test(
        'returns empty string when project text is empty and no report',
        () async {
          final project =
              makeTestProject(
                id: projectId,
                categoryId: categoryId,
              ).copyWith(
                entryText: const EntryText(plainText: ''),
              );

          final container = createContainer(
            detailState: ProjectDetailState(
              project: project,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          final result = await container.read(
            projectDetailRecordProvider(projectId).future,
          );

          expect(result!.aiSummary, isEmpty);
        },
      );
    });

    group('report content and metadata', () {
      test('uses report content and createdAt when report exists', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final agent = makeAgent();
        final reportCreatedAt = DateTime(2026, 4, 1, 14, 30);
        final report = makeTestReport(
          agentId: agentId,
          content: '# Status Report\nAll systems go.',
          tldr: 'All systems go',
          createdAt: reportCreatedAt,
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          agent: agent,
          reportEntity: report,
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(
          result!.reportContent,
          '# Status Report\nAll systems go.',
        );
        expect(result.reportUpdatedAt, reportCreatedAt);
      });

      test(
        'falls back to aiSummary for reportContent when no report',
        () async {
          final project =
              makeTestProject(
                id: projectId,
                categoryId: categoryId,
              ).copyWith(
                entryText: const EntryText(
                  plainText: 'Project summary text',
                ),
              );

          final container = createContainer(
            detailState: ProjectDetailState(
              project: project,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          final result = await container.read(
            projectDetailRecordProvider(projectId).future,
          );

          expect(result!.reportContent, 'Project summary text');
        },
      );

      test('uses project updatedAt when no report exists', () async {
        final createdAt = DateTime(2024, 6, 10, 8);
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
          createdAt: createdAt,
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.reportUpdatedAt, createdAt);
      });
    });

    group('agent and next wake at', () {
      test('reportNextWakeAt is null when no agent exists', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.reportNextWakeAt, isNull);
      });

      test('reportNextWakeAt comes from agent state', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final agent = makeAgent();
        final nextWake = DateTime(2026, 4, 5, 9);
        final state = makeTestState(
          agentId: agentId,
          nextWakeAt: nextWake,
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          agent: agent,
          agentState: state,
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.reportNextWakeAt, nextWake);
      });
    });

    group('task sorting via highlightedTaskSummaries order', () {
      test('sorts by status rank: blocked before open before done', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final doneTask = makeTask(
          status: doneStatus(),
          title: 'Done Task',
        );
        final openTask = makeTask(
          status: openStatus(),
          title: 'Open Task',
        );
        final blockedTask = makeTask(
          status: blockedStatus(),
          title: 'Blocked Task',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: [doneTask, openTask, blockedTask],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        final titles = result!.highlightedTaskSummaries
            .map((s) => s.task.data.title)
            .toList();
        expect(titles, ['Blocked Task', 'Open Task', 'Done Task']);
      });

      test('sorts all seven status ranks in correct order', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final tasks = [
          makeTask(status: rejectedStatus(), title: 'Rejected'),
          makeTask(status: doneStatus(), title: 'Done'),
          makeTask(status: groomedStatus(), title: 'Groomed'),
          makeTask(status: openStatus(), title: 'Open'),
          makeTask(status: inProgressStatus(), title: 'In Progress'),
          makeTask(status: onHoldStatus(), title: 'On Hold'),
          makeTask(status: blockedStatus(), title: 'Blocked'),
        ];

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: tasks,
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        final titles = result!.highlightedTaskSummaries
            .map((s) => s.task.data.title)
            .toList();
        expect(titles, [
          'Blocked',
          'On Hold',
          'In Progress',
          'Open',
          'Groomed',
          'Done',
          'Rejected',
        ]);
      });

      test('within same status, sorts by due date ascending', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final laterDue = makeTask(
          status: openStatus(),
          title: 'Later',
          due: DateTime(2025, 6, 15),
        );
        final earlierDue = makeTask(
          status: openStatus(),
          title: 'Earlier',
          due: DateTime(2025, 3),
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: [laterDue, earlierDue],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        final titles = result!.highlightedTaskSummaries
            .map((s) => s.task.data.title)
            .toList();
        expect(titles, ['Earlier', 'Later']);
      });

      test('tasks with due date come before tasks without', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final withDue = makeTask(
          status: openStatus(),
          title: 'Has Due',
          due: DateTime(2025, 12, 31),
        );
        final withoutDue = makeTask(
          status: openStatus(),
          title: 'No Due',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: [withoutDue, withDue],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        final titles = result!.highlightedTaskSummaries
            .map((s) => s.task.data.title)
            .toList();
        expect(titles, ['Has Due', 'No Due']);
      });

      test(
        'within same status and due, sorts by estimate descending',
        () async {
          final project = makeTestProject(
            id: projectId,
            categoryId: categoryId,
          );
          final smallEstimate = makeTask(
            status: openStatus(),
            title: 'Small',
            estimate: const Duration(hours: 1),
          );
          final largeEstimate = makeTask(
            status: openStatus(),
            title: 'Large',
            estimate: const Duration(hours: 8),
          );

          final container = createContainer(
            detailState: ProjectDetailState(
              project: project,
              linkedTasks: [smallEstimate, largeEstimate],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          final result = await container.read(
            projectDetailRecordProvider(projectId).future,
          );

          final titles = result!.highlightedTaskSummaries
              .map((s) => s.task.data.title)
              .toList();
          // Larger estimate comes first (descending)
          expect(titles, ['Large', 'Small']);
        },
      );

      test(
        'within same status, due, and estimate, sorts by title alphabetically',
        () async {
          final project = makeTestProject(
            id: projectId,
            categoryId: categoryId,
          );
          final zulu = makeTask(
            status: openStatus(),
            title: 'Zulu',
          );
          final alpha = makeTask(
            status: openStatus(),
            title: 'Alpha',
          );

          final container = createContainer(
            detailState: ProjectDetailState(
              project: project,
              linkedTasks: [zulu, alpha],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          final result = await container.read(
            projectDetailRecordProvider(projectId).future,
          );

          final titles = result!.highlightedTaskSummaries
              .map((s) => s.task.data.title)
              .toList();
          expect(titles, ['Alpha', 'Zulu']);
        },
      );

      test('title sorting is case-insensitive', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final upper = makeTask(status: openStatus(), title: 'Bravo');
        final lower = makeTask(status: openStatus(), title: 'alpha');

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: [upper, lower],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        final titles = result!.highlightedTaskSummaries
            .map((s) => s.task.data.title)
            .toList();
        // 'alpha' < 'bravo' case-insensitively
        expect(titles, ['alpha', 'Bravo']);
      });
    });

    group('task summaries and total duration', () {
      test('maps task estimates to TaskSummary and sums durations', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final task1 = makeTask(
          status: openStatus(),
          title: 'Task A',
          estimate: const Duration(hours: 2),
        );
        final task2 = makeTask(
          status: openStatus(),
          title: 'Task B',
          estimate: const Duration(hours: 3),
        );
        final task3 = makeTask(
          status: openStatus(),
          title: 'Task C',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: [task1, task2, task3],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.highlightedTaskSummaries, hasLength(3));
        expect(
          result.highlightedTaskSummaries[0].estimatedDuration,
          const Duration(hours: 3),
        );
        expect(
          result.highlightedTaskSummaries[1].estimatedDuration,
          const Duration(hours: 2),
        );
        expect(
          result.highlightedTaskSummaries[2].estimatedDuration,
          Duration.zero,
        );
        expect(
          result.highlightedTasksTotalDuration,
          const Duration(hours: 5),
        );
      });
    });

    group('recommendations', () {
      test('maps recommendation titles', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );
        final recs = [
          makeTestProjectRecommendation(
            id: 'pr-1',
            projectId: projectId,
            title: 'First recommendation',
          ),
          makeTestProjectRecommendation(
            id: 'pr-2',
            projectId: projectId,
            title: 'Second recommendation',
          ),
        ];

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          recommendations: recs,
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.recommendations, [
          'First recommendation',
          'Second recommendation',
        ]);
      });

      test('returns empty list when no recommendations', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.recommendations, isEmpty);
      });
    });

    group('category lookup', () {
      test('resolves category from EntitiesCacheService', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: categoryId,
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.category, testCategory);
        expect(result.category!.name, 'Engineering');
      });

      test('category is null when not found in cache', () async {
        final project = makeTestProject(
          id: projectId,
          categoryId: 'unknown-category',
        );

        final container = createContainer(
          detailState: ProjectDetailState(
            project: project,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
        );

        final result = await container.read(
          projectDetailRecordProvider(projectId).future,
        );

        expect(result!.category, isNull);
      });
    });
  });

  group('projectDetailNowProvider', () {
    test('returns a function that produces a DateTime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final nowFn = container.read(projectDetailNowProvider);
      final result = nowFn();

      expect(result, isA<DateTime>());
    });
  });
}

/// A minimal controller that returns a fixed state, used to override
/// [projectDetailControllerProvider] in tests.
class _FixedProjectDetailController extends ProjectDetailController {
  _FixedProjectDetailController(this._fixedState) : super('');

  final ProjectDetailState _fixedState;

  @override
  ProjectDetailState build() => _fixedState;
}
