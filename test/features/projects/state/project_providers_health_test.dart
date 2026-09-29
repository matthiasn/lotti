import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
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
  late MockAiConfigRepository mockAiConfigRepo;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockProjectRepository();
    mockAgentRepo = MockAgentRepository();
    mockAiConfigRepo = MockAiConfigRepository();
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
    when(
      () => mockAgentRepo.getEntitiesByIds(any()),
    ).thenAnswer((_) async => <String, AgentDomainEntity>{});
    when(
      () => mockAiConfigRepo.getConfigById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockAiConfigRepo.watchProfiles(),
    ).thenAnswer((_) => const Stream.empty());

    container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
        agentRepositoryProvider.overrideWithValue(mockAgentRepo),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
        projectAgentOverviewUpdateStreamProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
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
            aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
            projectAgentOverviewUpdateStreamProvider.overrideWith(
              (ref) => agentUpdates.stream,
            ),
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
      'projectsOverviewProvider ignores unrelated agent notifications',
      () async {
        final snapshot = makeSnapshot();
        final agentUpdates = StreamController<Set<String>>.broadcast();
        addTearDown(agentUpdates.close);
        final notifications = MockUpdateNotifications();
        var enrichmentAttempts = 0;
        when(
          () => notifications.updateStream,
        ).thenAnswer((_) => agentUpdates.stream);
        when(
          () => mockAgentRepo.getEntitiesByIds({'task-agent-id'}),
        ).thenAnswer(
          (_) async => {
            'task-agent-id': makeTestIdentity(
              id: 'task-agent-id',
              agentId: 'task-agent-id',
            ),
          },
        );
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => Stream.value(snapshot));
        when(
          () => mockAgentRepo.getLinksToMultiple(
            any(),
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async {
          enrichmentAttempts++;
          return <String, List<AgentLink>>{};
        });
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            agentRepositoryProvider.overrideWithValue(mockAgentRepo),
            aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(scopedContainer.dispose);
        final subscription = scopedContainer.listen(
          projectsOverviewProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await scopedContainer.read(projectsOverviewProvider.future);
        expect(enrichmentAttempts, 1);

        agentUpdates.add({'task-agent-id', agentNotification});
        await pumpEventQueue();
        await pumpEventQueue();

        expect(enrichmentAttempts, 1);
      },
    );

    test(
      'project agent update lookup failures trigger a conservative refresh',
      () async {
        final agentUpdates = StreamController<Set<String>>.broadcast();
        addTearDown(agentUpdates.close);
        final notifications = MockUpdateNotifications();
        when(
          () => notifications.updateStream,
        ).thenAnswer((_) => agentUpdates.stream);
        when(
          () => mockAgentRepo.getEntitiesByIds({'agent-1'}),
        ).thenThrow(StateError('agent database unavailable'));
        final scopedContainer = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(mockAgentRepo),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final subscription = scopedContainer.listen(
          projectAgentOverviewUpdateStreamProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final refresh = scopedContainer.read(
          projectAgentOverviewUpdateStreamProvider.future,
        );
        await pumpEventQueue();
        final ids = {'agent-1', agentNotification};
        agentUpdates.add(ids);

        expect(await refresh, ids);
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

    group('project agent sidecars', () {
      AgentLink projectLink(String agentId, String projectId) =>
          AgentLink.agentProject(
            id: 'link-$projectId',
            fromId: agentId,
            toId: projectId,
            createdAt: DateTime(2026, 4, 2),
            updatedAt: DateTime(2026, 4, 2),
            vectorClock: null,
          );

      AgentIdentityEntity projectAgent(String agentId, AgentConfig config) =>
          makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.projectAgent,
            config: config,
          );

      const configuredSetup = AgentInferenceSetup(
        mode: AgentInferenceSetupMode.configured,
        origin: AgentInferenceSetupOrigin.categorySnapshot,
        baseProfileId: 'profile-claude',
      );

      void stubAgents({
        required Map<String, List<AgentLink>> links,
        required Map<String, AgentDomainEntity> identities,
      }) {
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => Stream.value(makeSnapshot()));
        when(
          () => mockAgentRepo.getLinksToMultiple(
            any(),
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async => links);
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((_) async => identities);
      }

      void showProfiles(ProviderContainer target) {
        final controller = target.read(
          projectsFilterControllerProvider.notifier,
        );
        controller.filter = controller.filter.copyWith(
          showInferenceProfile: true,
        );
      }

      Future<ProjectListItemData Function(String)> loadRows(
        ProviderContainer target, {
        bool showInferenceProfile = true,
      }) async {
        if (showInferenceProfile) showProfiles(target);
        final subscription = target.listen(
          projectsOverviewProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final result = await target.read(projectsOverviewProvider.future);
        final rows = {
          for (final group in result.groups)
            for (final item in group.projects) item.project.meta.id: item,
        };
        return (String projectId) => rows[projectId]!;
      }

      test('names the profile an agent is assigned', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
          },
          identities: {
            'agent-work': projectAgent(
              'agent-work',
              const AgentConfig(inferenceSetup: configuredSetup),
            ),
          },
        );
        when(
          () => mockAiConfigRepo.getConfigById('profile-claude'),
        ).thenAnswer(
          (_) async => testInferenceProfile(
            id: 'profile-claude',
            name: 'Claude Sonnet',
          ),
        );

        final row = await loadRows(container);

        expect(row('project-work').hasProjectAgent, isTrue);
        expect(row('project-work').inferenceProfileName, 'Claude Sonnet');
        expect(row('project-work').inferenceProfileMissing, isFalse);
        expect(row('project-study').hasProjectAgent, isFalse);
        expect(row('project-study').inferenceProfileName, isNull);
      });

      test(
        'an agent on the legacy chain has an agent but no profile',
        () async {
          stubAgents(
            links: {
              'project-work': [projectLink('agent-work', 'project-work')],
            },
            identities: {
              'agent-work': projectAgent('agent-work', const AgentConfig()),
            },
          );

          final row = await loadRows(container);

          expect(row('project-work').hasProjectAgent, isTrue);
          expect(row('project-work').inferenceProfileName, isNull);
          expect(row('project-work').inferenceProfileMissing, isFalse);
          verifyNever(() => mockAiConfigRepo.getConfigById(any()));
        },
      );

      test('a profile that no longer exists reads as missing', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
          },
          identities: {
            'agent-work': projectAgent(
              'agent-work',
              const AgentConfig(profileId: 'profile-deleted'),
            ),
          },
        );

        final row = await loadRows(container);

        expect(row('project-work').hasProjectAgent, isTrue);
        expect(row('project-work').inferenceProfileName, isNull);
        expect(row('project-work').inferenceProfileMissing, isTrue);
        verify(
          () => mockAiConfigRepo.getConfigById('profile-deleted'),
        ).called(1);
      });

      test('a non-profile config under the id reads as missing', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
          },
          identities: {
            'agent-work': projectAgent(
              'agent-work',
              const AgentConfig(profileId: 'model-row'),
            ),
          },
        );
        when(
          () => mockAiConfigRepo.getConfigById('model-row'),
        ).thenAnswer((_) async => testAiModel(id: 'model-row'));

        final row = await loadRows(container);

        expect(row('project-work').inferenceProfileName, isNull);
        expect(row('project-work').inferenceProfileMissing, isTrue);
      });

      test('a non-identity entity under the agent id is skipped', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
          },
          identities: {
            'agent-work': makeTestReport(agentId: 'agent-work'),
          },
        );

        final row = await loadRows(container);

        expect(row('project-work').hasProjectAgent, isTrue);
        expect(row('project-work').inferenceProfileName, isNull);
        expect(row('project-work').inferenceProfileMissing, isFalse);
      });

      test('a profile shared by two agents is read once', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
            'project-study': [projectLink('agent-study', 'project-study')],
          },
          identities: {
            for (final agentId in ['agent-work', 'agent-study'])
              agentId: projectAgent(
                agentId,
                const AgentConfig(inferenceSetup: configuredSetup),
              ),
          },
        );
        when(
          () => mockAiConfigRepo.getConfigById('profile-claude'),
        ).thenAnswer(
          (_) async => testInferenceProfile(
            id: 'profile-claude',
            name: 'Claude Sonnet',
          ),
        );

        final row = await loadRows(container);

        expect(row('project-work').inferenceProfileName, 'Claude Sonnet');
        expect(row('project-study').inferenceProfileName, 'Claude Sonnet');
        verify(
          () => mockAiConfigRepo.getConfigById('profile-claude'),
        ).called(1);
      });

      test(
        'a failed profile lookup keeps the last loaded sidecars on refresh',
        () async {
          final agentUpdates = StreamController<Set<String>>.broadcast();
          addTearDown(agentUpdates.close);
          stubAgents(
            links: {
              'project-work': [projectLink('agent-work', 'project-work')],
            },
            identities: const {},
          );
          var identityReads = 0;
          when(() => mockAgentRepo.getEntitiesByIds(any())).thenAnswer((
            _,
          ) async {
            identityReads++;
            if (identityReads > 1) throw StateError('agent store offline');
            return {
              'agent-work': projectAgent(
                'agent-work',
                const AgentConfig(inferenceSetup: configuredSetup),
              ),
            };
          });
          when(
            () => mockAiConfigRepo.getConfigById('profile-claude'),
          ).thenAnswer(
            (_) async => testInferenceProfile(
              id: 'profile-claude',
              name: 'Claude Sonnet',
            ),
          );
          final scopedContainer = ProviderContainer(
            overrides: [
              projectRepositoryProvider.overrideWithValue(mockRepo),
              agentRepositoryProvider.overrideWithValue(mockAgentRepo),
              aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
              projectAgentOverviewUpdateStreamProvider.overrideWith(
                (ref) => agentUpdates.stream,
              ),
            ],
          );
          addTearDown(scopedContainer.dispose);
          showProfiles(scopedContainer);
          final values = <ProjectsOverviewSnapshot>[];
          final subscription = scopedContainer.listen(
            projectsOverviewProvider,
            (_, next) {
              if (next case AsyncData(:final value)) values.add(value);
            },
            fireImmediately: true,
          );
          addTearDown(subscription.close);
          await scopedContainer.read(projectsOverviewProvider.future);

          agentUpdates.add({agentNotification});
          await pumpEventQueue();
          await pumpEventQueue();

          expect(identityReads, 2);
          final refreshed = values.last.groups.first.projects.single;
          expect(refreshed.hasProjectAgent, isTrue);
          expect(refreshed.inferenceProfileName, 'Claude Sonnet');
        },
      );

      test('profiles are not looked up while the switch is off', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
          },
          identities: {
            'agent-work': projectAgent(
              'agent-work',
              const AgentConfig(inferenceSetup: configuredSetup),
            ),
          },
        );

        final row = await loadRows(container, showInferenceProfile: false);

        expect(row('project-work').hasProjectAgent, isTrue);
        expect(row('project-work').inferenceProfileName, isNull);
        expect(row('project-work').inferenceProfileMissing, isFalse);
        verifyNever(() => mockAgentRepo.getEntitiesByIds(any()));
        verifyNever(() => mockAiConfigRepo.getConfigById(any()));
        expect(row('project-work').inferenceProfileLoaded, isFalse);
        verifyNever(() => mockAiConfigRepo.watchProfiles());
      });

      test('turning the switch on reloads the rows with profiles', () async {
        stubAgents(
          links: {
            'project-work': [projectLink('agent-work', 'project-work')],
          },
          identities: {
            'agent-work': projectAgent(
              'agent-work',
              const AgentConfig(inferenceSetup: configuredSetup),
            ),
          },
        );
        when(
          () => mockAiConfigRepo.getConfigById('profile-claude'),
        ).thenAnswer(
          (_) async => testInferenceProfile(
            id: 'profile-claude',
            name: 'Claude Sonnet',
          ),
        );
        final before = await loadRows(container, showInferenceProfile: false);
        expect(before('project-work').inferenceProfileName, isNull);

        showProfiles(container);
        final after = await container.read(projectsOverviewProvider.future);

        expect(
          after.groups.first.projects.single.inferenceProfileName,
          'Claude Sonnet',
        );
        expect(
          after.groups.first.projects.single.inferenceProfileLoaded,
          isTrue,
        );
      });

      test(
        'a row cached without profiles stays unloaded when a switched-on '
        'refresh fails',
        () async {
          stubAgents(
            links: {
              'project-work': [projectLink('agent-work', 'project-work')],
            },
            identities: const {},
          );
          when(
            () => mockAgentRepo.getEntitiesByIds(any()),
          ).thenThrow(StateError('agent store offline'));
          final before = await loadRows(
            container,
            showInferenceProfile: false,
          );
          expect(before('project-work').inferenceProfileLoaded, isFalse);

          showProfiles(container);
          final after = await container.read(projectsOverviewProvider.future);

          final row = after.groups.first.projects.single;
          expect(row.hasProjectAgent, isTrue);
          expect(
            row.inferenceProfileLoaded,
            isFalse,
            reason: 'the empty profile fields were never looked up',
          );
        },
      );

      group('profile changes while the switch is on', () {
        late StreamController<List<AiConfigInferenceProfile>> profiles;

        setUp(() {
          profiles =
              StreamController<List<AiConfigInferenceProfile>>.broadcast();
          addTearDown(profiles.close);
          when(
            () => mockAiConfigRepo.watchProfiles(),
          ).thenAnswer((_) => profiles.stream);
          stubAgents(
            links: {
              'project-work': [projectLink('agent-work', 'project-work')],
            },
            identities: {
              'agent-work': projectAgent(
                'agent-work',
                const AgentConfig(inferenceSetup: configuredSetup),
              ),
            },
          );
        });

        void profileNamed(String? name) {
          when(
            () => mockAiConfigRepo.getConfigById('profile-claude'),
          ).thenAnswer(
            (_) async => name == null
                ? null
                : testInferenceProfile(id: 'profile-claude', name: name),
          );
        }

        Future<ProjectListItemData> settledRow() async {
          await pumpEventQueue();
          await pumpEventQueue();
          final result = await container.read(projectsOverviewProvider.future);
          return result.groups.first.projects.single;
        }

        test('a rename reloads the rows with the new name', () async {
          profileNamed('Claude Sonnet');
          final row = await loadRows(container);
          profiles.add([
            testInferenceProfile(id: 'profile-claude', name: 'Claude Sonnet'),
          ]);
          await pumpEventQueue();
          expect(row('project-work').inferenceProfileName, 'Claude Sonnet');

          profileNamed('Claude Opus');
          profiles.add([
            testInferenceProfile(id: 'profile-claude', name: 'Claude Opus'),
          ]);

          expect((await settledRow()).inferenceProfileName, 'Claude Opus');
        });

        test('a deletion turns the pill into the missing warning', () async {
          profileNamed('Claude Sonnet');
          await loadRows(container);
          profiles.add([
            testInferenceProfile(id: 'profile-claude', name: 'Claude Sonnet'),
          ]);
          await pumpEventQueue();

          profileNamed(null);
          profiles.add(const []);

          final row = await settledRow();
          expect(row.inferenceProfileName, isNull);
          expect(row.inferenceProfileMissing, isTrue);
        });

        test('an edit that keeps every name does not reload', () async {
          profileNamed('Claude Sonnet');
          await loadRows(container);
          profiles.add([
            testInferenceProfile(id: 'profile-claude', name: 'Claude Sonnet'),
          ]);
          await pumpEventQueue();
          clearInteractions(mockAgentRepo);

          profiles.add([
            testInferenceProfile(
              id: 'profile-claude',
              name: 'Claude Sonnet',
              thinkingModelId: 'models/other-thinking-model',
            ),
          ]);
          await pumpEventQueue();
          await pumpEventQueue();

          verifyNever(
            () => mockAgentRepo.getLinksToMultiple(
              any(),
              type: AgentLinkTypes.agentProject,
            ),
          );
        });

        test('a failing profile watch leaves the list loaded', () async {
          profileNamed('Claude Sonnet');
          final row = await loadRows(container);

          profiles.addError(StateError('config db closed'));
          await pumpEventQueue();

          expect(container.read(projectsOverviewProvider).hasError, isFalse);
          expect(row('project-work').inferenceProfileName, 'Claude Sonnet');
        });
      });
    });

    group('visibleProjectGroupsProvider keeps the list while it reloads', () {
      test('a reload shows the previous groups, then the new ones', () async {
        final agentUpdates = StreamController<Set<String>>.broadcast();
        addTearDown(agentUpdates.close);
        final firstLoad = StreamController<ProjectsOverviewSnapshot>();
        final reload = StreamController<ProjectsOverviewSnapshot>();
        addTearDown(firstLoad.close);
        addTearDown(reload.close);
        final loads = [firstLoad, reload];
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => loads.removeAt(0).stream);
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            agentRepositoryProvider.overrideWithValue(mockAgentRepo),
            aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
            projectAgentOverviewUpdateStreamProvider.overrideWith(
              (ref) => agentUpdates.stream,
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);
        scopedContainer
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedStatusIds(const {});
        final states = <AsyncValue<List<ProjectCategoryGroup>>>[];
        final subscription = scopedContainer.listen(
          visibleProjectGroupsProvider,
          (_, next) => states.add(next),
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        firstLoad.add(makeSnapshot());
        await pumpEventQueue();
        expect(states.last.value, hasLength(2));
        final loadedAt = states.length;
        Iterable<AsyncValue<List<ProjectCategoryGroup>>> blankStates() =>
            states.skip(loadedAt).where((state) => !state.hasValue);

        // An agent update rebuilds the overview; its new stream has not
        // emitted yet, so the overview is reloading.
        agentUpdates.add({agentNotification});
        await pumpEventQueue();
        expect(
          scopedContainer.read(projectsOverviewProvider).isLoading,
          isTrue,
        );
        expect(
          blankStates(),
          isEmpty,
          reason: 'the list must never blink out while it reloads',
        );
        expect(states.last.value, hasLength(2));

        reload.add(
          ProjectsOverviewSnapshot(groups: [makeSnapshot().groups.first]),
        );
        await pumpEventQueue();
        expect(states.last.value, hasLength(1));
        expect(blankStates(), isEmpty);
      });

      test('is loading before the first snapshot arrives', () {
        when(
          () => mockRepo.watchProjectsOverview(query: const ProjectsQuery()),
        ).thenAnswer((_) => const Stream.empty());
        final subscription = container.listen(
          visibleProjectGroupsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final state = container.read(visibleProjectGroupsProvider);
        expect(state, isA<AsyncLoading<List<ProjectCategoryGroup>>>());
        expect(state.hasValue, isFalse);
      });

      test('a first-load failure surfaces as an error', () async {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith(
              (ref) => Stream.error(StateError('db closed')),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);
        final subscription = scopedContainer.listen(
          visibleProjectGroupsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        await pumpEventQueue();

        final state = scopedContainer.read(visibleProjectGroupsProvider);
        expect(state, isA<AsyncError<List<ProjectCategoryGroup>>>());
        expect(state.error, isA<StateError>());
      });

      test('an error after a loaded snapshot keeps the snapshot', () async {
        final overview = StreamController<ProjectsOverviewSnapshot>();
        addTearDown(overview.close);
        final scopedContainer = ProviderContainer(
          overrides: [
            projectsOverviewProvider.overrideWith((ref) => overview.stream),
          ],
        );
        addTearDown(scopedContainer.dispose);
        scopedContainer
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedStatusIds(const {});
        final subscription = scopedContainer.listen(
          visibleProjectGroupsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        overview.add(makeSnapshot());
        await pumpEventQueue();
        overview.addError(StateError('transient'));
        await pumpEventQueue();

        expect(scopedContainer.read(projectsOverviewProvider).hasError, isTrue);
        final state = scopedContainer.read(visibleProjectGroupsProvider);
        expect(state, isA<AsyncData<List<ProjectCategoryGroup>>>());
        expect(state.value, hasLength(2));
      });
    });

    test('resetToCurrent keeps the inference profile display switch', () {
      final scopedContainer = ProviderContainer();
      addTearDown(scopedContainer.dispose);

      scopedContainer.read(projectsFilterControllerProvider.notifier)
        ..filter = const ProjectsFilter(
          selectedCategoryIds: {'stale'},
          showInferenceProfile: true,
        )
        ..resetToCurrent();

      expect(
        scopedContainer.read(projectsFilterControllerProvider),
        const ProjectsFilter(
          selectedStatusIds: currentProjectStatusFilterIds,
          showInferenceProfile: true,
        ),
      );
    });
  });
}
