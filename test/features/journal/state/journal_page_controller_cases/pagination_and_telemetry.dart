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

  group('Search by meaning', () {
    Task task(String id) =>
        _buildTestTaskRefresh(id: id, title: id, createdAt: _testDateRefresh);

    /// Answers the task query with the [tasks] it asks for, in the order
    /// given here rather than the order asked: the list's order is the
    /// search's, which the runner restores.
    void stubTasks(List<Task> tasks) {
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
        final ids = invocation.namedArguments[#ids] as List<String>?;
        return [
          for (final task in tasks)
            if (ids == null || ids.contains(task.meta.id)) task,
        ];
      });
    }

    /// Opens the tasks page with search by meaning on, its repository
    /// answering [answers] per query, and the words matching [words].
    (JournalPageController, MockVectorSearchRepository) meaningPage(
      FakeAsync async, {
      Map<String, Future<VectorSearchResult> Function()> answers = const {},
      Map<String, List<String>> words = const {},
      bool enabled = true,
    }) {
      final repo = MockVectorSearchRepository();
      getIt.registerSingleton<VectorSearchRepository>(repo);
      for (final MapEntry(:key, :value) in answers.entries) {
        when(
          () => repo.searchRelatedTasks(
            query: key,
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) => value());
      }
      stubFts5Db(
        setup.mockFts5Db,
        matches: (query) => words[query] ?? const [],
      );
      final controller = setup.container.read(
        journalPageControllerProvider(true).notifier,
      );
      settle(async);
      setup.configFlagsController.add({if (enabled) enableVectorSearchFlag});
      settle(async);
      return (controller, repo);
    }

    JournalPageState read() =>
        setup.container.read(journalPageControllerProvider(true));

    VectorSearchResult found(Map<String, double> distances) =>
        VectorSearchResult(
          entities: [for (final id in distances.keys) task(id)],
          elapsed: const Duration(milliseconds: 5),
          distances: distances,
        );

    test('lists what the words missed after the word matches', () {
      fakeAsync((async) {
        stubTasks([task('fish-census'), task('feeder-rota'), task('krill')]);
        final (controller, _) = meaningPage(
          async,
          words: {
            'krill': ['krill', 'feeder-rota'],
          },
          answers: {
            // Meaning also finds a word match; it stays where the words put
            // it, and only what they missed follows.
            'krill': () async =>
                found({'fish-census': 0.2, 'krill': 0.3, 'feeder-rota': 0.4}),
          },
        );

        controller.setSearchString('krill');
        settle(async);

        expect(
          read().pagingController?.value.items?.map((t) => t.meta.id),
          ['krill', 'feeder-rota', 'fish-census'],
        );
        expect(read().relatedByMeaningIds, {'fish-census'});
        // The distances stay whole: the due views count from them.
        expect(read().vectorSearchDistances, {
          'fish-census': 0.2,
          'krill': 0.3,
          'feeder-rota': 0.4,
        });
        expect(read().pagingController?.value.hasNextPage, isFalse);
      });
    });

    test('a search is one page: scrolling on searches nothing again', () {
      fakeAsync((async) {
        // A full page, so the list asks for another.
        final many = [for (var i = 0; i < 50; i++) task('task-$i')];
        stubTasks(many);
        final (controller, repo) = meaningPage(
          async,
          words: {
            'krill': [for (final t in many) t.meta.id],
          },
          answers: {'krill': () async => found(const {})},
        );
        controller.setSearchString('krill');
        settle(async);
        final paging = read().pagingController!;
        expect(paging.value.items, hasLength(50));
        expect(paging.value.hasNextPage, isTrue);
        clearInteractions(setup.mockFts5Db);

        paging.fetchNextPage();
        settle(async);

        // The next page was asked for, and came back empty.
        expect(paging.value.keys, hasLength(2));
        expect(paging.value.items, hasLength(50));
        verifyNever(() => anyMatchHits(setup.mockFts5Db));
        verify(
          () => repo.searchRelatedTasks(
            query: 'krill',
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
      });
    });

    test('a blank query lists everything again, with nothing related', () {
      fakeAsync((async) {
        stubTasks([task('fish-census'), task('krill')]);
        final (controller, repo) = meaningPage(
          async,
          words: {
            'krill': ['krill'],
          },
          answers: {
            'krill': () async => found({'fish-census': 0.2}),
          },
        );
        controller.setSearchString('krill');
        settle(async);
        expect(read().relatedByMeaningIds, {'fish-census'});

        controller.setSearchString('');
        settle(async);

        expect(read().relatedByMeaningIds, isEmpty);
        expect(read().vectorSearchDistances, isEmpty);
        verify(
          () => repo.searchRelatedTasks(
            query: 'krill',
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
        verifyNoMoreInteractions(repo);
      });
    });

    test('is not asked while it is turned off', () {
      fakeAsync((async) {
        stubTasks([task('krill')]);
        final (controller, repo) = meaningPage(
          async,
          enabled: false,
          words: {
            'krill': ['krill'],
          },
        );

        controller.setSearchString('krill');
        settle(async);

        expect(
          read().pagingController?.value.items?.map((t) => t.meta.id),
          ['krill'],
        );
        expect(read().relatedByMeaningIds, isEmpty);
        verifyZeroInteractions(repo);
      });
    });

    test('keeps what is shown until the next results land', () {
      fakeAsync((async) {
        stubTasks([task('first'), task('second')]);
        final pending = Completer<VectorSearchResult>();
        final (controller, _) = meaningPage(
          async,
          answers: {
            'colony': () async => found({'first': 0.2}),
            'colony counts': () => pending.future,
          },
        );

        controller.setSearchString('colony');
        settle(async);
        expect(
          read().pagingController?.value.items?.map((t) => t.meta.id),
          ['first'],
        );

        // The next keystroke's search waits on the model.
        controller.setSearchString('colony counts');
        settle(async);

        expect(
          read().pagingController?.value.items?.map((t) => t.meta.id),
          ['first'],
        );
        expect(read().relatedByMeaningIds, {'first'});
        expect(read().vectorSearchDistances, {'first': 0.2});

        pending.complete(found({'second': 0.3}));
        settle(async);

        expect(
          read().pagingController?.value.items?.map((t) => t.meta.id),
          ['second'],
        );
        expect(read().relatedByMeaningIds, {'second'});
        expect(read().vectorSearchDistances, {'second': 0.3});
      });
    });

    test('a slower search for an earlier keystroke never lands over the '
        'newer one', () {
      fakeAsync((async) {
        stubTasks([task('older'), task('newer')]);
        final slow = Completer<VectorSearchResult>();
        final (controller, _) = meaningPage(
          async,
          answers: {
            'colony': () => slow.future,
            'colony counts': () async => found({'newer': 0.3}),
          },
        );

        controller.setSearchString('colony');
        async.flushMicrotasks();
        controller.setSearchString('colony counts');
        settle(async);
        slow.complete(found({'older': 0.1}));
        settle(async);

        expect(
          read().pagingController?.value.items?.map((t) => t.meta.id),
          ['newer'],
        );
        expect(read().relatedByMeaningIds, {'newer'});
        expect(read().vectorSearchDistances, {'newer': 0.3});
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
      'logs a warning and returns early when pagingController is null',
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

          // Must not throw; should log the warning.
          controller.refreshQuery();

          settle(async);

          verify(
            () => setup.mockDomainLogger.log(
              LogDomain.persistence,
              'refreshQuery called but pagingController is null',
              subDomain: 'JournalPageController',
              level: InsightLevel.warn,
            ),
          ).called(1);
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
