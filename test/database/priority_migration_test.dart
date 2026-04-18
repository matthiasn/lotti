// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'migration_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }

    testDirectory = Directory.systemTemp.createTempSync('lotti_priority_mig_');

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory != null && testDirectory!.existsSync()) {
      testDirectory!.deleteSync(recursive: true);
    }
  });

  group('Priority Migration v29', () {
    test('adds columns and backfills defaults for legacy tasks', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v29_priority.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // Create a v28-style journal table without priority columns
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
          category TEXT,
          flag INTEGER DEFAULT 0,
          schema_version INTEGER DEFAULT 0
        )
      ''');

      createLinkedEntriesTableWithBuggyIndex(sqlite);

      // Insert a legacy task row (no priority columns exist yet)
      sqlite.execute("""
        INSERT INTO journal (id, serialized, created_at, updated_at, date_from, date_to, type, task, task_status)
        VALUES ('legacy-task', '{}', 0, 0, 0, 0, 'Task', 1, 'OPEN')
      """);

      // Set user_version to 28 to trigger v29 migration
      sqlite.execute('PRAGMA user_version = 28');
      sqlite.dispose();

      // Open with Drift to run migration
      final db = JournalDb(overriddenFilename: 'test_v29_priority.db');
      addTearDown(db.close);

      // Schema version advanced
      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);

      // Columns exist
      final tableInfo = await db
          .customSelect('PRAGMA table_info(journal)')
          .get();
      final cols = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(cols.contains('task_priority'), isTrue);
      expect(cols.contains('task_priority_rank'), isTrue);

      // Backfill applied for legacy task rows: default P2 / rank 2
      final row = await db
          .customSelect(
            "SELECT task_priority, task_priority_rank FROM journal WHERE id = 'legacy-task'",
          )
          .get();
      expect(row, hasLength(1));
      expect(row.first.read<String>('task_priority'), equals('P2'));
      expect(row.first.read<int>('task_priority_rank'), equals(2));

      // Index exists and references task_priority_rank
      final idx = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type='index' AND name='idx_journal_tasks'",
          )
          .get();
      expect(idx, hasLength(1));
      expect(idx.first.read<String>('sql'), contains('task_priority_rank'));

      await db.close();
    });
  });

  group('Task Due Index Migration v33', () {
    test(
      'adds the active task due-date index for existing databases',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v33_due_idx.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

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
        CREATE TABLE IF NOT EXISTS config_flags (
          name TEXT NOT NULL UNIQUE,
          description TEXT NOT NULL UNIQUE,
          status BOOLEAN NOT NULL DEFAULT FALSE,
          PRIMARY KEY (name)
        )
      ''');

        sqlite.execute('PRAGMA user_version = 32');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v33_due_idx.db');
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);
        expect(db.schemaVersion, 39);

        final idx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_tasks_due_active'
      """).get();
        expect(idx, hasLength(1));
        final sql = idx.first.read<String>('sql');
        expect(sql, contains(r"json_extract(serialized, '$.data.due')"));
        expect(sql, contains('type COLLATE BINARY ASC'));
        expect(sql, contains('deleted COLLATE BINARY ASC'));

        await db.close();
      },
    );
  });

  group('Task Date Index Migration v35', () {
    test('adds the date-oriented task index for existing databases', () async {
      final dbFile = File(
        p.join(testDirectory!.path, 'test_v35_task_date_idx.db'),
      );
      final sqlite = sqlite3.open(dbFile.path);

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

      sqlite.execute('PRAGMA user_version = 34');
      sqlite.dispose();

      final db = JournalDb(overriddenFilename: 'test_v35_task_date_idx.db');
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);
      expect(db.schemaVersion, 39);

      final idx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_tasks_date'
      """).get();
      expect(idx, hasLength(1));
      final sql = idx.first.read<String>('sql');
      expect(sql, contains('task_status COLLATE BINARY ASC'));
      expect(sql, contains('category COLLATE BINARY ASC'));
      expect(sql, contains('date_from COLLATE BINARY DESC'));
      expect(sql, contains('id COLLATE BINARY ASC'));

      await db.close();
    });

    test(
      'recreates an already-existing date-oriented task index safely',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v35_task_date_idx_existing.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

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
        CREATE INDEX idx_journal_tasks_date
        ON journal (
          category COLLATE BINARY ASC,
          task_status COLLATE BINARY ASC,
          date_from COLLATE BINARY DESC,
          id COLLATE BINARY ASC
        )
        WHERE type = 'Task' AND deleted = FALSE AND task = 1
      ''');

        sqlite.execute('PRAGMA user_version = 34');
        sqlite.dispose();

        final db = JournalDb(
          overriddenFilename: 'test_v35_task_date_idx_existing.db',
        );
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);

        final idx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_tasks_date'
      """).get();
        expect(idx, hasLength(1));

        await db.close();
      },
    );
  });

  group('Journal Browse Index Migration v36', () {
    test(
      'adds the browse-oriented journal index for existing databases',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v36_journal_browse_idx.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

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

        sqlite.execute('PRAGMA user_version = 35');
        sqlite.dispose();

        final db = JournalDb(
          overriddenFilename: 'test_v36_journal_browse_idx.db',
        );
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);
        expect(db.schemaVersion, 39);

        final idx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_browse'
      """).get();
        expect(idx, hasLength(1));
        final sql = idx.first.read<String>('sql');
        expect(sql, contains('deleted COLLATE BINARY ASC'));
        expect(sql, contains('type COLLATE BINARY ASC'));
        expect(sql, contains('date_from COLLATE BINARY DESC'));

        await db.close();
      },
    );

    test(
      'recreates an already-existing browse-oriented journal index safely',
      () async {
        final dbFile = File(
          p.join(
            testDirectory!.path,
            'test_v36_journal_browse_idx_existing.db',
          ),
        );
        final sqlite = sqlite3.open(dbFile.path);

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
        CREATE INDEX idx_journal_browse
        ON journal (
          deleted COLLATE BINARY ASC,
          type COLLATE BINARY ASC,
          date_from COLLATE BINARY DESC
        )
      ''');

        sqlite.execute('PRAGMA user_version = 35');
        sqlite.dispose();

        final db = JournalDb(
          overriddenFilename: 'test_v36_journal_browse_idx_existing.db',
        );
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);

        final idx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_browse'
      """).get();
        expect(idx, hasLength(1));

        await db.close();
      },
    );
  });

  group('Task Index Rebuild Migration v37', () {
    test(
      'rebuilds task indexes and adds the composite labeled lookup index',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v37_task_index_rebuild.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

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
        CREATE TABLE IF NOT EXISTS labeled (
          id TEXT PRIMARY KEY,
          journal_id TEXT NOT NULL,
          label_id TEXT NOT NULL
        )
      ''');

        sqlite.execute('PRAGMA user_version = 36');
        sqlite.dispose();

        final db = JournalDb(
          overriddenFilename: 'test_v37_task_index_rebuild.db',
        );
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);
        expect(db.schemaVersion, 39);

        final taskIdx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_tasks'
      """).get();
        expect(taskIdx, hasLength(1));
        final taskIdxSql = taskIdx.first.read<String>('sql');
        expect(taskIdxSql, contains('category COLLATE BINARY ASC'));
        expect(taskIdxSql, contains('task_status COLLATE BINARY ASC'));
        expect(taskIdxSql, contains('task_priority_rank COLLATE BINARY ASC'));
        expect(taskIdxSql, contains("WHERE type = 'Task'"));
        expect(taskIdxSql, contains('deleted = FALSE'));
        expect(taskIdxSql, contains('task = 1'));

        final taskDateIdx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_tasks_date'
      """).get();
        expect(taskDateIdx, hasLength(1));
        final taskDateIdxSql = taskDateIdx.first.read<String>('sql');
        expect(taskDateIdxSql, contains('category COLLATE BINARY ASC'));
        expect(taskDateIdxSql, contains('task_status COLLATE BINARY ASC'));
        expect(taskDateIdxSql, contains('date_from COLLATE BINARY DESC'));
        expect(taskDateIdxSql, contains('id COLLATE BINARY ASC'));
        expect(taskDateIdxSql, contains("WHERE type = 'Task'"));

        final taskDatePriorityIdx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_journal_tasks_date_priority'
      """).get();
        expect(taskDatePriorityIdx, hasLength(1));
        final taskDatePriorityIdxSql = taskDatePriorityIdx.first.read<String>(
          'sql',
        );
        expect(
          taskDatePriorityIdxSql,
          contains('task_priority COLLATE BINARY ASC'),
        );
        expect(
          taskDatePriorityIdxSql,
          contains('date_from COLLATE BINARY DESC'),
        );
        expect(taskDatePriorityIdxSql, contains("WHERE type = 'Task'"));

        // The redundant idx_labeled_journal_id_label_id was removed because the
        // UNIQUE(journal_id, label_id) constraint already provides an equivalent
        // implicit index.
        final labeledIdx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_labeled_journal_id_label_id'
      """).get();
        expect(labeledIdx, isEmpty);

        await db.close();
      },
    );

    test(
      'drops redundant labeled lookup index during migration',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v37_labeled_idx_existing.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

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
        CREATE TABLE IF NOT EXISTS labeled (
          id TEXT PRIMARY KEY,
          journal_id TEXT NOT NULL,
          label_id TEXT NOT NULL
        )
      ''');

        sqlite.execute('''
        CREATE INDEX idx_labeled_journal_id_label_id
        ON labeled (
          journal_id COLLATE BINARY ASC,
          label_id COLLATE BINARY ASC
        )
      ''');

        sqlite.execute('PRAGMA user_version = 36');
        sqlite.dispose();

        final db = JournalDb(
          overriddenFilename: 'test_v37_labeled_idx_existing.db',
        );
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);

        // The redundant index should be dropped during migration since
        // UNIQUE(journal_id, label_id) already provides an equivalent index.
        final idx = await db.customSelect("""
        SELECT sql FROM sqlite_master
        WHERE type='index' AND name='idx_labeled_journal_id_label_id'
      """).get();
        expect(idx, isEmpty);

        await db.close();
      },
    );
  });
}
