import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';
import '../test_utils.dart';
import 'project_providers_test_helpers.dart';

void main() {
  late MockProjectRepository mockRepo;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  const categoryId = 'cat-1';
  const taskId = 'task-1';

  setUp(() {
    mockRepo = MockProjectRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => mockRepo.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
  });

  group('projectsForCategoryProvider', () {
    test('fetches projects for category', () async {
      final projects = [
        makeTestProject(categoryId: categoryId),
        makeTestProject(title: 'Project 2', categoryId: categoryId),
      ];
      when(
        () => mockRepo.getProjectsForCategory(categoryId),
      ).thenAnswer((_) async => projects);

      final result = await container.read(
        projectsForCategoryProvider(categoryId).future,
      );

      expect(result, hasLength(2));
      expect(result.first.data.title, 'Test Project');
    });

    test('returns empty list when no projects', () async {
      when(
        () => mockRepo.getProjectsForCategory(categoryId),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        projectsForCategoryProvider(categoryId).future,
      );

      expect(result, isEmpty);
    });
  });

  group('projectForTaskProvider', () {
    test('returns project for linked task', () async {
      final project = makeTestProject(categoryId: categoryId);
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => project);

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );

      expect(result, isNotNull);
      expect(result!.data.title, 'Test Project');
    });

    test('returns null for unlinked task', () async {
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => null);

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('re-fetches when stream emits matching task id', () async {
      final project = makeTestProject(categoryId: categoryId);
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => project);

      await container.read(projectForTaskProvider(taskId).future);

      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => null);

      updateStreamController.add({taskId});
      await Future<void>.microtask(() {});

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );
      expect(result, isNull);
    });

    test('re-fetches when stream emits projectNotification', () async {
      final project = makeTestProject(categoryId: categoryId);
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => project);

      await container.read(projectForTaskProvider(taskId).future);

      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => null);

      updateStreamController.add({projectNotification});
      await Future<void>.microtask(() {});

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );
      expect(result, isNull);
    });
  });

  group('projectHealthMetricsProvider', () {
    const projectId = 'proj-health';
    const agentId = 'agent-health';

    test(
      'returns null without reading the report provider when no project agent exists',
      () async {
        var reportRead = false;
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectAgentProvider(projectId).overrideWith((ref) async => null),
            agentReportProvider(agentId).overrideWith((ref) async {
              reportRead = true;
              throw StateError('report provider should not be read');
            }),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthMetricsProvider(projectId).future,
        );

        expect(result, isNull);
        expect(reportRead, isFalse);
      },
    );

    test('returns null when the project agent has no report yet', () async {
      final scopedContainer = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(mockRepo),
          projectAgentProvider(projectId).overrideWith(
            (ref) async => hMakeProjectAgent(agentId),
          ),
          agentReportProvider(agentId).overrideWith((ref) async => null),
        ],
      );
      addTearDown(scopedContainer.dispose);

      final result = await scopedContainer.read(
        projectHealthMetricsProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test(
      'reads the health band from the latest project-agent report',
      () async {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectAgentProvider(projectId).overrideWith(
              (ref) async => hMakeProjectAgent(agentId),
            ),
            agentReportProvider(agentId).overrideWith(
              (ref) async => AgentDomainEntity.agentReport(
                id: 'report-1',
                agentId: agentId,
                scope: 'current',
                createdAt: DateTime(2026, 4, 2, 9),
                vectorClock: null,
                content: '# Status Report',
                provenance: const {
                  'project_health_band': 'blocked',
                  'project_health_rationale':
                      'A dependency is still blocking the next step.',
                  'project_health_confidence': 0.91,
                },
              ),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthMetricsProvider(projectId).future,
        );

        expect(result, isNotNull);
        expect(result!.band, ProjectHealthBand.blocked);
        expect(
          result.rationale,
          'A dependency is still blocking the next step.',
        );
        expect(result.confidence, 0.91);
      },
    );
  });

  group('projectHealthSnapshotProvider', () {
    const projectId = 'proj-snapshot';
    const agentId = 'agent-snapshot';

    test(
      'aggregates health metrics, stale state, and recommendations',
      () async {
        final recommendation = makeTestProjectRecommendation(
          agentId: agentId,
          projectId: projectId,
          title: 'Escalate the dependency blocker',
        );
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectHealthMetricsProvider(projectId).overrideWith(
              (ref) async => makeTestProjectHealthMetrics(
                band: ProjectHealthBand.atRisk,
                rationale: 'A critical dependency is slipping again.',
                confidence: 0.64,
              ),
            ),
            projectAgentSummaryProvider(projectId).overrideWith(
              (ref) async => ProjectAgentSummaryState(
                hasReport: true,
                pendingProjectActivityAt: DateTime(2026, 4, 2, 11),
                scheduledWakeAt: DateTime(2026, 4, 3, 6),
              ),
            ),
            projectRecommendationsProvider(projectId).overrideWith(
              (ref) async => [recommendation],
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthSnapshotProvider(projectId).future,
        );

        expect(result.projectId, projectId);
        expect(result.healthBand, ProjectHealthBand.atRisk);
        expect(result.isSummaryOutdated, isTrue);
        expect(result.scheduledWakeAt, DateTime(2026, 4, 3, 6));
        expect(result.recommendations, [recommendation]);
      },
    );

    test(
      'summary with no pending activity is NOT outdated',
      () async {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectHealthMetricsProvider(projectId).overrideWith(
              (ref) async => makeTestProjectHealthMetrics(),
            ),
            projectAgentSummaryProvider(projectId).overrideWith(
              (ref) async => ProjectAgentSummaryState(
                hasReport: true,
                scheduledWakeAt: DateTime(2026, 4, 3, 6),
              ),
            ),
            projectRecommendationsProvider(projectId).overrideWith(
              (ref) async => [],
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthSnapshotProvider(projectId).future,
        );

        // hasReport && pendingProjectActivityAt == null → fresh.
        expect(result.isSummaryOutdated, isFalse);
        expect(result.scheduledWakeAt, DateTime(2026, 4, 3, 6));
      },
    );

    test('exposes null-safe getters when metrics and summary are absent', () {
      final project = makeTestProject(
        id: projectId,
        categoryId: categoryId,
      );
      const snapshot = ProjectHealthSnapshot(
        projectId: projectId,
        metrics: null,
        summary: null,
        recommendations: [],
      );
      final entry = ProjectHealthOverviewEntry(
        project: project,
        snapshot: snapshot,
      );

      expect(snapshot.healthBand, isNull);
      expect(snapshot.isSummaryOutdated, isFalse);
      expect(snapshot.scheduledWakeAt, isNull);
      expect(entry.healthBand, isNull);
    });
  });

  group('queryProjectHealthOverviewEntries', () {
    test('filters by selected health bands and can sort alphabetically', () {
      final entries = [
        ProjectHealthOverviewEntry(
          project: makeTestProject(
            id: 'blocked',
            title: 'Zulu',
            categoryId: categoryId,
          ),
          snapshot: ProjectHealthSnapshot(
            projectId: 'blocked',
            metrics: makeTestProjectHealthMetrics(
              band: ProjectHealthBand.blocked,
              rationale: 'Still blocked.',
            ),
            summary: null,
            recommendations: const [],
          ),
        ),
        ProjectHealthOverviewEntry(
          project: makeTestProject(
            id: 'watch',
            title: 'Alpha',
            categoryId: categoryId,
          ),
          snapshot: ProjectHealthSnapshot(
            projectId: 'watch',
            metrics: makeTestProjectHealthMetrics(
              band: ProjectHealthBand.watch,
              rationale: 'Needs follow-up.',
            ),
            summary: null,
            recommendations: const [],
          ),
        ),
        ProjectHealthOverviewEntry(
          project: makeTestProject(
            id: 'unrated',
            title: 'Beta',
            categoryId: categoryId,
          ),
          snapshot: const ProjectHealthSnapshot(
            projectId: 'unrated',
            metrics: null,
            summary: null,
            recommendations: [],
          ),
        ),
      ];

      final filtered = queryProjectHealthOverviewEntries(
        entries,
        includedBands: {ProjectHealthBand.watch, ProjectHealthBand.blocked},
        sort: ProjectHealthOverviewSort.title,
        includeWithoutHealth: false,
      );

      expect(
        filtered.map((entry) => entry.project.meta.id).toList(),
        ['watch', 'blocked'],
      );
    });

    test(
      'sorts best-band-first, keeps entries without health, and tie-breaks by title',
      () {
        final entries = [
          ProjectHealthOverviewEntry(
            project: makeTestProject(
              id: 'on-track-zulu',
              title: 'Zulu',
              categoryId: categoryId,
            ),
            snapshot: ProjectHealthSnapshot(
              projectId: 'on-track-zulu',
              metrics: makeTestProjectHealthMetrics(
                rationale: 'Steady delivery.',
              ),
              summary: null,
              recommendations: const [],
            ),
          ),
          ProjectHealthOverviewEntry(
            project: makeTestProject(
              id: 'watch-bravo',
              title: 'Bravo',
              categoryId: categoryId,
            ),
            snapshot: ProjectHealthSnapshot(
              projectId: 'watch-bravo',
              metrics: makeTestProjectHealthMetrics(
                band: ProjectHealthBand.watch,
                rationale: 'Needs attention.',
              ),
              summary: null,
              recommendations: const [],
            ),
          ),
          ProjectHealthOverviewEntry(
            project: makeTestProject(
              id: 'on-track-alpha',
              title: 'Alpha',
              categoryId: categoryId,
            ),
            snapshot: ProjectHealthSnapshot(
              projectId: 'on-track-alpha',
              metrics: makeTestProjectHealthMetrics(
                rationale: 'Also steady.',
              ),
              summary: null,
              recommendations: const [],
            ),
          ),
          ProjectHealthOverviewEntry(
            project: makeTestProject(
              id: 'no-health',
              title: 'Omega',
              categoryId: categoryId,
            ),
            snapshot: const ProjectHealthSnapshot(
              projectId: 'no-health',
              metrics: null,
              summary: null,
              recommendations: [],
            ),
          ),
        ];

        final sorted = queryProjectHealthOverviewEntries(
          entries,
          sort: ProjectHealthOverviewSort.bestBandFirst,
        );

        expect(
          sorted.map((entry) => entry.project.meta.id).toList(),
          ['on-track-alpha', 'on-track-zulu', 'watch-bravo', 'no-health'],
        );
      },
    );
  });
}
