// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' show SqliteException, sqlite3;

void main() {
  late Directory testDirectory;

  setUp(() {
    testDirectory = Directory.systemTemp.createTempSync(
      'lotti_agent_migration_test_',
    );
  });

  tearDown(() {
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  group('AgentDatabase migration', () {
    test(
      'v1 to v2 adds user_rating and rated_at columns to wake_run_log',
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
        addTearDown(db.close);

        // Verify schema version is now latest.
        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
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
      },
    );

    test('v2 to v3 adds unique partial index '
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
      addTearDown(db.close);

      // Verify schema version is now latest.
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        db.schemaVersion,
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
      addTearDown(db.close);

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

    test('v3 to v4 adds resolved_model_id column to wake_run_log', () async {
      final dbFile = path.join(testDirectory.path, agentDbFileName);
      final rawDb = sqlite3.open(dbFile);

      // Create v3 schema (without resolved_model_id).
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
            schema_version INTEGER NOT NULL DEFAULT 1,
            UNIQUE(from_id, to_id, type)
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

      rawDb.execute('PRAGMA user_version = 3');
      rawDb.dispose();

      final db = AgentDatabase(
        background: false,
        documentsDirectoryProvider: () async => testDirectory,
        tempDirectoryProvider: () async => testDirectory,
      );
      addTearDown(db.close);

      // Verify schema version is now latest.
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        db.schemaVersion,
      );

      // Verify the column exists by selecting it.
      final rows = await db
          .customSelect(
            'SELECT run_key, resolved_model_id FROM wake_run_log',
          )
          .get();
      expect(rows, isEmpty);

      await db.close();
    });

    test(
      'v4 to v5 adds targeted performance indexes for agent reads',
      () async {
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
              schema_version INTEGER NOT NULL DEFAULT 1,
              UNIQUE(from_id, to_id, type)
            )
          ''')
          ..execute('''
            CREATE INDEX idx_agent_links_from ON agent_links(from_id, type)
          ''')
          ..execute('''
            CREATE INDEX idx_agent_links_to ON agent_links(to_id, type)
          ''')
          ..execute('''
            CREATE INDEX idx_agent_links_type ON agent_links(type)
          ''')
          ..execute('''
            CREATE UNIQUE INDEX idx_unique_improver_per_template
            ON agent_links(to_id)
            WHERE type = 'improver_target' AND deleted_at IS NULL
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
              resolved_model_id TEXT,
              user_rating REAL,
              rated_at DATETIME
            )
          ''')
          ..execute('''
            CREATE INDEX idx_wake_run_log_agent
            ON wake_run_log(agent_id, created_at DESC)
          ''')
          ..execute('''
            CREATE INDEX idx_wake_run_log_template
            ON wake_run_log(template_id, created_at DESC)
          ''')
          ..execute('''
            CREATE INDEX idx_wake_run_log_status
            ON wake_run_log(status)
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
          ''')
          ..execute('''
            CREATE INDEX idx_saga_log_agent ON saga_log(agent_id)
          ''')
          ..execute('''
            CREATE INDEX idx_saga_log_status
            ON saga_log(status, updated_at)
          ''');

        rawDb.execute('PRAGMA user_version = 4');
        rawDb.dispose();

        final db = AgentDatabase(
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              'AND name IN ( '
              "'idx_agent_links_active_from_type_to', "
              "'idx_wake_run_log_agent_thread', "
              "'idx_saga_log_status_created_at'"
              ') ORDER BY name',
            )
            .get();

        expect(
          indexes.map((row) => row.read<String>('name')).toList(),
          [
            'idx_agent_links_active_from_type_to',
            'idx_saga_log_status_created_at',
            'idx_wake_run_log_agent_thread',
          ],
        );

        await db.close();
      },
    );

    test(
      'v5 to v6 adds soul columns and unique soul assignment index',
      () async {
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
              schema_version INTEGER NOT NULL DEFAULT 1,
              UNIQUE(from_id, to_id, type)
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
              resolved_model_id TEXT,
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
          ''')
          ..execute('''
            INSERT INTO wake_run_log
              (run_key, agent_id, reason, thread_id, status, created_at)
            VALUES
              ('run-soul', 'agent-1', 'trigger', 'thread-1', 'pending',
               '2026-04-06 10:00:00')
          ''')
          // Insert two soul_assignment links for the same template (sync
          // race residue). The migration must soft-delete all but the most
          // recent before creating the unique partial index.
          ..execute('''
            INSERT INTO agent_links
              (id, from_id, to_id, type, created_at, updated_at,
               serialized, schema_version)
            VALUES
              ('link-old', 'tpl-1', 'soul-A', 'soul_assignment',
               '2026-01-01', '2026-01-01', '{}', 1)
          ''')
          ..execute('''
            INSERT INTO agent_links
              (id, from_id, to_id, type, created_at, updated_at,
               serialized, schema_version)
            VALUES
              ('link-new', 'tpl-1', 'soul-B', 'soul_assignment',
               '2026-02-01', '2026-02-01', '{}', 1)
          ''');

        rawDb.execute('PRAGMA user_version = 5');
        rawDb.dispose();

        final db = AgentDatabase(
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        // Verify wake_run_log soul columns exist and are readable.
        final rows = await db
            .customSelect(
              'SELECT run_key, soul_id, soul_version_id FROM wake_run_log',
            )
            .get();
        expect(rows, hasLength(1));
        expect(rows.first.readNullable<String>('soul_id'), isNull);
        expect(rows.first.readNullable<String>('soul_version_id'), isNull);

        // Verify wake_run_log soul columns are writable.
        await db.customStatement('''
          UPDATE wake_run_log
          SET soul_id = 'soul-001', soul_version_id = 'sv-001'
          WHERE run_key = 'run-soul'
        ''');

        final updated = await db
            .customSelect(
              'SELECT soul_id, soul_version_id FROM wake_run_log '
              "WHERE run_key = 'run-soul'",
            )
            .get();
        expect(updated.first.read<String>('soul_id'), 'soul-001');
        expect(updated.first.read<String>('soul_version_id'), 'sv-001');

        // Verify dedup: only the most recently inserted link survives.
        final activeLinks = await db
            .customSelect(
              'SELECT id FROM agent_links '
              "WHERE type = 'soul_assignment' AND deleted_at IS NULL",
            )
            .get();
        expect(activeLinks, hasLength(1));
        expect(activeLinks.first.read<String>('id'), 'link-new');

        // Verify unique index enforces one active soul per template.
        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_unique_soul_per_template'",
            )
            .get();
        expect(indexes, hasLength(1));

        // A second active soul_assignment for the same template must fail.
        expect(
          () async => db.customStatement('''
            INSERT INTO agent_links
              (id, from_id, to_id, type, created_at, updated_at,
               serialized, schema_version)
            VALUES
              ('link-dup', 'tpl-1', 'soul-C', 'soul_assignment',
               '2026-03-01', '2026-03-01', '{}', 1)
          '''),
          throwsA(isA<SqliteException>()),
        );

        await db.close();
      },
    );

    test('v8 to latest adds active agent read indexes', () async {
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
            schema_version INTEGER NOT NULL DEFAULT 1,
            UNIQUE(from_id, to_id, type)
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
            resolved_model_id TEXT,
            soul_id TEXT,
            soul_version_id TEXT,
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
        ''')
        ..execute('PRAGMA user_version = 8');
      rawDb.dispose();

      final db = AgentDatabase(
        background: false,
        documentsDirectoryProvider: () async => testDirectory,
        tempDirectoryProvider: () async => testDirectory,
      );
      addTearDown(db.close);

      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), db.schemaVersion);

      final indexes = await db.customSelect('''
            SELECT name FROM sqlite_master WHERE type = 'index'
            AND name IN (
              'idx_agent_entities_active_agent_type_created_id',
              'idx_agent_entities_active_agent_type_sub_created_id',
              'idx_agent_entities_active_type_created',
              'idx_agent_links_active_to_type'
            )
            ORDER BY name
          ''').get();

      expect(
        indexes.map((row) => row.read<String>('name')).toList(),
        [
          'idx_agent_entities_active_agent_type_created_id',
          'idx_agent_entities_active_agent_type_sub_created_id',
          'idx_agent_entities_active_type_created',
          'idx_agent_links_active_to_type',
        ],
      );

      await db.close();
    });

    test(
      'v9 to latest replaces active agent/type index with ranked variants',
      () async {
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
          // A real v9 database always has agent_links (created at v1); the
          // v11 migration rebuilds it, so the fixture must include it.
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
              schema_version INTEGER NOT NULL DEFAULT 1,
              UNIQUE(from_id, to_id, type)
            )
          ''')
          ..execute(
            'CREATE INDEX idx_agent_entities_active_agent_type_created '
            'ON agent_entities(agent_id, type, created_at DESC) '
            'WHERE deleted_at IS NULL',
          )
          ..execute(
            'CREATE INDEX idx_agent_entities_active_type_created '
            'ON agent_entities(type, created_at DESC) '
            'WHERE deleted_at IS NULL',
          )
          ..execute('PRAGMA user_version = 9');
        rawDb.dispose();

        final db = AgentDatabase(
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        final indexes = await db.customSelect('''
              SELECT name FROM sqlite_master WHERE type = 'index'
              AND name IN (
                'idx_agent_entities_active_agent_type_created',
                'idx_agent_entities_active_agent_type_created_id',
                'idx_agent_entities_active_agent_type_sub_created_id'
              )
              ORDER BY name
            ''').get();

        expect(
          indexes.map((row) => row.read<String>('name')).toList(),
          [
            'idx_agent_entities_active_agent_type_created_id',
            'idx_agent_entities_active_agent_type_sub_created_id',
          ],
        );

        await db.close();
      },
    );

    test(
      'v10 to v11 rebuilds agent_links so capture events can share a '
      'payload while assignment links stay unique',
      () async {
        // The production bug (2026-06-04): two task entries rendering
        // byte-identical content share one content-addressed payload, but the
        // table-level UNIQUE(from_id, to_id, type) forbade the second
        // message_payload link → SqliteException 2067 → every capture failed.
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
              schema_version INTEGER NOT NULL DEFAULT 1,
              UNIQUE(from_id, to_id, type)
            )
          ''')
          ..execute(
            'CREATE UNIQUE INDEX idx_unique_improver_per_template '
            "ON agent_links(to_id) WHERE type = 'improver_target' "
            'AND deleted_at IS NULL',
          )
          ..execute(
            'CREATE UNIQUE INDEX idx_unique_soul_per_template '
            "ON agent_links(from_id) WHERE type = 'soul_assignment' "
            'AND deleted_at IS NULL',
          )
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
              resolved_model_id TEXT,
              soul_id TEXT,
              soul_version_id TEXT,
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
          ''')
          // Pre-existing rows that must survive the table rebuild: one
          // capture link and one soul assignment.
          ..execute(
            'INSERT INTO agent_links '
            '(id, from_id, to_id, type, created_at, updated_at, serialized) '
            "VALUES ('link-1', 'agent-1', 'sha256-v1:abc', "
            "'message_payload', 1, 1, '{}')",
          )
          ..execute(
            'INSERT INTO agent_links '
            '(id, from_id, to_id, type, created_at, updated_at, serialized) '
            "VALUES ('link-2', 'tpl-1', 'soul-1', "
            "'soul_assignment', 1, 1, '{}')",
          )
          ..execute('PRAGMA user_version = 10');
        rawDb.dispose();

        final db = AgentDatabase(
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        // Rows survived the rebuild.
        final ids = await db
            .customSelect('SELECT id FROM agent_links ORDER BY id')
            .get();
        expect(
          ids.map((row) => row.read<String>('id')).toList(),
          ['link-1', 'link-2'],
        );

        // The regression: a SECOND capture link from the same agent to the
        // same payload digest (different provenance) now inserts cleanly.
        await db.customStatement(
          'INSERT INTO agent_links '
          '(id, from_id, to_id, type, created_at, updated_at, serialized) '
          "VALUES ('link-3', 'agent-1', 'sha256-v1:abc', "
          "'message_payload', 2, 2, '{}')",
        );

        // Assignment-style links keep natural-key uniqueness.
        await expectLater(
          db.customStatement(
            'INSERT INTO agent_links '
            '(id, from_id, to_id, type, created_at, updated_at, serialized) '
            "VALUES ('link-4', 'tpl-1', 'soul-1', "
            "'soul_assignment', 2, 2, '{}')",
          ),
          throwsA(isA<SqliteException>()),
        );

        // Recreated indexes, including the new partial unique.
        final indexes = await db.customSelect('''
              SELECT name FROM sqlite_master WHERE type = 'index'
              AND tbl_name = 'agent_links' AND name LIKE 'idx_%'
              ORDER BY name
            ''').get();
        expect(
          indexes.map((row) => row.read<String>('name')).toList(),
          containsAll(<String>[
            'idx_agent_links_from',
            'idx_agent_links_to',
            'idx_agent_links_type',
            'idx_agent_links_active_from_type_to',
            'idx_agent_links_active_to_type',
            'idx_agent_links_unique_from_to_type',
            'idx_unique_improver_per_template',
            'idx_unique_soul_per_template',
          ]),
        );

        await db.close();
      },
    );

    test(
      'v12 to v13 adds standing agreement projection table and indexes',
      () async {
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
            CREATE TABLE attention_claim_index (
              request_id TEXT NOT NULL PRIMARY KEY,
              agent_id TEXT NOT NULL,
              status TEXT NOT NULL,
              scope_kind TEXT NOT NULL,
              visibility_start DATETIME NOT NULL,
              visibility_end DATETIME NOT NULL,
              deadline DATETIME,
              next_review_at DATETIME,
              target_id TEXT,
              target_kind TEXT,
              updated_at DATETIME NOT NULL,
              deleted_at DATETIME
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
              resolved_model_id TEXT,
              soul_id TEXT,
              soul_version_id TEXT,
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
          ''')
          ..execute('PRAGMA user_version = 12');
        rawDb.dispose();

        final db = AgentDatabase(
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        final tables = await db.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type = 'table' AND name = 'standing_agreement_index'
        ''').get();
        expect(tables, hasLength(1));

        final indexes = await db.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type = 'index'
            AND tbl_name = 'standing_agreement_index'
          ORDER BY name
        ''').get();
        expect(
          indexes.map((row) => row.read<String>('name')).toList(),
          containsAll(<String>[
            'idx_standing_agreements_active_window',
            'idx_standing_agreements_active_scope_window',
          ]),
        );

        await db.customStatement('''
          INSERT INTO standing_agreement_index (
            agreement_id,
            agent_id,
            status,
            scope,
            cadence,
            approval_mode,
            enforcement,
            active_from,
            active_until,
            priority,
            updated_at
          )
          VALUES (
            'agreement-1',
            'fitness-agent-1',
            'active',
            'fitness',
            'weekly',
            'ask',
            'target',
            '2026-05-01',
            '2026-06-01',
            10,
            '2026-05-01'
          )
        ''');

        final rows = await db.customSelect('''
          SELECT agreement_id FROM standing_agreement_index
          WHERE status = 'active'
            AND scope = 'fitness'
            AND active_from < '2026-05-28'
            AND active_until > '2026-05-27'
        ''').get();
        expect(rows.map((row) => row.read<String>('agreement_id')), [
          'agreement-1',
        ]);

        await db.close();
      },
    );

    test(
      'v13 to v14 adds active attention target lookup index',
      () async {
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
            CREATE TABLE attention_claim_index (
              request_id TEXT NOT NULL PRIMARY KEY,
              agent_id TEXT NOT NULL,
              status TEXT NOT NULL,
              scope_kind TEXT NOT NULL,
              visibility_start DATETIME NOT NULL,
              visibility_end DATETIME NOT NULL,
              deadline DATETIME,
              next_review_at DATETIME,
              target_id TEXT,
              target_kind TEXT,
              updated_at DATETIME NOT NULL,
              deleted_at DATETIME
            )
          ''')
          ..execute('''
            CREATE TABLE standing_agreement_index (
              agreement_id TEXT NOT NULL PRIMARY KEY,
              agent_id TEXT NOT NULL,
              status TEXT NOT NULL,
              scope TEXT NOT NULL,
              cadence TEXT NOT NULL,
              approval_mode TEXT NOT NULL,
              enforcement TEXT NOT NULL,
              active_from DATETIME NOT NULL,
              active_until DATETIME NOT NULL,
              priority INTEGER NOT NULL,
              target_id TEXT,
              target_kind TEXT,
              updated_at DATETIME NOT NULL,
              deleted_at DATETIME
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
              resolved_model_id TEXT,
              soul_id TEXT,
              soul_version_id TEXT,
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
          ''')
          ..execute('PRAGMA user_version = 13');
        rawDb.dispose();

        final db = AgentDatabase(
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        final indexes = await db.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type = 'index'
            AND tbl_name = 'attention_claim_index'
          ORDER BY name
        ''').get();
        expect(
          indexes.map((row) => row.read<String>('name')),
          contains('idx_attention_claims_active_target'),
        );

        await db.customStatement('''
          INSERT INTO attention_claim_index (
            request_id,
            agent_id,
            status,
            scope_kind,
            visibility_start,
            visibility_end,
            target_id,
            target_kind,
            updated_at
          )
          VALUES (
            'request-1',
            'task-agent-1',
            'open',
            'dateRange',
            '2026-05-27',
            '2026-05-28',
            'task-1',
            'task',
            '2026-05-27'
          )
        ''');

        final plan = await db.customSelect('''
          EXPLAIN QUERY PLAN
          SELECT request_id
          FROM attention_claim_index
          WHERE target_kind = 'task'
            AND target_id = 'task-1'
            AND status = 'open'
            AND deleted_at IS NULL
        ''').get();
        expect(
          plan.map((row) => row.read<String>('detail')).join('\n'),
          contains('idx_attention_claims_active_target'),
        );

        await db.close();
      },
    );
  });

  group('AgentDatabase fresh install', () {
    test(
      'two capture links may share a payload digest; assignment links '
      'keep natural-key uniqueness',
      () async {
        final db = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
          documentsDirectoryProvider: () async => testDirectory,
          tempDirectoryProvider: () async => testDirectory,
        );
        addTearDown(db.close);

        // Two sources rendering identical content → one shared payload,
        // two links (ADR 0020). Must not violate any unique constraint.
        await db.customStatement(
          'INSERT INTO agent_links '
          '(id, from_id, to_id, type, created_at, updated_at, serialized) '
          "VALUES ('link-1', 'agent-1', 'sha256-v1:abc', "
          "'message_payload', 1, 1, '{}')",
        );
        await db.customStatement(
          'INSERT INTO agent_links '
          '(id, from_id, to_id, type, created_at, updated_at, serialized) '
          "VALUES ('link-2', 'agent-1', 'sha256-v1:abc', "
          "'message_payload', 2, 2, '{}')",
        );

        await db.customStatement(
          'INSERT INTO agent_links '
          '(id, from_id, to_id, type, created_at, updated_at, serialized) '
          "VALUES ('link-3', 'agent-1', 'task-1', "
          "'agent_task', 1, 1, '{}')",
        );
        await expectLater(
          db.customStatement(
            'INSERT INTO agent_links '
            '(id, from_id, to_id, type, created_at, updated_at, serialized) '
            "VALUES ('link-4', 'agent-1', 'task-1', "
            "'agent_task', 2, 2, '{}')",
          ),
          throwsA(isA<SqliteException>()),
        );

        await db.close();
      },
    );

    test(
      'idx_wake_run_log_created_at exists so getWakeRunsInWindow can '
      'walk the range in `created_at` order instead of `SCAN '
      'wake_run_log` + temp B-tree (2026-05-10 desktop super_slow log: '
      '11 hits/day at 305-408 ms before the index was added)',
      () async {
        final db = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        addTearDown(db.close);

        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_wake_run_log_created_at'",
            )
            .get();
        expect(indexes, hasLength(1));

        // Seed enough rows that the planner can choose between
        // SCAN and the new index — ANALYZE so the choice is
        // cost-based on real stats.
        for (var i = 0; i < 60; i++) {
          // Use raw seconds-since-epoch — drift stores `DateTime`
          // columns as INTEGER, so the planner's range filter works
          // on integer comparisons. Passing a Dart `DateTime` to
          // `customStatement` won't bind; pass the same int value
          // that drift would have written.
          final ts =
              DateTime(
                2026,
                1,
                2,
              ).add(Duration(minutes: i)).millisecondsSinceEpoch ~/
              1000;
          await db.customStatement(
            'INSERT INTO wake_run_log '
            '(run_key, agent_id, reason, thread_id, status, created_at) '
            "VALUES ('run-$i', 'agent-A', 'test', 'thread-$i', 'ok', ?)",
            [ts],
          );
        }
        await db.customStatement('ANALYZE');

        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT * FROM wake_run_log '
              'WHERE created_at >= ?1 AND created_at <= ?2 '
              'ORDER BY created_at DESC',
              variables: [
                Variable<DateTime>(DateTime(2026, 1, 2)),
                Variable<DateTime>(DateTime(2026, 1, 3)),
              ],
            )
            .get();
        final details = plan.map((r) => r.data.toString()).join('\n');

        expect(
          details,
          contains('idx_wake_run_log_created_at'),
          reason:
              'created_at window query must use the dedicated index '
              'instead of falling back to a base-table scan',
        );
        expect(
          details,
          isNot(matches(RegExp('SCAN wake_run_log(?! USING)'))),
          reason: 'must not regress to a full base-table scan',
        );
        expect(
          details,
          isNot(contains('USE TEMP B-TREE FOR ORDER BY')),
          reason:
              'the (created_at DESC) index already provides the sort '
              'order — no temp B-tree should appear',
        );
      },
    );

    test('active agent indexes support slow-query hot paths', () async {
      final db = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      addTearDown(db.close);

      final indexes = await db.customSelect('''
            SELECT name FROM sqlite_master WHERE type = 'index'
            AND name IN (
              'idx_agent_entities_active_agent_type_created_id',
              'idx_agent_entities_active_agent_type_sub_created_id',
              'idx_agent_entities_active_type_created',
              'idx_agent_links_active_to_type'
            )
            ORDER BY name
          ''').get();
      expect(
        indexes.map((row) => row.read<String>('name')).toList(),
        [
          'idx_agent_entities_active_agent_type_created_id',
          'idx_agent_entities_active_agent_type_sub_created_id',
          'idx_agent_entities_active_type_created',
          'idx_agent_links_active_to_type',
        ],
      );

      for (var i = 0; i < 80; i++) {
        final ts =
            DateTime(
              2026,
              5,
            ).add(Duration(minutes: i)).millisecondsSinceEpoch ~/
            1000;
        final type = i.isEven ? 'agent' : 'agentTemplate';
        final deletedAt = i % 10 == 0 ? ts + 60 : null;
        await db.customStatement(
          'INSERT INTO agent_entities '
          '(id, agent_id, type, created_at, updated_at, deleted_at, '
          'serialized, schema_version) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
          [
            'entity-$i',
            'agent-${i % 4}',
            type,
            ts,
            ts,
            deletedAt,
            '{}',
          ],
        );
        await db.customStatement(
          'INSERT INTO agent_links '
          '(id, from_id, to_id, type, created_at, updated_at, deleted_at, '
          'serialized, schema_version) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)',
          [
            'link-$i',
            'agent-$i',
            'task-${i % 4}',
            'agent_task',
            ts,
            ts,
            deletedAt,
            '{}',
          ],
        );
      }
      for (var agentIndex = 0; agentIndex < 25; agentIndex++) {
        for (var revision = 0; revision < 4; revision++) {
          final ts =
              DateTime(
                2026,
                5,
                24,
              ).add(Duration(minutes: revision)).millisecondsSinceEpoch ~/
              1000;
          await db.customStatement(
            'INSERT INTO agent_entities '
            '(id, agent_id, type, subtype, created_at, updated_at, '
            'serialized, schema_version) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
            [
              'report-head-$agentIndex-$revision',
              'report-agent-$agentIndex',
              'agentReportHead',
              'current',
              ts,
              ts,
              '{}',
            ],
          );
        }
      }
      await db.customStatement('ANALYZE');

      final globalTypePlan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN '
            'SELECT * FROM agent_entities '
            'WHERE type = ?1 AND deleted_at IS NULL '
            'ORDER BY created_at DESC',
            variables: [const Variable<String>('agent')],
          )
          .get();
      final globalTypeDetails = globalTypePlan
          .map((r) => r.data.toString())
          .join('\n');
      expect(
        globalTypeDetails,
        contains('idx_agent_entities_active_type_created'),
      );
      expect(
        globalTypeDetails,
        isNot(contains('USE TEMP B-TREE FOR ORDER BY')),
      );

      final agentTypePlan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN '
            'SELECT * FROM agent_entities '
            'WHERE agent_id = ?1 AND type = ?2 AND deleted_at IS NULL '
            'ORDER BY created_at DESC LIMIT ?3',
            variables: [
              const Variable<String>('agent-1'),
              const Variable<String>('agentTemplate'),
              const Variable<int>(10),
            ],
          )
          .get();
      final agentTypeDetails = agentTypePlan
          .map((r) => r.data.toString())
          .join('\n');
      expect(
        agentTypeDetails,
        contains('idx_agent_entities_active_agent_type_created_id'),
      );
      expect(agentTypeDetails, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));

      Future<String> explainLatestByAgentIds({String? subtype}) async {
        final agentIds = [
          for (var agentIndex = 0; agentIndex < 25; agentIndex++)
            'report-agent-$agentIndex',
        ];
        final placeholders = List.filled(agentIds.length, '?').join(', ');
        final subtypePredicate = subtype == null ? '' : 'AND subtype = ? ';
        final plan = await db
            .customSelect(
              '''
                EXPLAIN QUERY PLAN
                SELECT id, agent_id, type, subtype, thread_id, created_at,
                  updated_at, deleted_at, serialized, schema_version
                FROM (
                  SELECT agent_entities.*,
                    ROW_NUMBER() OVER (
                      PARTITION BY agent_id
                      ORDER BY created_at DESC, id DESC
                    ) AS rn
                  FROM agent_entities
                  WHERE agent_id IN ($placeholders)
                    AND type = ?
                    $subtypePredicate
                    AND deleted_at IS NULL
                )
                WHERE rn = 1
              ''',
              variables: [
                ...agentIds.map(Variable<String>.new),
                const Variable<String>('agentReportHead'),
                if (subtype != null) Variable<String>(subtype),
              ],
            )
            .get();
        return plan.map((r) => r.data.toString()).join('\n');
      }

      final latestPlanDetails = await explainLatestByAgentIds();
      expect(
        latestPlanDetails,
        contains('idx_agent_entities_active_agent_type_created_id'),
      );
      expect(
        latestPlanDetails,
        isNot(contains('USE TEMP B-TREE')),
      );

      final latestSubtypePlanDetails = await explainLatestByAgentIds(
        subtype: 'current',
      );
      expect(
        latestSubtypePlanDetails,
        contains('idx_agent_entities_active_agent_type_sub_created_id'),
      );
      expect(
        latestSubtypePlanDetails,
        isNot(contains('USE TEMP B-TREE')),
      );

      final linkPlan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN '
            'SELECT * FROM agent_links '
            'WHERE to_id = ?1 AND type = ?2 AND deleted_at IS NULL',
            variables: [
              const Variable<String>('task-1'),
              const Variable<String>('agent_task'),
            ],
          )
          .get();
      final linkDetails = linkPlan.map((r) => r.data.toString()).join('\n');
      expect(linkDetails, contains('idx_agent_links_active_to_type'));
    });

    test('creates idx_unique_soul_per_template index on new DB', () async {
      final db = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      addTearDown(db.close);

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_unique_soul_per_template'",
          )
          .get();
      expect(indexes, hasLength(1));

      // Verify it enforces one active soul per template.
      await db.customStatement('''
        INSERT INTO agent_links
          (id, from_id, to_id, type, created_at, updated_at,
           serialized, schema_version)
        VALUES
          ('link-1', 'tpl-1', 'soul-A', 'soul_assignment',
           '2026-01-01', '2026-01-01', '{}', 1)
      ''');

      expect(
        () async => db.customStatement('''
          INSERT INTO agent_links
            (id, from_id, to_id, type, created_at, updated_at,
             serialized, schema_version)
          VALUES
            ('link-2', 'tpl-1', 'soul-B', 'soul_assignment',
             '2026-02-01', '2026-02-01', '{}', 1)
        '''),
        throwsA(isA<SqliteException>()),
      );

      await db.close();
    });

    test('creates soul_id and soul_version_id columns on new DB', () async {
      final db = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      addTearDown(db.close);

      // Verify columns exist by inserting and querying.
      await db.customStatement('''
        INSERT INTO wake_run_log
          (run_key, agent_id, reason, thread_id, status, created_at,
           soul_id, soul_version_id)
        VALUES
          ('run-fresh', 'agent-1', 'trigger', 'thread-1', 'pending',
           '2026-04-06 10:00:00', 'soul-001', 'sv-001')
      ''');

      final rows = await db
          .customSelect(
            'SELECT soul_id, soul_version_id FROM wake_run_log '
            "WHERE run_key = 'run-fresh'",
          )
          .get();
      expect(rows.first.read<String>('soul_id'), 'soul-001');
      expect(rows.first.read<String>('soul_version_id'), 'sv-001');

      await db.close();
    });
  });

  group('AgentDatabase streaming and counting', () {
    late AgentDatabase db;

    setUp(() {
      db = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertAgentEntity({
      required String id,
      required String serialized,
    }) async {
      await db.customStatement('''
        INSERT INTO agent_entities
          (id, agent_id, type, created_at, updated_at, serialized,
           schema_version)
        VALUES
          ('$id', 'agent-1', 'agentMessage',
           '2026-01-01', '2026-01-01', '$serialized', 1)
      ''');
    }

    Future<void> insertAgentLink({
      required String id,
      required String serialized,
      String? deletedAt,
    }) async {
      final deletedClause = deletedAt != null ? "'$deletedAt'" : 'NULL';
      await db.customStatement('''
        INSERT INTO agent_links
          (id, from_id, to_id, type, created_at, updated_at, deleted_at,
           serialized, schema_version)
        VALUES
          ('$id', 'from-1', 'to-$id', 'some_type',
           '2026-01-01', '2026-01-01', $deletedClause, '$serialized', 1)
      ''');
    }

    test(
      'streamAgentEntitiesWithVectorClock yields entities with VCs',
      () async {
        await insertAgentEntity(
          id: 'e-1',
          serialized: '{"vectorClock":{"host-a":1,"host-b":2}}',
        );
        await insertAgentEntity(
          id: 'e-2',
          serialized: '{"vectorClock":{"host-a":3}}',
        );

        final batches = await db
            .streamAgentEntitiesWithVectorClock(batchSize: 10)
            .toList();

        expect(batches, hasLength(1));
        final records = batches.first;
        expect(records, hasLength(2));

        final e1 = records.firstWhere((r) => r.id == 'e-1');
        expect(e1.vectorClock, {'host-a': 1, 'host-b': 2});

        final e2 = records.firstWhere((r) => r.id == 'e-2');
        expect(e2.vectorClock, {'host-a': 3});
      },
    );

    test('streamAgentEntitiesWithVectorClock handles null VC', () async {
      await insertAgentEntity(
        id: 'e-1',
        serialized: '{"type":"agentMessage"}',
      );

      final batches = await db
          .streamAgentEntitiesWithVectorClock(batchSize: 10)
          .toList();

      expect(batches, hasLength(1));
      expect(batches.first.first.vectorClock, isNull);
    });

    test('streamAgentEntitiesWithVectorClock paginates batches', () async {
      for (var i = 0; i < 5; i++) {
        await insertAgentEntity(
          id: 'e-$i',
          serialized: '{"vectorClock":{"host-a":$i}}',
        );
      }

      final batches = await db
          .streamAgentEntitiesWithVectorClock(batchSize: 2)
          .toList();

      // 5 entities / batchSize 2 = 3 batches (2, 2, 1)
      expect(batches, hasLength(3));
      expect(batches[0], hasLength(2));
      expect(batches[1], hasLength(2));
      expect(batches[2], hasLength(1));
    });

    test('streamAgentLinksWithVectorClock yields links with VCs', () async {
      await insertAgentLink(
        id: 'l-1',
        serialized: '{"vectorClock":{"host-a":10,"host-b":20}}',
      );
      await insertAgentLink(
        id: 'l-2',
        serialized: '{"vectorClock":{"host-c":5}}',
      );

      final batches = await db
          .streamAgentLinksWithVectorClock(batchSize: 10)
          .toList();

      expect(batches, hasLength(1));
      final records = batches.first;
      expect(records, hasLength(2));

      final l1 = records.firstWhere((r) => r.id == 'l-1');
      expect(l1.vectorClock, {'host-a': 10, 'host-b': 20});

      final l2 = records.firstWhere((r) => r.id == 'l-2');
      expect(l2.vectorClock, {'host-c': 5});
    });

    test('streamAgentLinksWithVectorClock handles null VC', () async {
      await insertAgentLink(
        id: 'l-1',
        serialized: '{"type":"some_type"}',
      );

      final batches = await db
          .streamAgentLinksWithVectorClock(batchSize: 10)
          .toList();

      expect(batches, hasLength(1));
      expect(batches.first.first.vectorClock, isNull);
    });

    test('countAllAgentEntities returns correct count', () async {
      expect(await db.countAllAgentEntities(), 0);

      await insertAgentEntity(
        id: 'e-1',
        serialized: '{"vectorClock":{"host-a":1}}',
      );
      await insertAgentEntity(
        id: 'e-2',
        serialized: '{"vectorClock":{"host-a":2}}',
      );

      expect(await db.countAllAgentEntities(), 2);
    });

    test('countAllAgentLinks returns correct count', () async {
      expect(await db.countAllAgentLinks(), 0);

      await insertAgentLink(
        id: 'l-1',
        serialized: '{"vectorClock":{"host-a":1}}',
      );
      await insertAgentLink(
        id: 'l-2',
        serialized: '{"vectorClock":{"host-a":2}}',
      );

      expect(await db.countAllAgentLinks(), 2);
    });

    test('_extractVectorClock handles invalid JSON gracefully', () async {
      await insertAgentEntity(
        id: 'e-bad',
        serialized: 'not-json',
      );

      final batches = await db
          .streamAgentEntitiesWithVectorClock(batchSize: 10)
          .toList();

      expect(batches, hasLength(1));
      expect(batches.first.first.vectorClock, isNull);
    });

    test('_extractVectorClock handles non-numeric VC values', () async {
      await insertAgentEntity(
        id: 'e-bad',
        serialized: '{"vectorClock":{"host-a":"not-a-number"}}',
      );

      final batches = await db
          .streamAgentEntitiesWithVectorClock(batchSize: 10)
          .toList();

      expect(batches, hasLength(1));
      expect(batches.first.first.vectorClock, isNull);
    });
  });
}
