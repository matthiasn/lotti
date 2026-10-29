import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/title_search.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import 'test_utils.dart';

final _base = DateTime(2024, 3, 15, 9);

Metadata _meta(
  String id, {
  int minutes = 0,
  String? categoryId,
  bool private = false,
  bool deleted = false,
}) {
  final at = _base.add(Duration(minutes: minutes));
  return Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
    categoryId: categoryId,
    private: private,
    deletedAt: deleted ? at : null,
  );
}

JournalEntity _entry(
  String id,
  String text, {
  int minutes = 0,
  String? categoryId,
  bool private = false,
  bool deleted = false,
}) => JournalEntity.journalEntry(
  meta: _meta(
    id,
    minutes: minutes,
    categoryId: categoryId,
    private: private,
    deleted: deleted,
  ),
  entryText: EntryText(plainText: text),
);

JournalEntity _task(String id, String title, {String body = ''}) =>
    testTask.copyWith(
      meta: _meta(id),
      data: testTask.data.copyWith(title: title),
      entryText: EntryText(plainText: body),
    );

void main() {
  late JournalDb journalDb;
  late Fts5Db fts;
  late Directory documents;
  final updateNotifications = MockUpdateNotifications();
  final logger = MockDomainLogger();

  setUpAll(() {
    registerJournalDbTestFallbacks();
    registerFts5Fallbacks();
  });

  setUp(() async {
    documents = setupTestDirectory();
    registerJournalDbTestServices(
      updateNotifications: updateNotifications,
      loggingService: logger,
      documentsDirectory: documents,
    );
    final cache = MockEntitiesCacheService();
    when(() => cache.getDataTypeById(any())).thenReturn(null);
    getIt.registerSingleton<EntitiesCacheService>(cache);
    journalDb = JournalDb(inMemoryDatabase: true);
    fts = Fts5Db(inMemoryDatabase: true, rebuildBatchSize: 2);
  });

  tearDown(() async {
    await fts.close();
    await journalDb.close();
    await getIt.reset();
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  Future<void> store(Iterable<JournalEntity> entities) async {
    for (final entity in entities) {
      await journalDb.upsertJournalDbEntity(toDbEntity(entity));
    }
  }

  Future<List<String>> search(
    String query, {
    Set<String>? types,
    Set<String>? categoryIds,
    bool includePrivate = true,
    int limit = Fts5Db.defaultMatchLimit,
    bool anyTerm = false,
  }) => fts.matchIds(
    query,
    types: types,
    categoryIds: categoryIds,
    includePrivate: includePrivate,
    limit: limit,
    anyTerm: anyTerm,
  );

  group('catching up with the journal', () {
    test('a new index owes the journal a rebuild, and indexes every live '
        'row in batches', () async {
      await store([
        for (var i = 0; i < 5; i++) _entry('entry-$i', 'krill haul $i'),
        _entry('gone', 'krill haul', deleted: true),
      ]);
      expect(await fts.needsCatchUp(), isTrue);

      final progress = <int>[];
      final indexed = await fts.catchUp(journalDb, onProgress: progress.add);

      expect(indexed, 5);
      expect(progress, [2, 4, 5], reason: 'one report per batch of two');
      expect(await fts.needsCatchUp(), isFalse);
      expect(
        (await search('krill')).toSet(),
        {for (var i = 0; i < 5; i++) 'entry-$i'},
      );
    });

    test(
      'a catch-up stopped between batches resumes where it stopped',
      () async {
        await store([for (var i = 0; i < 5; i++) _entry('entry-$i', 'squid')]);

        var batches = 0;
        final first = await fts.catchUp(
          journalDb,
          shouldContinue: () => batches++ < 1,
        );
        expect(first, 2);
        expect(await fts.needsCatchUp(), isTrue);

        final rest = await fts.catchUp(journalDb);
        expect(rest, 3, reason: 'the first batch is not read again');
        expect(await search('squid'), hasLength(5));
      },
    );

    test('a live edit queued behind a rebuild batch is written after it, so '
        'the batch cannot overwrite it with what it read before', () async {
      final journal = MockJournalDb();
      final batchRead =
          Completer<({List<JournalEntity> entities, int lastRowId})>();
      when(
        () => journal.liveEntitiesAfterRowId(any(), any()),
      ).thenAnswer((_) => batchRead.future);
      when(
        () => journal.getJournalEntitiesForIdsIncludingDeleted(any()),
      ).thenAnswer((_) async => [_entry('entry-1', 'fresh words')]);

      final rebuilding = fts.catchUp(journal);
      await pumpEventQueue();
      final edit = fts.indexByIds(journal, {'entry-1'});
      batchRead.complete((
        entities: [_entry('entry-1', 'stale words')],
        lastRowId: 1,
      ));
      await rebuilding;
      await edit;

      expect(await search('fresh'), ['entry-1']);
      expect(await search('stale'), isEmpty);
    });
  });

  group('indexing by id', () {
    setUp(() => fts.catchUp(journalDb));

    test('a new entry becomes searchable, and an edit replaces what it '
        'said', () async {
      await store([_entry('entry-1', 'emperor colony')]);
      await fts.indexByIds(journalDb, {'entry-1'});
      expect(await search('emperor'), ['entry-1']);

      await store([_entry('entry-1', 'adelie colony')]);
      await fts.indexByIds(journalDb, {'entry-1', 'TEXT_ENTRY'});

      expect(await search('adelie'), ['entry-1']);
      expect(await search('emperor'), isEmpty);
    });

    test('a deleted entry, and an id with no row, leave the index', () async {
      await store([_entry('kept', 'ice'), _entry('deleted', 'ice')]);
      await fts.indexByIds(journalDb, {'kept', 'deleted'});
      await fts.indexEntities([_entry('purged', 'ice')]);
      expect(await search('ice'), hasLength(3));

      await store([_entry('deleted', 'ice', deleted: true)]);
      await fts.indexByIds(journalDb, {'deleted', 'purged'});

      expect(await search('ice'), ['kept']);
    });

    test('an entry whose text is blank is not indexed', () async {
      await store([_entry('blank', '   ')]);
      await fts.indexByIds(journalDb, {'blank'});

      final docs = await fts.select(fts.searchDoc).get();
      expect(docs, isEmpty);
    });
  });

  group('searchTitles', () {
    setUp(() => fts.catchUp(journalDb));

    Future<List<String>> titles(
      String query, {
      Set<String>? types,
      bool includePrivate = true,
    }) async => [
      for (final match in await fts.searchTitles(
        query,
        types: types,
        includePrivate: includePrivate,
      ))
        match.entityId,
    ];

    test('a fragment of a word finds the title, best placed first', () async {
      await fts.indexEntities([
        _task('inside', 'Pre-launch checks'),
        _task('starts', 'Launch day rehearsal'),
        _entry('text-only', 'the launch went well'),
      ]);

      expect(await titles('launch'), ['starts', 'inside']);
      expect(
        (await titles('aunc')).toSet(),
        {'starts', 'inside'},
        reason: 'inside a word, neither starts with it',
      );
    });

    test('the ranking folds exactly the letters the index folds, to the same '
        'base', () async {
      await fts.customStatement(
        'CREATE VIRTUAL TABLE fold_probe USING fts5(title, '
        "tokenize = 'trigram remove_diacritics 1')",
      );
      for (final rune in [
        for (var c = 0xC0; c <= 0x24F; c++) c,
        for (var c = 0x1E00; c <= 0x1EFF; c++) c,
      ]) {
        final letter = String.fromCharCode(rune);
        if (letter.toLowerCase() != letter || letter.toUpperCase() == letter) {
          continue;
        }
        await fts.customStatement(
          'INSERT INTO fold_probe(rowid, title) VALUES (?, ?)',
          [rune, 'q${letter}q'],
        );
      }
      final indexFolds = <String, String>{};
      for (var b = 0x61; b <= 0x7A; b++) {
        final base = String.fromCharCode(b);
        final rows = await fts
            .customSelect(
              'SELECT rowid AS rune FROM fold_probe WHERE fold_probe MATCH ?',
              variables: [Variable.withString('"q${base}q"')],
            )
            .get();
        for (final row in rows) {
          indexFolds[String.fromCharCode(row.read<int>('rune'))] = base;
        }
      }

      expect(foldedLetters, indexFolds);
    });

    test('accents and case do not matter, and do not make a match '
        'fuzzy', () async {
      await fts.indexEntities([
        _task('task-1', 'Pingüine zählen'),
        _task('task-2', 'Úkol'),
      ]);

      final matches = await fts.searchTitles('pinguine');
      expect(matches.map((m) => m.entityId), ['task-1']);
      expect(matches.single.fuzzy, isFalse);
      expect(await titles('ZÄHL'), ['task-1']);
      expect(await titles('ukol'), ['task-2']);
      await fts.indexEntities([_task('task-3', 'Søren')]);
      expect(await titles('søren'), ['task-3'], reason: 'kept as stored');
      expect(await titles('sø'), ['task-3']);
    });

    test('the whole candidate pool is ranked before the limit: an exact '
        'title, and a short word, are not crowded out by BM25', () async {
      await fts.indexEntities([
        for (var i = 0; i < 40; i++) _task('repeat-$i', 'launch launch'),
        _task('exact', 'Launch'),
        for (var i = 0; i < 40; i++) _task('plan-$i', 'Plan'),
        _task('john', 'Plan John'),
      ]);

      final launch = await fts.searchTitles('launch', limit: 8);
      expect(launch.first.entityId, 'exact');

      final plan = await fts.searchTitles('plan jo', limit: 8);
      expect(plan.map((m) => m.entityId), ['john']);
      expect(plan.single.fuzzy, isFalse);
    });

    test(
      'a one- or two-letter query matches the start of a title word',
      () async {
        await fts.indexEntities([
          _task('roll', 'Emperor penguin roll call'),
          _task('other', 'Sardine futures'),
        ]);

        expect(await titles('ro'), ['roll']);
        expect(await titles('pe ro'), ['roll']);
      },
    );

    test('a misspelt title finds its nearest titles, marked fuzzy', () async {
      await fts.indexEntities([
        _task('roll', 'Emperor penguin roll call'),
        _task('other', 'Sardine futures'),
      ]);

      final near = await fts.searchTitles('pengiun rolcall');
      expect(near.map((m) => m.entityId), ['roll']);
      expect(near.single.fuzzy, isTrue);
    });

    test(
      'filters apply, and an edit or delete takes the old title out',
      () async {
        await fts.indexEntities([
          _task('task-1', 'Feed the chicks'),
          _entry('entry-1', 'Feed the chicks', private: true),
        ]);
        expect(await titles('chicks', types: {'Task'}), ['task-1']);

        await fts.indexEntities([
          _task('task-1', 'Count the chicks'),
          _task('task-2', 'Feed the chicks').copyWith(
            meta: _meta('task-2', deleted: true),
          ),
        ]);
        expect(await titles('feed'), isEmpty);
        expect(await titles('count'), ['task-1']);
      },
    );
  });

  group('matching', () {
    setUp(() => fts.catchUp(journalDb));

    test('a title match ranks above a match in the text, and newer above '
        'older among equals', () async {
      await fts.indexEntities([
        _entry('older-text', 'about the krill run', minutes: 1),
        _entry('newer-text', 'about the krill run', minutes: 2),
        _task('title', 'Krill run'),
      ]);

      expect(await search('krill run'), ['title', 'newer-text', 'older-text']);
    });

    test('the last word matches as a prefix while it is typed', () async {
      await fts.indexEntities([_entry('entry-1', 'penguin census')]);

      expect(await search('pengu'), ['entry-1']);
      expect(await search('penguin cen'), ['entry-1']);
      expect(await search('cen penguin'), isEmpty);
    });

    test('diacritics match either way', () async {
      await fts.indexEntities([
        _entry('accented', 'Pingüine am Südpol'),
        _entry('plain', 'Pinguine am Sudpol'),
      ]);

      expect((await search('pinguine sudpol')).toSet(), {'accented', 'plain'});
      expect((await search('Pingüine Südpol')).toSet(), {'accented', 'plain'});
    });

    test('filters apply before the limit', () async {
      await fts.indexEntities([
        _entry('colony-entry', 'krill', categoryId: 'colony', minutes: 3),
        _entry('loose-entry', 'krill', minutes: 2),
        _entry('private-entry', 'krill', private: true, minutes: 4),
        _task('task', 'krill'),
      ]);

      expect(await search('krill', types: {'Task'}), ['task']);
      expect(await search('krill', categoryIds: {'colony'}), ['colony-entry']);
      expect(
        (await search('krill', categoryIds: {''})).toSet(),
        {'loose-entry', 'private-entry', 'task'},
        reason: 'the empty id stands for uncategorised',
      );
      expect(
        await search('krill', includePrivate: false),
        isNot(contains('private-entry')),
      );
      expect(
        await search('krill', categoryIds: {}),
        isEmpty,
        reason: 'an empty selection matches nothing',
      );
      expect(
        await search('krill', types: {'JournalEntry'}, limit: 1),
        ['private-entry'],
        reason: 'the newest entry, the task being filtered out first',
      );
    });

    test('anyTerm is satisfied by one of the words', () async {
      await fts.indexEntities([
        _entry('krill', 'krill only'),
        _entry('squid', 'squid only'),
      ]);

      expect(await search('krill squid'), isEmpty);
      expect(
        (await search('krill squid', anyTerm: true)).toSet(),
        {'krill', 'squid'},
      );
    });

    test('input with nothing to match finds nothing', () async {
      await fts.indexEntities([_entry('entry-1', 'krill')]);
      expect(await search('  "" ** '), isEmpty);
    });

    glados.Glados(
      glados.any.list(
        glados.any.choose([
          'krill',
          'OR',
          'NEAR',
          'NOT',
          '"',
          "'",
          '-',
          '*',
          ':',
          '(',
          ')',
          '^',
          '{',
          ' ',
          'ü',
          'x',
        ]),
      ),
    ).test('whatever a user types, matching never throws', (parts) async {
      await fts.indexEntities([_entry('entry-1', 'krill and squid')]);
      final query = parts.join();
      final matches = await search(query);
      expect(matches, anyOf(isEmpty, ['entry-1']), reason: query);
    }, tags: 'glados');
  });

  test('reindexing measurements applies the definition given, not the '
      'cached one', () async {
    await fts.catchUp(journalDb);
    await fts.reindexMeasurements(measurableChocolate, [
      testMeasurementChocolateEntry,
      testTextEntry,
    ]);

    expect(
      await search('Chocolate'),
      [testMeasurementChocolateEntry.meta.id],
      reason: 'only measurements of that definition are written',
    );
  });

  test('upgrading a version 1 index drops its table and starts a '
      'rebuild', () async {
    final directory = setupTestDirectory();
    addTearDown(() => directory.deleteSync(recursive: true));
    sqlite3.open(p.join(directory.path, fts5DbFileName))
      ..execute(
        'CREATE VIRTUAL TABLE journal_fts USING '
        'fts5(plain_text, title, summary, tags, uuid)',
      )
      ..execute("INSERT INTO journal_fts VALUES ('krill', '', '', '', 'old')")
      ..execute('PRAGMA user_version = 1')
      ..close();

    final upgraded = Fts5Db(
      documentsDirectoryProvider: () async => directory,
      tempDirectoryProvider: () async => directory,
    );
    addTearDown(upgraded.close);

    expect(await upgraded.needsCatchUp(), isTrue);
    final tables = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'journal_fts'",
        )
        .get();
    expect(tables, isEmpty);
    expect(upgraded.schemaVersion, 3);
  });

  test('upgrading a version 2 index adds the title trigrams and starts a '
      'rebuild that fills them', () async {
    final directory = setupTestDirectory();
    addTearDown(() => directory.deleteSync(recursive: true));
    sqlite3.open(p.join(directory.path, fts5DbFileName))
      ..execute(
        'CREATE TABLE search_doc (id INTEGER NOT NULL PRIMARY KEY '
        'AUTOINCREMENT, entity_id TEXT NOT NULL UNIQUE, type TEXT NOT NULL, '
        "category_id TEXT NOT NULL DEFAULT '', private INTEGER NOT NULL "
        'DEFAULT 0, date_from INTEGER NOT NULL)',
      )
      ..execute(
        'CREATE VIRTUAL TABLE search_fts USING fts5(title, body, extra, '
        "tokenize = 'unicode61 remove_diacritics 2', prefix = '2 3')",
      )
      ..execute(
        'CREATE TABLE search_index_state (name TEXT NOT NULL PRIMARY KEY, '
        'int_value INTEGER NOT NULL)',
      )
      ..execute('PRAGMA user_version = 2')
      ..close();
    await store([_task('task-1', 'Emperor penguin roll call')]);

    final upgraded = Fts5Db(
      documentsDirectoryProvider: () async => directory,
      tempDirectoryProvider: () async => directory,
    );
    addTearDown(upgraded.close);

    expect(await upgraded.needsCatchUp(), isTrue);
    await upgraded.catchUp(journalDb);
    expect(
      (await upgraded.searchTitles('guin')).map((m) => m.entityId),
      ['task-1'],
    );
  });
}
