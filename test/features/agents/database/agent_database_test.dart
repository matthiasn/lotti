// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

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
      final dbFile =
          path.join(testDirectory.path, agentDbFileName);
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

      // Verify schema version is now 2
      final versionResult =
          await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        2,
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

      await db.close();
    });
  });
}
