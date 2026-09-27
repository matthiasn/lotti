import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/shown_checklist_items.dart';
import 'package:lotti/get_it.dart';

import '../../../database/test_utils.dart';
import '../../../mocks/mocks.dart';

// readShownChecklistItems over a real in-memory JournalDb: the items a
// checklist shows are the live ones whose back-link names it, found through
// JournalDb.checklistItemsNaming and its index, and ordered by its list
// (ADR 0105, specs/tla/ChecklistReplication.tla).

final _date = DateTime(2024, 3, 15);

Metadata _meta(String id, {int day = 15, bool deleted = false}) => Metadata(
  id: id,
  createdAt: _date,
  updatedAt: _date,
  dateFrom: DateTime(2024, 3, day),
  dateTo: DateTime(2024, 3, day),
  deletedAt: deleted ? _date : null,
  vectorClock: const VectorClock({'host': 1}),
);

Checklist _checklist(String id, List<String> items, {bool deleted = false}) =>
    Checklist(
      meta: _meta(id, deleted: deleted),
      data: ChecklistData(
        title: id,
        linkedChecklistItems: items,
        linkedTasks: const ['task'],
      ),
    );

ChecklistItem _item(
  String id,
  List<String> checklists, {
  int day = 15,
  bool deleted = false,
}) => ChecklistItem(
  meta: _meta(id, day: day, deleted: deleted),
  data: ChecklistItemData(
    title: id,
    isChecked: false,
    linkedChecklists: checklists,
  ),
);

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  late JournalDb db;
  late Directory directory;
  final updateNotifications = MockUpdateNotifications();
  final logger = MockDomainLogger();

  setUpAll(() => db = JournalDb(inMemoryDatabase: true));

  setUp(() async {
    directory = setupTestDirectory();
    registerJournalDbTestServices(
      updateNotifications: updateNotifications,
      loggingService: logger,
      documentsDirectory: directory,
    );
    await clearAllTables(db);
  });

  tearDown(() {
    unregisterJournalDbTestServices();
    directory.deleteSync(recursive: true);
  });

  tearDownAll(() async {
    await db.close();
    await getIt.reset();
  });

  Future<void> store(Iterable<JournalEntity> entities) async {
    for (final entity in entities) {
      await db.updateJournalEntity(entity);
    }
  }

  List<String> ids(List<ChecklistItem>? items) => [
    for (final item in items ?? const <ChecklistItem>[]) item.meta.id,
  ];

  test(
    'an item two checklists list is shown by the one it names, and one no '
    'list holds yet by the one it names, after the listed ones',
    () async {
      final first = _checklist('c1', ['a', 'moved', 'b']);
      final second = _checklist('c2', ['moved']);
      await store([
        first,
        second,
        _item('a', ['c1']),
        _item('b', ['c1']),
        // Moved to c2 on another device; c1's unlisting has not arrived.
        _item('moved', ['c2']),
        // Added to c1 on another device; c1's listing has not arrived.
        _item('late', ['c1'], day: 16),
        _item('deleted', ['c1'], deleted: true),
      ]);

      final shown = await readShownChecklistItems(db, [first, second]);

      expect(ids(shown['c1']), ['a', 'b', 'late']);
      expect(ids(shown['c2']), ['moved']);
    },
  );

  test(
    'a deleted checklist shows nothing, and no checklists read nothing',
    () async {
      final deleted = _checklist('c1', ['a'], deleted: true);
      await store([
        _item('a', ['c1']),
      ]);

      expect(await readShownChecklistItems(db, [deleted]), isEmpty);
      expect(await readShownChecklistItems(db, const []), isEmpty);
    },
  );

  test('a listed row that cannot be read is reported and skipped', () async {
    final checklist = _checklist('c1', ['good', 'corrupt']);
    await store([
      checklist,
      _item('good', ['c1']),
      _item('corrupt', ['c1']),
    ]);
    await db.customStatement(
      "UPDATE journal SET serialized = '{not json' WHERE id = 'corrupt'",
    );
    final unreadable = <Object>[];

    final shown = await readShownChecklistItems(
      db,
      [checklist],
      onUnreadable: (error, _) => unreadable.add(error),
    );

    expect(ids(shown['c1']), ['good']);
    expect(unreadable, hasLength(1));
  });

  group('JournalDb.checklistItemsNaming', () {
    test(
      'finds the live items by the first checklist their back-link names',
      () async {
        await store([
          _item('first', ['c1', 'c2']),
          _item('second', ['c2', 'c1']),
          _item('deleted', ['c1'], deleted: true),
          _item('legacy', const []),
        ]);

        expect(
          (await db.checklistItemsNaming(['c1'])).map((i) => i.meta.id),
          ['first'],
        );
        expect(
          (await db.checklistItemsNaming(['c1', 'c2'])).map((i) => i.meta.id),
          unorderedEquals(['first', 'second']),
        );
        expect(await db.checklistItemsNaming(const []), isEmpty);
      },
    );

    test('reads them through idx_journal_checklist_item_home', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM journal '
            "WHERE type = 'ChecklistItem' AND deleted = FALSE "
            'AND json_valid(serialized) '
            r"AND json_extract(serialized, '$.data.linkedChecklists[0]') "
            'IN (?)',
            variables: [Variable.withString('c1')],
          )
          .get();

      expect(
        plan.map((row) => row.read<String>('detail')).join('\n'),
        contains('idx_journal_checklist_item_home'),
      );
    });

    test('skips a row that cannot be read', () async {
      await store([
        _item('good', ['c1']),
        _item('corrupt', ['c1']),
      ]);
      await db.customStatement(
        'UPDATE journal SET serialized = '
        "'{\"data\": {\"linkedChecklists\": [\"c1\"]}}' WHERE id = 'corrupt'",
      );

      expect(
        (await db.checklistItemsNaming(['c1'])).map((i) => i.meta.id),
        ['good'],
      );
    });
  });
}
