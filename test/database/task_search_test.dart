import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/search_hit.dart';
import 'package:lotti/database/task_search.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import 'test_utils.dart';

final _at = DateTime(2024, 3, 15, 9);

Metadata _meta(String id) => Metadata(
  id: id,
  createdAt: _at,
  updatedAt: _at,
  dateFrom: _at,
  dateTo: _at,
);

JournalEntity _task(String id, String title) => testTask.copyWith(
  meta: _meta(id),
  data: testTask.data.copyWith(title: title),
  entryText: const EntryText(plainText: ''),
);

JournalEntity _entry(String id, String text) => JournalEntity.journalEntry(
  meta: _meta(id),
  entryText: EntryText(plainText: text),
);

void main() {
  late JournalDb journalDb;
  late Fts5Db fts;
  late Directory documents;

  setUpAll(registerJournalDbTestFallbacks);

  setUp(() async {
    documents = setupTestDirectory();
    registerJournalDbTestServices(
      updateNotifications: MockUpdateNotifications(),
      loggingService: MockDomainLogger(),
      documentsDirectory: documents,
    );
    final cache = MockEntitiesCacheService();
    when(() => cache.getDataTypeById(any())).thenReturn(null);
    getIt.registerSingleton<EntitiesCacheService>(cache);
    journalDb = JournalDb(inMemoryDatabase: true);
    fts = Fts5Db(inMemoryDatabase: true);
    await fts.catchUp(journalDb);
  });

  tearDown(() async {
    await fts.close();
    await journalDb.close();
    await getIt.reset();
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  Future<void> store(List<JournalEntity> entities) async {
    for (final entity in entities) {
      await journalDb.upsertJournalDbEntity(toDbEntity(entity));
    }
    await fts.indexEntities(entities);
  }

  Future<void> link(String fromId, String toId) => journalDb.upsertEntryLink(
    EntryLink.basic(
      id: 'link-$fromId-$toId',
      fromId: fromId,
      toId: toId,
      createdAt: _at,
      updatedAt: _at,
      vectorClock: null,
    ),
  );

  Future<List<String>> found(String query) async => [
    for (final hit in await searchTasks(
      fts5Db: fts,
      journalDb: journalDb,
      query: query,
      includePrivate: true,
    ))
      hit.taskId,
  ];

  test('a task is found by its own text, by an entry linked from it, and by '
      'an item of its checklist, best match first', () async {
    await store([
      _task('own', 'Krill run'),
      _task('linked', 'Colony diary'),
      _entry('diary-note', 'saw a swarm of krill near the shelf'),
      _task('checklist-task', 'Feeder rota'),
      JournalEntity.checklist(
        meta: _meta('checklist'),
        data: const ChecklistData(
          title: 'Morning feed',
          linkedChecklistItems: ['item'],
          linkedTasks: ['checklist-task'],
        ),
      ),
      JournalEntity.checklistItem(
        meta: _meta('item'),
        data: const ChecklistItemData(
          title: 'Refill the krill tubs',
          isChecked: false,
          linkedChecklists: ['checklist'],
        ),
      ),
      _entry('stray', 'krill, linked from nothing'),
    ]);
    await link('linked', 'diary-note');

    final hits = await searchTasks(
      fts5Db: fts,
      journalDb: journalDb,
      query: 'krill',
      includePrivate: true,
    );

    expect(hits.map((h) => h.taskId).toSet(), {
      'own',
      'linked',
      'checklist-task',
    });
    expect(hits.first.taskId, 'own', reason: 'a title match ranks first');
    final byTask = {for (final hit in hits) hit.taskId: hit};
    expect(byTask['linked']!.matchedType, 'JournalEntry');
    expect(byTask['checklist-task']!.matchedType, 'ChecklistItem');
    expect(
      snippetSpans(
        byTask['checklist-task']!.snippet,
      ).where((span) => span.matched).map((span) => span.text.toLowerCase()),
      ['krill'],
    );
  });

  test('a task matched twice keeps its best match', () async {
    await store([
      _task('task-1', 'Krill run'),
      _entry('note', 'notes on krill'),
    ]);
    await link('task-1', 'note');

    final hits = await searchTasks(
      fts5Db: fts,
      journalDb: journalDb,
      query: 'krill',
      includePrivate: true,
    );

    expect(hits, hasLength(1));
    expect(hits.single.matchedType, 'Task');
  });

  test('a checklist that matches counts for the tasks it names', () async {
    await store([
      _task('task-1', 'Morning'),
      JournalEntity.checklist(
        meta: _meta('checklist'),
        data: const ChecklistData(
          title: 'Krill inventory',
          linkedChecklistItems: [],
          linkedTasks: ['task-1'],
        ),
      ),
    ]);

    expect(await found('krill'), ['task-1']);
  });

  test('loose entries outranking a task do not crowd it out: the ranking is '
      'read page by page until enough tasks are found', () async {
    await store([
      for (var i = 0; i < 12; i++) _entry('loose-$i', 'krill'),
      _task('task-1', 'Colony'),
      _entry('long-note', 'a long diary of the colony, the shelf, and krill'),
    ]);
    await link('task-1', 'long-note');

    final hits = await searchTasks(
      fts5Db: fts,
      journalDb: journalDb,
      query: 'krill',
      includePrivate: true,
      limit: 5,
    );

    expect(hits.map((h) => h.taskId), ['task-1']);
  });

  test('at most limit tasks come back', () async {
    await store([for (var i = 0; i < 8; i++) _task('task-$i', 'Krill $i')]);

    final hits = await searchTasks(
      fts5Db: fts,
      journalDb: journalDb,
      query: 'krill',
      includePrivate: true,
      limit: 3,
    );

    expect(hits, hasLength(3));
  });

  test('nothing matching finds no task', () async {
    await store([_task('task-1', 'Morning')]);
    expect(await found('krill'), isEmpty);
  });
}
