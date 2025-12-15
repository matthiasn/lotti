// ignore_for_file: avoid_redundant_argument_values, cascade_invocations
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
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
    testDirectory =
        Directory.systemTemp.createTempSync('lotti_sync_migration_test_');

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
    });

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
    test('v2 migration creates sync_sequence_log and host_activity tables',
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
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), db.schemaVersion);
      expect(db.schemaVersion, 4);

      // Verify sync_sequence_log table exists and has correct schema
      final seqLogResult = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='sync_sequence_log'")
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
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='host_activity'")
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
    });

    test('fresh install creates all tables correctly', () async {
      // Just open a new database - this should use onCreate
      final db = SyncDatabase(overriddenFilename: 'test_fresh_install.db');

      // Verify schema version
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 4);

      // Verify all tables exist
      final tablesResult = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('outbox', 'sync_sequence_log', 'host_activity')")
          .get();
      expect(tablesResult, hasLength(3));

      final tableNames =
          tablesResult.map((r) => r.read<String>('name')).toSet();
      expect(tableNames, contains('outbox'));
      expect(tableNames, contains('sync_sequence_log'));
      expect(tableNames, contains('host_activity'));

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
  });
}
