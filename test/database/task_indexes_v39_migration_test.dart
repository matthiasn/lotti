// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
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
    testDirectory = Directory.systemTemp.createTempSync('lotti_v39_mig_');
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

  // Minimal pre-v39 schema: the journal table with the columns the v39
  // migration touches, plus the old non-partial idx_journal_tasks_due_active
  // that the migration is expected to drop and replace.
  void createV38Schema(Database sqlite) {
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
        project_id TEXT,
        flag INTEGER DEFAULT 0,
        schema_version INTEGER DEFAULT 0,
        plain_text TEXT,
        latitude REAL,
        longitude REAL,
        geohash_string TEXT,
        geohash_int INTEGER
      )
    ''');
    sqlite.execute(r'''
      CREATE INDEX idx_journal_tasks_due_active ON journal(
        type COLLATE BINARY ASC,
        deleted COLLATE BINARY ASC,
        json_extract(serialized, '$.data.due') ASC
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
  }

  Future<String> indexSql(JournalDb db, String name) async {
    final rows = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type='index' AND name = ?",
          variables: [Variable.withString(name)],
        )
        .get();
    expect(rows, hasLength(1));
    return rows.first.read<String>('sql');
  }

  group('Task indexes v39 migration', () {
    test(
      'adds the idx_journal_tasks_due_open partial expression index',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v39_due_open.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);
        createV38Schema(sqlite);
        sqlite.execute('PRAGMA user_version = 38');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v39_due_open.db');
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);
        expect(db.schemaVersion, 39);

        final sql = await indexSql(db, 'idx_journal_tasks_due_open');
        expect(sql, contains(r"json_extract(serialized, '$.data.due')"));
        expect(sql, contains("WHERE type = 'Task'"));
        expect(sql, contains('task = 1'));
        expect(sql, contains('deleted = FALSE'));
        expect(sql, contains("task_status NOT IN ('DONE', 'REJECTED')"));

        // The pre-existing non-partial composite must remain intact for
        // `getTasksSortedByDueDate`, whose IN-list task_status predicates
        // can't prove the partial's WHERE.
        final existing = await indexSql(db, 'idx_journal_tasks_due_active');
        expect(existing, contains('type COLLATE BINARY ASC'));
        expect(existing, contains('deleted COLLATE BINARY ASC'));
      },
    );

    test('adds idx_journal_task_status_private partial index', () async {
      final dbFile = File(
        p.join(testDirectory!.path, 'test_v39_status_private.db'),
      );
      final sqlite = sqlite3.open(dbFile.path);
      createV38Schema(sqlite);
      sqlite.execute('PRAGMA user_version = 38');
      sqlite.dispose();

      final db = JournalDb(overriddenFilename: 'test_v39_status_private.db');
      addTearDown(db.close);

      final sql = await indexSql(db, 'idx_journal_task_status_private');
      expect(sql, contains('task_status COLLATE BINARY ASC'));
      expect(sql, contains('private COLLATE BINARY ASC'));
      expect(sql, contains("type = 'Task'"));
      expect(sql, contains('task = 1'));
      expect(sql, contains('deleted = FALSE'));
    });

    test('is idempotent when the v39 indexes already exist', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v39_rerun.db'));
      final sqlite = sqlite3.open(dbFile.path);
      createV38Schema(sqlite);
      // Pre-create the target indexes so the migration's DROP IF EXISTS
      // + CREATE path is exercised.
      sqlite.execute(
        'CREATE INDEX idx_journal_task_status_private '
        'ON journal(task_status COLLATE BINARY ASC, '
        'private COLLATE BINARY ASC) '
        "WHERE type = 'Task' AND task = 1 AND deleted = FALSE",
      );
      sqlite.execute(
        'CREATE INDEX idx_journal_tasks_due_open '
        r"ON journal(json_extract(serialized, '$.data.due') ASC) "
        "WHERE type = 'Task' AND task = 1 AND deleted = FALSE "
        "AND task_status NOT IN ('DONE', 'REJECTED')",
      );
      sqlite.execute('PRAGMA user_version = 38');
      sqlite.dispose();

      final db = JournalDb(overriddenFilename: 'test_v39_rerun.db');
      addTearDown(db.close);

      await indexSql(db, 'idx_journal_tasks_due_open');
      await indexSql(db, 'idx_journal_tasks_due_active');
      await indexSql(db, 'idx_journal_task_status_private');
    });

    test(
      'countInProgressTasks query plan uses idx_journal_task_status_private',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v39_count_plan.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);
        createV38Schema(sqlite);
        sqlite.execute('PRAGMA user_version = 38');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v39_count_plan.db');
        addTearDown(db.close);

        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT COUNT(*) FROM journal '
              'WHERE deleted = FALSE '
              "AND type = 'Task' "
              'AND task = 1 '
              'AND private IN (0, 1) '
              'AND task_status IN (?)',
              variables: [Variable.withString('IN PROGRESS')],
            )
            .get();

        final detail = plan.map((row) => row.read<String>('detail')).join('\n');
        expect(detail, contains('idx_journal_task_status_private'));
      },
    );

    test(
      'open-task due query plan uses the partial idx_journal_tasks_due_open',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v39_due_plan.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);
        createV38Schema(sqlite);
        sqlite.execute('PRAGMA user_version = 38');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v39_due_plan.db');
        addTearDown(db.close);

        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM journal INDEXED BY idx_journal_tasks_due_open '
              "WHERE type = 'Task' "
              'AND task = 1 '
              'AND deleted = FALSE '
              "AND task_status NOT IN ('DONE', 'REJECTED') "
              r"AND json_extract(serialized, '$.data.due') IS NOT NULL "
              r"AND json_extract(serialized, '$.data.due') <= ? "
              'AND private IN (0, 1) '
              r"ORDER BY json_extract(serialized, '$.data.due') ASC",
              variables: [Variable.withString('2026-12-31T23:59:59Z')],
            )
            .get();

        final detail = plan.map((row) => row.read<String>('detail')).join('\n');
        expect(detail, contains('idx_journal_tasks_due_open'));
      },
    );
  });
}
