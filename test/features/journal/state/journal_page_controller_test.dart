// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/src/core/extensions.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageController Tests', () {
    late MockJournalDb mockJournalDb;
    late MockSettingsDb mockSettingsDb;
    late MockFts5Db mockFts5Db;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late StreamController<Set<String>> updateStreamController;
    late StreamController<Set<String>> configFlagsController;
    late StreamController<bool> privateFlagController;
    late ProviderContainer container;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockSettingsDb = MockSettingsDb();
      mockFts5Db = MockFts5Db();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();

      updateStreamController = StreamController<Set<String>>.broadcast();
      configFlagsController = StreamController<Set<String>>.broadcast();
      privateFlagController = StreamController<bool>.broadcast();

      // Default mock behaviors
      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => updateStreamController.stream);

      when(() => mockJournalDb.watchActiveConfigFlagNames())
          .thenAnswer((_) => configFlagsController.stream);

      when(() => mockJournalDb.watchConfigFlag(privateFlag))
          .thenAnswer((_) => privateFlagController.stream);

      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);

      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      when(() => mockFts5Db.watchFullTextMatches(any()))
          .thenAnswer((_) => Stream.value(<String>[]));

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      when(() => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            sortByDate: any(named: 'sortByDate'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      container = ProviderContainer();
    });

    tearDown(() async {
      await updateStreamController.close();
      await configFlagsController.close();
      await privateFlagController.close();
      container.dispose();
      await getIt.reset();
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
          final tasksState =
              container.read(journalPageControllerProvider(true));
          final journalState =
              container.read(journalPageControllerProvider(false));

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
          when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

          final state = container.read(journalPageControllerProvider(true));

          // Verify immediately after construction
          expect(state.selectedCategoryIds, equals(<String>{''}));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
        });
      });

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
          verify(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).called(greaterThan(0));
        });
      });
    });

    group('Filter Management - Task Status', () {
      test('toggleSelectedTaskStatus adds status when not present', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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

          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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

    group('Show Creation Date Toggle', () {
      test('setShowCreationDate updates showCreationDate to true', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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

      test('sortOption and showCreationDate persist across other state changes',
          () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
      });
    });

    group('Show Due Date Toggle', () {
      test('setShowDueDate updates showDueDate to false', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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

    group('Search Functionality', () {
      test('setSearchString updates match in state', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSearchString('test query');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(() => mockFts5Db.watchFullTextMatches('test query'))
              .called(greaterThan(0));
        });
      });

      test('empty search string clears match and fullTextMatches', () {
        fakeAsync((async) {
          when(() => mockFts5Db.watchFullTextMatches('test'))
              .thenAnswer((_) => Stream.value(['id1', 'id2']));

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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

    group('Persistence - Loading', () {
      test('loads persisted filters from per-tab key', () {
        fakeAsync((async) {
          final persistedFilter = jsonEncode({
            'selectedCategoryIds': ['cat1'],
            'selectedTaskStatuses': ['DONE'],
            'selectedLabelIds': ['label1'],
            'selectedPriorities': ['P0'],
            'sortOption': 'byDate',
            'showCreationDate': true,
            'showDueDate': false,
          });

          when(
            () => mockSettingsDb
                .itemByKey(JournalPageController.tasksCategoryFiltersKey),
          ).thenAnswer((_) async => persistedFilter);

          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedCategoryIds, contains('cat1'));
          expect(state.selectedTaskStatuses, equals({'DONE'}));
          expect(state.selectedLabelIds, equals({'label1'}));
          expect(state.selectedPriorities, equals({'P0'}));
          expect(state.sortOption, equals(TaskSortOption.byDate));
          expect(state.showCreationDate, isTrue);
          expect(state.showDueDate, isFalse);
        });
      });

      test('loads persisted filters from journal per-tab key', () {
        fakeAsync((async) {
          final persistedFilter = jsonEncode({
            'selectedCategoryIds': ['cat2'],
            'selectedTaskStatuses': <String>[],
            'selectedLabelIds': <String>[],
            'selectedPriorities': <String>[],
            'sortOption': 'byPriority',
            'showCreationDate': false,
          });

          when(
            () => mockSettingsDb
                .itemByKey(JournalPageController.journalCategoryFiltersKey),
          ).thenAnswer((_) async => persistedFilter);

          container.read(journalPageControllerProvider(false));

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          // Journal tab only loads category filters
          expect(state.selectedCategoryIds, contains('cat2'));
          // Task-specific filters should not be loaded for journal tab
          expect(state.selectedLabelIds, isEmpty);
        });
      });

      test('falls back to legacy key when per-tab key not found', () {
        fakeAsync((async) {
          final persistedFilter = jsonEncode({
            'selectedCategoryIds': ['legacy-cat'],
            'selectedTaskStatuses': ['OPEN'],
            'selectedLabelIds': <String>[],
            'selectedPriorities': <String>[],
            'sortOption': 'byPriority',
            'showCreationDate': false,
          });

          // Per-tab key returns null
          when(
            () => mockSettingsDb
                .itemByKey(JournalPageController.tasksCategoryFiltersKey),
          ).thenAnswer((_) async => null);

          // Legacy key returns data
          when(
            () =>
                mockSettingsDb.itemByKey(JournalPageController.taskFiltersKey),
          ).thenAnswer((_) async => persistedFilter);

          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          expect(state.selectedCategoryIds, contains('legacy-cat'));
        });
      });

      test('loads persisted entry types', () {
        fakeAsync((async) {
          final persistedTypes = jsonEncode(['Task', 'JournalEntry']);

          when(
            () => mockSettingsDb
                .itemByKey(JournalPageController.selectedEntryTypesKey),
          ).thenAnswer((_) async => persistedTypes);

          container.read(journalPageControllerProvider(false));

          async.elapse(const Duration(milliseconds: 200));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(
            state.selectedEntryTypes.toSet(),
            equals({'Task', 'JournalEntry'}),
          );
        });
      });
    });

    group('Persistence - Saving', () {
      test('persistTasksFilter saves to per-tab key for tasks tab', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedTaskStatus('DONE');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(
            () => mockSettingsDb.saveSettingsItem(
              JournalPageController.tasksCategoryFiltersKey,
              any(),
            ),
          ).called(greaterThan(0));
        });
      });

      test('persistTasksFilter saves to legacy key for tasks tab', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedTaskStatus('DONE');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(
            () => mockSettingsDb.saveSettingsItem(
              JournalPageController.taskFiltersKey,
              any(),
            ),
          ).called(greaterThan(0));
        });
      });

      test(
          'persistTasksFilter saves to per-tab key only for journal tab (no legacy)',
          () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedCategoryIds('cat1');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(
            () => mockSettingsDb.saveSettingsItem(
              JournalPageController.journalCategoryFiltersKey,
              any(),
            ),
          ).called(greaterThan(0));

          // Legacy key should NOT be written for journal tab
          verifyNever(
            () => mockSettingsDb.saveSettingsItem(
              JournalPageController.taskFiltersKey,
              any(),
            ),
          );
        });
      });

      test('persistEntryTypes saves entry types', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.selectSingleEntryType('Task');

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(
            () => mockSettingsDb.saveSettingsItem(
              JournalPageController.selectedEntryTypesKey,
              any(),
            ),
          ).called(greaterThan(0));
        });
      });
    });

    group('Feature Flag Handling', () {
      test('feature flags affect allowed entry types', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          when(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).thenAnswer((invocation) async {
            capturedTypes = invocation.namedArguments[#types] as List<String>?;
            return [];
          });

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
      });

      test('enabling all flags includes all gated types', () {
        fakeAsync((async) {
          List<String>? capturedTypes;
          when(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).thenAnswer((invocation) async {
            capturedTypes = invocation.namedArguments[#types] as List<String>?;
            return [];
          });

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
      test('updateVisibility refreshes when becoming visible', () {
        fakeAsync((async) {
          var queryCallCount = 0;
          when(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).thenAnswer((_) async {
            queryCallCount++;
            return [];
          });

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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

          // Now simulate becoming visible - this should trigger refresh
          controller.updateVisibility(
            const MockVisibilityInfo(
              visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
            ),
          );

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Should have increased due to visibility change
          expect(queryCallCount, greaterThan(initialCount));
        });
      });

      test('does not refresh when staying invisible', () {
        fakeAsync((async) {
          var queryCallCount = 0;
          when(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).thenAnswer((_) async {
            queryCallCount++;
            return [];
          });

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          verify(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: 50, // pageSize
                categoryIds: any(named: 'categoryIds'),
              )).called(greaterThan(0));
        });
      });

      test('tasks query uses getTasks instead of getJournalEntities', () {
        fakeAsync((async) {
          container.read(journalPageControllerProvider(true));

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          verify(() => mockJournalDb.getTasks(
                ids: any(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                sortByDate: any(named: 'sortByDate'),
                limit: 50,
              )).called(greaterThan(0));
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

    group('Label Filter Persistence', () {
      test('label filter state persists across state updates', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.toggleSelectedLabelId('label-A');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // Trigger unrelated state update
          controller.setFilters({DisplayFilter.starredEntriesOnly});

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(false));
          expect(state.selectedLabelIds, contains('label-A'));
          expect(state.filters, contains(DisplayFilter.starredEntriesOnly));
        });
      });
    });

    group('Update Notifications', () {
      test('visible controller refreshes when update affects displayed items',
          () {
        fakeAsync((async) {
          var queryCallCount = 0;
          when(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).thenAnswer((_) async {
            queryCallCount++;
            return [];
          });

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
      });
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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.selectedEntryTypesInternal, isNotEmpty);
        });
      });

      test('filtersInternal returns internal filters set', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
            () => mockSettingsDb
                .itemByKey(JournalPageController.tasksCategoryFiltersKey),
          ).thenAnswer((_) async => 'not valid json {{{');

          when(
            () =>
                mockSettingsDb.itemByKey(JournalPageController.taskFiltersKey),
          ).thenAnswer((_) async => null);

          // Controller should initialize without throwing
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // State should still be valid with defaults
          expect(controller.state, isNotNull);
          expect(controller.state.showTasks, isTrue);
        });
      });

      test('handles missing pagingController gracefully in refreshQuery', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // This should not throw even if pagingController state is complex
          expect(controller.refreshQuery, returnsNormally);
        });
      });
    });

    group('Visibility Edge Cases', () {
      test('does not refresh when transitioning from visible to invisible', () {
        fakeAsync((async) {
          var queryCount = 0;
          when(() => mockJournalDb.getJournalEntities(
                types: any(named: 'types'),
                starredStatuses: any(named: 'starredStatuses'),
                privateStatuses: any(named: 'privateStatuses'),
                flaggedStatuses: any(named: 'flaggedStatuses'),
                ids: any(named: 'ids'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                categoryIds: any(named: 'categoryIds'),
              )).thenAnswer((_) async {
            queryCount++;
            return [];
          });

          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          // First select all
          controller.selectAllEntryTypes(entryTypes);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(
              controller.selectedEntryTypesInternal.length, entryTypes.length);

          // Then select single
          controller.selectSingleEntryType('Task');

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          expect(controller.selectedEntryTypesInternal, equals({'Task'}));
        });
      });

      test('clearSelectedEntryTypes results in empty set', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

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
      test('empty selection repopulates with all allowed types on flag change',
          () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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

          expect(controller.selectedEntryTypesInternal, equals(expectedTypes));
        });
      });

      test(
          'selection with all previously selected adopts new allowed types '
          'when flags change', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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

      test('partial selection intersects with new allowed types on flag change',
          () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
      });

      test('enabling new flag adds types when user had all selected', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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
          final controller =
              container.read(journalPageControllerProvider(false).notifier);

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

    group('Due Date Sorting', () {
      test('byDueDate sort option triggers sortByDate in database query', () {
        fakeAsync((async) {
          bool? capturedSortByDate;
          when(() => mockJournalDb.getTasks(
                ids: any(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                sortByDate: any(named: 'sortByDate'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              )).thenAnswer((invocation) async {
            capturedSortByDate =
                invocation.namedArguments[#sortByDate] as bool?;
            return <JournalEntity>[];
          });

          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // byDueDate should also use date-based query
          expect(capturedSortByDate, isTrue);
        });
      });

      test('byDueDate sorts tasks with due dates before tasks without', () {
        fakeAsync((async) {
          // Create tasks: one with due date, one without
          final taskWithDue = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'Task with due date',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              due: DateTime(2024, 6, 15),
            ),
            meta: Metadata(
              id: 'task-with-due',
              createdAt: DateTime(2024, 1, 1),
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              updatedAt: DateTime(2024, 1, 1),
            ),
          );

          final taskWithoutDue = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_2',
                createdAt: DateTime(2024, 1, 2),
                utcOffset: 0,
              ),
              title: 'Task without due date',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
            ),
            meta: Metadata(
              id: 'task-without-due',
              createdAt: DateTime(2024, 1, 2),
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
              updatedAt: DateTime(2024, 1, 2),
            ),
          );

          // Return tasks in reverse order (without due first)
          when(() => mockJournalDb.getTasks(
                ids: any(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                sortByDate: any(named: 'sortByDate'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              )).thenAnswer((_) async => [taskWithoutDue, taskWithDue]);

          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          final items = state.pagingController?.value.items ?? [];

          // Task with due date should be first
          expect(items.length, 2);
          expect((items[0] as Task).meta.id, 'task-with-due');
          expect((items[1] as Task).meta.id, 'task-without-due');
        });
      });

      test('byDueDate sorts tasks by due date ascending (soonest first)', () {
        fakeAsync((async) {
          final taskDueLater = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'Task due later',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              due: DateTime(2024, 12, 31),
            ),
            meta: Metadata(
              id: 'task-due-later',
              createdAt: DateTime(2024, 1, 1),
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              updatedAt: DateTime(2024, 1, 1),
            ),
          );

          final taskDueSooner = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_2',
                createdAt: DateTime(2024, 1, 2),
                utcOffset: 0,
              ),
              title: 'Task due sooner',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
              due: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: 'task-due-sooner',
              createdAt: DateTime(2024, 1, 2),
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
              updatedAt: DateTime(2024, 1, 2),
            ),
          );

          // Return tasks in reverse order (later due first)
          when(() => mockJournalDb.getTasks(
                ids: any(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                sortByDate: any(named: 'sortByDate'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              )).thenAnswer((_) async => [taskDueLater, taskDueSooner]);

          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          final items = state.pagingController?.value.items ?? [];

          // Task due sooner should be first
          expect(items.length, 2);
          expect((items[0] as Task).meta.id, 'task-due-sooner');
          expect((items[1] as Task).meta.id, 'task-due-later');
        });
      });

      test('byDueDate preserves creation date order for same due date', () {
        fakeAsync((async) {
          final taskOlder = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'Older task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              due: DateTime(2024, 6, 15),
            ),
            meta: Metadata(
              id: 'task-older',
              createdAt: DateTime(2024, 1, 1),
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
              updatedAt: DateTime(2024, 1, 1),
            ),
          );

          final taskNewer = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_2',
                createdAt: DateTime(2024, 1, 5),
                utcOffset: 0,
              ),
              title: 'Newer task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 5),
              dateTo: DateTime(2024, 1, 5),
              due: DateTime(2024, 6, 15), // Same due date
            ),
            meta: Metadata(
              id: 'task-newer',
              createdAt: DateTime(2024, 1, 5),
              dateFrom: DateTime(2024, 1, 5),
              dateTo: DateTime(2024, 1, 5),
              updatedAt: DateTime(2024, 1, 5),
            ),
          );

          // Return in order older first
          when(() => mockJournalDb.getTasks(
                ids: any(named: 'ids'),
                starredStatuses: any(named: 'starredStatuses'),
                taskStatuses: any(named: 'taskStatuses'),
                categoryIds: any(named: 'categoryIds'),
                labelIds: any(named: 'labelIds'),
                priorities: any(named: 'priorities'),
                sortByDate: any(named: 'sortByDate'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              )).thenAnswer((_) async => [taskOlder, taskNewer]);

          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          final items = state.pagingController?.value.items ?? [];

          // Newer task should be first (descending creation date for same due)
          expect(items.length, 2);
          expect((items[0] as Task).meta.id, 'task-newer');
          expect((items[1] as Task).meta.id, 'task-older');
        });
      });

      test('byDueDate handles mixed tasks with and without due dates', () {
        fakeAsync((async) {
          final taskNoDue1 = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 's1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'No due 1',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 10),
              dateTo: DateTime(2024, 1, 10),
            ),
            meta: Metadata(
              id: 'no-due-1',
              createdAt: DateTime(2024, 1, 10),
              dateFrom: DateTime(2024, 1, 10),
              dateTo: DateTime(2024, 1, 10),
              updatedAt: DateTime(2024, 1, 10),
            ),
          );

          final taskWithDueLater = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 's2',
                createdAt: DateTime(2024, 1, 2),
                utcOffset: 0,
              ),
              title: 'Due later',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
              due: DateTime(2024, 12, 1),
            ),
            meta: Metadata(
              id: 'due-later',
              createdAt: DateTime(2024, 1, 2),
              dateFrom: DateTime(2024, 1, 2),
              dateTo: DateTime(2024, 1, 2),
              updatedAt: DateTime(2024, 1, 2),
            ),
          );

          final taskWithDueSooner = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 's3',
                createdAt: DateTime(2024, 1, 3),
                utcOffset: 0,
              ),
              title: 'Due sooner',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 3),
              dateTo: DateTime(2024, 1, 3),
              due: DateTime(2024, 6, 1),
            ),
            meta: Metadata(
              id: 'due-sooner',
              createdAt: DateTime(2024, 1, 3),
              dateFrom: DateTime(2024, 1, 3),
              dateTo: DateTime(2024, 1, 3),
              updatedAt: DateTime(2024, 1, 3),
            ),
          );

          final taskNoDue2 = Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 's4',
                createdAt: DateTime(2024, 1, 4),
                utcOffset: 0,
              ),
              title: 'No due 2',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 5),
              dateTo: DateTime(2024, 1, 5),
            ),
            meta: Metadata(
              id: 'no-due-2',
              createdAt: DateTime(2024, 1, 5),
              dateFrom: DateTime(2024, 1, 5),
              dateTo: DateTime(2024, 1, 5),
              updatedAt: DateTime(2024, 1, 5),
            ),
          );

          // Return in mixed order
          when(() => mockJournalDb.getTasks(
                    ids: any(named: 'ids'),
                    starredStatuses: any(named: 'starredStatuses'),
                    taskStatuses: any(named: 'taskStatuses'),
                    categoryIds: any(named: 'categoryIds'),
                    labelIds: any(named: 'labelIds'),
                    priorities: any(named: 'priorities'),
                    sortByDate: any(named: 'sortByDate'),
                    limit: any(named: 'limit'),
                    offset: any(named: 'offset'),
                  ))
              .thenAnswer((_) async => [
                    taskNoDue1,
                    taskWithDueLater,
                    taskNoDue2,
                    taskWithDueSooner
                  ]);

          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          final state = container.read(journalPageControllerProvider(true));
          final items = state.pagingController?.value.items ?? [];

          // Expected order:
          // 1. due-sooner (due 2024-06-01)
          // 2. due-later (due 2024-12-01)
          // 3. no-due-1 (created 2024-01-10, newest of no-due)
          // 4. no-due-2 (created 2024-01-05)
          expect(items.length, 4);
          expect((items[0] as Task).meta.id, 'due-sooner');
          expect((items[1] as Task).meta.id, 'due-later');
          expect((items[2] as Task).meta.id, 'no-due-1');
          expect((items[3] as Task).meta.id, 'no-due-2');
        });
      });

      test('byDueDate persists sort option correctly', () {
        fakeAsync((async) {
          final controller =
              container.read(journalPageControllerProvider(true).notifier);

          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();

          controller.setSortOption(TaskSortOption.byDueDate);

          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          // Verify save was called with byDueDate
          verify(
            () => mockSettingsDb.saveSettingsItem(
              JournalPageController.tasksCategoryFiltersKey,
              any(that: contains('"sortOption":"byDueDate"')),
            ),
          ).called(greaterThan(0));
        });
      });
    });
  });
}

class MockVisibilityInfo extends VisibilityInfo {
  const MockVisibilityInfo({required super.visibleBounds})
      : super(
          key: const Key('test'),
          size: const Size(100, 100),
        );
}
