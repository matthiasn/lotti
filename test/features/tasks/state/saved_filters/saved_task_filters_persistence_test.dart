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
  });
}
