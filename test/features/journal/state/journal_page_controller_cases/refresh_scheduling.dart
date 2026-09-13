// ignore_for_file: avoid_redundant_argument_values

part of '../journal_page_controller_test.dart';

void _registerRefreshScheduling(JournalControllerTestSetup setup) {
  group('Refresh Behavior', () {
    test(
      'refreshQuery keeps visible first-page items until replacement data arrives',
      () {
        fakeAsync((async) {
          final initialTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-1',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Initial task',
              status: TaskStatus.open(
                id: 'status-initial',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
          );
          final refreshedTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-1',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh.add(const Duration(minutes: 1)),
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Refreshed task',
              status: TaskStatus.open(
                id: 'status-refreshed',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
          );
          final refreshCompleter = Completer<List<JournalEntity>>();
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
          ).thenAnswer((_) {
            getTasksCallCount++;
            if (getTasksCallCount == 1) {
              return Future.value([initialTask]);
            }
            if (getTasksCallCount == 2) {
              return refreshCompleter.future;
            }
            return Future.value([refreshedTask]);
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );
          expect(state.pagingController?.value.isLoading, isTrue);

          refreshCompleter.complete([refreshedTask]);
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([refreshedTask]),
          );
          expect(state.pagingController?.value.isLoading, isFalse);
        });
      },
    );

    test(
      'refreshQuery without preserveVisibleItems does full refresh — '
      'items are transiently cleared',
      () {
        fakeAsync((async) {
          final initialTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-1',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Initial task',
              status: TaskStatus.open(
                id: 'status-initial',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
          );
          final refreshedTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-2',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Refreshed task',
              status: TaskStatus.open(
                id: 'status-refreshed',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
          );
          final refreshCompleter = Completer<List<JournalEntity>>();
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
          ).thenAnswer((_) {
            getTasksCallCount++;
            if (getTasksCallCount == 1) {
              return Future.value([initialTask]);
            }
            return refreshCompleter.future;
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );

          // Default refreshQuery (preserveVisibleItems: false) triggers
          // a full refresh — items are transiently cleared.
          unawaited(controller.refreshQuery());
          async.flushMicrotasks();

          // Items are cleared during full refresh (unlike retained refresh)
          expect(state.pagingController?.value.items, isNull);

          // Complete the refresh query
          refreshCompleter.complete([refreshedTask]);
          async.flushMicrotasks();

          // Items are now repopulated with the new data
          expect(
            state.pagingController?.value.items,
            equals([refreshedTask]),
          );
        });
      },
    );

    test(
      'refreshQuery with preserveVisibleItems handles query error '
      'by restoring offset and setting error state',
      () {
        fakeAsync((async) {
          final initialTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-1',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Initial task',
              status: TaskStatus.open(
                id: 'status-initial',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
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
          ).thenAnswer((_) {
            getTasksCallCount++;
            if (getTasksCallCount == 1) {
              return Future.value([initialTask]);
            }
            return Future<List<JournalEntity>>.error(Exception('DB error'));
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );
          expect(state.pagingController?.value.error, isA<Exception>());
          expect(state.pagingController?.value.isLoading, isFalse);
        });
      },
    );

    test(
      'finishRetainedRefreshWithError is no-op when refresh token '
      'does not match',
      () {
        fakeAsync((async) {
          final initialTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-1',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Initial task',
              status: TaskStatus.open(
                id: 'status-initial',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
          );
          final firstRefreshCompleter = Completer<List<JournalEntity>>();
          final secondRefreshCompleter = Completer<List<JournalEntity>>();
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
          ).thenAnswer((_) {
            getTasksCallCount++;
            if (getTasksCallCount == 1) {
              return Future.value([initialTask]);
            }
            if (getTasksCallCount == 2) {
              return firstRefreshCompleter.future;
            }
            return secondRefreshCompleter.future;
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          firstRefreshCompleter.completeError(Exception('stale'));
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );
          expect(state.pagingController?.value.isLoading, isTrue);

          final updatedTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-2',
              createdAt: _testDateRefresh,
              updatedAt: _testDateRefresh,
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
            ),
            data: TaskData(
              dateFrom: _testDateRefresh,
              dateTo: _testDateRefresh,
              statusHistory: const [],
              title: 'Updated task',
              status: TaskStatus.open(
                id: 'status-updated',
                createdAt: _testDateRefresh,
                utcOffset: 0,
              ),
            ),
          );
          secondRefreshCompleter.complete([updatedTask]);
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([updatedTask]),
          );
          expect(state.pagingController?.value.isLoading, isFalse);
          expect(state.pagingController?.value.error, isNull);
        });
      },
    );

    test(
      'refreshQuery replaces all loaded pages so later-page tasks can regroup',
      () {
        fakeAsync((async) {
          final initialFirstPage = List<JournalEntity>.generate(
            JournalPageController.pageSize,
            (index) => _buildTestTaskRefresh(
              id: 'task-$index',
              title: 'Initial task $index',
              createdAt: _testDateRefresh.add(Duration(minutes: index)),
              priority: TaskPriority.p1High,
            ),
            growable: false,
          );
          final initialSecondPageTask = _buildTestTaskRefresh(
            id: 'task-late',
            title: 'Initial late task',
            createdAt: _testDateRefresh.add(const Duration(hours: 3)),
            priority: TaskPriority.p2Medium,
          );
          final regroupedTask = _buildTestTaskRefresh(
            id: 'task-late',
            title: 'Regrouped late task',
            createdAt: _testDateRefresh.add(const Duration(hours: 3)),
            updatedAt: _testDateRefresh.add(const Duration(days: 1)),
            priority: TaskPriority.p0Urgent,
          );
          final refreshedFirstPage = <JournalEntity>[
            regroupedTask,
            ...initialFirstPage.take(JournalPageController.pageSize - 1),
          ];
          final refreshedSecondPageTask = _buildTestTaskRefresh(
            id: 'task-tail',
            title: 'Refreshed tail task',
            createdAt: _testDateRefresh.add(const Duration(hours: 4)),
            priority: TaskPriority.p2Medium,
          );
          final firstPageCompleter = Completer<List<JournalEntity>>();
          final secondPageCompleter = Completer<List<JournalEntity>>();

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          state.pagingController!.value = PagingState<int, JournalEntity>(
            pages: [
              initialFirstPage,
              [initialSecondPageTask],
            ],
            keys: const [0, JournalPageController.pageSize],
            hasNextPage: false,
          );

          clearInteractions(setup.mockJournalDb);

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
          ).thenAnswer((invocation) {
            final offset = invocation.namedArguments[#offset] as int;
            if (offset == 0) {
              return firstPageCompleter.future;
            }
            if (offset == JournalPageController.pageSize) {
              return secondPageCompleter.future;
            }
            return Future.value(<JournalEntity>[]);
          });

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([
              ...initialFirstPage,
              initialSecondPageTask,
            ]),
          );
          expect(state.pagingController?.value.isLoading, isTrue);
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

          firstPageCompleter.complete(refreshedFirstPage);
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([
              ...initialFirstPage,
              initialSecondPageTask,
            ]),
          );
          expect(state.pagingController?.value.isLoading, isTrue);

          secondPageCompleter.complete([refreshedSecondPageTask]);
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([
              ...refreshedFirstPage,
              refreshedSecondPageTask,
            ]),
          );
          expect(
            state.pagingController?.value.items,
            isNot(contains(initialSecondPageTask)),
          );
          expect(state.pagingController?.value.isLoading, isFalse);
        });
      },
    );

    test(
      'refreshQuery keeps sequential retained refresh when project filters are active',
      () {
        fakeAsync((async) {
          final initialFirstPage = List<JournalEntity>.generate(
            JournalPageController.pageSize,
            (index) => _buildTestTaskRefresh(
              id: 'task-$index',
              title: 'Initial task $index',
              createdAt: _testDateRefresh.add(Duration(minutes: index)),
              priority: TaskPriority.p1High,
            ),
            growable: false,
          );
          final initialSecondPageTask = _buildTestTaskRefresh(
            id: 'task-late',
            title: 'Initial late task',
            createdAt: _testDateRefresh.add(const Duration(hours: 3)),
            priority: TaskPriority.p2Medium,
          );
          final refreshedFirstPage = List<JournalEntity>.generate(
            JournalPageController.pageSize,
            (index) => _buildTestTaskRefresh(
              id: 'refreshed-$index',
              title: 'Refreshed task $index',
              createdAt: _testDateRefresh.add(Duration(hours: index)),
              priority: TaskPriority.p1High,
            ),
            growable: false,
          );
          final refreshedSecondPageTask = _buildTestTaskRefresh(
            id: 'refreshed-tail',
            title: 'Refreshed tail task',
            createdAt: _testDateRefresh.add(const Duration(hours: 5)),
            priority: TaskPriority.p2Medium,
          );
          final firstPageCompleter = Completer<List<JournalEntity>>();
          final secondPageCompleter = Completer<List<JournalEntity>>();

          when(
            () => setup.mockJournalDb.getTaskIdsForProjects(any()),
          ).thenAnswer(
            (_) async => {
              ...initialFirstPage.map((entity) => entity.meta.id),
              initialSecondPageTask.meta.id,
              ...refreshedFirstPage.map((entity) => entity.meta.id),
              refreshedSecondPageTask.meta.id,
            },
          );

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
          async.flushMicrotasks();

          state.pagingController!.value = PagingState<int, JournalEntity>(
            pages: [
              initialFirstPage,
              [initialSecondPageTask],
            ],
            keys: const [0, JournalPageController.pageSize],
            hasNextPage: false,
          );

          clearInteractions(setup.mockJournalDb);

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
          ).thenAnswer((invocation) {
            final offset = invocation.namedArguments[#offset] as int;
            if (offset == 0) {
              return firstPageCompleter.future;
            }
            if (offset == JournalPageController.pageSize) {
              return secondPageCompleter.future;
            }
            return Future.value(<JournalEntity>[]);
          });

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
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
              offset: 0,
            ),
          ).called(1);
          verifyNever(
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
          );

          firstPageCompleter.complete(refreshedFirstPage);
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
              offset: JournalPageController.pageSize,
            ),
          ).called(1);

          secondPageCompleter.complete([refreshedSecondPageTask]);
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([
              ...refreshedFirstPage,
              refreshedSecondPageTask,
            ]),
          );
        });
      },
    );

    test(
      'stale project-filter refresh does not overwrite the winning next-page offset',
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

          final initialFirstPage = List<JournalEntity>.generate(
            JournalPageController.pageSize,
            (index) => _buildTestTaskRefresh(
              id: 'initial-$index',
              title: 'Initial task $index',
              createdAt: _testDateRefresh.add(Duration(minutes: index)),
              priority: TaskPriority.p1High,
            ),
            growable: false,
          );
          final firstRefreshChunk0 = buildRawChunk('first-a');
          final firstRefreshChunk50 = buildRawChunk('first-b');
          final secondRefreshChunk0 = buildRawChunk('second-a');
          final secondRefreshChunk50 = buildRawChunk('second-b');
          final firstRefreshProjectIds = {
            ...firstRefreshChunk0.take(25).map((entity) => entity.meta.id),
            ...firstRefreshChunk50.take(25).map((entity) => entity.meta.id),
          };
          final secondRefreshProjectIds = {
            ...secondRefreshChunk0.take(10).map((entity) => entity.meta.id),
            ...secondRefreshChunk50.take(40).map((entity) => entity.meta.id),
          };
          final firstRefreshSecondChunkCompleter =
              Completer<List<JournalEntity>>();
          final nextPageCompleter = Completer<List<JournalEntity>>();
          var projectIdsCallCount = 0;
          var offset0CallCount = 0;
          var offset50CallCount = 0;

          when(
            () => setup.mockJournalDb.getTaskIdsForProjects(any()),
          ).thenAnswer((_) async {
            projectIdsCallCount++;
            if (projectIdsCallCount == 1) {
              return firstRefreshProjectIds;
            }
            return secondRefreshProjectIds;
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
          async.flushMicrotasks();

          state.pagingController!.value = PagingState<int, JournalEntity>(
            pages: [initialFirstPage],
            keys: const [0],
            hasNextPage: true,
          );

          clearInteractions(setup.mockJournalDb);

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
          ).thenAnswer((invocation) {
            final offset = invocation.namedArguments[#offset] as int;
            if (offset == 0) {
              offset0CallCount++;
              return Future.value(
                offset0CallCount == 1
                    ? firstRefreshChunk0
                    : secondRefreshChunk0,
              );
            }
            if (offset == JournalPageController.pageSize) {
              offset50CallCount++;
              return offset50CallCount == 1
                  ? firstRefreshSecondChunkCompleter.future
                  : Future.value(secondRefreshChunk50);
            }
            if (offset == 90) {
              return nextPageCompleter.future;
            }
            return Future.value(<JournalEntity>[]);
          });

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          firstRefreshSecondChunkCompleter.complete(firstRefreshChunk50);
          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([
              ...secondRefreshChunk0.take(10),
              ...secondRefreshChunk50.take(40),
            ]),
          );
          expect(state.pagingController?.value.hasNextPage, isTrue);

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
              offset: 90,
            ),
          ).called(1);

          nextPageCompleter.complete(<JournalEntity>[]);
          async.flushMicrotasks();
        });
      },
    );

    test(
      'sequential retained refresh aborts loop iteration when a second '
      'refresh supersedes the first',
      () {
        fakeAsync((async) {
          final initialFirstPage = List<JournalEntity>.generate(
            JournalPageController.pageSize,
            (index) => _buildTestTaskRefresh(
              id: 'task-$index',
              title: 'Initial task $index',
              createdAt: _testDateRefresh.add(Duration(minutes: index)),
              priority: TaskPriority.p1High,
            ),
            growable: false,
          );
          final initialSecondPageTask = _buildTestTaskRefresh(
            id: 'task-late',
            title: 'Initial late task',
            createdAt: _testDateRefresh.add(const Duration(hours: 3)),
            priority: TaskPriority.p2Medium,
          );
          final winnerTask = _buildTestTaskRefresh(
            id: 'winner-task',
            title: 'Winner task',
            createdAt: _testDateRefresh.add(const Duration(hours: 10)),
            priority: TaskPriority.p0Urgent,
          );
          final allProjectIds = {
            ...initialFirstPage.map((e) => e.meta.id),
            initialSecondPageTask.meta.id,
            winnerTask.meta.id,
          };
          final firstRefreshPage0Completer = Completer<List<JournalEntity>>();
          var getTasksCallCount = 0;

          when(
            () => setup.mockJournalDb.getTaskIdsForProjects(any()),
          ).thenAnswer((_) async => allProjectIds);

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
          async.flushMicrotasks();

          // Set up two pages so sequential loop iterates twice.
          state.pagingController!.value = PagingState<int, JournalEntity>(
            pages: [
              initialFirstPage,
              [initialSecondPageTask],
            ],
            keys: const [0, JournalPageController.pageSize],
            hasNextPage: false,
          );

          clearInteractions(setup.mockJournalDb);

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
          ).thenAnswer((_) {
            getTasksCallCount++;
            // First call (first refresh, page 0): slow — use completer.
            if (getTasksCallCount == 1) {
              return firstRefreshPage0Completer.future;
            }
            // All subsequent calls (second refresh): resolve instantly.
            return Future.value([winnerTask]);
          });

          // Start first sequential retained refresh (page 0 will block).
          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          // First refresh is now awaiting page 0. Start second refresh
          // which supersedes the first's refresh token.
          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          // Complete the first refresh's page 0 — the loop should detect
          // the stale token and abort before fetching page 1.
          firstRefreshPage0Completer.complete(initialFirstPage);
          async.flushMicrotasks();

          // The winning (second) refresh should have replaced the pages.
          expect(
            state.pagingController?.value.items,
            equals([winnerTask]),
          );
          expect(state.pagingController?.value.isLoading, isFalse);
        });
      },
    );

    test(
      'refreshQuery with preserveVisibleItems rethrows non-Exception errors',
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
          ).thenAnswer((_) {
            getTasksCallCount++;
            if (getTasksCallCount == 1) {
              return Future.value([initialTask]);
            }
            // Throw a non-Exception (Error) to trigger the rethrow path.
            return Future<List<JournalEntity>>.error(
              StateError('fatal error'),
            );
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          setup.container.read(journalPageControllerProvider(true).notifier);

          async.flushMicrotasks();

          expect(
            state.pagingController?.value.items,
            equals([initialTask]),
          );

          // The Error should propagate as an uncaught error in the zone.
          Object? caughtError;
          runZonedGuarded(
            () {
              fakeAsync((innerAsync) {
                // Re-read because we're in a new fakeAsync zone — but we
                // only need to trigger refreshQuery on the existing
                // controller.  Directly call the paging controller's
                // retained-refresh path by calling refreshQuery.
                final ctrl = setup.container.read(
                  journalPageControllerProvider(true).notifier,
                );
                unawaited(
                  ctrl.refreshQuery(preserveVisibleItems: true),
                );
                innerAsync.flushMicrotasks();
              });
            },
            (error, stack) {
              caughtError = error;
            },
          );

          async.flushMicrotasks();

          // StateError is not an Exception, so it should be rethrown.
          expect(caughtError, isA<StateError>());
        });
      },
    );

    test(
      'refreshQuery repopulates an empty page from offset zero',
      () {
        fakeAsync((async) {
          final offsets = <int?>[];
          final nextTask = _buildTestTaskRefresh(
            id: 'new-task',
            title: 'Newly available task',
            createdAt: _testDateRefresh,
          );
          var result = <JournalEntity>[];

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
            offsets.add(invocation.namedArguments[#offset] as int?);
            return result;
          });

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.flushMicrotasks();

          // Keep the exhausted empty page: a newly available task must still
          // be discovered when a preserving refresh is requested.
          state.pagingController!.value = PagingState<int, JournalEntity>(
            pages: const [[]],
            keys: const [0],
            hasNextPage: false,
          );

          clearInteractions(setup.mockJournalDb);
          offsets.clear();
          result = [nextTask];

          // Assert the observable query and result, without coupling the test
          // to which equivalent paging-controller refresh method is selected.
          unawaited(
            controller.refreshQuery(preserveVisibleItems: true),
          );
          async.flushMicrotasks();

          expect(offsets, [0]);
          expect(state.pagingController!.value.items, [nextTask]);
        });
      },
    );
  });
}
