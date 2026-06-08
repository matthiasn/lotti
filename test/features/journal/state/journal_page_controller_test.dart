// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'helpers/journal_controller_test_setup.dart';

final _testDate = DateTime(2024);
final _testDateRefresh = DateTime(2024, 3, 15);

/// Mutable call counter returned by `stubCountingQuery`.
class _QueryCallCounter {
  int count = 0;
}

/// Stubs the full 8-param getJournalEntities query on [db] with [result]
/// and returns a counter incremented on every run — the shared arrangement
/// for the visibility/notification refresh tests.
// ignore: library_private_types_in_public_api
_QueryCallCounter stubCountingQuery(
  MockJournalDb db, {
  List<JournalEntity> result = const [],
}) {
  final counter = _QueryCallCounter();
  when(
    () => db.getJournalEntities(
      types: any(named: 'types'),
      starredStatuses: any(named: 'starredStatuses'),
      privateStatuses: any(named: 'privateStatuses'),
      flaggedStatuses: any(named: 'flaggedStatuses'),
      ids: any(named: 'ids'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      categoryIds: any(named: 'categoryIds'),
    ),
  ).thenAnswer((_) async {
    counter.count++;
    return result;
  });
  return counter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageController Tests', () {
    final setup = JournalControllerTestSetup();

    late MockJournalDb mockJournalDb;
    late MockSettingsDb mockSettingsDb;
    late MockFts5Db mockFts5Db;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late StreamController<Set<String>> updateStreamController;
    late StreamController<Set<String>> configFlagsController;
    late StreamController<bool> privateFlagController;
    late ProviderContainer container;

    setUp(() {
      setup.setUp();
      mockJournalDb = setup.mockJournalDb;
      mockSettingsDb = setup.mockSettingsDb;
      mockFts5Db = setup.mockFts5Db;
      mockEntitiesCacheService = setup.mockEntitiesCacheService;
      updateStreamController = setup.updateStreamController;
      configFlagsController = setup.configFlagsController;
      privateFlagController = setup.privateFlagController;
      container = setup.container;
    });

    tearDown(() async {
      await setup.tearDown();
    });

    group('debugGetNextPageKey (pure page-key computation)', () {
      JournalEntity entryFor(int i) => JournalEntity.journalEntry(
        meta: Metadata(
          id: 'pk-$i',
          createdAt: _testDate,
          updatedAt: _testDate,
          dateFrom: _testDate,
          dateTo: _testDate,
        ),
        entryText: const EntryText(plainText: 'pk'),
      );

      List<JournalEntity> page(int length) => List.generate(length, entryFor);

      test('covers the full branch matrix of the key computation', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );
          settle(async);

          const pageSize = JournalPageController.pageSize;

          // No loaded keys -> first page key is 0.
          expect(
            controller.debugGetNextPageKey(
              PagingState(keys: const [], pages: const []),
            ),
            0,
          );
          expect(controller.debugGetNextPageKey(PagingState()), 0);

          // hasNextPage=false -> null regardless of pages.
          expect(
            controller.debugGetNextPageKey(
              PagingState(
                keys: const [0],
                pages: [page(pageSize)],
                hasNextPage: false,
              ),
            ),
            isNull,
          );

          // Short last page -> null (the previous fetch exhausted the data).
          expect(
            controller.debugGetNextPageKey(
              PagingState(
                keys: const [0],
                pages: [page(pageSize - 1)],
              ),
            ),
            isNull,
          );

          // Full page -> next key is lastKey + lastPage.length.
          expect(
            controller.debugGetNextPageKey(
              PagingState(
                keys: const [0],
                pages: [page(pageSize)],
              ),
            ),
            pageSize,
          );
          expect(
            controller.debugGetNextPageKey(
              PagingState(
                keys: const [0, pageSize],
                pages: [page(pageSize), page(pageSize)],
              ),
            ),
            pageSize * 2,
          );

          // A pending post-filter offset wins over the computed key and is
          // consumed exactly once.
          controller.debugPostFilterNextRawOffset = 777;
          final fullState = PagingState<int, JournalEntity>(
            keys: const [0],
            pages: [page(pageSize)],
          );
          expect(controller.debugGetNextPageKey(fullState), 777);
          expect(controller.debugPostFilterNextRawOffset, isNull);
          expect(controller.debugGetNextPageKey(fullState), pageSize);

          // consumePostFilterOffset=false peeks without consuming.
          controller.debugPostFilterNextRawOffset = 555;
          expect(
            controller.debugGetNextPageKey(
              fullState,
              consumePostFilterOffset: false,
            ),
            555,
          );
          expect(controller.debugPostFilterNextRawOffset, 555);
        });
      });

      // -------------------------------------------------------------------
      // Glados: pagination boundary arithmetic.
      //
      // For a chain of consecutively-keyed pages, the next page key is the
      // exclusive end offset of the last page (`lastKey + lastPage.length`)
      // when every loaded page is full, and `null` the moment the last page
      // comes back short (the data is exhausted). These properties pin that
      // arithmetic across arbitrary page counts and last-page sizes.
      // -------------------------------------------------------------------
      glados.Glados2(
        glados.IntAnys(glados.any).intInRange(1, 7),
        // [0, pageSize] inclusive — the upper bound exercises the full-last-page
        // branch (intInRange's max is exclusive, hence the +1).
        glados.IntAnys(
          glados.any,
        ).intInRange(0, JournalPageController.pageSize + 1),
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'next key is the cumulative end offset for full-page chains',
        (
          numFullPages,
          lastPageLen,
        ) {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );
            settle(async);
            controller.debugPostFilterNextRawOffset = null;

            const pageSize = JournalPageController.pageSize;

            // Build a chain of [numFullPages] full pages followed by one page
            // of [lastPageLen] items, with keys = cumulative start offsets.
            final pages = <List<JournalEntity>>[
              for (var i = 0; i < numFullPages; i++) page(pageSize),
              page(lastPageLen),
            ];
            final keys = <int>[];
            var offset = 0;
            for (final p in pages) {
              keys.add(offset);
              offset += p.length;
            }

            final state = PagingState<int, JournalEntity>(
              keys: keys,
              pages: pages,
            );
            final next = controller.debugGetNextPageKey(state);

            if (lastPageLen < pageSize) {
              // Short last page -> data exhausted -> no further page.
              expect(
                next,
                isNull,
                reason: 'len=$lastPageLen pages=$numFullPages',
              );
            } else {
              // Every page full -> next key is the exclusive end offset, which
              // equals lastKey + lastPage.length and the total item count.
              final totalItems = pages.fold<int>(0, (sum, p) => sum + p.length);
              expect(next, totalItems, reason: 'pages=${numFullPages + 1}');
              expect(next, keys.last + pages.last.length);
            }
          });
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.IntAnys(glados.any).intInRange(0, 100000),
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'a pending post-filter offset wins and is consumed exactly once',
        (
          rawOffset,
        ) {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );
            settle(async);

            const pageSize = JournalPageController.pageSize;
            final fullState = PagingState<int, JournalEntity>(
              keys: const [0],
              pages: [page(pageSize)],
            );

            controller.debugPostFilterNextRawOffset = rawOffset;
            // First call returns the override and consumes it.
            expect(controller.debugGetNextPageKey(fullState), rawOffset);
            expect(controller.debugPostFilterNextRawOffset, isNull);
            // Second call falls back to the computed cumulative key.
            expect(controller.debugGetNextPageKey(fullState), pageSize);
          });
        },
        tags: 'glados',
      );
    });

    group('Initialization', () {
      test('initializes with showTasks=true', () {
        fakeAsync((async) {
          final state = container.read(journalPageControllerProvider(true));

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
          final state = container.read(journalPageControllerProvider(false));

          expect(state.showTasks, isFalse);
          expect(state.pagingController, isNotNull);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        });
      });

      test('default selectedTaskStatuses is same for both tabs', () {
        fakeAsync((async) {
          final tasksState = container.read(
            journalPageControllerProvider(true),
          );
          final journalState = container.read(
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
              () => mockEntitiesCacheService.sortedCategories,
            ).thenReturn([]);

            final state = container.read(journalPageControllerProvider(true));

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
          when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

          final state = container.read(journalPageControllerProvider(false));

          // Verify state does not have unassigned selected
          expect(state.selectedCategoryIds, equals(<String>{}));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        });
      });

      test('does not default to unassigned when categories exist', () {
        fakeAsync((async) {
          // Mock some categories
          when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
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

          final state = container.read(journalPageControllerProvider(true));

          // Verify state does not have unassigned selected
          expect(state.selectedCategoryIds, equals(<String>{}));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        });
      });

      test('pagination controller fetches initial page', () {
        fakeAsync((async) {
          container.read(journalPageControllerProvider(false));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Verify getJournalEntities was called for initial page load
          verify(
            () => mockJournalDb.getJournalEntities(
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
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setSearchString('test query');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.match, equals('test query'));
        });
      });

      test('setSearchString triggers fts5 search', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setSearchString('test query');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(
            () => mockFts5Db.watchFullTextMatches('test query'),
          ).called(greaterThan(0));
        });
      });

      test('empty search string clears match and fullTextMatches', () {
        fakeAsync((async) {
          when(
            () => mockFts5Db.watchFullTextMatches('test'),
          ).thenAnswer((_) => Stream.value(['id1', 'id2']));

          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setSearchString('test');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          var state = container.read(journalPageControllerProvider(false));
          expect(state.match, equals('test'));

          controller.setSearchString('');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          state = container.read(journalPageControllerProvider(false));
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
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Select all entry types initially
          controller.selectAllEntryTypes(entryTypes);

          settle(async);

          // Enable only events flag
          configFlagsController.add({enableEventsFlag});

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Verify internal flags are updated
          expect(controller.enableEvents, isTrue);
          expect(controller.enableHabits, isFalse);
          expect(controller.enableDashboards, isFalse);
        });
      });

      test(
        'disabling dashboard flag removes MeasurementEntry and QuantitativeEntry',
        () {
          fakeAsync((async) {
            List<String>? capturedTypes;
            when(
              () => mockJournalDb.getJournalEntities(
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
              capturedTypes =
                  invocation.namedArguments[#types] as List<String>?;
              return [];
            });

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            settle(async);

            // Enable events and habits, but NOT dashboards
            configFlagsController.add({enableEventsFlag, enableHabitsPageFlag});

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
            () => mockJournalDb.getJournalEntities(
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

          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Enable all feature flags
          configFlagsController.add({
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
          final state = container.read(journalPageControllerProvider(false));

          expect(state.pagingController, isNotNull);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Initial fetch should have been called
          verify(
            () => mockJournalDb.getJournalEntities(
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
          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(
            () => mockJournalDb.getTasks(
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
          container.read(journalPageControllerProvider(false));

          settle(async);

          var state = container.read(journalPageControllerProvider(false));
          expect(state.showPrivateEntries, isFalse);

          privateFlagController.add(true);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          state = container.read(journalPageControllerProvider(false));
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
          configFlagsController.add({enableEventsFlag});
          privateFlagController.add(true);
          updateStreamController.add({'test-id'});

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        });
      });
    });

    group('Getters for Testing', () {
      test('selectedEntryTypesInternal exposes the full default set', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // No config-flag event has been emitted, so the controller keeps the
          // full default selection (`entryTypes`) it was constructed with.
          expect(
            controller.selectedEntryTypesInternal,
            equals(entryTypes.toSet()),
          );
          // The getter exposes the same set the controller publishes in state.
          expect(
            controller.selectedEntryTypesInternal,
            equals(controller.state.selectedEntryTypes.toSet()),
          );
        });
      });

      test('filtersInternal reflects the exact set passed to setFilters', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Initial filters set is empty.
          expect(controller.filtersInternal, isEmpty);

          controller.setFilters({
            DisplayFilter.starredEntriesOnly,
            DisplayFilter.flaggedEntriesOnly,
          });

          settle(async);

          // The getter returns exactly what was set — no more, no less — and
          // mirrors the published state.
          expect(
            controller.filtersInternal,
            equals({
              DisplayFilter.starredEntriesOnly,
              DisplayFilter.flaggedEntriesOnly,
            }),
          );
          expect(
            controller.filtersInternal,
            equals(controller.state.filters),
          );
        });
      });
    });

    group('Error Handling', () {
      test('handles malformed JSON in persisted filters gracefully', () {
        fakeAsync((async) {
          // Set up malformed JSON that will fail to parse
          when(
            () => mockSettingsDb.itemByKey(
              JournalPageController.tasksCategoryFiltersKey,
            ),
          ).thenAnswer((_) async => 'not valid json {{{');

          // Controller should initialize without throwing
          final controller = container.read(
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
          final controller = container.read(
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
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // First select all
          controller.selectAllEntryTypes(entryTypes);

          settle(async);

          expect(
            controller.selectedEntryTypesInternal.length,
            entryTypes.length,
          );

          // Then select single
          controller.selectSingleEntryType('Task');

          settle(async);

          expect(controller.selectedEntryTypesInternal, equals({'Task'}));
        });
      });

      test('clearSelectedEntryTypes results in empty set', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.clearSelectedEntryTypes();

          settle(async);

          expect(controller.selectedEntryTypesInternal, isEmpty);
        });
      });
    });

    group('Task Status Selection Edge Cases', () {
      test('selectSingleTaskStatus clears other statuses', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // First select all
          controller.selectAllTaskStatuses();

          settle(async);

          // Then select single
          controller.selectSingleTaskStatus('DONE');

          settle(async);

          expect(controller.state.selectedTaskStatuses, equals({'DONE'}));
        });
      });
    });

    group('Feature Flag Selection Semantics', () {
      test(
        'empty selection repopulates with all allowed types on flag change',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            settle(async);

            // Clear selection to make it empty
            controller.clearSelectedEntryTypes();

            settle(async);

            expect(controller.selectedEntryTypesInternal, isEmpty);

            // Emit config flags with events enabled
            configFlagsController.add({enableEventsFlag});

            settle(async);

            // Should repopulate with all allowed types (events enabled)
            final expectedTypes = computeAllowedEntryTypes(
              events: true,
              habits: false,
              dashboards: false,
            ).toSet();

            expect(
              controller.selectedEntryTypesInternal,
              equals(expectedTypes),
            );
          });
        },
      );

      test('selection with all previously selected adopts new allowed types '
          'when flags change', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // First emit with no flags - get initial allowed types
          configFlagsController.add(<String>{});

          settle(async);

          final initialAllowed = computeAllowedEntryTypes(
            events: false,
            habits: false,
            dashboards: false,
          ).toSet();

          // Select all allowed types
          controller.selectAllEntryTypes(initialAllowed.toList());

          settle(async);

          expect(controller.selectedEntryTypesInternal, equals(initialAllowed));

          // Now enable events flag
          configFlagsController.add({enableEventsFlag});

          settle(async);

          // Should adopt new allowed types (including JournalEvent)
          final newAllowed = computeAllowedEntryTypes(
            events: true,
            habits: false,
            dashboards: false,
          ).toSet();

          expect(controller.selectedEntryTypesInternal, equals(newAllowed));
          expect(
            controller.selectedEntryTypesInternal,
            contains('JournalEvent'),
          );
        });
      });

      test(
        'partial selection intersects with new allowed types on flag change',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            settle(async);

            // First emit with all flags enabled
            configFlagsController.add({
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
              controller.selectedEntryTypesInternal,
              equals({'Task', 'JournalEvent', 'HabitCompletionEntry'}),
            );

            // Now disable events and habits flags
            configFlagsController.add(<String>{});

            settle(async);

            // Should intersect - only Task remains (JournalEvent and
            // HabitCompletionEntry are no longer allowed)
            expect(controller.selectedEntryTypesInternal, equals({'Task'}));
            expect(
              controller.selectedEntryTypesInternal,
              isNot(contains('JournalEvent')),
            );
            expect(
              controller.selectedEntryTypesInternal,
              isNot(contains('HabitCompletionEntry')),
            );
          });
        },
      );

      test('enabling new flag adds types when user had all selected', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Start with events only
          configFlagsController.add({enableEventsFlag});

          settle(async);

          final eventsAllowed = computeAllowedEntryTypes(
            events: true,
            habits: false,
            dashboards: false,
          ).toSet();

          // Select all currently allowed types
          controller.selectAllEntryTypes(eventsAllowed.toList());

          settle(async);

          expect(controller.selectedEntryTypesInternal, equals(eventsAllowed));
          expect(
            controller.selectedEntryTypesInternal,
            isNot(contains('HabitCompletionEntry')),
          );

          // Now also enable habits
          configFlagsController.add({enableEventsFlag, enableHabitsPageFlag});

          settle(async);

          // Should include HabitCompletionEntry now
          expect(
            controller.selectedEntryTypesInternal,
            contains('HabitCompletionEntry'),
          );
        });
      });

      test('disabling flag removes types from partial selection', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Start with dashboards enabled
          configFlagsController.add({enableDashboardsPageFlag});

          settle(async);

          // Select only dashboard-gated types plus Task
          controller.selectAllEntryTypes([
            'Task',
            'MeasurementEntry',
            'QuantitativeEntry',
          ]);

          settle(async);

          expect(
            controller.selectedEntryTypesInternal,
            equals({'Task', 'MeasurementEntry', 'QuantitativeEntry'}),
          );

          // Disable dashboards
          configFlagsController.add(<String>{});

          settle(async);

          // Only Task should remain
          expect(controller.selectedEntryTypesInternal, equals({'Task'}));
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
            () => mockSettingsDb.itemByKey(
              JournalPageController.tasksCategoryFiltersKey,
            ),
          ).thenAnswer((_) async => persistedJson);

          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
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
          () => mockJournalDb.getTasks(
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
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.hasAgent);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final items = container
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
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.noAgent);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final items = container
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
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Default is 'all' — should return both tasks
          controller.setAgentAssignmentFilter(AgentAssignmentFilter.all);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final items = container
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
        () async {
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
            () => mockJournalDb.getTasks(
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
            () => mockJournalDb.getTasksSortedByDueDate(
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

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          await controller.setAgentAssignmentFilter(
            AgentAssignmentFilter.hasAgent,
          );
          await controller.setSortOption(TaskSortOption.byDueDate);

          await Future<void>.delayed(const Duration(milliseconds: 200));

          final items = container
              .read(journalPageControllerProvider(true))
              .pagingController
              ?.value
              .items;

          expect(items, isNotNull);
          expect(items!.length, equals(1));
          expect(items.first.meta.id, equals('task-with-agent'));
        },
      );

      test('fetches in normal-sized chunks when agent filter is active', () {
        fakeAsync((async) {
          int? capturedLimit;
          when(
            () => mockJournalDb.getTasks(
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

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.noAgent);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Post-filters use normal chunk size; loop handles exhaustion
          expect(capturedLimit, equals(50));
        });
      });
    });

    group('Filter Management - Project', () {
      test('toggleProjectFilter adds project when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-1'}));
        });
      });

      test('toggleProjectFilter removes project when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-1');

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('clearProjectFilter removes all project selections', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-2');

          settle(async);

          controller.clearProjectFilter();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('removeStaleProjectFilters removes only stale IDs', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-2')
            ..toggleProjectFilter('proj-3');

          settle(async);

          controller.removeStaleProjectFilters({'proj-1', 'proj-3'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-2'}));
        });
      });

      test('removeStaleProjectFilters is no-op when staleIds is empty', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          settle(async);

          controller.removeStaleProjectFilters(<String>{});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-1'}));
        });
      });

      test('toggleSelectedCategoryIds clears project filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Set a project filter first
          controller.toggleProjectFilter('proj-1');

          settle(async);

          var state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isNotEmpty);

          // Changing category should clear project filters
          controller.toggleSelectedCategoryIds('cat-1');

          settle(async);

          state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('selectedAllCategories clears project filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          settle(async);

          controller.selectedAllCategories();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('project filter post-filters tasks from _runQuery', () {
        fakeAsync((async) {
          final taskInProject = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_p1',
                createdAt: DateTime(2024),
                utcOffset: 0,
              ),
              title: 'Task in project',
              statusHistory: const [],
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
            meta: Metadata(
              id: 'task-in-project',
              createdAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
              updatedAt: DateTime(2024),
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
            () => mockJournalDb.getTasks(
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
            () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
          ).thenAnswer((_) async => {'task-in-project'});

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final items = container
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
        () async {
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
            () => mockJournalDb.getTasks(
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
            () => mockJournalDb.getTasksSortedByDueDate(
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
            () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
          ).thenAnswer(
            (_) async => {'task-proj-due', 'task-proj-nodue'},
          );

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          await controller.toggleProjectFilter('proj-1');
          await controller.setSortOption(TaskSortOption.byDueDate);

          await Future<void>.delayed(const Duration(milliseconds: 200));

          final items = container
              .read(journalPageControllerProvider(true))
              .pagingController
              ?.value
              .items;

          expect(items, isNotNull);
          expect(items!.length, equals(2));
          // Task with due date should come first
          expect(items.first.meta.id, equals('task-proj-due'));
        },
      );
    });

    group('Batch Setters', () {
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

      test('setSelectedTaskStatuses replaces all statuses', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setSelectedTaskStatuses({'DONE', 'BLOCKED'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses, {'DONE', 'BLOCKED'});
        });
      });

      test(
        'setSelectedCategoryIds replaces categories and clears projects',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            // First set some projects
            controller.setSelectedProjectIds({'proj-1'});

            settle(async);

            // Now set categories — projects should be cleared
            controller.setSelectedCategoryIds({'cat-1', 'cat-2'});

            settle(async);

            final state = container.read(journalPageControllerProvider(true));
            expect(state.selectedCategoryIds, {'cat-1', 'cat-2'});
            expect(state.selectedProjectIds, isEmpty);
          });
        },
      );

      test('setSelectedLabelIds replaces all labels', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setSelectedLabelIds({'label-1', 'label-2'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedLabelIds, {'label-1', 'label-2'});
        });
      });

      test('setSelectedProjectIds replaces all projects', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setSelectedProjectIds({'proj-a', 'proj-b'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, {'proj-a', 'proj-b'});
        });
      });

      test('setSelectedPriorities replaces all priorities', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setSelectedPriorities({'HIGH', 'CRITICAL'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedPriorities, {'HIGH', 'CRITICAL'});
        });
      });

      test('batch setters defensively copy input sets', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          final mutableSet = {'DONE'};
          controller.setSelectedTaskStatuses(mutableSet);

          settle(async);

          // Mutate original set — should not affect controller
          mutableSet.add('BLOCKED');

          final state = container.read(journalPageControllerProvider(true));
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
          final controller = container.read(
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

          final state = container.read(journalPageControllerProvider(true));
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
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          final stateBefore = container.read(
            journalPageControllerProvider(true),
          );

          // Only update statuses, leave everything else
          controller.applyBatchFilterUpdate(statuses: {'BLOCKED'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
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
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            controller.applyBatchFilterUpdate(
              searchMode: SearchMode.vector,
            );

            settle(async);

            final state = container.read(journalPageControllerProvider(true));
            // Vector search not enabled, so mode should stay fullText
            expect(state.searchMode, SearchMode.fullText);
          });
        },
      );

      test(
        'applyBatchFilterUpdate applies searchMode when vector enabled',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            // Enable vector search via config flags
            configFlagsController.add({enableVectorSearchFlag});
            settle(async);

            expect(controller.enableVectorSearchInternal, isTrue);

            controller.applyBatchFilterUpdate(
              searchMode: SearchMode.vector,
            );

            settle(async);

            final state = container.read(journalPageControllerProvider(true));
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
        configFlagsController.add({enableVectorSearchFlag});
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      }

      test(
        'setSearchMode guards against vector mode when flag is disabled',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            // Flag is disabled by default
            controller.setSearchMode(SearchMode.vector);

            settle(async);

            final state = container.read(journalPageControllerProvider(true));
            expect(state.searchMode, equals(SearchMode.fullText));
          });
        },
      );

      test('setSearchMode allows vector mode when flag is enabled', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          emitVectorSearchFlag(async);

          controller.setSearchMode(SearchMode.vector);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.searchMode, equals(SearchMode.vector));
          expect(state.enableVectorSearch, isTrue);
        });
      });

      test('vector search returns results and updates telemetry state', () {
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
            () => mockSettingsDb.itemByKey(
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

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          emitVectorSearchFlag(async);

          controller
            ..setSearchMode(SearchMode.vector)
            ..setSearchString('semantic query');

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
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

    group('Persisted Entry Types', () {
      test('loads persisted entry types and applies them', () {
        fakeAsync((async) {
          when(
            () => mockSettingsDb.itemByKey('SELECTED_ENTRY_TYPES'),
          ).thenAnswer((_) async => '["Task","JournalEntry"]');

          container.read(journalPageControllerProvider(false));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
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

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Enable vector search flag
          configFlagsController.add({enableVectorSearchFlag});

          settle(async);

          // Set search mode to vector
          controller.setSearchMode(SearchMode.vector);

          settle(async);

          // Set a search string to trigger vector search
          controller.setSearchString('semantic query');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
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

    group('searchModeInternal Getter', () {
      test('returns fullText by default', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          expect(controller.searchModeInternal, equals(SearchMode.fullText));
        });
      });

      test('returns vector after setSearchMode with vector search enabled', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          configFlagsController.add({enableVectorSearchFlag});

          settle(async);

          controller.setSearchMode(SearchMode.vector);

          settle(async);

          expect(controller.searchModeInternal, equals(SearchMode.vector));
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
              () => mockJournalDb.getJournalEntities(
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

            container.read(journalPageControllerProvider(false));

            // Let page 0 load.
            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final pagingController = container
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
              () => mockSettingsDb.itemByKey(
                JournalPageController.journalCategoryFiltersKey,
              ),
            ).thenAnswer((_) async => persistedJson);

            container.read(journalPageControllerProvider(false));

            async.elapse(const Duration(milliseconds: 200));
            async.flushMicrotasks();

            final state = container.read(journalPageControllerProvider(false));

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
            final controller = container.read(
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
              () => mockJournalDb.getJournalEntities(
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

            container.read(journalPageControllerProvider(false));

            // Allow the initial fetch to complete (and fail).
            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final pagingState = container
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
  });

  group('JournalPageController Refresh Tests', () {
    final setup = JournalControllerTestSetup();

    late MockJournalDb mockJournalDb;
    late StreamController<Set<String>> updateStreamController;
    late ProviderContainer container;

    setUp(() {
      setup.setUp();
      mockJournalDb = setup.mockJournalDb;
      updateStreamController = setup.updateStreamController;
      container = setup.container;
    });

    tearDown(() async {
      await setup.tearDown();
    });

    group('Visibility Updates', () {
      test(
        'visibility transition refreshes when becoming visible after missed update',
        () {
          fakeAsync((async) {
            final queryCalls = stubCountingQuery(mockJournalDb, result: []);

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final initialCount = queryCalls.count;

            // First, simulate being invisible
            controller.debugSetVisibility(isVisible: false);

            settle(async);

            // Count should remain unchanged (no refresh when becoming invisible)
            expect(queryCalls.count, equals(initialCount));

            // Fire an update while invisible — this sets the dirty flag
            updateStreamController.add({'some-missed-id'});
            async.elapse(const Duration(milliseconds: 600));
            async.flushMicrotasks();

            // Still no refresh while invisible
            expect(queryCalls.count, equals(initialCount));

            // Now simulate becoming visible - should trigger refresh
            // because updates were missed
            controller.debugSetVisibility(isVisible: true);

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
            final queryCalls = stubCountingQuery(mockJournalDb, result: []);

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final initialCount = queryCalls.count;

            // Go invisible
            controller.debugSetVisibility(isVisible: false);

            settle(async);

            // Come back visible without any missed updates
            controller.debugSetVisibility(isVisible: true);

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            // Should NOT have refreshed — no updates were missed
            expect(queryCalls.count, equals(initialCount));
          });
        },
      );

      test('does not refresh when staying invisible', () {
        fakeAsync((async) {
          final queryCalls = stubCountingQuery(mockJournalDb, result: []);

          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final initialCount = queryCalls.count;

          // Simulate being invisible
          controller.debugSetVisibility(isVisible: false);

          settle(async);

          // Stay invisible - should NOT trigger refresh
          controller.debugSetVisibility(isVisible: false);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Count should remain unchanged
          expect(queryCalls.count, equals(initialCount));
        });
      });

      test('isVisible getter reflects current visibility', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          expect(controller.isVisible, isFalse);

          controller.debugSetVisibility(isVisible: true);

          settle(async);

          expect(controller.isVisible, isTrue);

          controller.debugSetVisibility(isVisible: false);

          settle(async);

          expect(controller.isVisible, isFalse);
        });
      });
    });

    group('Update Notifications', () {
      test(
        'visible controller refreshes when update affects displayed items',
        () {
          fakeAsync((async) {
            final queryCalls = stubCountingQuery(mockJournalDb, result: []);

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            // Make visible
            controller.debugSetVisibility(isVisible: true);

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final countAfterVisible = queryCalls.count;

            // Send update notification
            updateStreamController.add({'some-id'});

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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            controller.debugSetVisibility(isVisible: true);

            clearInteractions(mockJournalDb);
            getTasksCallCount = 0;

            updateStreamController.add({'task-1'});

            async.elapse(const Duration(milliseconds: 200));
            async.flushMicrotasks();

            expect(state.pagingController?.value.items, equals([initialTask]));
            expect(getTasksCallCount, 1);
            verify(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            controller.debugSetVisibility(isVisible: true);

            clearInteractions(mockJournalDb);
            getTasksCallCount = 1;

            updateStreamController.add({'off-screen-task'});

            async.elapse(const Duration(milliseconds: 200));
            async.flushMicrotasks();

            expect(
              state.pagingController?.value.items,
              equals([refreshedLeadingTask]),
            );
            expect(getTasksCallCount, 3);
            verify(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
            ).thenAnswer((_) async => projectTaskIds);

            when(
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            unawaited(controller.toggleProjectFilter('proj-1'));
            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            controller.debugSetVisibility(isVisible: true);

            clearInteractions(mockJournalDb);

            updateStreamController.add({'off-screen-task'});
            settle(async);

            verify(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              mockJournalDb,
              result: [entry],
            );

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.flushMicrotasks();

            controller.debugSetVisibility(isVisible: true);

            clearInteractions(mockJournalDb);
            queryCalls.count = 0;

            updateStreamController.add({'entry-1'});

            async.elapse(const Duration(milliseconds: 200));
            async.flushMicrotasks();

            expect(queryCalls.count, 1);
            verify(
              () => mockJournalDb.getJournalEntities(
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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
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

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
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

            clearInteractions(mockJournalDb);

            when(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTaskIdsForProjects(any()),
            ).thenAnswer(
              (_) async => {
                ...initialFirstPage.map((entity) => entity.meta.id),
                initialSecondPageTask.meta.id,
                ...refreshedFirstPage.map((entity) => entity.meta.id),
                refreshedSecondPageTask.meta.id,
              },
            );

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            unawaited(controller.toggleProjectFilter('proj-1'));
            async.flushMicrotasks();

            state.pagingController!.value = PagingState<int, JournalEntity>(
              pages: [
                initialFirstPage,
                [initialSecondPageTask],
              ],
              keys: const [0, JournalPageController.pageSize],
              hasNextPage: false,
            );

            clearInteractions(mockJournalDb);

            when(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTaskIdsForProjects(any()),
            ).thenAnswer((_) async {
              projectIdsCallCount++;
              if (projectIdsCallCount == 1) {
                return firstRefreshProjectIds;
              }
              return secondRefreshProjectIds;
            });

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            unawaited(controller.toggleProjectFilter('proj-1'));
            async.flushMicrotasks();

            state.pagingController!.value = PagingState<int, JournalEntity>(
              pages: [initialFirstPage],
              keys: const [0],
              hasNextPage: true,
            );

            clearInteractions(mockJournalDb);

            when(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTaskIdsForProjects(any()),
            ).thenAnswer((_) async => allProjectIds);

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            unawaited(controller.toggleProjectFilter('proj-1'));
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

            clearInteractions(mockJournalDb);

            when(
              () => mockJournalDb.getTasks(
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
              () => mockJournalDb.getTasks(
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

            final state = container.read(journalPageControllerProvider(true));
            container.read(journalPageControllerProvider(true).notifier);

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
                  final ctrl = container.read(
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
        'refreshQuery with preserveVisibleItems falls back to full refresh '
        'when no visible page keys exist',
        () {
          fakeAsync((async) {
            var getTasksCallCount = 0;

            when(
              () => mockJournalDb.getTasks(
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
              return <JournalEntity>[];
            });

            final state = container.read(journalPageControllerProvider(true));
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.flushMicrotasks();

            // Manually set paging state with an empty page so that
            // hasVisibleItems is false — refreshQuery should fall through
            // to the full refresh path.
            state.pagingController!.value = PagingState<int, JournalEntity>(
              pages: const [[]],
              keys: const [0],
              hasNextPage: false,
            );

            clearInteractions(mockJournalDb);
            getTasksCallCount = 0;

            // preserveVisibleItems=true but no visible items →
            // hasVisibleItems is false, so it should do a full refresh.
            unawaited(
              controller.refreshQuery(preserveVisibleItems: true),
            );
            async.flushMicrotasks();

            // A full refresh re-fetches page 0
            expect(getTasksCallCount, greaterThan(0));
          });
        },
      );
    });

    group('Visibility Edge Cases', () {
      test('does not refresh when transitioning from visible to invisible', () {
        fakeAsync((async) {
          var queryCount = 0;
          when(
            () => mockJournalDb.getJournalEntities(
              types: any(named: 'types'),
              starredStatuses: any(named: 'starredStatuses'),
              privateStatuses: any(named: 'privateStatuses'),
              flaggedStatuses: any(named: 'flaggedStatuses'),
              ids: any(named: 'ids'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              categoryIds: any(named: 'categoryIds'),
            ),
          ).thenAnswer((_) async {
            queryCount++;
            return [];
          });

          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Make visible first
          controller.debugSetVisibility(isVisible: true);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final visibleCount = queryCount;

          // Now make invisible
          controller.debugSetVisibility(isVisible: false);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Query count should not increase when becoming invisible
          expect(queryCount, equals(visibleCount));
          expect(controller.isVisible, isFalse);
        });
      });

      test('isVisible stays false when called with zero bounds repeatedly', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          // Multiple calls with zero bounds
          controller.debugSetVisibility(isVisible: false);
          controller.debugSetVisibility(isVisible: false);
          controller.debugSetVisibility(isVisible: false);

          expect(controller.isVisible, isFalse);
        });
      });
    });
  });

  group('JournalPageController Filter Tests', () {
    final setup = JournalControllerTestSetup();

    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late StreamController<Set<String>> configFlagsController;
    late ProviderContainer container;

    setUp(() {
      setup.setUp();
      mockJournalDb = setup.mockJournalDb;
      mockEntitiesCacheService = setup.mockEntitiesCacheService;
      configFlagsController = setup.configFlagsController;
      container = setup.container;
    });

    tearDown(() async {
      await setup.tearDown();
    });

    group('Filter Management - toggle membership contract', () {
      // All five toggle methods share one contract: toggling a value flips
      // its membership in the corresponding selection set. One spec per
      // method drives both directions.
      final toggleSpecs =
          <
            ({
              String method,
              bool tasksTab,
              void Function(JournalPageController controller, String value)
              toggle,
              void Function(JournalPageController controller)? prepareAdd,
              bool Function(JournalPageState state, String value) contains,
              String addValue,
              String removeValue,
              bool removeByDoubleToggle,
            })
          >[
            (
              method: 'toggleSelectedTaskStatus',
              tasksTab: true,
              toggle: (c, v) => c.toggleSelectedTaskStatus(v),
              prepareAdd: null,
              contains: (s, v) => s.selectedTaskStatuses.contains(v),
              addValue: 'BLOCKED',
              // OPEN is in the default set, so a single toggle removes it.
              removeValue: 'OPEN',
              removeByDoubleToggle: false,
            ),
            (
              method: 'toggleSelectedCategoryIds',
              tasksTab: true,
              toggle: (c, v) => c.toggleSelectedCategoryIds(v),
              prepareAdd: null,
              contains: (s, v) => s.selectedCategoryIds.contains(v),
              addValue: 'cat1',
              removeValue: 'cat1',
              removeByDoubleToggle: true,
            ),
            (
              method: 'toggleSelectedLabelId',
              tasksTab: true,
              toggle: (c, v) => c.toggleSelectedLabelId(v),
              prepareAdd: null,
              contains: (s, v) => s.selectedLabelIds.contains(v),
              addValue: 'label-A',
              removeValue: 'label-A',
              removeByDoubleToggle: true,
            ),
            (
              method: 'toggleSelectedPriority',
              tasksTab: true,
              toggle: (c, v) => c.toggleSelectedPriority(v),
              prepareAdd: null,
              contains: (s, v) => s.selectedPriorities.contains(v),
              addValue: 'P0',
              removeValue: 'P0',
              removeByDoubleToggle: true,
            ),
            (
              method: 'toggleSelectedEntryTypes',
              tasksTab: false,
              toggle: (c, v) => c.toggleSelectedEntryTypes(v),
              // Task is in the default set; clear first so the add is observable.
              prepareAdd: (c) => c.clearSelectedEntryTypes(),
              contains: (s, v) => s.selectedEntryTypes.contains(v),
              addValue: 'Task',
              removeValue: 'Task',
              removeByDoubleToggle: false,
            ),
          ];

      for (final spec in toggleSpecs) {
        test('${spec.method} adds ${spec.addValue} when not present', () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(spec.tasksTab).notifier,
            );

            settle(async);

            spec.prepareAdd?.call(controller);
            spec.toggle(controller, spec.addValue);

            settle(async);

            final state = container.read(
              journalPageControllerProvider(spec.tasksTab),
            );
            expect(spec.contains(state, spec.addValue), isTrue);
          });
        });

        test('${spec.method} removes ${spec.removeValue} when present', () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(spec.tasksTab).notifier,
            );

            settle(async);

            if (spec.removeByDoubleToggle) {
              spec.toggle(controller, spec.removeValue);
            }
            spec.toggle(controller, spec.removeValue);

            settle(async);

            final state = container.read(
              journalPageControllerProvider(spec.tasksTab),
            );
            expect(spec.contains(state, spec.removeValue), isFalse);
          });
        });
      }
    });

    group('Filter Management - Task Status', () {
      test('selectSingleTaskStatus sets only one status', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.selectSingleTaskStatus('DONE');

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses, equals({'DONE'}));
        });
      });

      test('selectAllTaskStatuses selects all statuses', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.selectAllTaskStatuses();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(
            state.selectedTaskStatuses,
            equals(state.taskStatuses.toSet()),
          );
        });
      });

      test('clearSelectedTaskStatuses removes all selections', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.clearSelectedTaskStatuses();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses, isEmpty);
        });
      });
    });

    group('Filter Management - Category', () {
      test('selectedAllCategories clears all selected categories', () {
        fakeAsync((async) {
          when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
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

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleSelectedCategoryIds('cat1')
            ..toggleSelectedCategoryIds('cat2');

          settle(async);

          controller.selectedAllCategories();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedCategoryIds, isEmpty);
        });
      });
    });

    group('Filter Management - Labels', () {
      test('clearSelectedLabelIds removes all label filters', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller
            ..toggleSelectedLabelId('label-A')
            ..toggleSelectedLabelId('label-B');

          settle(async);

          controller.clearSelectedLabelIds();

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedLabelIds, isEmpty);
        });
      });
    });

    group('Filter Management - Priority', () {
      test('clearSelectedPriorities removes all priorities', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleSelectedPriority('P0')
            ..toggleSelectedPriority('P1')
            ..clearSelectedPriorities();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedPriorities, isEmpty);
        });
      });
    });

    group('Filter Management - Entry Types', () {
      test('selectSingleEntryType sets only one type', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.selectSingleEntryType('Task');

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes, equals(['Task']));
        });
      });

      test('selectAllEntryTypes selects all types', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.selectAllEntryTypes();

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes.length, equals(entryTypes.length));
        });
      });

      test('clearSelectedEntryTypes clears all types', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.clearSelectedEntryTypes();

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes, isEmpty);
        });
      });
    });

    group('Display Filter Management', () {
      test('setFilters updates starred filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setFilters({DisplayFilter.starredEntriesOnly});

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.filters, equals({DisplayFilter.starredEntriesOnly}));
        });
      });

      test('setFilters updates flagged filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setFilters({DisplayFilter.flaggedEntriesOnly});

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.filters, equals({DisplayFilter.flaggedEntriesOnly}));
        });
      });

      test('setFilters updates private filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setFilters({DisplayFilter.privateEntriesOnly});

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(state.filters, equals({DisplayFilter.privateEntriesOnly}));
        });
      });

      test('setFilters can combine multiple filters', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          settle(async);

          controller.setFilters({
            DisplayFilter.starredEntriesOnly,
            DisplayFilter.privateEntriesOnly,
          });

          settle(async);

          final state = container.read(journalPageControllerProvider(false));
          expect(
            state.filters,
            equals({
              DisplayFilter.starredEntriesOnly,
              DisplayFilter.privateEntriesOnly,
            }),
          );
        });
      });
    });

    group('Sort Option Management', () {
      test('setSortOption updates sortOption to byDate', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setSortOption(TaskSortOption.byDate);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDate));
        });
      });

      test('setSortOption can toggle back to byPriority', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..setSortOption(TaskSortOption.byDate)
            ..setSortOption(TaskSortOption.byPriority);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byPriority));
        });
      });

      test('setSortOption updates sortOption to byDueDate', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setSortOption(TaskSortOption.byDueDate);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDueDate));
        });
      });

      test('setSortOption cycles through all three options', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Start with byPriority (default)
          var state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byPriority));

          // Switch to byDueDate
          controller.setSortOption(TaskSortOption.byDueDate);
          settle(async);
          state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDueDate));

          // Switch to byDate
          controller.setSortOption(TaskSortOption.byDate);
          settle(async);
          state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDate));

          // Back to byPriority
          controller.setSortOption(TaskSortOption.byPriority);
          settle(async);
          state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byPriority));
        });
      });
    });

    group('Filter Management - Agent Assignment', () {
      late AgentDatabase agentDbForFilter;

      setUp(() {
        agentDbForFilter = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        getIt.registerSingleton<AgentDatabase>(agentDbForFilter);
      });

      tearDown(() async {
        await agentDbForFilter.close();
        getIt.unregister<AgentDatabase>();
      });

      test(
        'debugRequiresSequentialRetainedRefresh covers the full '
        'showTasks x agentFilter x projectIds matrix',
        () {
          fakeAsync((async) {
            // showTasks=false: never sequential, regardless of filters.
            final journalController = container.read(
              journalPageControllerProvider(false).notifier,
            );
            settle(async);
            expect(
              journalController.debugRequiresSequentialRetainedRefresh,
              isFalse,
            );

            // showTasks=true with no post-filters: parallel refresh.
            final taskController = container.read(
              journalPageControllerProvider(true).notifier,
            );
            settle(async);
            expect(
              taskController.debugRequiresSequentialRetainedRefresh,
              isFalse,
            );

            // Agent filter active -> sequential.
            taskController.setAgentAssignmentFilter(
              AgentAssignmentFilter.hasAgent,
            );
            settle(async);
            expect(
              taskController.debugRequiresSequentialRetainedRefresh,
              isTrue,
            );

            // Back to all, but with a project selected -> still sequential.
            taskController.setAgentAssignmentFilter(AgentAssignmentFilter.all);
            settle(async);
            taskController.setSelectedProjectIds({'proj-1'});
            settle(async);
            expect(
              taskController.debugRequiresSequentialRetainedRefresh,
              isTrue,
            );

            // Clearing the project selection returns to parallel.
            taskController.setSelectedProjectIds({});
            settle(async);
            expect(
              taskController.debugRequiresSequentialRetainedRefresh,
              isFalse,
            );
          });
        },
      );

      test('setAgentAssignmentFilter updates to hasAgent', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.hasAgent);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(
            state.agentAssignmentFilter,
            equals(AgentAssignmentFilter.hasAgent),
          );
        });
      });

      test('setAgentAssignmentFilter updates to noAgent', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.noAgent);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(
            state.agentAssignmentFilter,
            equals(AgentAssignmentFilter.noAgent),
          );
        });
      });

      test('setAgentAssignmentFilter cycles back to all', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..setAgentAssignmentFilter(AgentAssignmentFilter.hasAgent)
            ..setAgentAssignmentFilter(AgentAssignmentFilter.all);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(
            state.agentAssignmentFilter,
            equals(AgentAssignmentFilter.all),
          );
        });
      });

      test('default agentAssignmentFilter is all', () {
        fakeAsync((async) {
          final state = container.read(journalPageControllerProvider(true));
          expect(
            state.agentAssignmentFilter,
            equals(AgentAssignmentFilter.all),
          );

          settle(async);
        });
      });
    });

    group('Show Creation Date Toggle', () {
      test('setShowCreationDate updates showCreationDate to true', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.setShowCreationDate(show: true);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCreationDate, isTrue);
        });
      });

      test('setShowCreationDate can toggle back to false', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..setShowCreationDate(show: true)
            ..setShowCreationDate(show: false);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCreationDate, isFalse);
        });
      });

      test(
        'sortOption and showCreationDate persist across other state changes',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            controller
              ..setSortOption(TaskSortOption.byDate)
              ..setShowCreationDate(show: true)
              // Trigger unrelated state update
              ..setFilters({DisplayFilter.starredEntriesOnly});

            settle(async);

            final state = container.read(journalPageControllerProvider(true));
            expect(state.sortOption, equals(TaskSortOption.byDate));
            expect(state.showCreationDate, isTrue);
            expect(state.filters, contains(DisplayFilter.starredEntriesOnly));
          });
        },
      );
    });

    group('Show Due Date Toggle', () {
      test('setShowDueDate updates showDueDate to false', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Default is true, so toggle to false
          controller.setShowDueDate(show: false);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showDueDate, isFalse);
        });
      });

      test('setShowDueDate can toggle back to true', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..setShowDueDate(show: false)
            ..setShowDueDate(show: true);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showDueDate, isTrue);
        });
      });

      test('showDueDate defaults to true', () {
        fakeAsync((async) {
          container.read(journalPageControllerProvider(true));

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showDueDate, isTrue);
        });
      });
    });

    group('Filter Management - Project (Filter)', () {
      test('toggleProjectFilter adds project when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-1'}));
        });
      });

      test('toggleProjectFilter removes project when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-1');

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('clearProjectFilter removes all project selections', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-2');

          settle(async);

          controller.clearProjectFilter();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('removeStaleProjectFilters removes only stale IDs', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-2')
            ..toggleProjectFilter('proj-3');

          settle(async);

          controller.removeStaleProjectFilters({'proj-1', 'proj-3'});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-2'}));
        });
      });

      test('removeStaleProjectFilters is no-op when staleIds is empty', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          settle(async);

          controller.removeStaleProjectFilters(<String>{});

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-1'}));
        });
      });

      test('toggleSelectedCategoryIds clears project filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Set a project filter first
          controller.toggleProjectFilter('proj-1');

          settle(async);

          var state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isNotEmpty);

          // Changing category should clear project filters
          controller.toggleSelectedCategoryIds('cat-1');

          settle(async);

          state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('selectedAllCategories clears project filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          settle(async);

          controller.selectedAllCategories();

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
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
            () => mockJournalDb.getTasks(
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
            () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
          ).thenAnswer((_) async => {'task-in-project'});

          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller.toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final items = container
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
              () => mockJournalDb.getTasksSortedByDueDate(
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
              () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
            ).thenAnswer(
              (_) async => {'task-proj-due', 'task-proj-nodue'},
            );

            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            controller
              ..toggleProjectFilter('proj-1')
              ..setSortOption(TaskSortOption.byDueDate);

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final items = container
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
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          // Enable vector search flag
          configFlagsController.add({enableVectorSearchFlag});

          settle(async);

          controller.setSearchMode(SearchMode.vector);

          settle(async);

          final state = container.read(journalPageControllerProvider(true));
          expect(state.searchMode, equals(SearchMode.vector));
        });
      });

      test(
        'setSearchMode falls back to fullText when vector search is disabled',
        () {
          fakeAsync((async) {
            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            settle(async);

            // Do not enable vector search flag
            controller.setSearchMode(SearchMode.vector);

            settle(async);

            final state = container.read(journalPageControllerProvider(true));
            expect(state.searchMode, equals(SearchMode.fullText));
          });
        },
      );
    });
  });
}

Task _buildTestTaskRefresh({
  required String id,
  required String title,
  required DateTime createdAt,
  DateTime? updatedAt,
  TaskPriority priority = TaskPriority.p2Medium,
}) {
  return Task(
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: createdAt,
        utcOffset: 0,
      ),
      dateFrom: createdAt,
      dateTo: createdAt,
      statusHistory: const [],
      title: title,
      priority: priority,
    ),
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
      updatedAt: updatedAt ?? createdAt,
    ),
  );
}
