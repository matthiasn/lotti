// ignore_for_file: cascade_invocations
import 'dart:io';

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

        // Verify schema version is now 6 (latest).
        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          6,
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

      // Verify schema version is now 6 (latest).
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        6,
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

      // Verify schema version is now 6 (latest).
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(
        versionResult.first.read<int>('user_version'),
        6,
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
          6,
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
          6,
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
  });

  group('AgentDatabase fresh install', () {
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
