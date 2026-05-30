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
        expect(db.schemaVersion, 24);

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

        final watermarkResult = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' "
              "AND name='sync_sequence_watermarks'",
            )
            .get();
        expect(watermarkResult, hasLength(1));
        final watermarkSql = watermarkResult.first.read<String>('sql');
        expect(watermarkSql, contains('sync_sequence_watermarks'));
        expect(watermarkSql, contains('host_id'));
        expect(watermarkSql, contains('last_counter'));

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
      expect(versionResult.first.read<int>('user_version'), 24);

      // Verify all tables exist
      final tablesResult = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name IN ('outbox', 'sync_sequence_log', "
            "'sync_sequence_watermarks', 'host_activity')",
          )
          .get();
      expect(tablesResult, hasLength(4));

      final tableNames = tablesResult
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(tableNames, contains('outbox'));
      expect(tableNames, contains('sync_sequence_log'));
      expect(tableNames, contains('sync_sequence_watermarks'));
      expect(tableNames, contains('host_activity'));

      final indexResults = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name IN ( "
            "'idx_outbox_status_priority_created_at', "
            "'idx_outbox_actionable_priority_created_at', "
            "'idx_sync_sequence_log_actionable_status_created_at', "
            "'idx_sync_sequence_log_actionable_status_updated_at', "
            "'idx_sync_sequence_log_host_status', "
            "'idx_sync_sequence_log_resolved_host_counter', "
            "'idx_sync_sequence_log_payload_resolution', "
            "'idx_sync_sequence_log_host_entry_status_counter', "
            "'idx_inbound_event_queue_abandoned_reason', "
            "'idx_inbound_event_queue_active_status_room')",
          )
          .get();
      final indexNames = indexResults
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        indexNames,
        containsAll(<String>{
          'idx_outbox_status_priority_created_at',
          'idx_outbox_actionable_priority_created_at',
          'idx_sync_sequence_log_actionable_status_created_at',
          'idx_sync_sequence_log_actionable_status_updated_at',
          'idx_sync_sequence_log_host_status',
          'idx_sync_sequence_log_resolved_host_counter',
          'idx_sync_sequence_log_payload_resolution',
          'idx_sync_sequence_log_host_entry_status_counter',
          'idx_inbound_event_queue_abandoned_reason',
          'idx_inbound_event_queue_active_status_room',
        }),
      );
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_outbox_sending_expiry'",
            )
            .get(),
        isEmpty,
        reason:
            'fresh v23 databases drop the v21 updated_at-leading sending '
            'index after createAll so expired-lease reclaim cannot regress '
            'to a temp-sort plan',
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
          last_requested_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          payload_type TEXT
        )
      ''');
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS host_activity (
          host_id TEXT NOT NULL PRIMARY KEY,
          last_seen_at INTEGER NOT NULL
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
      expect(versionResult.first.read<int>('user_version'), 24);

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
      expect(versionResult.first.read<int>('user_version'), 24);

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

      // Polling is priority-first, then FIFO by createdAt within each
      // priority tier. The newly inserted high-priority row should drain
      // before the older low-priority v5 row, proving the migrated column
      // participates in dequeue order.
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
      expect(versionResult.first.read<int>('user_version'), 24);

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
        expect(versionResult.first.read<int>('user_version'), 24);

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
        expect(versionResult.first.read<int>('user_version'), 24);

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

    test(
      'v14 migration adds the active_ready_at partial index so the '
      "worker's `earliestReadyAt` probe turns from a full scan into "
      'an index seek over the (active-status) subset of the queue',
      () async {
        // Seed a v13 database with a barebones inbound_event_queue +
        // the v13 indexes so the migration only applies the v14 step.
        final dbFile = File(path.join(testDirectory!.path, 'test_sync_v14.db'));
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
        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS inbound_event_queue (
            queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id TEXT NOT NULL UNIQUE,
            room_id TEXT NOT NULL,
            origin_ts INTEGER NOT NULL,
            producer TEXT NOT NULL,
            raw_json TEXT NOT NULL,
            enqueued_at INTEGER NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_due_at INTEGER NOT NULL DEFAULT 0,
            lease_until INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'enqueued',
            committed_at INTEGER,
            abandoned_at INTEGER,
            last_error_reason TEXT,
            resurrection_count INTEGER NOT NULL DEFAULT 0,
            json_path TEXT
          )
        ''');
        sqlite.execute('''
          CREATE TABLE IF NOT EXISTS queue_markers (
            room_id TEXT NOT NULL PRIMARY KEY,
            last_applied_event_id TEXT,
            last_applied_ts INTEGER NOT NULL DEFAULT 0,
            last_applied_commit_seq INTEGER NOT NULL DEFAULT 0
          )
        ''');
        sqlite.execute('PRAGMA user_version = 13');
        sqlite.dispose();

        final db = SyncDatabase(overriddenFilename: 'test_sync_v14.db');

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 24);

        final ready = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_inbound_event_queue_active_ready_at'",
            )
            .get();
        expect(ready, hasLength(1));
        final indexSql = ready.first.readNullable<String>('sql');
        expect(indexSql, isNotNull);
        // The column order must match the `earliestReadyAt` predicate
        // exactly: `(next_due_at, lease_until)` so the MIN expression
        // over `MAX(next_due_at, lease_until)` can be satisfied
        // straight from index keys.
        expect(indexSql, contains('next_due_at, lease_until'));
        // Partial filter must cover exactly the three active statuses
        // that `earliestReadyAt` scans. Applied and abandoned rows
        // (which dominate the table on a steady-state client) must
        // stay out of the index.
        expect(indexSql, contains("'enqueued', 'retrying', 'leased'"));

        await db.close();
      },
    );

    test(
      'v20 migration keeps the literal-status pending partial index and '
      'drops the expired-sending partial so claim paths avoid '
      '`USE TEMP B-TREE FOR ORDER BY` (2026-05-12 desktop super_slow '
      'log: tails up to 6.0 s)',
      () async {
        final dbFile = File(path.join(testDirectory!.path, 'test_sync_v21.db'));
        final sqlite = sqlite3.open(dbFile.path);

        // Seed a v20 schema: outbox table + the pre-v21 indices, so the
        // migration's CREATE-INDEX-IF-NOT-EXISTS only adds what is new.
        sqlite.execute('''
          CREATE TABLE outbox (
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
        sqlite.execute(
          'CREATE INDEX idx_outbox_status_priority_created_at '
          'ON outbox (status, priority, created_at)',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_actionable_priority_created_at '
          'ON outbox (priority, created_at) '
          'WHERE status IN (0, 3)',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_pending_entry_id_created_at '
          'ON outbox (outbox_entry_id, created_at) '
          'WHERE status = 0 AND outbox_entry_id IS NOT NULL',
        );
        sqlite.execute('''
          CREATE TABLE sync_sequence_log (
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
        sqlite.execute('PRAGMA user_version = 20');
        sqlite.dispose();

        final db = SyncDatabase(overriddenFilename: 'test_sync_v21.db');

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 24);

        final pendingIndex = await db
            .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_outbox_pending_created_id'",
            )
            .get();
        expect(pendingIndex, hasLength(1));
        final pendingSql = pendingIndex.first.readNullable<String>('sql');
        expect(pendingSql, contains('created_at, id'));
        expect(pendingSql, contains('WHERE status = 0'));

        final sendingIndex = await db
            .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_outbox_sending_expiry'",
            )
            .get();
        expect(
          sendingIndex,
          isEmpty,
          reason:
              'v22 drops the v21 updated_at-leading index because it makes '
              'SQLite prefer a range scan plus temp sort for expired leases',
        );

        final sequenceResolvedIndex = await db
            .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_resolved_host_counter'",
            )
            .get();
        expect(sequenceResolvedIndex, hasLength(1));
        final sequenceResolvedSql = sequenceResolvedIndex.first
            .readNullable<String>('sql');
        expect(
          sequenceResolvedSql,
          contains('host_id, counter'),
        );
        expect(
          sequenceResolvedSql,
          contains('status IN (0, 3, 4, 5, 8)'),
        );

        await db.close();
      },
    );

    test(
      'v21 migration adds the v23 sequence maintenance objects',
      () async {
        final dbFile = File(
          path.join(testDirectory!.path, 'test_sync_v23_from_v21.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

        sqlite.execute('''
          CREATE TABLE outbox (
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
        sqlite.execute(
          'CREATE INDEX idx_outbox_status_priority_created_at '
          'ON outbox (status, priority, created_at)',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_actionable_priority_created_at '
          'ON outbox (priority, created_at) '
          'WHERE status IN (0, 3)',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_pending_entry_id_created_at '
          'ON outbox (outbox_entry_id, created_at) '
          'WHERE status = 0 AND outbox_entry_id IS NOT NULL',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_pending_created_id '
          'ON outbox (created_at, id) '
          'WHERE status = 0',
        );
        sqlite.execute(
          'CREATE INDEX idx_outbox_sending_expiry '
          'ON outbox (updated_at, created_at, id) '
          'WHERE status = 3',
        );
        sqlite.execute('''
          CREATE TABLE sync_sequence_log (
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
        sqlite.execute('PRAGMA user_version = 21');
        sqlite.dispose();

        final db = SyncDatabase(
          overriddenFilename: 'test_sync_v23_from_v21.db',
        );

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 24);

        final newIndices = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              'AND name IN ( '
              "'idx_sync_sequence_log_resolved_host_counter')",
            )
            .get();
        expect(
          newIndices.map((row) => row.read<String>('name')).toSet(),
          containsAll(<String>{
            'idx_sync_sequence_log_resolved_host_counter',
          }),
        );

        final watermarkTable = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name = 'sync_sequence_watermarks'",
            )
            .get();
        expect(watermarkTable, hasLength(1));

        final legacySendingIndex = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_outbox_sending_expiry'",
            )
            .get();
        expect(
          legacySendingIndex,
          isEmpty,
          reason:
              'v22 removes the updated_at-leading sending index so the '
              'priority-ordered reclaim query cannot pick a temp-sort plan',
        );

        await db.close();
      },
    );

    test(
      'v22 migration drops existing v21 sending-expiry index so the '
      'priority-first expired-sending claim branch cannot pick a temp sort',
      () async {
        final dbFile = File(
          path.join(testDirectory!.path, 'test_sync_v22_reindex.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

        sqlite
          ..execute('''
            CREATE TABLE outbox (
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
          ''')
          ..execute('''
            CREATE TABLE sync_sequence_log (
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
          ''')
          ..execute(
            'CREATE INDEX idx_outbox_sending_expiry '
            'ON outbox (updated_at, created_at, id) '
            'WHERE status = 3',
          )
          ..execute('PRAGMA user_version = 21')
          ..dispose();

        final db = SyncDatabase(overriddenFilename: 'test_sync_v22_reindex.db');

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 24);

        final sendingIndex = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_outbox_sending_expiry'",
            )
            .get();
        expect(
          sendingIndex,
          isEmpty,
          reason:
              'the priority-first query should use '
              'idx_outbox_status_priority_created_at instead',
        );

        await db.close();
      },
    );

    test(
      'v23 migration adds the resolved-host partial index used by '
      'getLastCounterForHost',
      () async {
        final dbFile = File(
          path.join(testDirectory!.path, 'test_sync_v23_watermark.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

        sqlite
          ..execute('''
            CREATE TABLE sync_sequence_log (
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
          ''')
          ..execute('PRAGMA user_version = 22')
          ..dispose();

        final db = SyncDatabase(
          overriddenFilename: 'test_sync_v23_watermark.db',
        );

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 24);

        final index = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_resolved_host_counter'",
            )
            .get();
        expect(index, hasLength(1));
        final indexSql = index.first.readNullable<String>('sql');
        expect(indexSql, contains('host_id, counter'));
        // Migrations always run to the latest schema, so opening a v22 DB
        // lands on the v24 resolved-index shape (burned (8) included).
        expect(indexSql, contains('WHERE status IN (0, 3, 4, 5, 8)'));

        await db.close();
      },
    );

    test(
      'v24 migration rebuilds the resolved index to include burned (8) and '
      'the watermark advances across a burned counter',
      () async {
        final dbFile = File(
          path.join(testDirectory!.path, 'test_sync_v24_burned.db'),
        );
        final sqlite = sqlite3.open(dbFile.path);

        sqlite
          ..execute('''
            CREATE TABLE sync_sequence_log (
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
          ''')
          // The pre-v24 resolved index: burned (8) is absent from the WHERE.
          ..execute(
            'CREATE INDEX idx_sync_sequence_log_resolved_host_counter '
            'ON sync_sequence_log (host_id, counter) '
            'WHERE status IN (0, 3, 4, 5)',
          )
          ..execute('''
            CREATE TABLE sync_sequence_watermarks (
              host_id TEXT PRIMARY KEY NOT NULL,
              last_counter INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
          ''')
          ..execute('PRAGMA user_version = 23')
          ..dispose();

        final db = SyncDatabase(overriddenFilename: 'test_sync_v24_burned.db');

        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(versionResult.first.read<int>('user_version'), 24);

        // v24 drops and recreates the partial index so burned (8) joins the
        // resolved set.
        final index = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' "
              "AND name = 'idx_sync_sequence_log_resolved_host_counter'",
            )
            .get();
        expect(index, hasLength(1));
        expect(
          index.first.readNullable<String>('sql'),
          contains('WHERE status IN (0, 3, 4, 5, 8)'),
        );

        // Raw-insert a contiguous run with a burned counter in the middle so
        // getLastCounterForHost rebuilds the watermark via the CTE. If burned
        // did not count as resolved, the contiguous prefix would stop at 1.
        const hostId = 'host-v24';
        Future<void> insert(int counter, int status) => db.customStatement(
          'INSERT INTO sync_sequence_log '
          '(host_id, counter, status, created_at, updated_at) '
          'VALUES (?, ?, ?, 0, 0)',
          [hostId, counter, status],
        );
        await insert(1, SyncSequenceStatus.received.index);
        await insert(2, SyncSequenceStatus.burned.index);
        await insert(3, SyncSequenceStatus.received.index);

        expect(await db.getLastCounterForHost(hostId), 3);

        await db.close();
      },
    );
  });
}
