// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }

    testDirectory =
        Directory.systemTemp.createTempSync('lotti_linked_idx_mig_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getApplicationSupportDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return testDirectory!.path;
        }
        return null;
      },
    );

    getIt.registerSingleton<Directory>(testDirectory!);
  });

  tearDown(() async {
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory != null && testDirectory!.existsSync()) {
      testDirectory!.deleteSync(recursive: true);
    }
  });

  group('Linked Entries Index Migration v30', () {
    test('fixes idx_linked_entries_to_id_hidden to index to_id', () async {
      final dbFile =
          File(p.join(testDirectory!.path, 'test_v30_linked_idx.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // Create minimal v29-style schema with the buggy index
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS journal (
          id TEXT PRIMARY KEY,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          date_from INTEGER NOT NULL,
          date_to INTEGER NOT NULL,
          type TEXT NOT NULL,
          subtype TEXT,
          starred BOOLEAN DEFAULT FALSE,
          private BOOLEAN DEFAULT FALSE,
          deleted BOOLEAN DEFAULT FALSE,
          task BOOLEAN DEFAULT FALSE,
          task_status TEXT,
          task_priority TEXT,
          task_priority_rank INTEGER,
          category TEXT NOT NULL DEFAULT '',
          flag INTEGER DEFAULT 0,
          schema_version INTEGER DEFAULT 0,
          plain_text TEXT,
          latitude REAL,
          longitude REAL,
          geohash_string TEXT,
          geohash_int INTEGER
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS linked_entries (
          id TEXT NOT NULL UNIQUE,
          from_id TEXT NOT NULL,
          to_id TEXT NOT NULL,
          type TEXT NOT NULL,
          serialized TEXT NOT NULL,
          hidden BOOLEAN DEFAULT FALSE,
          created_at DATETIME,
          updated_at DATETIME,
          PRIMARY KEY (id),
          UNIQUE(from_id, to_id, type)
        )
      ''');

      // Create the buggy index (from_id instead of to_id)
      sqlite.execute('''
        CREATE INDEX idx_linked_entries_from_id ON linked_entries (from_id)
      ''');
      sqlite.execute('''
        CREATE INDEX idx_linked_entries_to_id ON linked_entries (to_id)
      ''');
      sqlite.execute('''
        CREATE INDEX idx_linked_entries_type ON linked_entries (type)
      ''');
      sqlite.execute('''
        CREATE INDEX idx_linked_entries_hidden ON linked_entries (hidden)
      ''');
      sqlite.execute('''
        CREATE INDEX idx_linked_entries_from_id_hidden
          ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)
      ''');
      // This is the buggy index: named _to_id_hidden but indexes from_id
      sqlite.execute('''
        CREATE INDEX idx_linked_entries_to_id_hidden
          ON linked_entries(from_id COLLATE BINARY ASC, hidden COLLATE BINARY ASC)
      ''');

      // Create other required tables for migration to succeed
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS conflicts (
          id TEXT PRIMARY KEY,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          serialized TEXT NOT NULL,
          schema_version INTEGER NOT NULL DEFAULT 0,
          status INTEGER NOT NULL
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS measurable_types (
          id TEXT PRIMARY KEY,
          unique_name TEXT NOT NULL UNIQUE,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL,
          version INTEGER NOT NULL DEFAULT 0,
          status INTEGER NOT NULL
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS habit_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL,
          active BOOLEAN NOT NULL
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS category_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL,
          active BOOLEAN NOT NULL
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS dashboard_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          last_reviewed DATETIME NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL,
          active BOOLEAN NOT NULL
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS config_flags (
          name TEXT NOT NULL UNIQUE,
          description TEXT NOT NULL UNIQUE,
          status BOOLEAN NOT NULL DEFAULT FALSE,
          PRIMARY KEY (name)
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS tag_entities (
          id TEXT NOT NULL UNIQUE,
          tag TEXT NOT NULL,
          type TEXT NOT NULL,
          inactive BOOLEAN DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted BOOLEAN DEFAULT FALSE,
          serialized TEXT NOT NULL,
          PRIMARY KEY (id),
          UNIQUE(tag, type)
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS tagged (
          id TEXT NOT NULL UNIQUE,
          journal_id TEXT NOT NULL,
          tag_entity_id TEXT NOT NULL,
          PRIMARY KEY (id),
          UNIQUE(journal_id, tag_entity_id)
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS label_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT NOT NULL,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS labeled (
          id TEXT NOT NULL UNIQUE,
          journal_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (id),
          FOREIGN KEY(journal_id) REFERENCES journal(id) ON DELETE CASCADE,
          FOREIGN KEY(label_id) REFERENCES label_definitions(id) ON DELETE CASCADE,
          UNIQUE(journal_id, label_id)
        )
      ''');

      // Verify the buggy index references from_id (not to_id) before migration.
      // We check the column list after 'ON linked_entries(' because the index
      // name itself contains 'to_id'.
      final preMigrationIdx = sqlite.select("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_linked_entries_to_id_hidden'
      """);
      expect(preMigrationIdx, hasLength(1));
      final buggyIndexSql = preMigrationIdx.first['sql'] as String;
      final buggyColumnPart =
          buggyIndexSql.substring(buggyIndexSql.indexOf('ON '));
      expect(buggyColumnPart, contains('from_id'));
      expect(buggyColumnPart, isNot(contains('to_id')));

      // Insert test linked entries to verify data survives migration
      sqlite.execute("""
        INSERT INTO linked_entries (id, from_id, to_id, type, serialized, hidden)
        VALUES ('link-1', 'entry-a', 'entry-b', 'BasicLink', '{}', 0)
      """);
      sqlite.execute("""
        INSERT INTO linked_entries (id, from_id, to_id, type, serialized, hidden)
        VALUES ('link-2', 'entry-c', 'entry-d', 'BasicLink', '{}', 1)
      """);

      // Set user_version to 29 to trigger v30 migration
      sqlite.execute('PRAGMA user_version = 29');
      sqlite.dispose();

      // Open with Drift to run migration
      final db = JournalDb(overriddenFilename: 'test_v30_linked_idx.db');

      // Schema version advanced to 30
      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);
      expect(db.schemaVersion, 30);

      // The corrected index now references to_id in its column list
      final postMigrationIdx = await db.customSelect("""
            SELECT sql FROM sqlite_master
            WHERE type='index' AND name='idx_linked_entries_to_id_hidden'
          """).get();
      expect(postMigrationIdx, hasLength(1));
      final fixedIndexSql = postMigrationIdx.first.read<String>('sql');
      final fixedColumnPart =
          fixedIndexSql.substring(fixedIndexSql.indexOf('ON '));
      expect(fixedColumnPart, contains('to_id'));
      expect(fixedColumnPart, isNot(contains('from_id')));

      // The from_id composite index is unchanged
      final fromIdIdx = await db.customSelect("""
            SELECT sql FROM sqlite_master
            WHERE type='index' AND name='idx_linked_entries_from_id_hidden'
          """).get();
      expect(fromIdIdx, hasLength(1));
      expect(fromIdIdx.first.read<String>('sql'), contains('from_id'));

      // Data survived migration intact
      final links = await db
          .customSelect('SELECT * FROM linked_entries ORDER BY id')
          .get();
      expect(links, hasLength(2));
      expect(links[0].read<String>('id'), 'link-1');
      expect(links[0].read<String>('from_id'), 'entry-a');
      expect(links[0].read<String>('to_id'), 'entry-b');
      expect(links[1].read<String>('id'), 'link-2');
      expect(links[1].read<String>('from_id'), 'entry-c');
      expect(links[1].read<String>('to_id'), 'entry-d');

      await db.close();
    });

    test('fresh database has correct index from the start', () async {
      // A fresh database (no migration) should have the correct index
      final db = JournalDb(
        inMemoryDatabase: true,
        overriddenFilename: 'fresh_v30.db',
      );

      // The to_id_hidden index should reference to_id
      final idx = await db.customSelect("""
            SELECT sql FROM sqlite_master
            WHERE type='index' AND name='idx_linked_entries_to_id_hidden'
          """).get();
      expect(idx, hasLength(1));
      final indexSql = idx.first.read<String>('sql');
      expect(indexSql, contains('to_id'));
      expect(indexSql, isNot(contains('from_id')));

      await db.close();
    });
  });
}
