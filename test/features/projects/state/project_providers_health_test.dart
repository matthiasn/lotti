import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../categories/test_utils.dart';
import '../test_utils.dart';

void main() {
  late MockProjectRepository mockRepo;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

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
      'ProjectsFilterController.clear resets to default filter',
      () async {
        final scopedContainer = await makeOverviewContainer();

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
