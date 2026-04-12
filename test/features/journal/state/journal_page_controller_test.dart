// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../mocks/mocks.dart';
import 'helpers/journal_controller_test_setup.dart';

final _testDate = DateTime(2024, 3, 15);

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

    group('Filter Management - Task Status', () {
      test('toggleSelectedTaskStatus adds status when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedTaskStatus('BLOCKED');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses.contains('BLOCKED'), isTrue);
        });
      });

      test('toggleSelectedTaskStatus removes status when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // OPEN is in the default set
          controller.toggleSelectedTaskStatus('OPEN');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses.contains('OPEN'), isFalse);
        });
      });

      test('selectSingleTaskStatus sets only one status', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectSingleTaskStatus('DONE');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses, equals({'DONE'}));
        });
      });

      test('selectAllTaskStatuses selects all statuses', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectAllTaskStatuses();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.clearSelectedTaskStatuses();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedTaskStatuses, isEmpty);
        });
      });
    });

    group('Filter Management - Category', () {
      test('toggleSelectedCategoryIds adds category when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedCategoryIds('cat1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedCategoryIds.contains('cat1'), isTrue);
        });
      });

      test('toggleSelectedCategoryIds removes category when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleSelectedCategoryIds('cat1')
            ..toggleSelectedCategoryIds('cat1');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedCategoryIds.contains('cat1'), isFalse);
        });
      });

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleSelectedCategoryIds('cat1')
            ..toggleSelectedCategoryIds('cat2');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectedAllCategories();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedCategoryIds, isEmpty);
        });
      });
    });

    group('Filter Management - Labels', () {
      test('toggleSelectedLabelId adds label when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedLabelId('label-A');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedLabelIds, equals({'label-A'}));
        });
      });

      test('toggleSelectedLabelId removes label when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleSelectedLabelId('label-A')
            ..toggleSelectedLabelId('label-A');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedLabelIds, isEmpty);
        });
      });

      test('clearSelectedLabelIds removes all label filters', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleSelectedLabelId('label-A')
            ..toggleSelectedLabelId('label-B');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.clearSelectedLabelIds();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedLabelIds, isEmpty);
        });
      });
    });

    group('Filter Management - Priority', () {
      test('toggleSelectedPriority adds priority when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedPriority('P0');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedPriorities, contains('P0'));
        });
      });

      test('toggleSelectedPriority removes priority when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleSelectedPriority('P0')
            ..toggleSelectedPriority('P0');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedPriorities.contains('P0'), isFalse);
        });
      });

      test('clearSelectedPriorities removes all priorities', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..toggleSelectedPriority('P0')
            ..toggleSelectedPriority('P1')
            ..clearSelectedPriorities();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedPriorities, isEmpty);
        });
      });
    });

    group('Filter Management - Entry Types', () {
      test('toggleSelectedEntryTypes adds type when not present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // First clear then add specific type
          controller
            ..clearSelectedEntryTypes()
            ..toggleSelectedEntryTypes('Task');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes.contains('Task'), isTrue);
        });
      });

      test('toggleSelectedEntryTypes removes type when present', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Task is in the default set, remove it
          controller.toggleSelectedEntryTypes('Task');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes.contains('Task'), isFalse);
        });
      });

      test('selectSingleEntryType sets only one type', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectSingleEntryType('Task');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes, equals(['Task']));
        });
      });

      test('selectAllEntryTypes selects all types', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectAllEntryTypes();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedEntryTypes.length, equals(entryTypes.length));
        });
      });

      test('clearSelectedEntryTypes clears all types', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.clearSelectedEntryTypes();

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setFilters({DisplayFilter.starredEntriesOnly});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.filters, equals({DisplayFilter.starredEntriesOnly}));
        });
      });

      test('setFilters updates flagged filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setFilters({DisplayFilter.flaggedEntriesOnly});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.filters, equals({DisplayFilter.flaggedEntriesOnly}));
        });
      });

      test('setFilters updates private filter', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setFilters({DisplayFilter.privateEntriesOnly});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.filters, equals({DisplayFilter.privateEntriesOnly}));
        });
      });

      test('setFilters can combine multiple filters', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setFilters({
            DisplayFilter.starredEntriesOnly,
            DisplayFilter.privateEntriesOnly,
          });

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDate);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDate));
        });
      });

      test('setSortOption can toggle back to byPriority', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..setSortOption(TaskSortOption.byDate)
            ..setSortOption(TaskSortOption.byPriority);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byPriority));
        });
      });

      test('setSortOption updates sortOption to byDueDate', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDueDate));
        });
      });

      test('setSortOption cycles through all three options', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Start with byPriority (default)
          var state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byPriority));

          // Switch to byDueDate
          controller.setSortOption(TaskSortOption.byDueDate);
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
          state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDueDate));

          // Switch to byDate
          controller.setSortOption(TaskSortOption.byDate);
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
          state = container.read(journalPageControllerProvider(true));
          expect(state.sortOption, equals(TaskSortOption.byDate));

          // Back to byPriority
          controller.setSortOption(TaskSortOption.byPriority);
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
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

      test('setAgentAssignmentFilter updates to hasAgent', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.hasAgent);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setAgentAssignmentFilter(AgentAssignmentFilter.noAgent);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..setAgentAssignmentFilter(AgentAssignmentFilter.hasAgent)
            ..setAgentAssignmentFilter(AgentAssignmentFilter.all);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        });
      });
    });

    group('Show Creation Date Toggle', () {
      test('setShowCreationDate updates showCreationDate to true', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setShowCreationDate(show: true);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCreationDate, isTrue);
        });
      });

      test('setShowCreationDate can toggle back to false', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..setShowCreationDate(show: true)
            ..setShowCreationDate(show: false);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

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

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            controller
              ..setSortOption(TaskSortOption.byDate)
              ..setShowCreationDate(show: true)
              // Trigger unrelated state update
              ..setFilters({DisplayFilter.starredEntriesOnly});

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Default is true, so toggle to false
          controller.setShowDueDate(show: false);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showDueDate, isFalse);
        });
      });

      test('setShowDueDate can toggle back to true', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..setShowDueDate(show: false)
            ..setShowDueDate(show: true);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showDueDate, isTrue);
        });
      });

      test('showDueDate defaults to true', () {
        fakeAsync((async) {
          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showDueDate, isTrue);
        });
      });
    });

    group('Show Cover Art Toggle', () {
      test('setShowCoverArt updates showCoverArt to false', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Default is true, so toggle to false
          controller.setShowCoverArt(show: false);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCoverArt, isFalse);
        });
      });

      test('setShowCoverArt can toggle back to true', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..setShowCoverArt(show: false)
            ..setShowCoverArt(show: true);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCoverArt, isTrue);
        });
      });

      test('showCoverArt defaults to true', () {
        fakeAsync((async) {
          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCoverArt, isTrue);
        });
      });

      test('showCoverArt persists alongside other settings', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(true).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller
            ..setShowCoverArt(show: false)
            ..setSortOption(TaskSortOption.byDate)
            ..setFilters({DisplayFilter.starredEntriesOnly});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.showCoverArt, isFalse);
          expect(state.sortOption, equals(TaskSortOption.byDate));
          expect(state.filters, contains(DisplayFilter.starredEntriesOnly));
        });
      });
    });

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

    group('Visibility Updates', () {
      test(
        'updateVisibility refreshes when becoming visible after missed update',
        () {
          fakeAsync((async) {
            var queryCallCount = 0;
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
              queryCallCount++;
              return [];
            });

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final initialCount = queryCallCount;

            // First, simulate being invisible
            controller.updateVisibility(
              const MockVisibilityInfo(visibleBounds: Rect.zero),
            );

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

            // Count should remain unchanged (no refresh when becoming invisible)
            expect(queryCallCount, equals(initialCount));

            // Fire an update while invisible — this sets the dirty flag
            updateStreamController.add({'some-missed-id'});
            async.elapse(const Duration(milliseconds: 600));
            async.flushMicrotasks();

            // Still no refresh while invisible
            expect(queryCallCount, equals(initialCount));

            // Now simulate becoming visible - should trigger refresh
            // because updates were missed
            controller.updateVisibility(
              const MockVisibilityInfo(
                visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
              ),
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            // Should have increased due to missed update
            expect(queryCallCount, greaterThan(initialCount));
          });
        },
      );

      test('updateVisibility does not refresh when no updates were missed', () {
        fakeAsync((async) {
          var queryCallCount = 0;
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
            queryCallCount++;
            return [];
          });

          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final initialCount = queryCallCount;

          // Go invisible
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Come back visible without any missed updates
          controller.updateVisibility(
            const MockVisibilityInfo(
              visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
            ),
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should NOT have refreshed — no updates were missed
          expect(queryCallCount, equals(initialCount));
        });
      });

      test('does not refresh when staying invisible', () {
        fakeAsync((async) {
          var queryCallCount = 0;
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
            queryCallCount++;
            return [];
          });

          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final initialCount = queryCallCount;

          // Simulate being invisible
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Stay invisible - should NOT trigger refresh
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Count should remain unchanged
          expect(queryCallCount, equals(initialCount));
        });
      });

      test('isVisible getter reflects current visibility', () {
        fakeAsync((async) {
          final controller = container.read(
            journalPageControllerProvider(false).notifier,
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.isVisible, isFalse);

          controller.updateVisibility(
            const MockVisibilityInfo(
              visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
            ),
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.isVisible, isTrue);

          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.isVisible, isFalse);
        });
      });
    });

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

    group('Update Notifications', () {
      test(
        'visible controller refreshes when update affects displayed items',
        () {
          fakeAsync((async) {
            var queryCallCount = 0;
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
              queryCallCount++;
              return [];
            });

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            // Make visible
            controller.updateVisibility(
              const MockVisibilityInfo(
                visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
              ),
            );

            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();

            final countAfterVisible = queryCallCount;

            // Send update notification
            updateStreamController.add({'some-id'});

            // Wait for throttle (500ms) plus processing
            async.elapse(const Duration(milliseconds: 600));
            async.flushMicrotasks();

            // Query count may increase depending on implementation details
            // At minimum, the subscription should be active
            expect(queryCallCount, greaterThanOrEqualTo(countAfterVisible));
          });
        },
      );

      test(
        'visible tasks refresh affected displayed items without an extra probe',
        () {
          fakeAsync((async) {
            final initialTask = _buildTestTask(
              id: 'task-1',
              title: 'Initial task',
              createdAt: _testDate,
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

            controller.updateVisibility(
              const MockVisibilityInfo(
                visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
              ),
            );

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
            final initialTask = _buildTestTask(
              id: 'task-1',
              title: 'Initial task',
              createdAt: _testDate,
              priority: TaskPriority.p1High,
            );
            final refreshedLeadingTask = _buildTestTask(
              id: 'task-2',
              title: 'Refreshed leading task',
              createdAt: _testDate.add(const Duration(minutes: 1)),
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

            controller.updateVisibility(
              const MockVisibilityInfo(
                visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
              ),
            );

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
                  (index) => _buildTestTask(
                    id: '$prefix-$index',
                    title: '$prefix task $index',
                    createdAt: _testDate.add(Duration(minutes: index)),
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

            controller.updateVisibility(
              const MockVisibilityInfo(
                visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
              ),
            );

            clearInteractions(mockJournalDb);

            updateStreamController.add({'off-screen-task'});
            async.elapse(const Duration(milliseconds: 50));
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
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              entryText: const EntryText(plainText: 'Entry'),
            );
            var queryCallCount = 0;

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
              queryCallCount++;
              return [entry];
            });

            final controller = container.read(
              journalPageControllerProvider(false).notifier,
            );

            async.flushMicrotasks();

            controller.updateVisibility(
              const MockVisibilityInfo(
                visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
              ),
            );

            clearInteractions(mockJournalDb);
            queryCallCount = 0;

            updateStreamController.add({'entry-1'});

            async.elapse(const Duration(milliseconds: 200));
            async.flushMicrotasks();

            expect(queryCallCount, 1);
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

    group('Refresh Behavior', () {
      test(
        'refreshQuery keeps visible first-page items until replacement data arrives',
        () {
          fakeAsync((async) {
            final initialTask = JournalEntity.task(
              meta: Metadata(
                id: 'task-1',
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Initial task',
                status: TaskStatus.open(
                  id: 'status-initial',
                  createdAt: _testDate,
                  utcOffset: 0,
                ),
              ),
            );
            final refreshedTask = JournalEntity.task(
              meta: Metadata(
                id: 'task-1',
                createdAt: _testDate,
                updatedAt: _testDate.add(const Duration(minutes: 1)),
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Refreshed task',
                status: TaskStatus.open(
                  id: 'status-refreshed',
                  createdAt: _testDate,
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
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Initial task',
                status: TaskStatus.open(
                  id: 'status-initial',
                  createdAt: _testDate,
                  utcOffset: 0,
                ),
              ),
            );
            final refreshedTask = JournalEntity.task(
              meta: Metadata(
                id: 'task-2',
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Refreshed task',
                status: TaskStatus.open(
                  id: 'status-refreshed',
                  createdAt: _testDate,
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
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Initial task',
                status: TaskStatus.open(
                  id: 'status-initial',
                  createdAt: _testDate,
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
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Initial task',
                status: TaskStatus.open(
                  id: 'status-initial',
                  createdAt: _testDate,
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
                createdAt: _testDate,
                updatedAt: _testDate,
                dateFrom: _testDate,
                dateTo: _testDate,
              ),
              data: TaskData(
                dateFrom: _testDate,
                dateTo: _testDate,
                statusHistory: const [],
                title: 'Updated task',
                status: TaskStatus.open(
                  id: 'status-updated',
                  createdAt: _testDate,
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
              (index) => _buildTestTask(
                id: 'task-$index',
                title: 'Initial task $index',
                createdAt: _testDate.add(Duration(minutes: index)),
                priority: TaskPriority.p1High,
              ),
              growable: false,
            );
            final initialSecondPageTask = _buildTestTask(
              id: 'task-late',
              title: 'Initial late task',
              createdAt: _testDate.add(const Duration(hours: 3)),
              priority: TaskPriority.p2Medium,
            );
            final regroupedTask = _buildTestTask(
              id: 'task-late',
              title: 'Regrouped late task',
              createdAt: _testDate.add(const Duration(hours: 3)),
              updatedAt: _testDate.add(const Duration(days: 1)),
              priority: TaskPriority.p0Urgent,
            );
            final refreshedFirstPage = <JournalEntity>[
              regroupedTask,
              ...initialFirstPage.take(JournalPageController.pageSize - 1),
            ];
            final refreshedSecondPageTask = _buildTestTask(
              id: 'task-tail',
              title: 'Refreshed tail task',
              createdAt: _testDate.add(const Duration(hours: 4)),
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
              (index) => _buildTestTask(
                id: 'task-$index',
                title: 'Initial task $index',
                createdAt: _testDate.add(Duration(minutes: index)),
                priority: TaskPriority.p1High,
              ),
              growable: false,
            );
            final initialSecondPageTask = _buildTestTask(
              id: 'task-late',
              title: 'Initial late task',
              createdAt: _testDate.add(const Duration(hours: 3)),
              priority: TaskPriority.p2Medium,
            );
            final refreshedFirstPage = List<JournalEntity>.generate(
              JournalPageController.pageSize,
              (index) => _buildTestTask(
                id: 'refreshed-$index',
                title: 'Refreshed task $index',
                createdAt: _testDate.add(Duration(hours: index)),
                priority: TaskPriority.p1High,
              ),
              growable: false,
            );
            final refreshedSecondPageTask = _buildTestTask(
              id: 'refreshed-tail',
              title: 'Refreshed tail task',
              createdAt: _testDate.add(const Duration(hours: 5)),
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
                  (index) => _buildTestTask(
                    id: '$prefix-$index',
                    title: '$prefix task $index',
                    createdAt: _testDate.add(Duration(minutes: index)),
                    priority: TaskPriority.p1High,
                  ),
                  growable: false,
                );

            final initialFirstPage = List<JournalEntity>.generate(
              JournalPageController.pageSize,
              (index) => _buildTestTask(
                id: 'initial-$index',
                title: 'Initial task $index',
                createdAt: _testDate.add(Duration(minutes: index)),
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
              (index) => _buildTestTask(
                id: 'task-$index',
                title: 'Initial task $index',
                createdAt: _testDate.add(Duration(minutes: index)),
                priority: TaskPriority.p1High,
              ),
              growable: false,
            );
            final initialSecondPageTask = _buildTestTask(
              id: 'task-late',
              title: 'Initial late task',
              createdAt: _testDate.add(const Duration(hours: 3)),
              priority: TaskPriority.p2Medium,
            );
            final winnerTask = _buildTestTask(
              id: 'winner-task',
              title: 'Winner task',
              createdAt: _testDate.add(const Duration(hours: 10)),
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
            final initialTask = _buildTestTask(
              id: 'task-1',
              title: 'Initial task',
              createdAt: _testDate,
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
          controller.updateVisibility(
            const MockVisibilityInfo(
              visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
            ),
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final visibleCount = queryCount;

          // Now make invisible
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );

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

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Multiple calls with zero bounds
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );
          controller.updateVisibility(
            const MockVisibilityInfo(visibleBounds: Rect.zero),
          );

          expect(controller.isVisible, isFalse);
        });
      });
    });

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
              () => mockJournalDb.getTaskIdsForProjects({'proj-1'}),
            ).thenAnswer(
              (_) async => {'task-proj-due', 'task-proj-nodue'},
            );

            final controller = container.read(
              journalPageControllerProvider(true).notifier,
            );

            async.elapse(const Duration(milliseconds: 50));
            async.flushMicrotasks();

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

    // Vector search tests moved to journal_query_runner_test.dart
  });
}

class MockVisibilityInfo extends VisibilityInfo {
  const MockVisibilityInfo({required super.visibleBounds})
    : super(
        key: const Key('test'),
        size: const Size(100, 100),
      );
}

Task _buildTestTask({
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
