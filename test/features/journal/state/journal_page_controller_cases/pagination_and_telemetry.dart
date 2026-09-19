// ignore_for_file: cascade_invocations

part of '../journal_page_controller_test.dart';

void _registerPaginationAndTelemetry(JournalControllerTestSetup setup) {
  group('Persisted Entry Types', () {
    test('loads persisted entry types and applies them', () {
      fakeAsync((async) {
        when(
          () => setup.mockSettingsDb.itemByKey('SELECTED_ENTRY_TYPES'),
        ).thenAnswer((_) async => '["Task","JournalEntry"]');
        // Reconciled against today's types, so nothing joins the selection.
        when(
          () => setup.mockSettingsDb.itemByKey(
            JournalFilterPersistence.reconciledEntryTypesKey,
          ),
        ).thenAnswer((_) async => jsonEncode(entryTypes));

        setup.container.read(journalPageControllerProvider(false));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(
          state.selectedEntryTypes.toSet(),
          equals({'Task', 'JournalEntry'}),
        );
      });
    });
  });

  group('Vector Search Telemetry', () {
    test('vector search flow updates telemetry state fields', () {
      fakeAsync((async) {
        final mockVectorSearchRepo = MockVectorSearchRepository();
        getIt.registerSingleton<VectorSearchRepository>(
          mockVectorSearchRepo,
        );

        when(
          () => mockVectorSearchRepo.searchRelatedTasks(
            query: any(named: 'query'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer(
          (_) async => VectorSearchResult(
            entities: [],
            elapsed: const Duration(milliseconds: 42),
            distances: const {'task-1': 0.5},
          ),
        );

        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // Enable vector search flag
        setup.configFlagsController.add({enableVectorSearchFlag});

        settle(async);

        // Set search mode to vector
        controller.setSearchMode(SearchMode.vector);

        settle(async);

        // Set a search string to trigger vector search
        controller.setSearchString('semantic query');

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.vectorSearchInFlight, isFalse);
        expect(
          state.vectorSearchElapsed,
          equals(const Duration(milliseconds: 42)),
        );
        expect(state.vectorSearchResultCount, equals(0));
        expect(state.vectorSearchDistances, equals({'task-1': 0.5}));

        getIt.unregister<VectorSearchRepository>();
      });
    });
  });

  group('Published Search Mode', () {
    test('returns fullText by default', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        expect(controller.state.searchMode, equals(SearchMode.fullText));
      });
    });

    test('returns vector after setSearchMode with vector search enabled', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        setup.configFlagsController.add({enableVectorSearchFlag});

        settle(async);

        controller.setSearchMode(SearchMode.vector);

        settle(async);

        expect(controller.state.searchMode, equals(SearchMode.vector));
      });
    });
  });

  group('Pagination - next page key calculation (lines 211-213)', () {
    // When the DB returns a full page (pageSize=50 items), the paging
    // controller must compute the next page key as
    //   currentKeys.last + currentPages.last.length  (= 0 + 50 = 50).
    // This exercises the branch at lines 210-213 of _getNextPageKey.

    test(
      'second page is fetched at offset equal to first-page item count',
      () {
        fakeAsync((async) {
          const pageSize = JournalPageController.pageSize; // 50

          // Build a list of pageSize distinct JournalEntry items.
          final fullPage = List<JournalEntity>.generate(
            pageSize,
            (i) => JournalEntry(
              meta: Metadata(
                id: 'entry-$i',
                createdAt: DateTime(2024, 1, i + 1),
                dateFrom: DateTime(2024, 1, i + 1),
                dateTo: DateTime(2024, 1, i + 1),
                updatedAt: DateTime(2024, 1, i + 1),
              ),
            ),
          );

          // Track every offset the DB is called with.
          final capturedOffsets = <int>[];
          when(
            () => setup.mockJournalDb.getJournalEntities(
              types: any(named: 'types'),
              starredStatuses: any(named: 'starredStatuses'),
              privateStatuses: any(named: 'privateStatuses'),
              flaggedStatuses: any(named: 'flaggedStatuses'),
              ids: any(named: 'ids'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              categoryIds: any(named: 'categoryIds'),
            ),
          ).thenAnswer((invocation) async {
            final offset = invocation.namedArguments[#offset] as int? ?? 0;
            capturedOffsets.add(offset);
            // First page: return full page; subsequent pages: empty.
            return offset == 0 ? fullPage : <JournalEntity>[];
          });

          setup.container.read(journalPageControllerProvider(false));

          // Let page 0 load.
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final pagingController = setup.container
              .read(journalPageControllerProvider(false))
              .pagingController;
          expect(pagingController, isNotNull);

          // After page 0 is loaded with a full page, fetchNextPage triggers
          // _getNextPageKey with pages=[[50 items]], keys=[0].
          // That must enter the branch at lines 210-213 and return 50.
          pagingController!.fetchNextPage();

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // The DB must have been asked for offset 50 (the second page key).
          expect(
            capturedOffsets,
            contains(pageSize),
            reason:
                '_getNextPageKey should have returned $pageSize '
                'as next page key',
          );
        });
      },
    );
  });

  group('Persisted Filters - Journal Tab (lines 594-595)', () {
    // When showTasks=false and persisted filters exist, the else-branch
    // at lines 593-596 clears _selectedLabelIds and _selectedPriorities
    // while still applying _selectedCategoryIds from the persisted filter.

    test(
      'journal tab loads persisted category filter and clears label/priority',
      () {
        fakeAsync((async) {
          // Persist a filter that includes non-empty labelIds/priorities
          // and a category selection.
          const persistedJson =
              '{"selectedCategoryIds":["cat-journal"],'
              '"selectedTaskStatuses":[],'
              '"selectedProjectIds":[],'
              '"selectedLabelIds":["label-old"],'
              '"selectedPriorities":["P1"],'
              '"sortOption":"byPriority",'
              '"showCreationDate":false,'
              '"showDueDate":true,'
              '"showCoverArt":true,'
              '"showProjectsHeader":true,'
              '"showDistances":false,'
              '"agentAssignmentFilter":"all"}';

          when(
            () => setup.mockSettingsDb.itemByKey(
              JournalPageController.journalCategoryFiltersKey,
            ),
          ).thenAnswer((_) async => persistedJson);

          setup.container.read(journalPageControllerProvider(false));

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = setup.container.read(
            journalPageControllerProvider(false),
          );

          // Category is loaded from persisted filter.
          expect(state.selectedCategoryIds, equals({'cat-journal'}));

          // Labels and priorities are cleared by the else-branch
          // (lines 594-595) regardless of what was in the persisted JSON.
          expect(
            state.selectedLabelIds,
            isEmpty,
            reason: 'journal tab must clear persisted labelIds',
          );
          expect(
            state.selectedPriorities,
            isEmpty,
            reason: 'journal tab must clear persisted priorities',
          );
        });
      },
    );
  });

  group('refreshQuery with null pagingController (line 658)', () {
    // The defensive warning branch at line 657-663 fires when
    // state.pagingController is null at the time refreshQuery is called.

    test(
      'emits DevLogger warning and returns early when pagingController is null',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Forcibly null out the pagingController in state.
          controller.state = controller.state.copyWith(
            pagingController: null,
          );

          DevLogger.clear();

          // Must not throw; should log the warning.
          controller.refreshQuery();

          settle(async);

          // Verify the DevLogger warning was emitted.
          expect(
            DevLogger.capturedLogs.any(
              (msg) => msg.contains(
                'refreshQuery called but pagingController is null',
              ),
            ),
            isTrue,
            reason:
                'DevLogger.warning must be called when pagingController '
                'is null',
          );
        });
      },
    );
  });

  group('_fetchPage error handling (line 722)', () {
    // When _runQuery throws inside _fetchPage, the catch-block at
    // lines 721-724 prints in kDebugMode and rethrows.
    // The paging controller records the error in its state.

    test(
      'paging controller records error when DB throws during page fetch',
      () {
        fakeAsync((async) {
          final exception = Exception('simulated DB failure');

          when(
            () => setup.mockJournalDb.getJournalEntities(
              types: any(named: 'types'),
              starredStatuses: any(named: 'starredStatuses'),
              privateStatuses: any(named: 'privateStatuses'),
              flaggedStatuses: any(named: 'flaggedStatuses'),
              ids: any(named: 'ids'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              categoryIds: any(named: 'categoryIds'),
            ),
          ).thenThrow(exception);

          setup.container.read(journalPageControllerProvider(false));

          // Allow the initial fetch to complete (and fail).
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final pagingState = setup.container
              .read(journalPageControllerProvider(false))
              .pagingController
              ?.value;

          expect(
            pagingState?.error,
            isNotNull,
            reason: 'paging controller must capture the thrown error',
          );
          expect(
            pagingState?.error.toString(),
            contains('simulated DB failure'),
          );

          // kDebugMode is true in test runs — the print branch is covered.
          // (No assertion needed for the print itself; error in state is
          //  sufficient proof the catch block was executed.)
          expect(kDebugMode, isTrue);
        });
      },
    );
  });
}
