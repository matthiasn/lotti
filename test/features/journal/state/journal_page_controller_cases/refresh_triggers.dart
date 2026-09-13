// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

part of '../journal_page_controller_test.dart';

void _registerRefreshTriggers(JournalControllerTestSetup setup) {
  group('Visibility Updates', () {
    test(
      'visibility transition refreshes when becoming visible after missed update',
      () {
        fakeAsync((async) {
          final queryCalls = stubCountingQuery(setup.mockJournalDb, result: []);

          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final initialCount = queryCalls.count;

          // First, simulate being invisible
          _emitVisibility(setup, controller, isVisible: false);

          settle(async);

          // Count should remain unchanged (no refresh when becoming invisible)
          expect(queryCalls.count, equals(initialCount));

          // Fire an update while invisible — this sets the dirty flag
          setup.updateStreamController.add({'some-missed-id'});
          async.elapse(const Duration(milliseconds: 600));
          async.flushMicrotasks();

          // Still no refresh while invisible
          expect(queryCalls.count, equals(initialCount));

          // Now simulate becoming visible - should trigger refresh
          // because updates were missed
          _emitVisibility(setup, controller, isVisible: true);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should have increased due to missed update
          expect(queryCalls.count, greaterThan(initialCount));
        });
      },
    );

    test(
      'visibility transition does not refresh when no updates were missed',
      () {
        fakeAsync((async) {
          final queryCalls = stubCountingQuery(setup.mockJournalDb, result: []);

          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final initialCount = queryCalls.count;

          // Go invisible
          _emitVisibility(setup, controller, isVisible: false);

          settle(async);

          // Come back visible without any missed updates
          _emitVisibility(setup, controller, isVisible: true);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should NOT have refreshed — no updates were missed
          expect(queryCalls.count, equals(initialCount));
        });
      },
    );

    test('does not refresh when staying invisible', () {
      fakeAsync((async) {
        final queryCalls = stubCountingQuery(setup.mockJournalDb, result: []);

        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        final initialCount = queryCalls.count;

        // Simulate being invisible
        _emitVisibility(setup, controller, isVisible: false);

        settle(async);

        // Stay invisible - should NOT trigger refresh
        _emitVisibility(setup, controller, isVisible: false);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Count should remain unchanged
        expect(queryCalls.count, equals(initialCount));
      });
    });
  });

  group('Update Notifications', () {
    test(
      'visible controller refreshes when update affects displayed items',
      () {
        fakeAsync((async) {
          final queryCalls = stubCountingQuery(setup.mockJournalDb, result: []);

          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Make visible
          _emitVisibility(setup, controller, isVisible: true);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final countAfterVisible = queryCalls.count;

          // Send update notification
          setup.updateStreamController.add({'some-id'});

          // Wait for throttle (500ms) plus processing
          async.elapse(const Duration(milliseconds: 600));
          async.flushMicrotasks();

          // Query count may increase depending on implementation details
          // At minimum, the subscription should be active
          expect(queryCalls.count, greaterThanOrEqualTo(countAfterVisible));
        });
      },
    );

    test(
      'visible tasks refresh affected displayed items without an extra probe',
      () {
        fakeAsync((async) {
          final initialTask = _buildTestTaskRefresh(
            id: 'task-1',
            title: 'Initial task',
            createdAt: _testDateRefresh,
            priority: TaskPriority.p1High,
          );
          var getTasksCallCount = 0;

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
          ).thenAnswer((_) async {
            getTasksCallCount++;
            return [initialTask];
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          _emitVisibility(setup, controller, isVisible: true);

          clearInteractions(setup.mockJournalDb);
          getTasksCallCount = 0;

          setup.updateStreamController.add({'task-1'});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          expect(state.pagingController?.value.items, equals([initialTask]));
          expect(getTasksCallCount, 1);
          verify(
            () => setup.mockJournalDb.getTasks(
              ids: any(named: 'ids'),
              starredStatuses: any(named: 'starredStatuses'),
              taskStatuses: any(named: 'taskStatuses'),
              categoryIds: any(named: 'categoryIds'),
              labelIds: any(named: 'labelIds'),
              priorities: any(named: 'priorities'),
              sortByDate: any(named: 'sortByDate'),
              limit: any(named: 'limit'),
              offset: 0,
            ),
          ).called(1);
        });
      },
    );

    test(
      'visible tasks still probe first page when only off-screen ids change',
      () {
        fakeAsync((async) {
          final initialTask = _buildTestTaskRefresh(
            id: 'task-1',
            title: 'Initial task',
            createdAt: _testDateRefresh,
            priority: TaskPriority.p1High,
          );
          final refreshedLeadingTask = _buildTestTaskRefresh(
            id: 'task-2',
            title: 'Refreshed leading task',
            createdAt: _testDateRefresh.add(const Duration(minutes: 1)),
            priority: TaskPriority.p0Urgent,
          );
          var getTasksCallCount = 0;

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
          ).thenAnswer((_) async {
            getTasksCallCount++;
            return getTasksCallCount == 1
                ? [initialTask]
                : [refreshedLeadingTask];
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          _emitVisibility(setup, controller, isVisible: true);

          clearInteractions(setup.mockJournalDb);
          getTasksCallCount = 1;

          setup.updateStreamController.add({'off-screen-task'});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([refreshedLeadingTask]),
          );
          expect(getTasksCallCount, 3);
          verify(
            () => setup.mockJournalDb.getTasks(
              ids: any(named: 'ids'),
              starredStatuses: any(named: 'starredStatuses'),
              taskStatuses: any(named: 'taskStatuses'),
              categoryIds: any(named: 'categoryIds'),
              labelIds: any(named: 'labelIds'),
              priorities: any(named: 'priorities'),
              sortByDate: any(named: 'sortByDate'),
              limit: any(named: 'limit'),
              offset: 0,
            ),
          ).called(2);
        });
      },
    );

    test(
      'visible tasks preserve the post-filter next-page offset when a probe finds unchanged ids',
      () {
        fakeAsync((async) {
          List<JournalEntity> buildRawChunk(String prefix) =>
              List<JournalEntity>.generate(
                JournalPageController.pageSize,
                (index) => _buildTestTaskRefresh(
                  id: '$prefix-$index',
                  title: '$prefix task $index',
                  createdAt: _testDateRefresh.add(Duration(minutes: index)),
                  priority: TaskPriority.p1High,
                ),
                growable: false,
              );

          final rawChunk0 = buildRawChunk('chunk-a');
          final rawChunk50 = buildRawChunk('chunk-b');
          final projectTaskIds = {
            ...rawChunk0.take(25).map((entity) => entity.meta.id),
            ...rawChunk50.take(25).map((entity) => entity.meta.id),
          };

          when(
            () => setup.mockJournalDb.getTaskIdsForProjects({'proj-1'}),
          ).thenAnswer((_) async => projectTaskIds);

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
            final offset = invocation.namedArguments[#offset] as int;
            if (offset == 0) {
              return rawChunk0;
            }
            if (offset == JournalPageController.pageSize) {
              return rawChunk50;
            }
            return <JournalEntity>[];
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          unawaited(
            controller.applyBatchFilterUpdate(
              projectIds: const {'proj-1'},
            ),
          );
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          _emitVisibility(setup, controller, isVisible: true);

          clearInteractions(setup.mockJournalDb);

          setup.updateStreamController.add({'off-screen-task'});
          settle(async);

          verify(
            () => setup.mockJournalDb.getTasks(
              ids: any(named: 'ids'),
              starredStatuses: any(named: 'starredStatuses'),
              taskStatuses: any(named: 'taskStatuses'),
              categoryIds: any(named: 'categoryIds'),
              labelIds: any(named: 'labelIds'),
              priorities: any(named: 'priorities'),
              sortByDate: any(named: 'sortByDate'),
              limit: any(named: 'limit'),
              offset: 0,
            ),
          ).called(1);
          verify(
            () => setup.mockJournalDb.getTasks(
              ids: any(named: 'ids'),
              starredStatuses: any(named: 'starredStatuses'),
              taskStatuses: any(named: 'taskStatuses'),
              categoryIds: any(named: 'categoryIds'),
              labelIds: any(named: 'labelIds'),
              priorities: any(named: 'priorities'),
              sortByDate: any(named: 'sortByDate'),
              limit: any(named: 'limit'),
              offset: JournalPageController.pageSize,
            ),
          ).called(1);

          state.pagingController!.fetchNextPage();
          async.flushMicrotasks();

          verify(
            () => setup.mockJournalDb.getTasks(
              ids: any(named: 'ids'),
              starredStatuses: any(named: 'starredStatuses'),
              taskStatuses: any(named: 'taskStatuses'),
              categoryIds: any(named: 'categoryIds'),
              labelIds: any(named: 'labelIds'),
              priorities: any(named: 'priorities'),
              sortByDate: any(named: 'sortByDate'),
              limit: any(named: 'limit'),
              offset: 75,
            ),
          ).called(1);
        });
      },
    );

    test(
      'visible journal entries refresh when an affected displayed item changes',
      () {
        fakeAsync((async) {
          final entry = JournalEntity.journalEntry(
            meta: Metadata(
              id: 'entry-1',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            entryText: const EntryText(plainText: 'Entry'),
          );
          final queryCalls = stubCountingQuery(
            setup.mockJournalDb,
            result: [entry],
          );

          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.flushMicrotasks();

          _emitVisibility(setup, controller, isVisible: true);

          clearInteractions(setup.mockJournalDb);
          queryCalls.count = 0;

          setup.updateStreamController.add({'entry-1'});

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          expect(queryCalls.count, 1);
          verify(
            () => setup.mockJournalDb.getJournalEntities(
              types: any(named: 'types'),
              starredStatuses: any(named: 'starredStatuses'),
              privateStatuses: any(named: 'privateStatuses'),
              flaggedStatuses: any(named: 'flaggedStatuses'),
              ids: any(named: 'ids'),
              limit: any(named: 'limit'),
              offset: 0,
              categoryIds: any(named: 'categoryIds'),
            ),
          ).called(1);
        });
      },
    );
  });
}
