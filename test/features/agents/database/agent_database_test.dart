// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' show SqliteException, sqlite3;

void main() {
  late Directory testDirectory;

  setUp(() {
    testDirectory =
        Directory.systemTemp.createTempSync('lotti_agent_migration_test_');
  });

  tearDown(() {
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  group('AgentDatabase migration', () {
    test('v1 to v2 adds user_rating and rated_at columns to wake_run_log',
        () async {
      // Create a v1 database with the original schema (no rating columns)
      final dbFile = path.join(testDirectory.path, agentDbFileName);
      final rawDb = sqlite3.open(dbFile);

      // Create v1 schema tables (minimal — only wake_run_log needed)
      rawDb.execute('''
        CREATE TABLE agent_entities (
          id TEXT NOT NULL PRIMARY KEY,
          agent_id TEXT NOT NULL,
          type TEXT NOT NULL,
          subtype TEXT,
          thread_id TEXT,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted_at DATETIME,
          serialized TEXT NOT NULL,
          schema_version INTEGER NOT NULL DEFAULT 1
        )
      ''');
      rawDb.execute('''
        CREATE TABLE agent_links (
          id TEXT NOT NULL PRIMARY KEY,
          from_id TEXT NOT NULL,
          to_id TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted_at DATETIME,
          serialized TEXT NOT NULL,
          schema_version INTEGER NOT NULL DEFAULT 1,
          UNIQUE(from_id, to_id, type)
        )
      ''');
      rawDb.execute('''
        CREATE TABLE wake_run_log (
          run_key TEXT NOT NULL PRIMARY KEY,
          agent_id TEXT NOT NULL,
          reason TEXT NOT NULL,
          reason_id TEXT,
          thread_id TEXT NOT NULL,
          status TEXT NOT NULL,
          logical_change_key TEXT,
          created_at DATETIME NOT NULL,
          started_at DATETIME,
          completed_at DATETIME,
          error_message TEXT,
          template_id TEXT,
          template_version_id TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE saga_log (
          operation_id TEXT NOT NULL PRIMARY KEY,
          agent_id TEXT NOT NULL,
          run_key TEXT NOT NULL,
          phase TEXT NOT NULL,
          status TEXT NOT NULL,
          tool_name TEXT NOT NULL,
          last_error TEXT,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL
        )
      ''');

      // Insert a test row to verify data survives migration
      rawDb.execute('''
        INSERT INTO wake_run_log
          (run_key, agent_id, reason, thread_id, status, created_at)
        VALUES
          ('run-1', 'agent-1', 'scheduled', 'thread-1', 'completed',
           '2026-02-20 10:00:00')
      ''');

      // Set schema version to 1
      rawDb.execute('PRAGMA user_version = 1');
      rawDb.dispose();

      // Open with AgentDatabase to trigger v1→v2 migration
      final db = AgentDatabase(
        background: false,
        documentsDirectoryProvider: () async => testDirectory,
        tempDirectoryProvider: () async => testDirectory,
      );

      // Verify schema version is now 3 (latest).
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        3,
      );

      // Verify the new columns exist by querying them
      final rows = await db
          .customSelect(
            'SELECT run_key, user_rating, rated_at FROM wake_run_log',
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.read<String>('run_key'), 'run-1');
      expect(rows.first.readNullable<double>('user_rating'), isNull);
      expect(rows.first.readNullable<DateTime>('rated_at'), isNull);

      // Verify new columns are writable
      await db.customStatement('''
        UPDATE wake_run_log SET user_rating = 0.85,
        rated_at = '2026-02-20 15:30:00'
        WHERE run_key = 'run-1'
      ''');

      final updated = await db
          .customSelect(
            'SELECT user_rating, rated_at FROM wake_run_log '
            "WHERE run_key = 'run-1'",
          )
          .get();
      expect(updated.first.read<double>('user_rating'), 0.85);
      expect(updated.first.readNullable<String>('rated_at'), isNotNull);

      await db.close();
    });

    test(
        'v2 to v3 adds unique partial index '
        'idx_unique_improver_per_template', () async {
      // Create a v2 database with rating columns already present.
      final dbFile = path.join(testDirectory.path, agentDbFileName);
      final rawDb = sqlite3.open(dbFile);

      rawDb.execute('''
        CREATE TABLE agent_entities (
          id TEXT NOT NULL PRIMARY KEY,
          agent_id TEXT NOT NULL,
          type TEXT NOT NULL,
          subtype TEXT,
          thread_id TEXT,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted_at DATETIME,
          serialized TEXT NOT NULL,
          schema_version INTEGER NOT NULL DEFAULT 1
        )
      ''');
      rawDb.execute('''
        CREATE TABLE agent_links (
          id TEXT NOT NULL PRIMARY KEY,
          from_id TEXT NOT NULL,
          to_id TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          deleted_at DATETIME,
          serialized TEXT NOT NULL,
          schema_version INTEGER NOT NULL DEFAULT 1,
          UNIQUE(from_id, to_id, type)
        )
      ''');
      rawDb.execute('''
        CREATE TABLE wake_run_log (
          run_key TEXT NOT NULL PRIMARY KEY,
          agent_id TEXT NOT NULL,
          reason TEXT NOT NULL,
          reason_id TEXT,
          thread_id TEXT NOT NULL,
          status TEXT NOT NULL,
          logical_change_key TEXT,
          created_at DATETIME NOT NULL,
          started_at DATETIME,
          completed_at DATETIME,
          error_message TEXT,
          template_id TEXT,
          template_version_id TEXT,
          user_rating REAL,
          rated_at DATETIME
        )
      ''');
      rawDb.execute('''
        CREATE TABLE saga_log (
          operation_id TEXT NOT NULL PRIMARY KEY,
          agent_id TEXT NOT NULL,
          run_key TEXT NOT NULL,
          phase TEXT NOT NULL,
          status TEXT NOT NULL,
          tool_name TEXT NOT NULL,
          last_error TEXT,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL
        )
      ''');

      rawDb.execute('PRAGMA user_version = 2');
      rawDb.dispose();

      // Open with AgentDatabase to trigger v2→v3 migration.
      final db = AgentDatabase(
        background: false,
        documentsDirectoryProvider: () async => testDirectory,
        tempDirectoryProvider: () async => testDirectory,
      );

      // Verify schema version is now 3.
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        3,
      );

      // Verify the partial unique index exists.
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_unique_improver_per_template'",
          )
          .get();
      expect(indexes, hasLength(1));

      // Verify the index enforces uniqueness: two non-deleted
      // improver_target links to the same to_id should fail.
      await db.customStatement('''
        INSERT INTO agent_links
          (id, from_id, to_id, type, created_at, updated_at, serialized,
           schema_version)
        VALUES
          ('link-1', 'agent-a', 'tpl-1', 'improver_target',
           '2026-01-01', '2026-01-01', '{}', 1)
      ''');

      expect(
        () async => db.customStatement('''
          INSERT INTO agent_links
            (id, from_id, to_id, type, created_at, updated_at, serialized,
             schema_version)
          VALUES
            ('link-2', 'agent-b', 'tpl-1', 'improver_target',
             '2026-01-01', '2026-01-01', '{}', 1)
        '''),
        throwsA(isA<SqliteException>()),
      );

      await db.close();
    });

    test('v2 to v3 deduplicates existing improver_target rows', () async {
      final dbFile = path.join(testDirectory.path, agentDbFileName);
      final rawDb = sqlite3.open(dbFile);

      rawDb
        ..execute('''
          CREATE TABLE agent_entities (
            id TEXT NOT NULL PRIMARY KEY,
            agent_id TEXT NOT NULL,
            type TEXT NOT NULL,
            subtype TEXT,
            thread_id TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            deleted_at DATETIME,
            serialized TEXT NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1
          )
        ''')
        ..execute('''
          CREATE TABLE agent_links (
            id TEXT NOT NULL PRIMARY KEY,
            from_id TEXT NOT NULL,
            to_id TEXT NOT NULL,
            type TEXT NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            deleted_at DATETIME,
            serialized TEXT NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1
          )
        ''')
        ..execute('''
          CREATE TABLE wake_run_log (
            run_key TEXT NOT NULL PRIMARY KEY,
            agent_id TEXT NOT NULL,
            reason TEXT NOT NULL,
            reason_id TEXT,
            thread_id TEXT NOT NULL,
            status TEXT NOT NULL,
            logical_change_key TEXT,
            created_at DATETIME NOT NULL,
            started_at DATETIME,
            completed_at DATETIME,
            error_message TEXT,
            template_id TEXT,
            template_version_id TEXT,
            user_rating REAL,
            rated_at DATETIME
          )
        ''')
        ..execute('''
          CREATE TABLE saga_log (
            operation_id TEXT NOT NULL PRIMARY KEY,
            agent_id TEXT NOT NULL,
            run_key TEXT NOT NULL,
            phase TEXT NOT NULL,
            status TEXT NOT NULL,
            tool_name TEXT NOT NULL,
            last_error TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
          )
        ''');

      // Insert two duplicate improver_target links to the same template.
      // Note: no UNIQUE(from_id, to_id, type) constraint in this v2 schema
      // variant to simulate the scenario where duplicates slipped through.
      rawDb
        ..execute('''
          INSERT INTO agent_links
            (id, from_id, to_id, type, created_at, updated_at, serialized,
             schema_version)
          VALUES
            ('link-dup-1', 'agent-A', 'tpl-X', 'improver_target',
             '2026-01-01', '2026-01-01', '{}', 1)
        ''')
        ..execute('''
          INSERT INTO agent_links
            (id, from_id, to_id, type, created_at, updated_at, serialized,
             schema_version)
          VALUES
            ('link-dup-2', 'agent-B', 'tpl-X', 'improver_target',
             '2026-01-02', '2026-01-02', '{}', 1)
        ''')
        // A link to a different template should be unaffected.
        ..execute('''
          INSERT INTO agent_links
            (id, from_id, to_id, type, created_at, updated_at, serialized,
             schema_version)
          VALUES
            ('link-other', 'agent-C', 'tpl-Y', 'improver_target',
             '2026-01-01', '2026-01-01', '{}', 1)
        ''');

      rawDb.execute('PRAGMA user_version = 2');
      rawDb.dispose();

      // Migration should deduplicate before creating the index.
      final db = AgentDatabase(
        background: false,
        documentsDirectoryProvider: () async => testDirectory,
        tempDirectoryProvider: () async => testDirectory,
      );

      // Only one non-deleted link should remain per to_id.
      final activeLinks = await db
          .customSelect(
            'SELECT id FROM agent_links '
            "WHERE type = 'improver_target' AND deleted_at IS NULL",
          )
          .get();

      // tpl-X: 1 survivor, tpl-Y: 1 survivor = 2 total.
      expect(activeLinks, hasLength(2));

      // The soft-deleted duplicate should still exist in the table.
      final allLinks = await db
          .customSelect(
            'SELECT id, deleted_at FROM agent_links '
            "WHERE type = 'improver_target'",
          )
          .get();
      expect(allLinks, hasLength(3));

      final softDeleted = allLinks
          .where((r) => r.readNullable<String>('deleted_at') != null)
          .toList();
      expect(softDeleted, hasLength(1));

      await db.close();
    });
  });
}
