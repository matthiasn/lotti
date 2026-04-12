// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'helpers/journal_controller_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageController Filter Tests', () {
    final setup = JournalControllerTestSetup();

    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late ProviderContainer container;

    setUp(() {
      setup.setUp();
      mockJournalDb = setup.mockJournalDb;
      mockEntitiesCacheService = setup.mockEntitiesCacheService;
      container = setup.container;
    });

    tearDown(() async {
      await setup.tearDown();
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
  });
}
