import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/journal/state/journal_filter_persistence.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'journal_filter_persistence_test_helpers.dart';

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

  group('round-trip (Glados)', () {
    glados.Glados<TasksFilter>(
      glados.any.tasksFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'saveFilters then loadFilters reproduces an equal filter',
      (filter) {
        fakeAsync((async) {
          const key = 'rt-key';
          // Map-backed settings store so save actually persists and load reads
          // it back through the real encode/decode pipeline.
          final store = <String, String>{};
          final db = MockSettingsDb();
          when(() => db.itemByKey(any())).thenAnswer(
            (invocation) async =>
                store[invocation.positionalArguments.first as String],
          );
          when(() => db.saveSettingsItem(any(), any())).thenAnswer((
            invocation,
          ) async {
            store[invocation.positionalArguments[0] as String] =
                invocation.positionalArguments[1] as String;
            return 1;
          });

          final persistence = JournalFilterPersistence(db)
            ..saveFilters(filter, key);
          async.flushMicrotasks();

          TasksFilter? loaded;
          persistence.loadFilters(key).then((v) => loaded = v);
          async.flushMicrotasks();

          expect(loaded, equals(filter), reason: 'round-trip for $filter');
        });
      },
      tags: 'glados',
    );

    glados.Glados<TasksFilter>(
      glados.any.tasksFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'encode is idempotent: a saved filter round-trips without a second write',
      (filter) {
        fakeAsync((async) {
          const key = 'idem-key';
          final store = <String, String>{};
          final db = MockSettingsDb();
          when(() => db.itemByKey(any())).thenAnswer(
            (invocation) async =>
                store[invocation.positionalArguments.first as String],
          );
          var writeCount = 0;
          when(() => db.saveSettingsItem(any(), any())).thenAnswer((
            invocation,
          ) async {
            writeCount++;
            store[invocation.positionalArguments[0] as String] =
                invocation.positionalArguments[1] as String;
            return 1;
          });

          JournalFilterPersistence(db).saveFilters(filter, key);
          async.flushMicrotasks();
          expect(writeCount, 1, reason: 'first save persists $filter');

          // A fresh persistence instance loads the encoded value (seeding its
          // dedup snapshot) and then saving the same filter must be a no-op,
          // proving the encoded form is stable across the load path.
          final reloaded = JournalFilterPersistence(db);
          TasksFilter? loaded;
          reloaded.loadFilters(key).then((v) => loaded = v);
          async.flushMicrotasks();
          expect(loaded, equals(filter));

          reloaded.saveFilters(filter, key);
          async.flushMicrotasks();
          expect(
            writeCount,
            1,
            reason: 'no redundant write after reload for $filter',
          );
        });
      },
      tags: 'glados',
    );
  });
}
