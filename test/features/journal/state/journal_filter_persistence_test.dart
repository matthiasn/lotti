// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_filter_persistence.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
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
        when(
          () => mockSettingsDb.itemByKey(
            JournalFilterPersistence.reconciledEntryTypesKey,
          ),
        ).thenAnswer((_) async => jsonEncode(entryTypes));

        late Set<String>? result;
        sut.loadEntryTypes().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, {'Task', 'JournalEntry', 'JournalAudio'});
      });
    });

    // A type the filter gained after the selection was saved is one the user
    // never had the chance to deselect. It stays pending — the controller
    // adds it once the filter offers it — and a save records what was on
    // offer, so a later deselection sticks (ADR 0064).
    group('a type added since the selection was saved', () {
      void stubReconciled(String? raw) => when(
        () => mockSettingsDb.itemByKey(
          JournalFilterPersistence.reconciledEntryTypesKey,
        ),
      ).thenAnswer((_) async => raw);

      test('the stored selection loads as it was — nothing is added behind '
          "the filter's back", () {
        fakeAsync((async) {
          when(
            () => mockSettingsDb.itemByKey(
              JournalFilterPersistence.selectedEntryTypesKey,
            ),
          ).thenAnswer((_) async => jsonEncode(['JournalEntry', 'Task']));

          late Set<String>? result;
          sut.loadEntryTypes().then((v) => result = v);
          async.flushMicrotasks();

          expect(result, {'Task', 'JournalEntry'});
          verifyNever(() => mockSettingsDb.saveSettingsItem(any(), any()));
        });
      });

      for (final (label, raw) in [
        ('saved before the record existed', null),
        ('with a malformed record', 'not json'),
      ]) {
        test('CheckIn is pending for a selection $label', () {
          fakeAsync((async) {
            stubReconciled(raw);

            late Set<String> pending;
            sut.loadPendingEntryTypes().then((v) => pending = v);
            async.flushMicrotasks();

            expect(pending, {'CheckIn'});
          });
        });
      }

      test('nothing is pending once every type was on offer', () {
        fakeAsync((async) {
          stubReconciled(jsonEncode(entryTypes));

          late Set<String> pending;
          sut.loadPendingEntryTypes().then((v) => pending = v);
          async.flushMicrotasks();

          expect(pending, isEmpty);
        });
      });

      test('a save records the types on offer, and a type not on offer stays '
          'pending', () {
        fakeAsync((async) {
          sut.saveEntryTypes({'Task'}, offered: {'Task', 'JournalEntry'});
          async.flushMicrotasks();

          // Everything on offer was already on the record: nothing to add.
          verifyNever(
            () => mockSettingsDb.saveSettingsItem(
              JournalFilterPersistence.reconciledEntryTypesKey,
              any(),
            ),
          );
          late Set<String> pending;
          sut.loadPendingEntryTypes().then((v) => pending = v);
          async.flushMicrotasks();
          expect(pending, {'CheckIn'}, reason: 'CheckIn was not on offer');

          sut.saveEntryTypes({'Task'}, offered: {'Task', 'CheckIn'});
          async.flushMicrotasks();

          verify(
            () => mockSettingsDb.saveSettingsItem(
              JournalFilterPersistence.reconciledEntryTypesKey,
              jsonEncode(
                [
                  ...JournalFilterPersistence.legacyReconciledEntryTypes,
                  'CheckIn',
                ]..sort(),
              ),
            ),
          ).called(1);
          sut.loadPendingEntryTypes().then((v) => pending = v);
          async.flushMicrotasks();
          expect(pending, isEmpty, reason: 'deselected on offer: it sticks');
        });
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

    test('skips the write when the stored value is the same filter in a '
        'different key and element order', () {
      fakeAsync((async) {
        // Same filter as [filter], but unsorted arrays and shuffled keys —
        // normalisation must treat it as unchanged.
        final storedJson = jsonEncode(<String, dynamic>{
          'agentAssignmentFilter': 'noAgent',
          'selectedPriorities': ['P2', 'P0'],
          'selectedCategoryIds': ['cat-b', 'cat-a'],
          'selectedProjectIds': ['proj-1'],
          'selectedTaskStatuses': ['DONE'],
          'selectedLabelIds': <String>[],
          'sortOption': 'byDueDate',
          'showCreationDate': true,
          'showDueDate': false,
          'showCoverArt': true,
          'showDistances': false,
        });
        when(
          () => mockSettingsDb.itemByKey(filterKey),
        ).thenAnswer((_) async => storedJson);

        sut.saveFilters(filter, filterKey);
        async.flushMicrotasks();

        verify(() => mockSettingsDb.itemByKey(filterKey)).called(1);
        verifyNever(() => mockSettingsDb.saveSettingsItem(any(), any()));
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
    const selectedEntryTypesKey =
        JournalFilterPersistence.selectedEntryTypesKey;

    test('skips the write when the stored set only differs in order', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(selectedEntryTypesKey),
        ).thenAnswer((_) async => jsonEncode(['Task', 'JournalEntry']));

        sut.saveEntryTypes({'JournalEntry', 'Task'}, offered: const {});
        async.flushMicrotasks();

        verifyNever(
          () => mockSettingsDb.saveSettingsItem(selectedEntryTypesKey, any()),
        );
      });
    });

    test('writes the sorted set once and dedups the repeat', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(selectedEntryTypesKey),
        ).thenAnswer((_) async => 'not json');

        sut.saveEntryTypes({'Task', 'JournalEntry'}, offered: const {});
        async.flushMicrotasks();
        sut.saveEntryTypes({'JournalEntry', 'Task'}, offered: const {});
        async.flushMicrotasks();

        verify(
          () => mockSettingsDb.saveSettingsItem(
            selectedEntryTypesKey,
            jsonEncode(['JournalEntry', 'Task']),
          ),
        ).called(1);
        verify(() => mockSettingsDb.itemByKey(selectedEntryTypesKey)).called(1);
      });
    });
  });
}
