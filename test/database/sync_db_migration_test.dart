// ignore_for_file: avoid_redundant_argument_values, cascade_invocations
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as path;
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

    // Create a test directory and mock path_provider to return it
    testDirectory = Directory.systemTemp.createTempSync(
      'lotti_sync_migration_test_',
    );

    // Mock path_provider to return our test directory
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

  group('SyncDatabase Migration Tests', () {
    test(
      'v2 migration creates sync_sequence_log and host_activity tables',
      () async {
        // Create a v1 database with only the outbox table
        final dbFile = File(path.join(testDirectory!.path, 'test_sync_v2.db'));
        final sqlite = sqlite3.open(dbFile.path);

        // Create the v1 schema (only outbox table)
        sqlite.execute('''
        CREATE TABLE IF NOT EXISTS outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          retries INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL,
          subject TEXT NOT NULL,
          file_path TEXT
        )
      ''');

        // Insert some test data to verify it survives migration
        sqlite.execute('''
        INSERT INTO outbox (created_at, updated_at, status, retries, message, subject)
        VALUES (1704067200000, 1704067200000, 0, 0, '{"test": true}', 'test-subject')
      ''');

        // Set schema version to 1
        sqlite.execute('PRAGMA user_version = 1');

        // Close raw connection
        sqlite.dispose();

        // Open with SyncDatabase to trigger migration
        final db = SyncDatabase(overriddenFilename: 'test_sync_v2.db');

        // Verify the migration occurred by checking schema version
        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), db.schemaVersion);
        expect(db.schemaVersion, 14);

        // Verify sync_sequence_log table exists and has correct schema
        final seqLogResult = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='sync_sequence_log'",
            )
            .get();
        expect(seqLogResult, hasLength(1));
        final seqLogSql = seqLogResult.first.read<String>('sql');
        expect(seqLogSql, contains('sync_sequence_log'));
        expect(seqLogSql, contains('host_id'));
        expect(seqLogSql, contains('counter'));
        expect(seqLogSql, contains('entry_id'));
        expect(seqLogSql, contains('status'));
        expect(seqLogSql, contains('request_count'));
        expect(seqLogSql, contains('payload_type')); // Added in v3

        // Verify host_activity table exists
        final hostActivityResult = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='host_activity'",
            )
            .get();
        expect(hostActivityResult, hasLength(1));
        final hostActivitySql = hostActivityResult.first.read<String>('sql');
        expect(hostActivitySql, contains('host_activity'));
        expect(hostActivitySql, contains('host_id'));
        expect(hostActivitySql, contains('last_seen_at'));

        // Verify existing outbox data survived the migration
        final outboxItems = await db.oldestOutboxItems(10);
        expect(outboxItems, hasLength(1));
        expect(outboxItems.first.subject, 'test-subject');
        expect(outboxItems.first.message, '{"test": true}');

        await db.close();
      },
    );

    test('fresh install creates all tables correctly', () async {
      // Just open a new database - this should use onCreate
      final db = SyncDatabase(overriddenFilename: 'test_fresh_install.db');

      // Verify schema version
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 14);

      // Verify all tables exist
      final tablesResult = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('outbox', 'sync_sequence_log', 'host_activity')",
          )
          .get();
      expect(tablesResult, hasLength(3));

      final tableNames = tablesResult
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(tableNames, contains('outbox'));
      expect(tableNames, contains('sync_sequence_log'));
      expect(tableNames, contains('host_activity'));

      final indexResults = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name IN ( "
            "'idx_outbox_status_priority_created_at', "
            "'idx_sync_sequence_log_actionable_status_created_at', "
            "'idx_sync_sequence_log_payload_resolution', "
            "'idx_sync_sequence_log_host_entry_status_counter')",
          )
          .get();
      final indexNames = indexResults
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        indexNames,
        containsAll(<String>{
          'idx_outbox_status_priority_created_at',
          'idx_sync_sequence_log_actionable_status_created_at',
          'idx_sync_sequence_log_payload_resolution',
          'idx_sync_sequence_log_host_entry_status_counter',
        }),
      );

      await db.close();
    });

    test('v2 tables can be used after migration', () async {
      // Create a v1 database
      final dbFile = File(path.join(testDirectory!.path, 'test_usage.db'));
      final sqlite = sqlite3.open(dbFile.path);

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          retries INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL,
          subject TEXT NOT NULL,
          file_path TEXT
        )
      ''');
      sqlite.execute('PRAGMA user_version = 1');
      sqlite.dispose();

      // Open with SyncDatabase to trigger migration
      final db = SyncDatabase(overriddenFilename: 'test_usage.db');

      // Test that we can use the new sync_sequence_log table
      await db.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('test-host'),
          counter: const Value(1),
          entryId: const Value('entry-1'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final entry = await db.getEntryByHostAndCounter('test-host', 1);
      expect(entry, isNotNull);
      expect(entry!.hostId, 'test-host');
      expect(entry.counter, 1);
      expect(entry.entryId, 'entry-1');

      // Test that we can use the new host_activity table
      await db.updateHostActivity('test-host', DateTime(2024, 1, 1));

      final lastSeen = await db.getHostLastSeen('test-host');
      expect(lastSeen, DateTime(2024, 1, 1));

      await db.close();
    });

    test('v5 migration adds payload_size column to outbox', () async {
      // Create a v4 database with the outbox table lacking payload_size
      final dbFile = File(path.join(testDirectory!.path, 'test_sync_v5.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // v4 schema: outbox with outbox_entry_id but no payload_size
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          retries INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL,
          subject TEXT NOT NULL,
          file_path TEXT,
          outbox_entry_id TEXT
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS sync_sequence_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          host_id TEXT NOT NULL,
          counter INTEGER NOT NULL,
          entry_id TEXT NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          request_count INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          payload_type TEXT
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS host_activity (
          host_id TEXT NOT NULL PRIMARY KEY,
          last_seen_at INTEGER NOT NULL,
          last_requested_at INTEGER
        )
      ''');

      // Insert a v4 row (no payload_size column)
      final createdAtSeconds =
          DateTime(2024, 6, 15).millisecondsSinceEpoch ~/ 1000;
      sqlite.execute('''
        INSERT INTO outbox (created_at, updated_at, status, retries, message, subject)
        VALUES ($createdAtSeconds, $createdAtSeconds, 0, 0, '{"v4": true}', 'v4-subject')
      ''');

      sqlite.execute('PRAGMA user_version = 4');
      sqlite.dispose();

      // Open with SyncDatabase to trigger v4→v5 migration
      final db = SyncDatabase(overriddenFilename: 'test_sync_v5.db');

      // Verify schema version updated
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 14);

      // Verify existing row survived with null payload_size
      final items = await db.oldestOutboxItems(10);
      expect(items, hasLength(1));
      expect(items.first.subject, 'v4-subject');
      expect(items.first.payloadSize, isNull);

      // Verify payload_size column is usable
      await db.updateOutboxMessage(
        itemId: items.first.id,
        newMessage: '{"v5": true}',
        newSubject: 'v5-subject',
        payloadSize: 42,
      );
      final updated = await db.oldestOutboxItems(10);
      expect(updated.first.payloadSize, 42);

      await db.close();
    });

    test('v6 migration adds priority column to outbox', () async {
      // Create a v5 database with the outbox table lacking priority
      final dbFile = File(path.join(testDirectory!.path, 'test_sync_v6.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // v5 schema: outbox with payload_size but no priority
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          retries INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL,
          subject TEXT NOT NULL,
          file_path TEXT,
          outbox_entry_id TEXT,
          payload_size INTEGER
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS sync_sequence_log (
          host_id TEXT NOT NULL,
          counter INTEGER NOT NULL,
          entry_id TEXT,
          payload_type INTEGER NOT NULL DEFAULT 0,
          originating_host_id TEXT,
          status INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          request_count INTEGER NOT NULL DEFAULT 0,
          last_requested_at INTEGER,
          PRIMARY KEY (host_id, counter)
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS host_activity (
          host_id TEXT NOT NULL PRIMARY KEY,
          last_seen_at INTEGER NOT NULL
        )
      ''');

      // Insert a v5 row (no priority column)
      final createdAtSeconds =
          DateTime(2024, 8, 20).millisecondsSinceEpoch ~/ 1000;
      sqlite.execute('''
        INSERT INTO outbox (created_at, updated_at, status, retries, message, subject)
        VALUES ($createdAtSeconds, $createdAtSeconds, 0, 0, '{"v5": true}', 'v5-subject')
      ''');

      sqlite.execute('PRAGMA user_version = 5');
      sqlite.dispose();

      // Open with SyncDatabase to trigger v5→v6 migration
      final db = SyncDatabase(overriddenFilename: 'test_sync_v6.db');

      // Verify schema version updated
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 14);

      // Verify existing row survived with default priority=2 (low)
      final items = await db.oldestOutboxItems(10);
      expect(items, hasLength(1));
      expect(items.first.subject, 'v5-subject');
      expect(items.first.priority, OutboxPriority.low.index);

      // Verify priority column is usable
      await db.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"v6": true}'),
          subject: const Value('v6-high'),
          createdAt: Value(DateTime(2024, 8, 21)),
          updatedAt: Value(DateTime(2024, 8, 21)),
          priority: Value(OutboxPriority.high.index),
        ),
      );

      // The high-priority item should appear first
      final allItems = await db.oldestOutboxItems(10);
      expect(allItems, hasLength(2));
      expect(allItems.first.subject, 'v6-high');
      expect(allItems.first.priority, OutboxPriority.high.index);
      expect(allItems.last.subject, 'v5-subject');
      expect(allItems.last.priority, OutboxPriority.low.index);

      await db.close();
    });

    test('v8 migration adds sync sequence log indices', () async {
      final dbFile = File(path.join(testDirectory!.path, 'test_sync_v8.db'));
      final sqlite = sqlite3.open(dbFile.path);

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          retries INTEGER NOT NULL DEFAULT 0,
          message TEXT NOT NULL,
          subject TEXT NOT NULL,
          file_path TEXT,
          outbox_entry_id TEXT,
          payload_size INTEGER,
          priority INTEGER NOT NULL DEFAULT 2
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS sync_sequence_log (
          host_id TEXT NOT NULL,
          counter INTEGER NOT NULL,
          entry_id TEXT,
          payload_type INTEGER NOT NULL DEFAULT 0,
          originating_host_id TEXT,
          status INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          request_count INTEGER NOT NULL DEFAULT 0,
          last_requested_at INTEGER,
          json_path TEXT,
          PRIMARY KEY (host_id, counter)
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS host_activity (
          host_id TEXT NOT NULL PRIMARY KEY,
          last_seen_at INTEGER NOT NULL
        )
      ''');
      sqlite.execute('PRAGMA user_version = 7');
      sqlite.dispose();

      final db = SyncDatabase(overriddenFilename: 'test_sync_v8.db');

      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 14);

      final indexResults = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name IN ( "
            "'idx_outbox_status_priority_created_at', "
            "'idx_sync_sequence_log_actionable_status_created_at', "
            "'idx_sync_sequence_log_payload_resolution')",
          )
          .get();
      final indexNames = indexResults
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        indexNames,
        containsAll(<String>{
          'idx_outbox_status_priority_created_at',
          'idx_sync_sequence_log_actionable_status_created_at',
          'idx_sync_sequence_log_payload_resolution',
        }),
      );

      await db.close();
    });

    test(
      'v10 migration adds host_entry_status index when stepping v9 → v10 '
      'before the v11 swap',
      () async {
        final dbFile = File(path.join(testDirectory!.path, 'test_sync_v10.db'));
        final sqlite = sqlite3.open(dbFile.path);

        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            retries INTEGER NOT NULL DEFAULT 0,
            message TEXT NOT NULL,
            subject TEXT NOT NULL,
            file_path TEXT,
            outbox_entry_id TEXT,
            payload_size INTEGER,
            priority INTEGER NOT NULL DEFAULT 2
          )
        ''');
        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS sync_sequence_log (
            host_id TEXT NOT NULL,
            counter INTEGER NOT NULL,
            entry_id TEXT,
            payload_type INTEGER NOT NULL DEFAULT 0,
            originating_host_id TEXT,
            status INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            request_count INTEGER NOT NULL DEFAULT 0,
            last_requested_at INTEGER,
            json_path TEXT,
            PRIMARY KEY (host_id, counter)
          )
        ''');
        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS host_activity (
            host_id TEXT NOT NULL PRIMARY KEY,
            last_seen_at INTEGER NOT NULL
          )
        ''');
        // Pre-existing indices from v8/v9
        sqlite.execute(
          'CREATE INDEX idx_sync_sequence_log_actionable_status_created_at '
          'ON sync_sequence_log (status, created_at) '
          'WHERE status IN (1, 2)',
        );
        sqlite.execute(
          'CREATE INDEX idx_sync_sequence_log_payload_resolution '
          'ON sync_sequence_log (entry_id, payload_type, status) '
          'WHERE entry_id IS NOT NULL',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_status_priority_created_at '
          'ON outbox (status, priority, created_at)',
        );
        sqlite.execute('PRAGMA user_version = 9');
        sqlite.dispose();

        final db = SyncDatabase(overriddenFilename: 'test_sync_v10.db');

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 14);

        // v11 replaces the v10 index with the covering variant; when the
        // migration steps v9 → v11 in one run, the v10 index must no longer
        // exist (dropped by the v11 step) and the v11 covering index must
        // be present instead.
        final oldIndex = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_host_entry_status'",
            )
            .get();
        expect(oldIndex, isEmpty);

        final coveringIndex = await db
            .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_host_entry_status_counter'",
            )
            .get();
        expect(coveringIndex, hasLength(1));
        final indexSql = coveringIndex.first.readNullable<String>('sql');
        expect(indexSql, isNotNull);
        expect(indexSql, contains('host_id'));
        expect(indexSql, contains('entry_id'));
        expect(indexSql, contains('status'));
        expect(indexSql, contains('counter'));
        expect(indexSql, contains('WHERE'));
        // Column order matters for the `ORDER BY counter DESC LIMIT 1` plan
        // used by `getLastSentCounterForEntry`: counter must sit between the
        // `(host_id, entry_id)` equality prefix and the `status` filter.
        expect(
          indexSql,
          contains('host_id, entry_id, counter DESC, status'),
        );

        await db.close();
      },
    );

    test(
      'v11 migration drops the v10 prefix index and adds the covering '
      'counter index',
      () async {
        final dbFile = File(path.join(testDirectory!.path, 'test_sync_v11.db'));
        final sqlite = sqlite3.open(dbFile.path);

        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            retries INTEGER NOT NULL DEFAULT 0,
            message TEXT NOT NULL,
            subject TEXT NOT NULL,
            file_path TEXT,
            outbox_entry_id TEXT,
            payload_size INTEGER,
            priority INTEGER NOT NULL DEFAULT 2
          )
        ''');
        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS sync_sequence_log (
            host_id TEXT NOT NULL,
            counter INTEGER NOT NULL,
            entry_id TEXT,
            payload_type INTEGER NOT NULL DEFAULT 0,
            originating_host_id TEXT,
            status INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            request_count INTEGER NOT NULL DEFAULT 0,
            last_requested_at INTEGER,
            json_path TEXT,
            PRIMARY KEY (host_id, counter)
          )
        ''');
        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS host_activity (
            host_id TEXT NOT NULL PRIMARY KEY,
            last_seen_at INTEGER NOT NULL
          )
        ''');
        // Full v10 index set
        sqlite.execute(
          'CREATE INDEX idx_sync_sequence_log_actionable_status_created_at '
          'ON sync_sequence_log (status, created_at) '
          'WHERE status IN (1, 2)',
        );
        sqlite.execute(
          'CREATE INDEX idx_sync_sequence_log_payload_resolution '
          'ON sync_sequence_log (entry_id, payload_type, status) '
          'WHERE entry_id IS NOT NULL',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_status_priority_created_at '
          'ON outbox (status, priority, created_at)',
        );
        sqlite.execute(
          'CREATE INDEX idx_sync_sequence_log_host_entry_status '
          'ON sync_sequence_log (host_id, entry_id, status) '
          'WHERE entry_id IS NOT NULL',
        );
        sqlite.execute('PRAGMA user_version = 10');
        sqlite.dispose();

        final db = SyncDatabase(overriddenFilename: 'test_sync_v11.db');

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 14);

        final oldIndex = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_host_entry_status'",
            )
            .get();
        expect(
          oldIndex,
          isEmpty,
          reason: 'v11 migration must DROP the v10 prefix index',
        );

        final coveringIndex = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_host_entry_status_counter'",
            )
            .get();
        expect(coveringIndex, hasLength(1));
        final indexSql = coveringIndex.first.readNullable<String>('sql');
        expect(indexSql, isNotNull);
        expect(indexSql, contains('counter'));
        expect(
          indexSql,
          contains('host_id, entry_id, counter DESC, status'),
        );

        await db.close();
      },
    );
  });
}
