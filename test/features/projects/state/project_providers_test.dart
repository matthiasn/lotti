import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';
import '../../categories/test_utils.dart';
import '../test_utils.dart';

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

  group('projectTaskCountProvider', () {
    const projectId = 'proj-1';

    test('returns task count for a project', () async {
      final tasks = [makeTestTask(), makeTestTask()];
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => tasks);

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );

      expect(result, 2);
    });

    test('returns 0 when project has no tasks', () async {
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );

      expect(result, 0);
    });

    test('re-fetches when stream emits matching project id', () async {
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [makeTestTask()]);

      await container.read(projectTaskCountProvider(projectId).future);

      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [makeTestTask(), makeTestTask()]);

      updateStreamController.add({projectId});
      await Future<void>.microtask(() {});

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );
      expect(result, 2);
    });

    test('re-fetches when stream emits projectNotification', () async {
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [makeTestTask()]);

      await container.read(projectTaskCountProvider(projectId).future);

      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => []);

      updateStreamController.add({projectNotification});
      await Future<void>.microtask(() {});

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );
      expect(result, 0);
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
            (ref) async => _makeProjectAgent(agentId),
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
              (ref) async => _makeProjectAgent(agentId),
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
                agentId: agentId,
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

  group('projectHealthOverviewEntriesProvider', () {
    test(
      'prepares category health entries sorted by worst band first',
      () async {
        final blockedProject = makeTestProject(
          id: 'proj-blocked',
          title: 'Blocked Launch',
          categoryId: categoryId,
        );
        final healthyProject = makeTestProject(
          id: 'proj-healthy',
          title: 'Healthy Migration',
          categoryId: categoryId,
        );
        final unscoredProject = makeTestProject(
          id: 'proj-unscored',
          title: 'Awaiting First Report',
          categoryId: categoryId,
        );
        final recommendation = makeTestProjectRecommendation(
          projectId: blockedProject.meta.id,
          title: 'Unblock the release dependency',
        );

        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) async => [
                healthyProject,
                unscoredProject,
                blockedProject,
              ],
            ),
            projectHealthSnapshotProvider(blockedProject.meta.id).overrideWith(
              (ref) async => ProjectHealthSnapshot(
                projectId: blockedProject.meta.id,
                metrics: makeTestProjectHealthMetrics(
                  band: ProjectHealthBand.blocked,
                  rationale: 'Release work is blocked.',
                ),
                summary: const ProjectAgentSummaryState(
                  agentId: 'agent-blocked',
                  hasReport: true,
                ),
                recommendations: [recommendation],
              ),
            ),
            projectHealthSnapshotProvider(healthyProject.meta.id).overrideWith(
              (ref) async => ProjectHealthSnapshot(
                projectId: healthyProject.meta.id,
                metrics: makeTestProjectHealthMetrics(
                  rationale: 'Delivery is steady.',
                ),
                summary: const ProjectAgentSummaryState(
                  agentId: 'agent-healthy',
                  hasReport: true,
                ),
                recommendations: const [],
              ),
            ),
            projectHealthSnapshotProvider(unscoredProject.meta.id).overrideWith(
              (ref) async => ProjectHealthSnapshot(
                projectId: unscoredProject.meta.id,
                metrics: null,
                summary: null,
                recommendations: const [],
              ),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthOverviewEntriesProvider(categoryId).future,
        );

        expect(
          result.map((entry) => entry.project.meta.id).toList(),
          [
            blockedProject.meta.id,
            healthyProject.meta.id,
            unscoredProject.meta.id,
          ],
        );
        expect(result.first.snapshot.recommendations, [recommendation]);
      },
    );
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

  group('projects overview providers', () {
    final workCategory = CategoryTestUtils.createTestCategory(
      id: 'work',
      name: 'Work',
    );
    final studyCategory = CategoryTestUtils.createTestCategory(
      id: 'study',
      name: 'Study',
    );

    ProjectsOverviewSnapshot makeSnapshot() {
      return ProjectsOverviewSnapshot(
        groups: [
          ProjectCategoryGroup(
            categoryId: workCategory.id,
            category: workCategory,
            projects: [
              ProjectListItemData(
                project: makeTestProject(
                  id: 'project-work',
                  title: 'Device Sync',
                  status: ProjectStatus.active(
                    id: 'status-active',
                    createdAt: DateTime(2024, 3, 15),
                    utcOffset: 0,
                  ),
                  categoryId: workCategory.id,
                ),
                category: workCategory,
                taskRollup: const ProjectTaskRollupData(totalTaskCount: 5),
              ),
            ],
          ),
          ProjectCategoryGroup(
            categoryId: studyCategory.id,
            category: studyCategory,
            projects: [
              ProjectListItemData(
                project: makeTestProject(
                  id: 'project-study',
                  title: 'React Course',
                  categoryId: studyCategory.id,
                ),
                category: studyCategory,
                taskRollup: const ProjectTaskRollupData(totalTaskCount: 2),
              ),
            ],
          ),
        ],
      );
    }

    test(
      'projectsOverviewProvider exposes the repository watch stream',
      () async {
        final snapshot = makeSnapshot();
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => Stream.value(snapshot));
        final subscription = container.listen(
          projectsOverviewProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final result = await container.read(projectsOverviewProvider.future);

        expect(result.totalProjectCount, 2);
        expect(
          result.groups.first.projects.first.project.data.title,
          'Device Sync',
        );
      },
    );

    test(
      'visibleProjectGroupsProvider reflects updated project status from the overview stream',
      () async {
        final controller = StreamController<ProjectsOverviewSnapshot>();
        addTearDown(controller.close);
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => controller.stream);

        final initialSnapshot = makeSnapshot();
        final updatedSnapshot = ProjectsOverviewSnapshot(
          groups: [
            ProjectCategoryGroup(
              categoryId: workCategory.id,
              category: workCategory,
              projects: [
                ProjectListItemData(
                  project: makeTestProject(
                    id: 'project-work',
                    title: 'Device Sync',
                    status: ProjectStatus.completed(
                      id: 'status-completed',
                      createdAt: DateTime(2024, 3, 16),
                      utcOffset: 0,
                    ),
                    categoryId: workCategory.id,
                  ),
                  category: workCategory,
                  taskRollup: const ProjectTaskRollupData(
                    totalTaskCount: 5,
                    completedTaskCount: 5,
                  ),
                ),
              ],
            ),
            initialSnapshot.groups[1],
          ],
        );

        final subscription = container.listen(
          visibleProjectGroupsProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        controller.add(initialSnapshot);
        await Future<void>.microtask(() {});

        var visibleGroups = container.read(visibleProjectGroupsProvider).value;
        expect(
          visibleGroups?.first.projects.single.project.data.status,
          isA<ProjectActive>(),
        );

        controller.add(updatedSnapshot);
        await Future<void>.microtask(() {});

        visibleGroups = container.read(visibleProjectGroupsProvider).value;
        expect(
          visibleGroups?.first.projects.single.project.data.status,
          isA<ProjectCompleted>(),
        );
      },
    );

    test('visibleProjectGroupsProvider filters by local text query', () async {
      final snapshot = makeSnapshot();
      final scopedContainer = ProviderContainer(
        overrides: [
          projectsOverviewProvider.overrideWith(
            (ref) => Stream.value(snapshot),
          ),
        ],
      );
      addTearDown(scopedContainer.dispose);
      final subscription = scopedContainer.listen(
        projectsOverviewProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await scopedContainer.read(projectsOverviewProvider.future);
      scopedContainer
        ..read(projectsFilterControllerProvider.notifier).setSearchMode(
          ProjectsSearchMode.localText,
        )
        ..read(projectsFilterControllerProvider.notifier).setTextQuery('react');

      final filtered = scopedContainer.read(visibleProjectGroupsProvider).value;

      expect(filtered, isNotNull);
      expect(filtered, hasLength(1));
      expect(filtered!.single.category?.name, 'Study');
      expect(
        filtered.single.projects.single.project.data.title,
        'React Course',
      );
    });

    test(
      'visibleProjectGroupsProvider filters by selected category ids',
      () async {
        final snapshot = makeSnapshot();
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => Stream.value(snapshot),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);
        final subscription = scopedContainer.listen(
          projectsOverviewProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await scopedContainer.read(projectsOverviewProvider.future);
        scopedContainer
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedCategoryIds({workCategory.id});

        final filtered = scopedContainer
            .read(visibleProjectGroupsProvider)
            .value;

        expect(filtered, isNotNull);
        expect(filtered, hasLength(1));
        expect(filtered!.single.category?.name, 'Work');
      },
    );

    test(
      'ProjectsFilterController.clear resets to default filter',
      () async {
        final snapshot = makeSnapshot();
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => Stream.value(snapshot),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);
        final subscription = scopedContainer.listen(
          projectsOverviewProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        await scopedContainer.read(projectsOverviewProvider.future);

        // Apply a filter, then clear it
        scopedContainer
          ..read(
            projectsFilterControllerProvider.notifier,
          ).setSelectedCategoryIds({workCategory.id})
          ..read(
            projectsFilterControllerProvider.notifier,
          ).setTextQuery('something')
          ..read(
            projectsFilterControllerProvider.notifier,
          ).setSearchMode(ProjectsSearchMode.localText);

        scopedContainer.read(projectsFilterControllerProvider.notifier).clear();

        final filter = scopedContainer.read(projectsFilterControllerProvider);
        expect(filter.selectedCategoryIds, isEmpty);
        expect(filter.textQuery, isEmpty);
        expect(filter.searchMode, ProjectsSearchMode.disabled);

        // All groups should be visible again
        final groups = scopedContainer.read(visibleProjectGroupsProvider).value;
        expect(groups, hasLength(2));
      },
    );

    test(
      'ProjectsFilterController.filter getter returns the current state',
      () {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => const Stream<ProjectsOverviewSnapshot>.empty(),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final notifier = scopedContainer.read(
          projectsFilterControllerProvider.notifier,
        );

        // Initially returns the default filter
        expect(notifier.filter, const ProjectsFilter());

        // After mutation, getter reflects the updated state
        notifier
          ..setSelectedCategoryIds({'cat-a', 'cat-b'})
          ..setSelectedStatusIds(
            {ProjectStatusFilterIds.active},
          );

        final current = notifier.filter;
        expect(current.selectedCategoryIds, {'cat-a', 'cat-b'});
        expect(
          current.selectedStatusIds,
          {ProjectStatusFilterIds.active},
        );
      },
    );

    test(
      'ProjectsFilterController.filter setter replaces the entire filter state',
      () {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => const Stream<ProjectsOverviewSnapshot>.empty(),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final notifier = scopedContainer.read(
          projectsFilterControllerProvider.notifier,
        );

        const replacement = ProjectsFilter(
          selectedStatusIds: {
            ProjectStatusFilterIds.completed,
            ProjectStatusFilterIds.archived,
          },
          selectedCategoryIds: {'cat-x'},
          textQuery: 'hello',
          searchMode: ProjectsSearchMode.localText,
        );

        notifier.filter = replacement;

        final state = scopedContainer.read(
          projectsFilterControllerProvider,
        );
        expect(state, replacement);
        expect(
          state.selectedStatusIds,
          {
            ProjectStatusFilterIds.completed,
            ProjectStatusFilterIds.archived,
          },
        );
        expect(state.selectedCategoryIds, {'cat-x'});
        expect(state.textQuery, 'hello');
        expect(state.searchMode, ProjectsSearchMode.localText);
      },
    );

    test(
      'ProjectsFilterController.setSelectedStatusIds updates only status ids',
      () {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => const Stream<ProjectsOverviewSnapshot>.empty(),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        // Set up some pre-existing filter state, then update only status ids
        scopedContainer.read(projectsFilterControllerProvider.notifier)
          ..filter = const ProjectsFilter(
            selectedCategoryIds: {'cat-keep'},
            textQuery: 'preserved',
            searchMode: ProjectsSearchMode.localText,
          )
          ..setSelectedStatusIds({
            ProjectStatusFilterIds.onHold,
            ProjectStatusFilterIds.open,
          });

        final state = scopedContainer.read(
          projectsFilterControllerProvider,
        );
        expect(
          state.selectedStatusIds,
          {ProjectStatusFilterIds.onHold, ProjectStatusFilterIds.open},
        );
        // Other fields remain unchanged
        expect(state.selectedCategoryIds, {'cat-keep'});
        expect(state.textQuery, 'preserved');
        expect(state.searchMode, ProjectsSearchMode.localText);
      },
    );

    test(
      'ProjectsFilterController.setTextQuery toggles local text search mode',
      () {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => const Stream<ProjectsOverviewSnapshot>.empty(),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final notifier = scopedContainer.read(
          projectsFilterControllerProvider.notifier,
        )..setTextQuery('nonexistent-term');
        expect(
          scopedContainer.read(projectsFilterControllerProvider),
          const ProjectsFilter(
            textQuery: 'nonexistent-term',
            searchMode: ProjectsSearchMode.localText,
          ),
        );

        notifier.setTextQuery('');
        expect(
          scopedContainer.read(projectsFilterControllerProvider),
          const ProjectsFilter(),
        );
      },
    );

    test(
      'visibleProjectGroupsProvider filters by selected project statuses',
      () async {
        final snapshot = ProjectsOverviewSnapshot(
          groups: [
            ProjectCategoryGroup(
              categoryId: workCategory.id,
              category: workCategory,
              projects: [
                ProjectListItemData(
                  project: makeTestProject(
                    id: 'project-work',
                    title: 'Device Sync',
                    status: ProjectStatus.active(
                      id: 'status-active',
                      createdAt: DateTime(2024, 3, 15),
                      utcOffset: 0,
                    ),
                    categoryId: workCategory.id,
                  ),
                  category: workCategory,
                  taskRollup: const ProjectTaskRollupData(totalTaskCount: 5),
                ),
              ],
            ),
            ProjectCategoryGroup(
              categoryId: studyCategory.id,
              category: studyCategory,
              projects: [
                ProjectListItemData(
                  project: makeTestProject(
                    id: 'project-study',
                    title: 'API Migration',
                    status: ProjectStatus.completed(
                      id: 'status-completed',
                      createdAt: DateTime(2024, 3, 16),
                      utcOffset: 0,
                    ),
                    categoryId: studyCategory.id,
                  ),
                  category: studyCategory,
                  taskRollup: const ProjectTaskRollupData(totalTaskCount: 2),
                ),
              ],
            ),
          ],
        );
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => Stream.value(snapshot),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);
        final subscription = scopedContainer.listen(
          projectsOverviewProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await scopedContainer.read(projectsOverviewProvider.future);
        scopedContainer
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedStatusIds({ProjectStatusFilterIds.completed});

        final filtered = scopedContainer
            .read(visibleProjectGroupsProvider)
            .value;

        expect(filtered, isNotNull);
        expect(filtered, hasLength(1));
        expect(
          filtered!.single.projects.single.project.data.title,
          'API Migration',
        );
      },
    );
  });
}

AgentDomainEntity _makeProjectAgent(String agentId) {
  return AgentDomainEntity.agent(
    id: agentId,
    agentId: agentId,
    kind: 'project_agent',
    displayName: 'Project Agent',
    lifecycle: AgentLifecycle.active,
    mode: AgentInteractionMode.autonomous,
    allowedCategoryIds: const {},
    currentStateId: 'state-1',
    config: const AgentConfig(),
    createdAt: DateTime(2026, 4, 2, 9),
    updatedAt: DateTime(2026, 4, 2, 9),
    vectorClock: null,
  );
}
