// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

part of '../journal_page_controller_test.dart';

void _registerProjectSelection(JournalControllerTestSetup setup) {
  group('Filter Management - Project (Filter)', () {
    test('batch project update selects a project', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1'},
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, equals({'proj-1'}));
      });
    });

    test('batch project update clears an existing selection', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..applyBatchFilterUpdate(projectIds: const {'proj-1'})
          ..applyBatchFilterUpdate(projectIds: const {});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, isEmpty);
      });
    });

    test('empty project batch clears all selections', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1', 'proj-2'},
        );

        settle(async);

        controller.applyBatchFilterUpdate(projectIds: const {});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, isEmpty);
      });
    });

    test('replacement project batch keeps only valid IDs', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1', 'proj-2', 'proj-3'},
        );

        settle(async);

        controller.applyBatchFilterUpdate(projectIds: const {'proj-2'});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, equals({'proj-2'}));
      });
    });

    test('omitting project IDs preserves the current selection', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1'},
        );

        settle(async);

        controller.applyBatchFilterUpdate();

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, equals({'proj-1'}));
      });
    });

    test('toggleSelectedCategoryIds clears project filter', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // Set a project filter first
        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1'},
        );

        settle(async);

        var state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, isNotEmpty);

        // Changing category should clear project filters
        controller.toggleSelectedCategoryIds('cat-1');

        settle(async);

        state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, isEmpty);
      });
    });

    test('selectedAllCategories clears project filter', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1'},
        );

        settle(async);

        controller.selectedAllCategories();

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, isEmpty);
      });
    });

    test('project filter post-filters tasks from _runQuery', () {
      fakeAsync((async) {
        final taskInProject = Task(
          data: TaskData(
            status: TaskStatus.open(
              id: 'status_p1',
              createdAt: DateTime(2024, 1, 1),
              utcOffset: 0,
            ),
            title: 'Task in project',
            statusHistory: const [],
            dateFrom: DateTime(2024, 1, 1),
            dateTo: DateTime(2024, 1, 1),
          ),
          meta: Metadata(
            id: 'task-in-project',
            createdAt: DateTime(2024, 1, 1),
            dateFrom: DateTime(2024, 1, 1),
            dateTo: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        );

        final taskNotInProject = Task(
          data: TaskData(
            status: TaskStatus.open(
              id: 'status_p2',
              createdAt: DateTime(2024, 1, 2),
              utcOffset: 0,
            ),
            title: 'Task not in project',
            statusHistory: const [],
            dateFrom: DateTime(2024, 1, 2),
            dateTo: DateTime(2024, 1, 2),
          ),
          meta: Metadata(
            id: 'task-not-in-project',
            createdAt: DateTime(2024, 1, 2),
            dateFrom: DateTime(2024, 1, 2),
            dateTo: DateTime(2024, 1, 2),
            updatedAt: DateTime(2024, 1, 2),
          ),
        );

        when(
          () => setup.mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            sortByDate: any(named: 'sortByDate'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => [taskInProject, taskNotInProject],
        );

        // getTaskIdsForProjects returns only the task that's in the project
        when(
          () => setup.mockJournalDb.getTaskIdsForProjects({'proj-1'}),
        ).thenAnswer((_) async => {'task-in-project'});

        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-1'},
        );

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        final items = setup.container
            .read(journalPageControllerProvider(true))
            .pagingController
            ?.value
            .items;

        expect(items, isNotNull);
        expect(items!.length, equals(1));
        expect(items.first.meta.id, equals('task-in-project'));
      });
    });

    test(
      'project filter with byDueDate sort applies both filter and sort',
      () {
        fakeAsync((async) {
          final taskWithDue = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_pd1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'Task with due in project',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              due: DateTime(2024, 6, 15),
            ),
            meta: Metadata(
              id: 'task-proj-due',
              createdAt: DateTime(2024, 1, 1),
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              updatedAt: DateTime(2024, 1, 1),
            ),
          );

          final taskNoDue = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_pd2',
                createdAt: DateTime(2024, 1, 2),
                utcOffset: 0,
              ),
              title: 'Task no due in project',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
            ),
            meta: Metadata(
              id: 'task-proj-nodue',
              createdAt: DateTime(2024, 1, 2),
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
              updatedAt: DateTime(2024, 1, 2),
            ),
          );

          // byDueDate sort uses getTasksSortedByDueDate (DB-level sorting)
          when(
            () => setup.mockJournalDb.getTasksSortedByDueDate(
              ids: any(named: 'ids'),
              starredStatuses: any(named: 'starredStatuses'),
              taskStatuses: any(named: 'taskStatuses'),
              categoryIds: any(named: 'categoryIds'),
              labelIds: any(named: 'labelIds'),
              priorities: any(named: 'priorities'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => [taskWithDue, taskNoDue]);

          when(
            () => setup.mockJournalDb.getTaskIdsForProjects({'proj-1'}),
          ).thenAnswer(
            (_) async => {'task-proj-due', 'task-proj-nodue'},
          );

          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.applyBatchFilterUpdate(
            projectIds: const {'proj-1'},
            sortOption: TaskSortOption.byDueDate,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final items = setup.container
              .read(journalPageControllerProvider(true))
              .pagingController
              ?.value
              .items;

          expect(items, isNotNull);
          expect(items!.length, equals(2));
          // Task with due date should come first
          expect(items.first.meta.id, equals('task-proj-due'));
        });
      },
    );
  });

  group('Search Mode', () {
    test('setSearchMode sets vector mode when vector search is enabled', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // Enable vector search flag
        setup.configFlagsController.add({enableVectorSearchFlag});

        settle(async);

        controller.setSearchMode(SearchMode.vector);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.searchMode, equals(SearchMode.vector));
      });
    });

    test(
      'setSearchMode falls back to fullText when vector search is disabled',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Do not enable vector search flag
          controller.setSearchMode(SearchMode.vector);

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          expect(state.searchMode, equals(SearchMode.fullText));
        });
      },
    );
  });
}
