import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';
import '../../categories/test_utils.dart';
import '../test_utils.dart';

void main() {
  late MockProjectRepository mockRepo;
  late MockAgentRepository mockAgentRepo;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockProjectRepository();
    mockAgentRepo = MockAgentRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => mockRepo.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    when(
      () => mockAgentRepo.getLinksToMultiple(
        any(),
        type: AgentLinkTypes.agentProject,
      ),
    ).thenAnswer((_) async => <String, List<AgentLink>>{});
    when(
      () => mockAgentRepo.getLatestReportsByAgentIds(
        any(),
        AgentReportScopes.current,
      ),
    ).thenAnswer((_) async => {});

    container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
        agentRepositoryProvider.overrideWithValue(mockAgentRepo),
        agentUpdateStreamProvider(
          agentNotification,
        ).overrideWith((ref) => const Stream.empty()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
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

        expect(result.groups.expand((group) => group.projects), hasLength(2));
        expect(
          result.groups.first.projects.first.project.data.title,
          'Device Sync',
        );
      },
    );

    test(
      'projectsOverviewProvider bulk-loads stable one-liners into rows',
      () async {
        final snapshot = makeSnapshot();
        final link = AgentLink.agentProject(
          id: 'link-work',
          fromId: 'agent-work',
          toId: 'project-work',
          createdAt: DateTime(2026, 4, 2),
          updatedAt: DateTime(2026, 4, 2),
          vectorClock: null,
        );
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => Stream.value(snapshot));
        when(
          () => mockAgentRepo.getLinksToMultiple(
            ['project-work', 'project-study'],
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer(
          (_) async => <String, List<AgentLink>>{
            'project-work': [link],
          },
        );
        when(
          () => mockAgentRepo.getLatestReportsByAgentIds(
            ['agent-work'],
            AgentReportScopes.current,
          ),
        ).thenAnswer(
          (_) async => {
            'agent-work': makeTestReport(
              agentId: 'agent-work',
              oneLiner: '  Release review is ready  ',
            ),
          },
        );

        final subscription = container.listen(
          projectsOverviewProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final result = await container.read(projectsOverviewProvider.future);

        expect(
          result.groups.first.projects.single.oneLiner,
          'Release review is ready',
        );
        expect(result.groups[1].projects.single.oneLiner, isNull);
        verify(
          () => mockAgentRepo.getLinksToMultiple(
            ['project-work', 'project-study'],
            type: AgentLinkTypes.agentProject,
          ),
        ).called(1);
        verify(
          () => mockAgentRepo.getLatestReportsByAgentIds(
            ['agent-work'],
            AgentReportScopes.current,
          ),
        ).called(1);
      },
    );

    test(
      'projectsOverviewProvider keeps projects when one-liner loading fails',
      () async {
        final snapshot = makeSnapshot();
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => Stream.value(snapshot));
        when(
          () => mockAgentRepo.getLinksToMultiple(
            any(),
            type: AgentLinkTypes.agentProject,
          ),
        ).thenThrow(StateError('agent database unavailable'));
        final subscription = container.listen(
          projectsOverviewProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final result = await container.read(projectsOverviewProvider.future);

        expect(result.groups.expand((group) => group.projects), hasLength(2));
        expect(result.groups.first.projects.single.oneLiner, isNull);
      },
    );

    test(
      'projectsOverviewProvider preserves one-liners when refresh enrichment fails',
      () async {
        final snapshot = makeSnapshot();
        final link = AgentLink.agentProject(
          id: 'link-work',
          fromId: 'agent-work',
          toId: 'project-work',
          createdAt: DateTime(2026, 4, 2),
          updatedAt: DateTime(2026, 4, 2),
          vectorClock: null,
        );
        final agentUpdates = StreamController<Set<String>>.broadcast();
        addTearDown(agentUpdates.close);
        var enrichmentAttempt = 0;
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => Stream.value(snapshot));
        when(
          () => mockAgentRepo.getLinksToMultiple(
            ['project-work', 'project-study'],
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async {
          enrichmentAttempt++;
          if (enrichmentAttempt > 1) {
            throw StateError('agent database unavailable');
          }
          return <String, List<AgentLink>>{
            'project-work': [link],
          };
        });
        when(
          () => mockAgentRepo.getLatestReportsByAgentIds(
            ['agent-work'],
            AgentReportScopes.current,
          ),
        ).thenAnswer(
          (_) async => {
            'agent-work': makeTestReport(
              agentId: 'agent-work',
              oneLiner: 'Release review is ready',
            ),
          },
        );
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            agentRepositoryProvider.overrideWithValue(mockAgentRepo),
            agentUpdateStreamProvider(
              agentNotification,
            ).overrideWith((ref) => agentUpdates.stream),
          ],
        );
        addTearDown(scopedContainer.dispose);
        final values = <ProjectsOverviewSnapshot>[];
        final subscription = scopedContainer.listen(
          projectsOverviewProvider,
          (_, next) {
            if (next case AsyncData(:final value)) values.add(value);
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final initial = await scopedContainer.read(
          projectsOverviewProvider.future,
        );
        expect(
          initial.groups.first.projects.single.oneLiner,
          'Release review is ready',
        );

        agentUpdates.add({agentNotification});
        await pumpEventQueue();
        await pumpEventQueue();

        expect(enrichmentAttempt, greaterThan(1));
        expect(
          values.last.groups.first.projects.single.oneLiner,
          'Release review is ready',
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

        container
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedStatusIds(const {});
        final activeReady = Completer<void>();
        final completedReady = Completer<void>();
        final subscription = container.listen(
          visibleProjectGroupsProvider,
          (previous, next) {
            final status = next
                .value
                ?.firstOrNull
                ?.projects
                .firstOrNull
                ?.project
                .data
                .status;
            if (status is ProjectActive && !activeReady.isCompleted) {
              activeReady.complete();
            }
            if (status is ProjectCompleted && !completedReady.isCompleted) {
              completedReady.complete();
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        controller.add(initialSnapshot);
        await activeReady.future;

        var visibleGroups = container.read(visibleProjectGroupsProvider).value;
        expect(
          visibleGroups?.first.projects.single.project.data.status,
          isA<ProjectActive>(),
        );

        controller.add(updatedSnapshot);
        await completedReady.future;

        visibleGroups = container.read(visibleProjectGroupsProvider).value;
        expect(
          visibleGroups?.first.projects.single.project.data.status,
          isA<ProjectCompleted>(),
        );
      },
    );

    /// Container with the canonical snapshot loaded and the overview
    /// provider kept alive for the test's lifetime.
    Future<ProviderContainer> makeOverviewContainer() async {
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
      return scopedContainer;
    }

    test('visibleProjectGroupsProvider filters by local text query', () async {
      final scopedContainer = await makeOverviewContainer();
      scopedContainer
          .read(projectsFilterControllerProvider.notifier)
          .setTextQuery('react');

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
        final scopedContainer = await makeOverviewContainer();
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
      'ProjectsFilterController.filter replaces the entire filter state',
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

    test('ProjectsFilterController defaults to current work and can reset', () {
      final scopedContainer = ProviderContainer();
      addTearDown(scopedContainer.dispose);

      final notifier = scopedContainer.read(
        projectsFilterControllerProvider.notifier,
      );
      expect(
        scopedContainer
            .read(projectsFilterControllerProvider)
            .selectedStatusIds,
        currentProjectStatusFilterIds,
      );

      notifier
        ..filter = const ProjectsFilter(
          selectedCategoryIds: {'stale'},
          sortMode: ProjectsSortMode.name,
        )
        ..resetToCurrent();

      expect(
        scopedContainer.read(projectsFilterControllerProvider),
        const ProjectsFilter(
          selectedStatusIds: currentProjectStatusFilterIds,
        ),
      );
    });

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
            selectedStatusIds: currentProjectStatusFilterIds,
            textQuery: 'nonexistent-term',
            searchMode: ProjectsSearchMode.localText,
          ),
        );

        notifier.setTextQuery('');
        expect(
          scopedContainer.read(projectsFilterControllerProvider),
          const ProjectsFilter(
            selectedStatusIds: currentProjectStatusFilterIds,
          ),
        );
      },
    );

    test(
      'visibleProjectGroupsProvider filters by selected project statuses',
      () async {
        // The canonical snapshot has one active project ('Device Sync', Work)
        // and one open project ('React Course', Study); filtering by 'active'
        // must keep only the active one.
        final scopedContainer = await makeOverviewContainer();
        scopedContainer
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedStatusIds({ProjectStatusFilterIds.active});

        final filtered = scopedContainer
            .read(visibleProjectGroupsProvider)
            .value;

        expect(filtered, isNotNull);
        expect(filtered, hasLength(1));
        expect(filtered!.single.category?.name, 'Work');
        expect(
          filtered.single.projects.single.project.data.title,
          'Device Sync',
        );
      },
    );
  });
}
