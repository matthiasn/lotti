// ignore_for_file: avoid_redundant_argument_values, cascade_invocations
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
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
        Directory.systemTemp.createTempSync('lotti_migration_test_');

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

  group('Labels Migration Tests', () {
    test('v26 migration creates label_definitions and labeled tables',
        () async {
      // Create a mock db at v25 to test v26 migration
      final dbFile = File(path.join(testDirectory!.path, 'test_v26.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // First create basic schema at v25 (without label tables)
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

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS tag_entities (
          id TEXT PRIMARY KEY,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN DEFAULT FALSE,
          private BOOLEAN DEFAULT FALSE,
          schema_version INTEGER DEFAULT 0
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS category_definitions (
          id TEXT PRIMARY KEY,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN DEFAULT FALSE,
          private BOOLEAN DEFAULT FALSE,
          schema_version INTEGER DEFAULT 0
        )
      ''');

      // Set schema version to 25
      sqlite.execute('PRAGMA user_version = 25');

      // Close raw connection
      sqlite.dispose();

      // Open with JournalDb to trigger migration
      final db = JournalDb(overriddenFilename: 'test_v26.db');

      // Verify the migration occurred by checking schema version
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 28);

      // Verify label_definitions table exists and has correct schema
      final labelDefResult = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='label_definitions'")
          .get();
      expect(labelDefResult, hasLength(1));
      expect(labelDefResult.first.read<String>('sql'),
          contains('label_definitions'));

      // Verify labeled table exists
      final labeledResult = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='labeled'")
          .get();
      expect(labeledResult, hasLength(1));
      expect(labeledResult.first.read<String>('sql'), contains('labeled'));

      // Verify indices were created
      final indicesResult = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_label%'")
          .get();
      expect(indicesResult.length, greaterThanOrEqualTo(4));

      await db.close();
    });

    test('v27 migration ensures label tables exist for legacy v26 installs',
        () async {
      // Create a mock db at v26 without label tables (simulating incomplete v26 migration)
      final dbFile = File(path.join(testDirectory!.path, 'test_v27.db'));
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
          category TEXT,
          flag INTEGER DEFAULT 0,
          schema_version INTEGER DEFAULT 0
        )
      ''');

      // Set schema version to 26 without creating label tables
      sqlite.execute('PRAGMA user_version = 26');
      sqlite.dispose();

      // Open with JournalDb to trigger migration
      final db = JournalDb(overriddenFilename: 'test_v27.db');

      // Verify the migration occurred
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 28);

      // Verify both tables were created
      final tablesResult = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('label_definitions', 'labeled')")
          .get();
      expect(tablesResult, hasLength(2));

      await db.close();
    });

    test('v28 migration rebuilds labeled table with ON DELETE CASCADE',
        () async {
      // Create a mock db at v27 with old labeled table schema
      final dbFile = File(path.join(testDirectory!.path, 'test_v28.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // Create journal table
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

      // Create label_definitions table
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS label_definitions (
          id TEXT PRIMARY KEY,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN DEFAULT FALSE,
          private BOOLEAN DEFAULT FALSE,
          schema_version INTEGER DEFAULT 0
        )
      ''');

      // Create old labeled table WITHOUT ON DELETE CASCADE
      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS labeled (
          id TEXT NOT NULL UNIQUE,
          journal_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (id),
          FOREIGN KEY(journal_id) REFERENCES journal(id),
          FOREIGN KEY(label_id) REFERENCES label_definitions(id),
          UNIQUE(journal_id, label_id)
        )
      ''');

      // Insert test data
      sqlite.execute('''
        INSERT INTO journal (id, serialized, created_at, updated_at, date_from, date_to, type)
        VALUES ('task-1', '{}', 0, 0, 0, 0, 'Task')
      ''');

      sqlite.execute('''
        INSERT INTO label_definitions (id, serialized, created_at, updated_at, deleted, private)
        VALUES ('label-1', '{}', 0, 0, 0, 0)
      ''');

      sqlite.execute('''
        INSERT INTO label_definitions (id, serialized, created_at, updated_at, deleted, private)
        VALUES ('label-orphaned', '{}', 0, 0, 0, 0)
      ''');

      sqlite.execute('''
        INSERT INTO labeled (id, journal_id, label_id)
        VALUES ('link-1', 'task-1', 'label-1')
      ''');

      // Insert orphaned link (label-orphaned will be deleted)
      sqlite.execute('''
        INSERT INTO labeled (id, journal_id, label_id)
        VALUES ('link-orphaned', 'task-1', 'label-orphaned')
      ''');

      // Delete the orphaned label to create orphaned reference
      sqlite.execute('''
        DELETE FROM label_definitions WHERE id = 'label-orphaned'
      ''');

      // Set schema version to 27
      sqlite.execute('PRAGMA user_version = 27');
      sqlite.dispose();

      // Open with JournalDb to trigger migration
      final db = JournalDb(overriddenFilename: 'test_v28.db');

      // Verify the migration occurred
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 28);

      // Verify labeled table has CASCADE constraint
      final tableInfo = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='labeled'")
          .get();
      expect(tableInfo, hasLength(1));
      expect(
          tableInfo.first.read<String>('sql'), contains('ON DELETE CASCADE'));

      // Verify orphaned links were removed during migration
      final labeledRows = await db.customSelect('SELECT * FROM labeled').get();
      expect(labeledRows, hasLength(1));
      expect(labeledRows.first.read<String>('id'), 'link-1');

      await db.close();
    });

    test('migration is idempotent - can run multiple times safely', () async {
      // Create a db and run through all migrations
      final dbFile = File(path.join(testDirectory!.path, 'test_idempotent.db'));
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
          category TEXT,
          flag INTEGER DEFAULT 0,
          schema_version INTEGER DEFAULT 0
        )
      ''');
      sqlite.execute('PRAGMA user_version = 25');
      sqlite.dispose();

      // First migration
      var db = JournalDb(overriddenFilename: 'test_idempotent.db');

      // Verify tables were created
      final firstMigrationLabelDef = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='label_definitions'")
          .get();
      expect(firstMigrationLabelDef, hasLength(1));

      await db.close();

      // Second migration (should be idempotent)
      db = JournalDb(overriddenFilename: 'test_idempotent.db');

      // Verify tables still exist and structure unchanged
      final labelDefResult = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='label_definitions'")
          .get();
      expect(labelDefResult, hasLength(1));
      expect(labelDefResult.first.read<String>('sql'),
          firstMigrationLabelDef.first.read<String>('sql'));

      final labeledResult = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' AND name='labeled'")
          .get();
      expect(labeledResult, hasLength(1));
      expect(labeledResult.first.read<String>('sql'),
          contains('ON DELETE CASCADE'));

      await db.close();
    });

    test('migration preserves existing data during v28 rebuild', () async {
      // Create a db at v27 with existing labeled data
      final dbFile = File(path.join(testDirectory!.path, 'test_preserve.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // Create tables
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

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS label_definitions (
          id TEXT PRIMARY KEY,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN DEFAULT FALSE,
          private BOOLEAN DEFAULT FALSE,
          schema_version INTEGER DEFAULT 0
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS labeled (
          id TEXT NOT NULL UNIQUE,
          journal_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (id),
          FOREIGN KEY(journal_id) REFERENCES journal(id),
          FOREIGN KEY(label_id) REFERENCES label_definitions(id),
          UNIQUE(journal_id, label_id)
        )
      ''');

      // Insert multiple labels and tasks
      for (var i = 0; i < 5; i++) {
        sqlite.execute('''
          INSERT INTO journal (id, serialized, created_at, updated_at, date_from, date_to, type)
          VALUES ('task-$i', '{}', 0, 0, 0, 0, 'Task')
        ''');

        sqlite.execute('''
          INSERT INTO label_definitions (id, serialized, created_at, updated_at, deleted, private)
          VALUES ('label-$i', '{}', 0, 0, 0, 0)
        ''');

        sqlite.execute('''
          INSERT INTO labeled (id, journal_id, label_id)
          VALUES ('link-$i', 'task-$i', 'label-$i')
        ''');
      }

      sqlite.execute('PRAGMA user_version = 27');
      sqlite.dispose();

      // Open with JournalDb to trigger migration
      final db = JournalDb(overriddenFilename: 'test_preserve.db');

      // Verify all data preserved
      for (var i = 0; i < 5; i++) {
        final labeledLinks = await db.labeledForJournal('task-$i').get();
        expect(labeledLinks, hasLength(1));
        expect(labeledLinks.first, 'label-$i');
      }

      await db.close();
    });

    test('label cascading deletion works after v28 migration', () async {
      final db = JournalDb(inMemoryDatabase: true);

      final now = DateTime(2024, 1, 1);

      // Create a label
      final label = LabelDefinition(
        id: 'label-cascade',
        name: 'Cascade Test',
        color: '#00FF00',
        createdAt: now,
        updatedAt: now,
        vectorClock: const VectorClock(<String, int>{}),
      );
      await db.upsertLabelDefinition(label);

      // Create tasks with the label
      for (var i = 0; i < 3; i++) {
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-cascade-$i',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            labelIds: ['label-cascade'],
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-$i',
              createdAt: now,
              utcOffset: 0,
            ),
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
            title: 'Cascade Task $i',
          ),
        );
        await db.updateJournalEntity(task);
      }

      // Verify labeled entries exist
      for (var i = 0; i < 3; i++) {
        final links = await db.labeledForJournal('task-cascade-$i').get();
        expect(links, hasLength(1));
      }

      // Delete the label (soft delete via the proper API)
      final deletedLabel = label.copyWith(deletedAt: DateTime.now());
      await db.upsertLabelDefinition(deletedLabel);

      // Hard delete from table (simulating what cascade would do)
      await db.customStatement(
        'DELETE FROM label_definitions WHERE id = ?',
        ['label-cascade'],
      );

      // Verify labeled entries were cascaded
      for (var i = 0; i < 3; i++) {
        final links = await db.labeledForJournal('task-cascade-$i').get();
        expect(links, isEmpty);
      }

      await db.close();
    });

    test('migration handles empty database gracefully', () async {
      final dbFile = File(path.join(testDirectory!.path, 'test_empty.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // Create minimal schema
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
      sqlite.execute('PRAGMA user_version = 25');
      sqlite.dispose();

      // Open with JournalDb to trigger migration
      final db = JournalDb(overriddenFilename: 'test_empty.db');

      // Verify migration completed
      final versionResult = await db.customSelect('PRAGMA user_version').get();
      expect(versionResult.first.read<int>('user_version'), 28);

      // Verify tables exist
      final tables = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('label_definitions', 'labeled')")
          .get();
      expect(tables, hasLength(2));

      await db.close();
    });
  });
}
