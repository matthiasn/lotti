// ignore_for_file: cascade_invocations

part of '../journal_page_controller_test.dart';

void _registerLifecycleAndSearch(JournalControllerTestSetup setup) {
  group('Initialization', () {
    test('initializes with showTasks=true', () {
      fakeAsync((async) {
        final state = setup.container.read(journalPageControllerProvider(true));

        expect(state.showTasks, isTrue);
        expect(state.pagingController, isNotNull);
        expect(state.taskStatuses, isNotEmpty);
        expect(state.taskStatuses.length, equals(7));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });
    });

    test('initializes with showTasks=false', () {
      fakeAsync((async) {
        final state = setup.container.read(
          journalPageControllerProvider(false),
        );

        expect(state.showTasks, isFalse);
        expect(state.pagingController, isNotNull);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });
    });

    test('default selectedTaskStatuses is same for both tabs', () {
      fakeAsync((async) {
        final tasksState = setup.container.read(
          journalPageControllerProvider(true),
        );
        final journalState = setup.container.read(
          journalPageControllerProvider(false),
        );

        // Both should have the same default task statuses
        final expectedStatuses = {'OPEN', 'GROOMED', 'IN PROGRESS'};
        expect(tasksState.selectedTaskStatuses, equals(expectedStatuses));
        expect(journalState.selectedTaskStatuses, equals(expectedStatuses));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });
    });

    test(
      'initializes with unassigned category selected when showTasks=true and no categories exist',
      () {
        fakeAsync((async) {
          // Mock no categories
          when(
            () => setup.mockEntitiesCacheService.sortedCategories,
          ).thenReturn([]);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );

          // Verify immediately after construction
          expect(state.selectedCategoryIds, equals(<String>{''}));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        });
      },
    );

    test('does not initialize with unassigned when showTasks=false', () {
      fakeAsync((async) {
        // Mock no categories
        when(
          () => setup.mockEntitiesCacheService.sortedCategories,
        ).thenReturn([]);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );

        // Verify state does not have unassigned selected
        expect(state.selectedCategoryIds, equals(<String>{}));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });
    });

    test('does not default to unassigned when categories exist', () {
      fakeAsync((async) {
        // Mock some categories
        when(() => setup.mockEntitiesCacheService.sortedCategories).thenReturn([
          CategoryDefinition(
            id: 'cat1',
            name: 'Work',
            color: '#FF0000',
            createdAt: DateTime(2024, 1, 1, 10),
            updatedAt: DateTime(2024, 1, 1, 10),
            active: true,
            private: false,
            vectorClock: null,
          ),
        ]);

        final state = setup.container.read(journalPageControllerProvider(true));

        // Verify state does not have unassigned selected
        expect(state.selectedCategoryIds, equals(<String>{}));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });
    });

    test('pagination controller fetches initial page', () {
      fakeAsync((async) {
        setup.container.read(journalPageControllerProvider(false));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Verify getJournalEntities was called for initial page load
        verify(
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
        ).called(greaterThan(0));
      });
    });
  });

  // Filter tests moved to journal_page_controller_filter_test.dart

  group('Search Functionality', () {
    test('setSearchString updates match in state', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setSearchString('test query');

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.match, equals('test query'));
      });
    });

    test('setSearchString triggers fts5 search', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setSearchString('test query');

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        verify(
          () => setup.mockFts5Db.watchFullTextMatches('test query'),
        ).called(greaterThan(0));
      });
    });

    test('empty search string clears match and fullTextMatches', () {
      fakeAsync((async) {
        when(
          () => setup.mockFts5Db.watchFullTextMatches('test'),
        ).thenAnswer((_) => Stream.value(['id1', 'id2']));

        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setSearchString('test');

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        var state = setup.container.read(journalPageControllerProvider(false));
        expect(state.match, equals('test'));

        controller.setSearchString('');

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        state = setup.container.read(journalPageControllerProvider(false));
        // The match field is cleared immediately
        expect(state.match, isEmpty);
        // fullTextMatches is cleared internally when _fts5Search runs with empty query
        // The next query will have empty fullTextMatches
      });
    });
  });

  // Persistence loading tests moved to journal_filter_persistence_test.dart

  // Persistence saving tests moved to journal_filter_persistence_test.dart

  group('Feature Flag Handling', () {
    test('feature flags affect allowed entry types', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // Select all entry types initially
        controller.selectAllEntryTypes(entryTypes);

        settle(async);

        // Enable only events flag
        setup.configFlagsController.add({enableEventsFlag});

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        expect(
          controller.state.allowedEntryTypes,
          equals(
            computeAllowedEntryTypes(
              events: true,
              habits: false,
              dashboards: false,
            ),
          ),
        );
      });
    });

    test(
      'disabling dashboard flag removes MeasurementEntry and QuantitativeEntry',
      () {
        fakeAsync((async) {
          List<String>? capturedTypes;
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
            capturedTypes = invocation.namedArguments[#types] as List<String>?;
            return [];
          });

          final controller = setup.container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Enable events and habits, but NOT dashboards
          setup.configFlagsController.add({
            enableEventsFlag,
            enableHabitsPageFlag,
          });

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Trigger a refresh to issue a new query with updated flags
          controller.refreshQuery();

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // MeasurementEntry and QuantitativeEntry should be excluded
          expect(capturedTypes, isNotNull);
          expect(capturedTypes!.contains('MeasurementEntry'), isFalse);
          expect(capturedTypes!.contains('QuantitativeEntry'), isFalse);
          // Events should be included
          expect(capturedTypes!.contains('JournalEvent'), isTrue);
          // Habits should be included
          expect(capturedTypes!.contains('HabitCompletionEntry'), isTrue);
        });
      },
    );

    test('enabling all flags includes all gated types', () {
      fakeAsync((async) {
        List<String>? capturedTypes;
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
          capturedTypes = invocation.namedArguments[#types] as List<String>?;
          return [];
        });

        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // Enable all feature flags
        setup.configFlagsController.add({
          enableEventsFlag,
          enableHabitsPageFlag,
          enableDashboardsPageFlag,
        });

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Trigger a refresh to issue a new query with updated flags
        controller.refreshQuery();

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // All gated types should be included
        expect(capturedTypes, isNotNull);
        expect(capturedTypes!.contains('JournalEvent'), isTrue);
        expect(capturedTypes!.contains('HabitCompletionEntry'), isTrue);
        expect(capturedTypes!.contains('MeasurementEntry'), isTrue);
        expect(capturedTypes!.contains('QuantitativeEntry'), isTrue);
      });
    });
  });

  // Visibility updates moved to journal_page_controller_refresh_test.dart

  group('Pagination Controller', () {
    test('pagination controller is created and fetchNextPage is called', () {
      fakeAsync((async) {
        final state = setup.container.read(
          journalPageControllerProvider(false),
        );

        expect(state.pagingController, isNotNull);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Initial fetch should have been called
        verify(
          () => setup.mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: 50, // pageSize
            categoryIds: any(named: 'categoryIds'),
            offset: any(named: 'offset'),
          ),
        ).called(greaterThan(0));
      });
    });

    test('tasks query uses getTasks instead of getJournalEntities', () {
      fakeAsync((async) {
        setup.container.read(journalPageControllerProvider(true));

        async.elapse(const Duration(milliseconds: 100));
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
            limit: 50,
            offset: any(named: 'offset'),
          ),
        ).called(greaterThan(0));
      });
    });
  });

  group('Private Entries Flag', () {
    test('showPrivateEntries updates when private flag changes', () {
      fakeAsync((async) {
        setup.container.read(journalPageControllerProvider(false));

        settle(async);

        var state = setup.container.read(journalPageControllerProvider(false));
        expect(state.showPrivateEntries, isFalse);

        setup.privateFlagController.add(true);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        state = setup.container.read(journalPageControllerProvider(false));
        expect(state.showPrivateEntries, isTrue);
      });
    });
  });

  // Label filter persistence tests moved to journal_filter_persistence_test.dart

  // Update notifications moved to journal_page_controller_refresh_test.dart

  group('Controller Disposal', () {
    test('disposing container cleans up subscriptions', () {
      fakeAsync((async) {
        final localContainer = ProviderContainer();

        localContainer.read(journalPageControllerProvider(false));

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Dispose should not throw
        localContainer.dispose();

        settle(async);

        // Emitting to streams after disposal should not cause issues
        setup.configFlagsController.add({enableEventsFlag});
        setup.privateFlagController.add(true);
        setup.updateStreamController.add({'test-id'});

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });
    });
  });

  group('Published Filter State', () {
    test('publishes the full default entry-type set', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // No config-flag event has been emitted, so the controller keeps the
        // full default selection (`entryTypes`) it was constructed with.
        expect(
          controller.state.selectedEntryTypes.toSet(),
          equals(entryTypes.toSet()),
        );
      });
    });

    test('publishes the exact set passed to setFilters', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // Initial filters set is empty.
        expect(controller.state.filters, isEmpty);

        controller.setFilters({
          DisplayFilter.starredEntriesOnly,
          DisplayFilter.flaggedEntriesOnly,
        });

        settle(async);

        // State contains exactly what was set — no more, no less.
        expect(
          controller.state.filters,
          equals({
            DisplayFilter.starredEntriesOnly,
            DisplayFilter.flaggedEntriesOnly,
          }),
        );
      });
    });
  });

  group('Error Handling', () {
    test('handles malformed JSON in persisted filters gracefully', () {
      fakeAsync((async) {
        // Set up malformed JSON that will fail to parse
        when(
          () => setup.mockSettingsDb.itemByKey(
            JournalPageController.tasksCategoryFiltersKey,
          ),
        ).thenAnswer((_) async => 'not valid json {{{');

        // Controller should initialize without throwing
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // State should still be valid with defaults
        expect(controller.state, isNotNull);
        expect(controller.state.showTasks, isTrue);
      });
    });

    test('handles missing pagingController gracefully in refreshQuery', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // This should not throw even if pagingController state is complex
        expect(controller.refreshQuery, returnsNormally);
      });
    });
  });

  // Refresh behavior tests moved to journal_page_controller_refresh_test.dart

  // Visibility edge cases moved to journal_page_controller_refresh_test.dart

  group('Entry Type Selection Edge Cases', () {
    test('selectSingleEntryType clears other selections', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        // First select all
        controller.selectAllEntryTypes(entryTypes);

        settle(async);

        expect(
          controller.state.selectedEntryTypes.toSet().length,
          entryTypes.length,
        );

        // Then select single
        controller.selectSingleEntryType('Task');

        settle(async);

        expect(controller.state.selectedEntryTypes.toSet(), equals({'Task'}));
      });
    });

    test('clearSelectedEntryTypes results in empty set', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.clearSelectedEntryTypes();

        settle(async);

        expect(controller.state.selectedEntryTypes.toSet(), isEmpty);
      });
    });
  });

  group('Batch Task Status Selection Edge Cases', () {
    test('batch status update replaces an existing selection', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // First select all
        controller.applyBatchFilterUpdate(
          statuses: controller.state.taskStatuses.toSet(),
        );

        settle(async);

        // Then select single
        controller.applyBatchFilterUpdate(statuses: const {'DONE'});

        settle(async);

        expect(controller.state.selectedTaskStatuses, equals({'DONE'}));
      });
    });
  });
}
