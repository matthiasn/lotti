// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Migration tests for v41 — denormalized `due_at` column.
///
/// The migration replaces the v39 expression-keyed
/// `idx_journal_tasks_due_open` (`json_extract(serialized,'$.data.due')`)
/// with a partial index over a real `due_at INTEGER` column populated by
/// `toDbEntity` on every upsert. The non-partial composite
/// `idx_journal_tasks_due_active` is dropped because its only consumer
/// (`getTasksSortedByDueDate`) is rewritten to read the column directly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync('lotti_v41_due_at_');
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

  /// Builds a minimal v40-style schema: every column the v41 migration
  /// reads from, plus the v39 `idx_journal_tasks_due_open` it expects to
  /// drop and the non-partial `idx_journal_tasks_due_active` it expects
  /// to drop. Mirrors the shape used by `task_indexes_v39_migration_test`.
  void createV40Schema(Database sqlite) {
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
    sqlite.execute(
      'CREATE INDEX idx_journal_tasks_due_open '
      r"ON journal(json_extract(serialized, '$.data.due') ASC) "
      "WHERE type = 'Task' AND task = 1 AND deleted = FALSE "
      "AND task_status NOT IN ('DONE', 'REJECTED')",
    );
    sqlite.execute('''
      CREATE TABLE IF NOT EXISTS config_flags (
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL UNIQUE,
        status BOOLEAN NOT NULL DEFAULT FALSE,
        PRIMARY KEY (name)
      )
    ''');
  }

  /// Writes a journal row at v40 with a JSON `data.due` payload for
  /// `task` / non-task / null-due variants. The `data.due` field is
  /// serialized exactly as `DateTime.toIso8601String()` produces it,
  /// which is what the migration's `strftime('%s', ...)` expects.
  void insertV40Task(
    Database sqlite, {
    required String id,
    required String type,
    required bool task,
    required String taskStatus,
    DateTime? due,
    bool deleted = false,
  }) {
    final dueIso = due?.toIso8601String();
    final dataPayload = dueIso != null ? '"due":"$dueIso",' : '';
    final serialized =
        '{"meta":{"id":"$id"},"data":{$dataPayload"title":"$id"}}';
    sqlite.execute(
      'INSERT INTO journal (id, serialized, created_at, updated_at, '
      'date_from, date_to, type, task, task_status, deleted, category) '
      'VALUES (?, ?, 0, 0, 0, 0, ?, ?, ?, ?, ?)',
      [
        id,
        serialized,
        type,
        if (task) 1 else 0,
        taskStatus,
        if (deleted) 1 else 0,
        '',
      ],
    );
  }

  Future<String?> indexSqlOrNull(JournalDb db, String name) async {
    final rows = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type='index' AND name = ?",
          variables: [Variable.withString(name)],
        )
        .get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('sql');
  }

  group('Due-at column migration v41', () {
    test('adds the due_at column', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v41_column.db'));
      final sqlite = sqlite3.open(dbFile.path);
      createV40Schema(sqlite);
      sqlite.execute('PRAGMA user_version = 40');
      sqlite.dispose();

      final db = JournalDb(overriddenFilename: 'test_v41_column.db');
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);
      expect(db.schemaVersion, 43);

      final hasColumn = await db.columnExistsForTesting('journal', 'due_at');
      expect(hasColumn, isTrue);
    });

    test(
      'backfills due_at for every task with a non-null data.due, '
      'across all statuses',
      () async {
        final dbFile = File(
          p.join(testDirectory!.path, 'test_v41_backfill.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);
        createV40Schema(sqlite);

        // Tasks at every status that the migration must include.
        final openDue = DateTime.utc(2026, 5, 1, 12);
        final doneDue = DateTime.utc(2026, 4, 15, 9);
        final rejectedDue = DateTime.utc(2026, 3, 30, 16);

        insertV40Task(
          sqlite,
          id: 'task-open',
          type: 'Task',
          task: true,
          taskStatus: 'IN PROGRESS',
          due: openDue,
        );
        insertV40Task(
          sqlite,
          id: 'task-done',
          type: 'Task',
          task: true,
          taskStatus: 'DONE',
          due: doneDue,
        );
        insertV40Task(
          sqlite,
          id: 'task-rejected',
          type: 'Task',
          task: true,
          taskStatus: 'REJECTED',
          due: rejectedDue,
        );
        // Task without a due date — column must stay NULL after backfill.
        insertV40Task(
          sqlite,
          id: 'task-no-due',
          type: 'Task',
          task: true,
          taskStatus: 'OPEN',
        );
        // Non-Task journal row — column must stay NULL even though the
        // payload happens to carry a `data.due` field.
        insertV40Task(
          sqlite,
          id: 'entry-non-task',
          type: 'JournalEntry',
          task: false,
          taskStatus: '',
          due: DateTime.utc(2026, 6),
        );

        sqlite.execute('PRAGMA user_version = 40');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v41_backfill.db');
        addTearDown(db.close);

        Future<DateTime?> readDueAt(String id) async {
          final rows = await db
              .customSelect(
                'SELECT due_at FROM journal WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .get();
          expect(rows, hasLength(1));
          final raw = rows.first.data['due_at'];
          if (raw == null) return null;
          return DateTime.fromMillisecondsSinceEpoch(
            (raw as int) * 1000,
            isUtc: true,
          );
        }

        expect(await readDueAt('task-open'), openDue);
        expect(await readDueAt('task-done'), doneDue);
        expect(await readDueAt('task-rejected'), rejectedDue);
        expect(await readDueAt('task-no-due'), isNull);
        expect(await readDueAt('entry-non-task'), isNull);
      },
    );

    test(
      'replaces idx_journal_tasks_due_open with a column-keyed partial',
      () async {
        final dbFile = File(p.join(testDirectory!.path, 'test_v41_index.db'));
        final sqlite = sqlite3.open(dbFile.path);
        createV40Schema(sqlite);
        sqlite.execute('PRAGMA user_version = 40');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v41_index.db');
        addTearDown(db.close);

        final sql = await indexSqlOrNull(db, 'idx_journal_tasks_due_open');
        expect(sql, isNotNull);
        expect(sql, contains('due_at ASC'));
        expect(sql, isNot(contains('json_extract')));
        expect(sql, contains("WHERE type = 'Task'"));
        expect(sql, contains('task = 1'));
        expect(sql, contains('deleted = FALSE'));
        expect(sql, contains("task_status NOT IN ('DONE', 'REJECTED')"));
      },
    );

    test('drops idx_journal_tasks_due_active', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v41_drop.db'));
      final sqlite = sqlite3.open(dbFile.path);
      createV40Schema(sqlite);
      sqlite.execute('PRAGMA user_version = 40');
      sqlite.dispose();

      final db = JournalDb(overriddenFilename: 'test_v41_drop.db');
      addTearDown(db.close);

      final activeSql = await indexSqlOrNull(
        db,
        'idx_journal_tasks_due_active',
      );
      expect(activeSql, isNull);
    });

    test(
      'open-task due query plan uses the column-keyed partial index',
      () async {
        final dbFile = File(p.join(testDirectory!.path, 'test_v41_plan.db'));
        final sqlite = sqlite3.open(dbFile.path);
        createV40Schema(sqlite);
        sqlite.execute('PRAGMA user_version = 40');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v41_plan.db');
        addTearDown(db.close);

        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM journal INDEXED BY idx_journal_tasks_due_open '
              "WHERE type = 'Task' "
              'AND task = 1 '
              'AND deleted = FALSE '
              "AND task_status NOT IN ('DONE', 'REJECTED') "
              'AND due_at IS NOT NULL '
              'AND due_at <= ? '
              'AND private IN (0, 1) '
              'ORDER BY due_at ASC',
              variables: [Variable.withDateTime(DateTime.utc(2026, 12, 31))],
            )
            .get();

        final detail = plan.map((row) => row.read<String>('detail')).join('\n');
        expect(detail, contains('idx_journal_tasks_due_open'));
      },
    );

    test('migration is idempotent when re-run', () async {
      final dbFile = File(
        p.join(testDirectory!.path, 'test_v41_idempotent.db'),
      );
      final sqlite = sqlite3.open(dbFile.path);
      createV40Schema(sqlite);
      insertV40Task(
        sqlite,
        id: 'task-1',
        type: 'Task',
        task: true,
        taskStatus: 'OPEN',
        due: DateTime.utc(2026, 5),
      );
      sqlite.execute('PRAGMA user_version = 40');
      sqlite.dispose();

      // First open runs the migration.
      var db = JournalDb(overriddenFilename: 'test_v41_idempotent.db');
      final firstSql = await indexSqlOrNull(db, 'idx_journal_tasks_due_open');
      expect(firstSql, contains('due_at ASC'));
      await db.close();

      // Second open must be a no-op — beforeOpen's IF NOT EXISTS guards
      // and the column-existence check protect against re-creation.
      db = JournalDb(overriddenFilename: 'test_v41_idempotent.db');
      addTearDown(db.close);

      final secondSql = await indexSqlOrNull(db, 'idx_journal_tasks_due_open');
      expect(secondSql, equals(firstSql));

      // Backfill data must survive the second open unchanged.
      final rows = await db
          .customSelect(
            "SELECT due_at FROM journal WHERE id = 'task-1'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.data['due_at'], isNotNull);
    });
  });
}
