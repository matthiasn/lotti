// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

const _sampleFilter = TasksFilter(
  selectedCategoryIds: {'cat-1'},
  selectedProjectIds: <String>{},
  selectedTaskStatuses: {'IN_PROGRESS'},
  selectedLabelIds: <String>{},
  selectedPriorities: {'P0', 'P1'},
  sortOption: TaskSortOption.byPriority,
  showCreationDate: false,
  showDueDate: true,
  showCoverArt: true,
  showDistances: false,
  agentAssignmentFilter: AgentAssignmentFilter.all,
);

const _saved = [
  SavedTaskFilter(
    id: 'sv-1',
    name: 'In progress · P0–P1',
    filter: _sampleFilter,
  ),
  SavedTaskFilter(
    id: 'sv-2',
    name: 'No agent assigned',
    filter: TasksFilter(agentAssignmentFilter: AgentAssignmentFilter.noAgent),
  ),
];

void main() {
  late MockSettingsDb mockSettingsDb;
  late SavedTaskFiltersPersistence sut;

  setUp(() {
    mockSettingsDb = MockSettingsDb();
    sut = SavedTaskFiltersPersistence(mockSettingsDb);

    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });

  group('storageKey', () {
    test('has expected canonical value', () {
      expect(SavedTaskFiltersPersistence.storageKey, 'SAVED_TASK_FILTERS');
    });
  });

  group('load', () {
    test('returns empty list when nothing is stored', () {
      fakeAsync((async) {
        List<SavedTaskFilter>? result;
        sut.load().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isEmpty);
        verify(
          () => mockSettingsDb.itemByKey(
            SavedTaskFiltersPersistence.storageKey,
          ),
        ).called(1);
      });
    });

    test('decodes a persisted ordered list of saved filters', () {
      fakeAsync((async) {
        final stored = jsonEncode(
          _saved.map((e) => e.toJson()).toList(growable: false),
        );
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => stored);

        List<SavedTaskFilter>? result;
        sut.load().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, hasLength(2));
        expect(result![0].id, 'sv-1');
        expect(result![0].name, 'In progress · P0–P1');
        expect(result![0].filter.selectedPriorities, {'P0', 'P1'});
        expect(
          result![1].filter.agentAssignmentFilter,
          AgentAssignmentFilter.noAgent,
        );
      });
    });

    test('returns empty list when stored payload is malformed', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => '{not-json');

        List<SavedTaskFilter>? result;
        sut.load().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isEmpty);
      });
    });

    test('drops only the entries it cannot decode', () {
      fakeAsync((async) {
        final stored = jsonEncode([
          _saved[0].toJson(),
          {'id': 'broken'},
          _saved[1].toJson(),
        ]);
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => stored);

        List<SavedTaskFilter>? result;
        sut.load().then((v) => result = v);
        async.flushMicrotasks();

        expect(result!.map((f) => f.id), ['sv-1', 'sv-2']);
      });
    });
  });

  group('ledger', () {
    test('is null when this device never wrote one', () {
      fakeAsync((async) {
        SavedTaskFilterSyncLedger? result = const SavedTaskFilterSyncLedger();
        sut.loadLedger().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
        verify(
          () => mockSettingsDb.itemByKey(SavedTaskFiltersPersistence.ledgerKey),
        ).called(1);
      });
    });

    test('round-trips owed ids and tombstones', () {
      fakeAsync((async) {
        final deletedAt = DateTime.utc(2024, 3, 15, 12, 30);
        sut.saveLedger(
          SavedTaskFilterSyncLedger(
            pending: const {'sv-2', 'sv-1'},
            tombstones: {'sv-9': deletedAt},
          ),
        );
        async.flushMicrotasks();
        final written =
            verify(
                  () => mockSettingsDb.saveSettingsItem(
                    SavedTaskFiltersPersistence.ledgerKey,
                    captureAny(),
                  ),
                ).captured.single
                as String;
        expect(jsonDecode(written), {
          'pending': ['sv-1', 'sv-2'],
          'tombstones': {'sv-9': '2024-03-15T12:30:00.000Z'},
        });

        when(
          () => mockSettingsDb.itemByKey(SavedTaskFiltersPersistence.ledgerKey),
        ).thenAnswer((_) async => written);
        SavedTaskFilterSyncLedger? result;
        sut.loadLedger().then((v) => result = v);
        async.flushMicrotasks();

        expect(result!.pending, {'sv-1', 'sv-2'});
        expect(result!.tombstones, {'sv-9': deletedAt});
      });
    });

    test('reads an unreadable ledger as missing', () {
      fakeAsync((async) {
        when(
          () => mockSettingsDb.itemByKey(SavedTaskFiltersPersistence.ledgerKey),
        ).thenAnswer((_) async => '{"tombstones": {"sv-1": "not a date"}}');

        SavedTaskFilterSyncLedger? result = const SavedTaskFilterSyncLedger();
        sut.loadLedger().then((v) => result = v);
        async.flushMicrotasks();

        expect(result, isNull);
      });
    });

    test('reads absent fields as empty', () {
      final ledger = SavedTaskFilterSyncLedger.fromJson(const {});

      expect(ledger.pending, isEmpty);
      expect(ledger.tombstones, isEmpty);
    });
  });

  group('save', () {
    test('encodes the list as a JSON array preserving order', () {
      fakeAsync((async) {
        sut.save(_saved);
        async.flushMicrotasks();

        final captured = verify(
          () => mockSettingsDb.saveSettingsItem(
            SavedTaskFiltersPersistence.storageKey,
            captureAny(),
          ),
        ).captured;

        expect(captured, hasLength(1));
        final decoded = jsonDecode(captured.first as String) as List<dynamic>;
        expect(decoded, hasLength(2));
        expect(
          (decoded[0] as Map<String, dynamic>)['id'],
          'sv-1',
        );
        expect(
          (decoded[1] as Map<String, dynamic>)['name'],
          'No agent assigned',
        );
      });
    });

    test('writes empty array when list is empty', () {
      fakeAsync((async) {
        sut.save(const <SavedTaskFilter>[]);
        async.flushMicrotasks();

        final captured = verify(
          () => mockSettingsDb.saveSettingsItem(
            SavedTaskFiltersPersistence.storageKey,
            captureAny(),
          ),
        ).captured;

        expect(captured, hasLength(1));
        expect(captured.first, '[]');
      });
    });

    test('skips write when encoded value matches the loaded value', () {
      fakeAsync((async) {
        final stored = jsonEncode(
          _saved.map((e) => e.toJson()).toList(growable: false),
        );
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => stored);

        sut.load();
        async.flushMicrotasks();

        sut.save(_saved);
        async.flushMicrotasks();

        verifyNever(
          () => mockSettingsDb.saveSettingsItem(any(), any()),
        );
      });
    });

    test('writes when list differs from loaded value', () {
      fakeAsync((async) {
        final stored = jsonEncode(
          _saved.take(1).map((e) => e.toJson()).toList(growable: false),
        );
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => stored);

        sut.load();
        async.flushMicrotasks();

        sut.save(_saved);
        async.flushMicrotasks();

        verify(
          () => mockSettingsDb.saveSettingsItem(
            SavedTaskFiltersPersistence.storageKey,
            any(),
          ),
        ).called(1);
      });
    });

    test('fetches DB value when saving without a prior load', () {
      fakeAsync((async) {
        sut.save(_saved);
        async.flushMicrotasks();

        verify(
          () => mockSettingsDb.itemByKey(
            SavedTaskFiltersPersistence.storageKey,
          ),
        ).called(1);
        verify(
          () => mockSettingsDb.saveSettingsItem(
            SavedTaskFiltersPersistence.storageKey,
            any(),
          ),
        ).called(1);
      });
    });

    test(
      'skips write when DB value normalizes to the same encoding (no prior '
      'load)',
      () {
        fakeAsync((async) {
          // Stored payload is a re-encoded (key-reordered) variant of _saved.
          // _normalize must round-trip it through SavedTaskFilter so the
          // canonical encoding matches what save() produces, suppressing the
          // redundant DB write.
          final reordered = _saved
              .map((e) {
                final json = e.toJson();
                return {
                  'filter': json['filter'],
                  'name': json['name'],
                  'id': json['id'],
                };
              })
              .toList(growable: false);
          when(
            () => mockSettingsDb.itemByKey(any()),
          ).thenAnswer((_) async => jsonEncode(reordered));

          // No load() — save() must call _normalize on the stored value.
          sut.save(_saved);
          async.flushMicrotasks();

          verify(
            () => mockSettingsDb.itemByKey(
              SavedTaskFiltersPersistence.storageKey,
            ),
          ).called(1);
          verifyNever(
            () => mockSettingsDb.saveSettingsItem(any(), any()),
          );
        });
      },
    );

    test('writes when DB value normalizes to a different encoding (no prior '
        'load)', () {
      fakeAsync((async) {
        // Decodable stored value that holds only the first filter; the saved
        // list has two, so the normalized encoding differs and a write occurs.
        final stored = jsonEncode(
          _saved.take(1).map((e) => e.toJson()).toList(growable: false),
        );
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => stored);

        sut.save(_saved);
        async.flushMicrotasks();

        final captured = verify(
          () => mockSettingsDb.saveSettingsItem(
            SavedTaskFiltersPersistence.storageKey,
            captureAny(),
          ),
        ).captured;
        final decoded = jsonDecode(captured.single as String) as List<dynamic>;
        expect(decoded, hasLength(2));
        expect((decoded[1] as Map<String, dynamic>)['id'], 'sv-2');
      });
    });

    test('treats malformed DB value as raw and writes when it differs (no '
        'prior load)', () {
      fakeAsync((async) {
        // Malformed JSON exercises the catch branch in _normalize: the raw
        // string is kept verbatim, never equals the encoded filters, so save
        // proceeds with a write.
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => '{not-json');

        sut.save(_saved);
        async.flushMicrotasks();

        verify(
          () => mockSettingsDb.saveSettingsItem(
            SavedTaskFiltersPersistence.storageKey,
            any(),
          ),
        ).called(1);
      });
    });
  });
}
