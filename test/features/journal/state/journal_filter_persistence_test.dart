// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_filter_persistence.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSettingsDb mockSettingsDb;
  late JournalFilterPersistence sut;

  setUp(() {
    mockSettingsDb = MockSettingsDb();
    sut = JournalFilterPersistence(mockSettingsDb);

    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });

  group('selectedEntryTypesKey', () {
    test('has expected value', () {
      expect(
        JournalFilterPersistence.selectedEntryTypesKey,
        'SELECTED_ENTRY_TYPES',
      );
    });
  });

  group('loadFilters', () {
    test('returns null when nothing is stored', () {
      fakeAsync((async) {
        TasksFilter? result;
        sut.loadFilters('test-key').then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
        verify(() => mockSettingsDb.itemByKey('test-key')).called(1);
      });
    });

    test('decodes persisted JSON correctly', () {
      fakeAsync((async) {
        final storedJson = jsonEncode(<String, dynamic>{
          'selectedCategoryIds': ['cat-1', 'cat-2'],
          'selectedProjectIds': ['proj-1'],
          'selectedTaskStatuses': ['IN_PROGRESS'],
          'selectedLabelIds': <String>[],
          'selectedPriorities': ['P1'],
          'sortOption': 'byDate',
          'showCreationDate': true,
          'showDueDate': false,
          'showCoverArt': false,
          'showDistances': true,
          'agentAssignmentFilter': 'hasAgent',
        });

        when(
          () => mockSettingsDb.itemByKey('task-filter-key'),
        ).thenAnswer((_) async => storedJson);

        late TasksFilter? result;
        sut.loadFilters('task-filter-key').then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNotNull);
        expect(result!.selectedCategoryIds, {'cat-1', 'cat-2'});
        expect(result!.selectedProjectIds, {'proj-1'});
        expect(result!.selectedTaskStatuses, {'IN_PROGRESS'});
        expect(result!.selectedLabelIds, <String>{});
        expect(result!.selectedPriorities, {'P1'});
        expect(result!.sortOption, TaskSortOption.byDate);
        expect(result!.showCreationDate, isTrue);
        expect(result!.showDueDate, isFalse);
        expect(result!.showCoverArt, isFalse);
        expect(result!.showDistances, isTrue);
        expect(result!.agentAssignmentFilter, AgentAssignmentFilter.hasAgent);
      });
    });

    test('handles malformed JSON gracefully and returns null', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey('bad-key'),
        ).thenAnswer((_) async => 'not-valid-json{{{');

        late TasksFilter? result;
        sut.loadFilters('bad-key').then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
      });
    });

    test('handles JSON that is valid but not a Map gracefully', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey('array-key'),
        ).thenAnswer((_) async => '["a","b"]');

        late TasksFilter? result;
        sut.loadFilters('array-key').then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
      });
    });
  });

  group('loadEntryTypes', () {
    test('returns null when nothing is stored', () {
      fakeAsync((async) {
        Set<String>? result;
        sut.loadEntryTypes().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
        verify(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.selectedEntryTypesKey,
          ),
        ).called(1);
      });
    });

    test('decodes persisted JSON correctly', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.selectedEntryTypesKey,
          ),
        ).thenAnswer((_) async => '["Task","JournalEntry","JournalAudio"]');

        late Set<String>? result;
        sut.loadEntryTypes().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, {'Task', 'JournalEntry', 'JournalAudio'});
      });
    });

    test('returns null when key is missing (default stub)', () {
      fakeAsync((async) {
        // Default stub already returns null for any key.
        late Set<String>? result;
        sut.loadEntryTypes().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
      });
    });

    test('handles malformed JSON gracefully and returns null', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.selectedEntryTypesKey,
          ),
        ).thenAnswer((_) async => 'not valid json');

        late Set<String>? result;
        sut.loadEntryTypes().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
      });
    });
  });

  group('saveFilters', () {
    const filterKey = 'my-filter-key';

    const filter = TasksFilter(
      selectedCategoryIds: {'cat-b', 'cat-a'},
      selectedProjectIds: {'proj-1'},
      selectedTaskStatuses: {'DONE'},
      selectedLabelIds: <String>{},
      selectedPriorities: {'P0', 'P2'},
      sortOption: TaskSortOption.byDueDate,
      showCreationDate: true,
      showDueDate: false,
      showCoverArt: true,
      showDistances: false,
      agentAssignmentFilter: AgentAssignmentFilter.noAgent,
    );

    test('saves encoded filter JSON to settings', () {
      fakeAsync((async) {
        sut.saveFilters(filter, filterKey);
        async.flushMicrotasks();

        final captured = verify(
          () => mockSettingsDb.saveSettingsItem(filterKey, captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final savedJson =
            jsonDecode(captured.first as String) as Map<String, dynamic>;

        // Verify the encoded JSON has sorted arrays and correct values.
        expect(savedJson['selectedCategoryIds'], ['cat-a', 'cat-b']);
        expect(savedJson['selectedProjectIds'], ['proj-1']);
        expect(savedJson['selectedTaskStatuses'], ['DONE']);
        expect(savedJson['selectedLabelIds'], <String>[]);
        expect(savedJson['selectedPriorities'], ['P0', 'P2']);
        expect(savedJson['sortOption'], 'byDueDate');
        expect(savedJson['showCreationDate'], true);
        expect(savedJson['showDueDate'], false);
        expect(savedJson['showCoverArt'], true);
        expect(savedJson['showDistances'], false);
        expect(savedJson['agentAssignmentFilter'], 'noAgent');
      });
    });

    test('skips write when value is unchanged after loadFilters', () {
      fakeAsync((async) {
        // First, load persisted state that matches the filter we will save.
        final storedJson = jsonEncode(<String, dynamic>{
          'selectedCategoryIds': ['cat-a', 'cat-b'],
          'selectedProjectIds': ['proj-1'],
          'selectedTaskStatuses': ['DONE'],
          'selectedLabelIds': <String>[],
          'selectedPriorities': ['P0', 'P2'],
          'sortOption': 'byDueDate',
          'showCreationDate': true,
          'showDueDate': false,
          'showCoverArt': true,
          'showDistances': false,
          'agentAssignmentFilter': 'noAgent',
        });

        when(
          () => mockSettingsDb.itemByKey(filterKey),
        ).thenAnswer((_) async => storedJson);

        // Load first to seed the dedup state.
        sut.loadFilters(filterKey);
        async.flushMicrotasks();

        // Now save the same filter — should skip.
        sut.saveFilters(filter, filterKey);
        async.flushMicrotasks();

        verifyNever(
          () => mockSettingsDb.saveSettingsItem(any(), any()),
        );
      });
    });

    test('writes when value differs from loaded state', () {
      fakeAsync((async) {
        // Load an empty filter first.
        final emptyJson = jsonEncode(<String, dynamic>{
          'selectedCategoryIds': <String>[],
          'selectedProjectIds': <String>[],
          'selectedTaskStatuses': <String>[],
          'selectedLabelIds': <String>[],
          'selectedPriorities': <String>[],
          'sortOption': 'byPriority',
          'showCreationDate': false,
          'showDueDate': true,
          'showCoverArt': true,
          'showDistances': false,
          'agentAssignmentFilter': 'all',
        });

        when(
          () => mockSettingsDb.itemByKey(filterKey),
        ).thenAnswer((_) async => emptyJson);

        sut.loadFilters(filterKey);
        async.flushMicrotasks();

        // Save a different filter — should write.
        sut.saveFilters(filter, filterKey);
        async.flushMicrotasks();

        verify(
          () => mockSettingsDb.saveSettingsItem(filterKey, any()),
        ).called(1);
      });
    });

    test('fetches current value from DB when saving without prior load', () {
      fakeAsync((async) {
        // Never called loadFilters — saveFilters should read first.
        sut.saveFilters(filter, filterKey);
        async.flushMicrotasks();

        // itemByKey called once to seed dedup, then saveSettingsItem once.
        verify(() => mockSettingsDb.itemByKey(filterKey)).called(1);
        verify(
          () => mockSettingsDb.saveSettingsItem(filterKey, any()),
        ).called(1);
      });
    });

    test('proceeds when DB contains malformed JSON for tasks filter', () {
      fakeAsync((async) {
        // Stub returns malformed JSON that is not a valid Map.
        when(
          () => mockSettingsDb.itemByKey(filterKey),
        ).thenAnswer((_) async => '[not a map]');

        // saveFilters without prior loadFilters — seeds dedup via
        // _normalizeTasksFilterValue, which catches and returns raw value.
        sut.saveFilters(filter, filterKey);
        async.flushMicrotasks();

        // The normalize catch returns the raw malformed string, which differs
        // from the encoded filter, so a write should occur.
        verify(
          () => mockSettingsDb.saveSettingsItem(filterKey, any()),
        ).called(1);
      });
    });

    test(
      'saves two different keys independently without cross-key leakage',
      () {
        fakeAsync((async) {
          const keyA = 'TASKS_FILTERS';
          const keyB = 'JOURNAL_FILTERS';

          const filterA = TasksFilter(
            selectedCategoryIds: {'cat-a'},
            selectedTaskStatuses: {'OPEN'},
          );
          const filterB = TasksFilter(
            selectedCategoryIds: {'cat-b'},
            selectedTaskStatuses: {'DONE'},
          );

          // Save filter A under keyA.
          sut.saveFilters(filterA, keyA);
          async.flushMicrotasks();

          // Save filter B under keyB — should NOT reuse keyA's cached snapshot.
          sut.saveFilters(filterB, keyB);
          async.flushMicrotasks();

          // Both keys should have been written.
          verify(
            () => mockSettingsDb.saveSettingsItem(keyA, any()),
          ).called(1);
          verify(
            () => mockSettingsDb.saveSettingsItem(keyB, any()),
          ).called(1);
        });
      },
    );
  });

  group('saveEntryTypes', () {
    final entryTypes = {'Task', 'JournalEntry'};

    test('saves encoded entry types', () {
      fakeAsync((async) {
        sut.saveEntryTypes(entryTypes);
        async.flushMicrotasks();

        final captured = verify(
          () => mockSettingsDb.saveSettingsItem(
            JournalFilterPersistence.selectedEntryTypesKey,
            captureAny(),
          ),
        ).captured;

        expect(captured, hasLength(1));
        final savedList = jsonDecode(captured.first as String) as List<dynamic>;

        // Values should be sorted.
        expect(savedList, ['JournalEntry', 'Task']);
      });
    });

    test('skips write when value is unchanged after loadEntryTypes', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.selectedEntryTypesKey,
          ),
        ).thenAnswer((_) async => '["JournalEntry","Task"]');

        // Load first to seed the dedup state.
        sut.loadEntryTypes();
        async.flushMicrotasks();

        // Save the same set — should skip.
        sut.saveEntryTypes(entryTypes);
        async.flushMicrotasks();

        verifyNever(
          () => mockSettingsDb.saveSettingsItem(any(), any()),
        );
      });
    });

    test('writes when value differs from loaded state', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.selectedEntryTypesKey,
          ),
        ).thenAnswer((_) async => '["Task"]');

        sut.loadEntryTypes();
        async.flushMicrotasks();

        // Save a different set.
        sut.saveEntryTypes(entryTypes);
        async.flushMicrotasks();

        verify(
          () => mockSettingsDb.saveSettingsItem(
            JournalFilterPersistence.selectedEntryTypesKey,
            any(),
          ),
        ).called(1);
      });
    });

    test('proceeds when DB contains malformed JSON for entry types', () {
      fakeAsync((async) {
        // Stub returns malformed JSON that is not a valid List.
        when(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.selectedEntryTypesKey,
          ),
        ).thenAnswer((_) async => '{not a list}');

        // saveEntryTypes without prior loadEntryTypes — seeds dedup via
        // _normalizeEntryTypesValue, which catches and returns raw value.
        sut.saveEntryTypes(entryTypes);
        async.flushMicrotasks();

        // The normalize catch returns the raw malformed string, which differs
        // from the encoded entry types, so a write should occur.
        verify(
          () => mockSettingsDb.saveSettingsItem(
            JournalFilterPersistence.selectedEntryTypesKey,
            any(),
          ),
        ).called(1);
      });
    });
  });

  group('encoding normalization', () {
    test(
      'normalized filter values compare equal regardless of original key order',
      () {
        fakeAsync((async) {
          const filterKey = 'norm-key';

          // Store JSON with keys in non-standard order and unsorted arrays.
          final storedJson = jsonEncode(<String, dynamic>{
            'showDueDate': false,
            'sortOption': 'byPriority',
            'selectedCategoryIds': ['z-cat', 'a-cat'],
            'selectedProjectIds': <String>[],
            'selectedTaskStatuses': <String>[],
            'selectedLabelIds': <String>[],
            'selectedPriorities': <String>[],
            'showCreationDate': false,
            'showCoverArt': true,
            'showDistances': false,
            'agentAssignmentFilter': 'all',
          });

          when(
            () => mockSettingsDb.itemByKey(filterKey),
          ).thenAnswer((_) async => storedJson);

          // Load to seed dedup state (normalizes the stored value).
          sut.loadFilters(filterKey);
          async.flushMicrotasks();

          // Save the semantically identical filter built programmatically.
          const filter = TasksFilter(
            selectedCategoryIds: {'a-cat', 'z-cat'},
            showDueDate: false,
          );

          sut.saveFilters(filter, filterKey);
          async.flushMicrotasks();

          // Should skip the write because normalization makes them equal.
          verifyNever(
            () => mockSettingsDb.saveSettingsItem(any(), any()),
          );
        });
      },
    );

    test(
      'normalized entry-type values compare equal regardless of original order',
      () {
        fakeAsync((async) {
          when(
            () => mockSettingsDb.itemByKey(
              JournalFilterPersistence.selectedEntryTypesKey,
            ),
          ).thenAnswer((_) async => '["Task","JournalEntry"]');

          sut.loadEntryTypes();
          async.flushMicrotasks();

          // Save in the opposite order.
          sut.saveEntryTypes({'JournalEntry', 'Task'});
          async.flushMicrotasks();

          verifyNever(
            () => mockSettingsDb.saveSettingsItem(any(), any()),
          );
        });
      },
    );
  });
}
