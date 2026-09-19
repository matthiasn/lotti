// ignore_for_file: cascade_invocations

part of '../journal_page_controller_test.dart';

void _registerFlagsAndAgentQueries(JournalControllerTestSetup setup) {
  group('Feature Flag Selection Semantics', () {
    // ADR 0064: a saved selection made before CheckIn existed gains it once,
    // and only once People offers it — never behind a flag that is off,
    // where the gating would strip it and consume the migration unseen.
    group('a type added since the selection was saved', () {
      void stubLegacySelection() {
        when(
          () => setup.mockSettingsDb.itemByKey('SELECTED_ENTRY_TYPES'),
        ).thenAnswer((_) async => '["JournalEntry","Task"]');
      }

      test('joins the selection at once while People is on, and is saved '
          'with it', () {
        fakeAsync((async) {
          stubLegacySelection();
          setup.configFlagsController.add({enableRelationshipsFlag});
          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );
          settle(async);
          setup.configFlagsController.add({enableRelationshipsFlag});
          settle(async);

          expect(
            controller.state.selectedEntryTypes.toSet(),
            {'Task', 'JournalEntry', 'CheckIn'},
          );
          verify(
            () => setup.mockSettingsDb.saveSettingsItem(
              'SELECTED_ENTRY_TYPES',
              '["CheckIn","JournalEntry","Task"]',
            ),
          ).called(greaterThanOrEqualTo(1));
        });
      });

      test('joins while the saved selection loads when People is already '
          'known to be on, and is saved with it', () {
        fakeAsync((async) {
          final stored = Completer<String?>();
          when(
            () => setup.mockSettingsDb.itemByKey('SELECTED_ENTRY_TYPES'),
          ).thenAnswer((_) => stored.future);
          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );
          setup.configFlagsController.add({enableRelationshipsFlag});
          settle(async);

          stored.complete('["JournalEntry","Task"]');
          settle(async);

          expect(
            controller.state.selectedEntryTypes.toSet(),
            {'Task', 'JournalEntry', 'CheckIn'},
          );
          verify(
            () => setup.mockSettingsDb.saveSettingsItem(
              'SELECTED_ENTRY_TYPES',
              '["CheckIn","JournalEntry","Task"]',
            ),
          ).called(1);
        });
      });

      test('waits while People is off, and joins when People turns on', () {
        fakeAsync((async) {
          stubLegacySelection();
          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );
          settle(async);
          setup.configFlagsController.add(<String>{});
          settle(async);

          expect(
            controller.state.selectedEntryTypes.toSet(),
            {'Task', 'JournalEntry'},
          );
          verifyNever(
            () => setup.mockSettingsDb.saveSettingsItem(
              'ENTRY_TYPES_RECONCILED',
              any(that: contains('CheckIn')),
            ),
          );

          setup.configFlagsController.add({enableRelationshipsFlag});
          settle(async);

          expect(
            controller.state.selectedEntryTypes.toSet(),
            {'Task', 'JournalEntry', 'CheckIn'},
          );
        });
      });
    });

    test(
      'empty selection repopulates with all allowed types on flag change',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Clear selection to make it empty
          controller.clearSelectedEntryTypes();

          settle(async);

          expect(controller.state.selectedEntryTypes.toSet(), isEmpty);

          // Emit config flags with events enabled
          setup.configFlagsController.add({enableEventsFlag});

          settle(async);

          // Should repopulate with all allowed types (events enabled)
          final expectedTypes = computeAllowedEntryTypes(
            events: true,
            habits: false,
            dashboards: false,
            relationships: false,
          ).toSet();

          expect(
            controller.state.selectedEntryTypes.toSet(),
            equals(expectedTypes),
          );
        });
      },
    );

    test('selection with all previously selected adopts new allowed types '
        'when flags change', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // First emit with no flags - get initial allowed types
        setup.configFlagsController.add(<String>{});

        settle(async);

        final initialAllowed = computeAllowedEntryTypes(
          events: false,
          habits: false,
          dashboards: false,
          relationships: false,
        ).toSet();

        // Select all allowed types
        controller.selectAllEntryTypes(initialAllowed.toList());

        settle(async);

        expect(
          controller.state.selectedEntryTypes.toSet(),
          equals(initialAllowed),
        );

        // Now enable events flag
        setup.configFlagsController.add({enableEventsFlag});

        settle(async);

        // Should adopt new allowed types (including JournalEvent)
        final newAllowed = computeAllowedEntryTypes(
          events: true,
          habits: false,
          dashboards: false,
          relationships: false,
        ).toSet();

        expect(
          controller.state.selectedEntryTypes.toSet(),
          equals(newAllowed),
        );
        expect(
          controller.state.selectedEntryTypes.toSet(),
          contains('JournalEvent'),
        );
      });
    });

    test(
      'partial selection intersects with new allowed types on flag change',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // First emit with all flags enabled
          setup.configFlagsController.add({
            enableEventsFlag,
            enableHabitsPageFlag,
            enableDashboardsPageFlag,
          });

          settle(async);

          // Select a partial set including some gated types
          // JournalEvent (gated by events), HabitCompletionEntry (gated by habits)
          // Task (always allowed)
          controller.selectAllEntryTypes([
            'Task',
            'JournalEvent',
            'HabitCompletionEntry',
          ]);

          settle(async);

          expect(
            controller.state.selectedEntryTypes.toSet(),
            equals({'Task', 'JournalEvent', 'HabitCompletionEntry'}),
          );

          // Now disable events and habits flags
          setup.configFlagsController.add(<String>{});

          settle(async);

          // Should intersect - only Task remains (JournalEvent and
          // HabitCompletionEntry are no longer allowed)
          expect(
            controller.state.selectedEntryTypes.toSet(),
            equals({'Task'}),
          );
          expect(
            controller.state.selectedEntryTypes.toSet(),
            isNot(contains('JournalEvent')),
          );
          expect(
            controller.state.selectedEntryTypes.toSet(),
            isNot(contains('HabitCompletionEntry')),
          );
        });
      },
    );

    test('enabling new flag adds types when user had all selected', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // Start with events only
        setup.configFlagsController.add({enableEventsFlag});

        settle(async);

        final eventsAllowed = computeAllowedEntryTypes(
          events: true,
          habits: false,
          dashboards: false,
          relationships: false,
        ).toSet();

        // Select all currently allowed types
        controller.selectAllEntryTypes(eventsAllowed.toList());

        settle(async);

        expect(
          controller.state.selectedEntryTypes.toSet(),
          equals(eventsAllowed),
        );
        expect(
          controller.state.selectedEntryTypes.toSet(),
          isNot(contains('HabitCompletionEntry')),
        );

        // Now also enable habits
        setup.configFlagsController.add({
          enableEventsFlag,
          enableHabitsPageFlag,
        });

        settle(async);

        // Should include HabitCompletionEntry now
        expect(
          controller.state.selectedEntryTypes.toSet(),
          contains('HabitCompletionEntry'),
        );
      });
    });

    test('disabling flag removes types from partial selection', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // Start with dashboards enabled
        setup.configFlagsController.add({enableDashboardsPageFlag});

        settle(async);

        // Select only dashboard-gated types plus Task
        controller.selectAllEntryTypes([
          'Task',
          'MeasurementEntry',
          'QuantitativeEntry',
        ]);

        settle(async);

        expect(
          controller.state.selectedEntryTypes.toSet(),
          equals({'Task', 'MeasurementEntry', 'QuantitativeEntry'}),
        );

        // Disable dashboards
        setup.configFlagsController.add(<String>{});

        settle(async);

        // Only Task should remain
        expect(controller.state.selectedEntryTypes.toSet(), equals({'Task'}));
      });
    });
  });

  // Due date sorting tests moved to journal_query_runner_test.dart

  // Agent assignment filter query tests moved to journal_query_runner_test.dart

  // Project filter tests moved to journal_page_controller_filter_test.dart

  // Vector search tests moved to journal_query_runner_test.dart

  group('Persisted Filters - Tasks Tab', () {
    test('loads persisted task filters and applies them', () {
      fakeAsync((async) {
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

        setup.container.read(journalPageControllerProvider(true));

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
        expect(
          state.agentAssignmentFilter,
          equals(AgentAssignmentFilter.all),
        );
      });
    });
  });

  group('Agent Assignment Filter Query', () {
    late AgentDatabase agentDb;
    late AgentRepository agentRepo;

    final taskWithAgent = Task(
      data: TaskData(
        status: TaskStatus.open(
          id: 'status_1',
          createdAt: DateTime(2024),
          utcOffset: 0,
        ),
        title: 'Task with agent',
        statusHistory: const [],
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
      ),
      meta: Metadata(
        id: 'task-with-agent',
        createdAt: DateTime(2024),
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );

    final taskWithoutAgent = Task(
      data: TaskData(
        status: TaskStatus.open(
          id: 'status_2',
          createdAt: DateTime(2024, 1, 2),
          utcOffset: 0,
        ),
        title: 'Task without agent',
        statusHistory: const [],
        dateFrom: DateTime(2024, 1, 2),
        dateTo: DateTime(2024, 1, 2),
      ),
      meta: Metadata(
        id: 'task-without-agent',
        createdAt: DateTime(2024, 1, 2),
        dateFrom: DateTime(2024, 1, 2),
        dateTo: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
      ),
    );

    setUp(() async {
      agentDb = AgentDatabase(inMemoryDatabase: true, background: false);
      agentRepo = AgentRepository(agentDb);
      getIt.registerSingleton<AgentDatabase>(agentDb);

      // Insert an agent_task link for 'task-with-agent'
      await agentRepo.upsertLink(
        AgentTaskLink(
          id: 'link-1',
          fromId: 'agent-001',
          toId: 'task-with-agent',
          createdAt: _testDate,
          updatedAt: _testDate,
          vectorClock: null,
        ),
      );

      // Return both tasks from the journal DB
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
      ).thenAnswer((_) async => [taskWithAgent, taskWithoutAgent]);
    });

    tearDown(() async {
      await agentDb.close();
      getIt.unregister<AgentDatabase>();
    });

    test('hasAgent filter returns only tasks with agent links', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
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
        expect(items.first.meta.id, equals('task-with-agent'));
      });
    });

    test('noAgent filter returns only tasks without agent links', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          agentAssignmentFilter: AgentAssignmentFilter.noAgent,
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
        expect(items.first.meta.id, equals('task-without-agent'));
      });
    });

    test('all filter returns all tasks without agent DB access', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // Default is 'all' — should return both tasks
        controller.applyBatchFilterUpdate(
          agentAssignmentFilter: AgentAssignmentFilter.all,
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
      });
    });

    test(
      'hasAgent with byDueDate sort applies both filter and sort',
      () {
        fakeAsync((async) {
          final taskWithAgentAndDue = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_3',
                createdAt: DateTime(2024, 1, 3),
                utcOffset: 0,
              ),
              title: 'Agent task with due',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 3),
              dateTo: DateTime(2024, 1, 3),
              due: DateTime(2024, 6, 15),
            ),
            meta: Metadata(
              id: 'task-with-agent',
              createdAt: DateTime(2024, 1, 3),
              dateFrom: DateTime(2024, 1, 3),
              dateTo: DateTime(2024, 1, 3),
              updatedAt: DateTime(2024, 1, 3),
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
            (_) async => [taskWithAgentAndDue, taskWithoutAgent],
          );

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
          ).thenAnswer(
            (_) async => [taskWithAgentAndDue, taskWithoutAgent],
          );

          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.applyBatchFilterUpdate(
            agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
            sortOption: TaskSortOption.byDueDate,
          );

          settle(async);

          final items = setup.container
              .read(journalPageControllerProvider(true))
              .pagingController
              ?.value
              .items;

          expect(items, isNotNull);
          expect(items!.length, equals(1));
          expect(items.first.meta.id, equals('task-with-agent'));
          verify(
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
          ).called(1);
        });
      },
    );

    test('fetches in normal-sized chunks when agent filter is active', () {
      fakeAsync((async) {
        int? capturedLimit;
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
        ).thenAnswer((invocation) async {
          capturedLimit = invocation.namedArguments[#limit] as int?;
          return <JournalEntity>[];
        });

        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          agentAssignmentFilter: AgentAssignmentFilter.noAgent,
        );

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Post-filters use normal chunk size; loop handles exhaustion
        expect(capturedLimit, equals(50));
      });
    });
  });
}
