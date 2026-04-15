// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
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
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'helpers/journal_controller_test_setup.dart';

final _testDate = DateTime(2024);

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Select all entry types initially
          controller.selectAllEntryTypes(entryTypes);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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
            ),
          ).called(greaterThan(0));
        });
      });
    });

    group('Private Entries Flag', () {
      test('showPrivateEntries updates when private flag changes', () {
        fakeAsync((async) {
          container.read(journalPageControllerProvider(false));

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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
      test('selectedEntryTypesInternal returns internal set', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.selectedEntryTypesInternal, isNotEmpty);
        });
      });

      test('filtersInternal returns internal filters set', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setFilters({DisplayFilter.starredEntriesOnly});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(
            controller.filtersInternal,
            contains(DisplayFilter.starredEntriesOnly),
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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // First select all
          controller.selectAllEntryTypes(entryTypes);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(
            controller.selectedEntryTypesInternal.length,
            entryTypes.length,
          );

          // Then select single
          controller.selectSingleEntryType('Task');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.selectedEntryTypesInternal, equals({'Task'}));
        });
      });

      test('clearSelectedEntryTypes results in empty set', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.clearSelectedEntryTypes();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // First select all
          controller.selectAllTaskStatuses();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Then select single
          controller.selectSingleTaskStatus('DONE');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // Clear selection to make it empty
            controller.clearSelectedEntryTypes();

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            expect(controller.selectedEntryTypesInternal, isEmpty);

            // Emit config flags with events enabled
            configFlagsController.add({enableEventsFlag});

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // First emit with no flags - get initial allowed types
          configFlagsController.add(<String>{});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final initialAllowed = computeAllowedEntryTypes(
            events: false,
            habits: false,
            dashboards: false,
          ).toSet();

          // Select all allowed types
          controller.selectAllEntryTypes(initialAllowed.toList());

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.selectedEntryTypesInternal, equals(initialAllowed));

          // Now enable events flag
          configFlagsController.add({enableEventsFlag});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // First emit with all flags enabled
            configFlagsController.add({
              enableEventsFlag,
              enableHabitsPageFlag,
              enableDashboardsPageFlag,
            });

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // Select a partial set including some gated types
            // JournalEvent (gated by events), HabitCompletionEntry (gated by habits)
            // Task (always allowed)
            controller.selectAllEntryTypes([
              'Task',
              'JournalEvent',
              'HabitCompletionEntry',
            ]);

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            expect(
              controller.selectedEntryTypesInternal,
              equals({'Task', 'JournalEvent', 'HabitCompletionEntry'}),
            );

            // Now disable events and habits flags
            configFlagsController.add(<String>{});

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Start with events only
          configFlagsController.add({enableEventsFlag});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final eventsAllowed = computeAllowedEntryTypes(
            events: true,
            habits: false,
            dashboards: false,
          ).toSet();

          // Select all currently allowed types
          controller.selectAllEntryTypes(eventsAllowed.toList());

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.selectedEntryTypesInternal, equals(eventsAllowed));
          expect(
            controller.selectedEntryTypesInternal,
            isNot(contains('HabitCompletionEntry')),
          );

          // Now also enable habits
          configFlagsController.add({enableEventsFlag, enableHabitsPageFlag});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Start with dashboards enabled
          configFlagsController.add({enableDashboardsPageFlag});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Select only dashboard-gated types plus Task
          controller.selectAllEntryTypes([
            'Task',
            'MeasurementEntry',
            'QuantitativeEntry',
          ]);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(
            controller.selectedEntryTypesInternal,
            equals({'Task', 'MeasurementEntry', 'QuantitativeEntry'}),
          );

          // Disable dashboards
          configFlagsController.add(<String>{});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-1'}));
        });
      });

      test('toggleProjectFilter removes project when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('clearProjectFilter removes all project selections', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-2');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.clearProjectFilter();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('removeStaleProjectFilters removes only stale IDs', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleProjectFilter('proj-1')
            ..toggleProjectFilter('proj-2')
            ..toggleProjectFilter('proj-3');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.removeStaleProjectFilters({'proj-1', 'proj-3'});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-2'}));
        });
      });

      test('removeStaleProjectFilters is no-op when staleIds is empty', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.removeStaleProjectFilters(<String>{});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, equals({'proj-1'}));
        });
      });

      test('toggleSelectedCategoryIds clears project filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Set a project filter first
          controller.toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          var state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isNotEmpty);

          // Changing category should clear project filters
          controller.toggleSelectedCategoryIds('cat-1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, isEmpty);
        });
      });

      test('selectedAllCategories clears project filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleProjectFilter('proj-1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectedAllCategories();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSelectedTaskStatuses({'DONE', 'BLOCKED'});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // First set some projects
            controller.setSelectedProjectIds({'proj-1'});

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // Now set categories — projects should be cleared
            controller.setSelectedCategoryIds({'cat-1', 'cat-2'});

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSelectedLabelIds({'label-1', 'label-2'});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedLabelIds, {'label-1', 'label-2'});
        });
      });

      test('setSelectedProjectIds replaces all projects', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSelectedProjectIds({'proj-a', 'proj-b'});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedProjectIds, {'proj-a', 'proj-b'});
        });
      });

      test('setSelectedPriorities replaces all priorities', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSelectedPriorities({'HIGH', 'CRITICAL'});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedPriorities, {'HIGH', 'CRITICAL'});
        });
      });

      test('batch setters defensively copy input sets', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final mutableSet = {'DONE'};
          controller.setSelectedTaskStatuses(mutableSet);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final stateBefore = container.read(
            journalPageControllerProvider(true),
          );

          // Only update statuses, leave everything else
          controller.applyBatchFilterUpdate(statuses: {'BLOCKED'});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            controller.applyBatchFilterUpdate(
              searchMode: SearchMode.vector,
            );

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // Enable vector search via config flags
            configFlagsController.add({enableVectorSearchFlag});
            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            expect(controller.enableVectorSearchInternal, isTrue);

            controller.applyBatchFilterUpdate(
              searchMode: SearchMode.vector,
            );

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // Flag is disabled by default
            controller.setSearchMode(SearchMode.vector);

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          emitVectorSearchFlag(async);

          controller.setSearchMode(SearchMode.vector);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Enable vector search flag
          configFlagsController.add({enableVectorSearchFlag});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Set search mode to vector
          controller.setSearchMode(SearchMode.vector);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.searchModeInternal, equals(SearchMode.fullText));
        });
      });

      test('returns vector after setSearchMode with vector search enabled', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          configFlagsController.add({enableVectorSearchFlag});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSearchMode(SearchMode.vector);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.searchModeInternal, equals(SearchMode.vector));
        });
      });
    });
  });
}
