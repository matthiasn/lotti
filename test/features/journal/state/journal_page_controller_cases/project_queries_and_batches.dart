// ignore_for_file: cascade_invocations

part of '../journal_page_controller_test.dart';

void _registerProjectQueriesAndBatches(JournalControllerTestSetup setup) {
  group('Filter Management - Project', () {
    _registerSharedProjectFilters(setup);

    test(
      'project filter with byDueDate sort applies both filter and sort',
      () {
        fakeAsync((async) {
          final taskWithDue = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_pd1',
                createdAt: DateTime(2024),
                utcOffset: 0,
              ),
              title: 'Task with due in project',
              statusHistory: const [],
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
              due: DateTime(2024, 6, 15),
            ),
            meta: Metadata(
              id: 'task-proj-due',
              createdAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
              updatedAt: DateTime(2024),
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
          ).thenAnswer((_) async => [taskNoDue, taskWithDue]);

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
          );
          controller.applyBatchFilterUpdate(
            sortOption: TaskSortOption.byDueDate,
          );

          settle(async);

          final items = setup.container
              .read(journalPageControllerProvider(true))
              .pagingController
              ?.value
              .items;

          expect(items, isNotNull);
          expect(items!.map((entry) => entry.meta.id), [
            'task-proj-due',
            'task-proj-nodue',
          ]);
        });
      },
    );
  });

  group('Batch Filter Updates', () {
    late AgentDatabase agentDbForBatch;

    setUp(() {
      agentDbForBatch = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      getIt.registerSingleton<AgentDatabase>(agentDbForBatch);
    });

    tearDown(() async {
      await agentDbForBatch.close();
      getIt.unregister<AgentDatabase>();
    });

    test('replaces all selected task statuses', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          statuses: const {'DONE', 'BLOCKED'},
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedTaskStatuses, {'DONE', 'BLOCKED'});
      });
    });

    test(
      'replaces categories and clears projects atomically',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // First set some projects
          controller.applyBatchFilterUpdate(
            projectIds: const {'proj-1'},
          );

          settle(async);

          // Now set categories — projects should be cleared
          controller.applyBatchFilterUpdate(
            categoryIds: const {'cat-1', 'cat-2'},
            projectIds: const {},
          );

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          expect(state.selectedCategoryIds, {'cat-1', 'cat-2'});
          expect(state.selectedProjectIds, isEmpty);
        });
      },
    );

    test('replaces all selected labels', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          labelIds: const {'label-1', 'label-2'},
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedLabelIds, {'label-1', 'label-2'});
      });
    });

    test('replaces all selected projects', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          projectIds: const {'proj-a', 'proj-b'},
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedProjectIds, {'proj-a', 'proj-b'});
      });
    });

    test('replaces all selected priorities', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          priorities: const {'HIGH', 'CRITICAL'},
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedPriorities, {'HIGH', 'CRITICAL'});
      });
    });

    test('batch setters defensively copy input sets', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        final mutableSet = {'DONE'};
        controller.applyBatchFilterUpdate(statuses: mutableSet);

        settle(async);

        // Mutate original set — should not affect controller
        mutableSet.add('BLOCKED');

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedTaskStatuses, {'DONE'});
      });
    });
  });

  group('Batch Filter Update', () {
    late AgentDatabase agentDbForBatchUpdate;

    setUp(() {
      agentDbForBatchUpdate = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      getIt.registerSingleton<AgentDatabase>(agentDbForBatchUpdate);
    });

    tearDown(() async {
      await agentDbForBatchUpdate.close();
      getIt.unregister<AgentDatabase>();
    });

    test('applyBatchFilterUpdate sets all fields at once', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          statuses: {'DONE'},
          categoryIds: {'cat-1'},
          labelIds: {'label-1'},
          projectIds: {'proj-1'},
          priorities: {'HIGH'},
          sortOption: TaskSortOption.byDate,
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
          showCreationDate: false,
          showDueDate: true,
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedTaskStatuses, {'DONE'});
        expect(state.selectedCategoryIds, {'cat-1'});
        expect(state.selectedLabelIds, {'label-1'});
        expect(state.selectedProjectIds, {'proj-1'});
        expect(state.selectedPriorities, {'HIGH'});
        expect(state.sortOption, TaskSortOption.byDate);
        expect(
          state.agentAssignmentFilter,
          AgentAssignmentFilter.hasAgent,
        );
        expect(state.showCreationDate, isFalse);
        expect(state.showDueDate, isTrue);
      });
    });

    test('applyBatchFilterUpdate skips null fields', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        final stateBefore = setup.container.read(
          journalPageControllerProvider(true),
        );

        // Only update statuses, leave everything else
        controller.applyBatchFilterUpdate(statuses: {'BLOCKED'});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedTaskStatuses, {'BLOCKED'});
        // Other fields unchanged
        expect(state.sortOption, stateBefore.sortOption);
        expect(state.showCreationDate, stateBefore.showCreationDate);
      });
    });

    test(
      'applyBatchFilterUpdate ignores searchMode when vector disabled',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.applyBatchFilterUpdate(
            searchMode: SearchMode.vector,
          );

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          // Vector search not enabled, so mode should stay fullText
          expect(state.searchMode, SearchMode.fullText);
        });
      },
    );

    test(
      'applyBatchFilterUpdate applies searchMode when vector enabled',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Enable vector search via config flags
          setup.configFlagsController.add({enableVectorSearchFlag});
          settle(async);

          expect(controller.state.enableVectorSearch, isTrue);

          controller.applyBatchFilterUpdate(
            searchMode: SearchMode.vector,
          );

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          expect(state.searchMode, SearchMode.vector);
        });
      },
    );
  });

  group('Vector Search', () {
    late MockVectorSearchRepository mockVectorSearchRepo;

    setUp(() {
      mockVectorSearchRepo = MockVectorSearchRepository();
    });

    /// Enables the vector search feature flag by emitting it via the
    /// config flags stream, then waits for the controller to process it.
    void emitVectorSearchFlag(FakeAsync async) {
      setup.configFlagsController.add({enableVectorSearchFlag});
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
    }

    test(
      'setSearchMode guards against vector mode when flag is disabled',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Flag is disabled by default
          controller.setSearchMode(SearchMode.vector);

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          expect(state.searchMode, equals(SearchMode.fullText));
        });
      },
    );

    test('setSearchMode allows vector mode when flag is enabled', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        emitVectorSearchFlag(async);

        controller.setSearchMode(SearchMode.vector);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.searchMode, equals(SearchMode.vector));
        expect(state.enableVectorSearch, isTrue);
      });
    });

    test('persisted filters survive switching to vector search', () {
      fakeAsync((async) {
        // Persist filter state so the controller loads it on init
        const persistedJson =
            '{"selectedCategoryIds":["cat-1"],'
            '"selectedTaskStatuses":["OPEN","DONE"],'
            '"selectedProjectIds":[],'
            '"selectedLabelIds":["label-1"],'
            '"selectedPriorities":["P0"],'
            '"sortOption":"byDate",'
            '"showCreationDate":true,'
            '"showDueDate":false,'
            '"showCoverArt":false,'
            '"showProjectsHeader":false,'
            '"showDistances":true,'
            '"agentAssignmentFilter":"all"}';

        when(
          () => setup.mockSettingsDb.itemByKey(
            JournalPageController.tasksCategoryFiltersKey,
          ),
        ).thenAnswer((_) async => persistedJson);

        // Register the VectorSearchRepository mock in getIt
        getIt.registerSingleton<VectorSearchRepository>(
          mockVectorSearchRepo,
        );

        final testTask = Task(
          data: TaskData(
            status: TaskStatus.open(
              id: 'vs-status-1',
              createdAt: DateTime(2024, 3),
              utcOffset: 0,
            ),
            title: 'Vector search result task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3),
          ),
          meta: Metadata(
            id: 'vector-task-1',
            createdAt: DateTime(2024, 3),
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3),
            updatedAt: DateTime(2024, 3),
          ),
        );

        when(
          () => mockVectorSearchRepo.searchRelatedTasks(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer(
          (_) async => VectorSearchResult(
            entities: [testTask],
            elapsed: const Duration(milliseconds: 42),
            distances: const {'vector-task-1': 0.35},
          ),
        );

        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        emitVectorSearchFlag(async);

        controller
          ..setSearchMode(SearchMode.vector)
          ..setSearchString('semantic query');

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedCategoryIds, equals({'cat-1'}));
        expect(
          state.selectedTaskStatuses,
          equals({'OPEN', 'DONE'}),
        );
        expect(state.selectedLabelIds, equals({'label-1'}));
        expect(state.selectedPriorities, equals({'P0'}));
        expect(state.sortOption, equals(TaskSortOption.byDate));
        expect(state.showCreationDate, isTrue);
        expect(state.showDueDate, isFalse);
        expect(state.showCoverArt, isFalse);
        expect(state.showProjectsHeader, isFalse);
        expect(state.showDistances, isTrue);
        expect(
          state.agentAssignmentFilter,
          equals(AgentAssignmentFilter.all),
        );
      });
    });
  });
}
