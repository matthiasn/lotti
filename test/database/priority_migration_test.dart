// ignore_for_file: cascade_invocations
import 'dart:io';

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

    testDirectory = Directory.systemTemp.createTempSync('lotti_priority_mig_');

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

  group('Priority Migration v29', () {
    test('adds columns and backfills defaults for legacy tasks', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v29_priority.db'));
      final sqlite = sqlite3.open(dbFile.path);

      // Create a v28-style journal table without priority columns
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

      // Insert a legacy task row (no priority columns exist yet)
      sqlite.execute("""
        INSERT INTO journal (id, serialized, created_at, updated_at, date_from, date_to, type, task, task_status)
        VALUES ('legacy-task', '{}', 0, 0, 0, 0, 'Task', 1, 'OPEN')
      """);

      // Set user_version to 28 to trigger v29 migration
      sqlite.execute('PRAGMA user_version = 28');
      sqlite.dispose();

      // Open with Drift to run migration
      final db = JournalDb(overriddenFilename: 'test_v29_priority.db');

      // Schema version advanced
      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);

      // Columns exist
      final tableInfo =
          await db.customSelect('PRAGMA table_info(journal)').get();
      final cols = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(cols.contains('task_priority'), isTrue);
      expect(cols.contains('task_priority_rank'), isTrue);

      // Backfill applied for legacy task rows: default P2 / rank 2
      final row = await db
          .customSelect(
              "SELECT task_priority, task_priority_rank FROM journal WHERE id = 'legacy-task'")
          .get();
      expect(row, hasLength(1));
      expect(row.first.read<String>('task_priority'), equals('P2'));
      expect(row.first.read<int>('task_priority_rank'), equals(2));

      // Index exists and references task_priority_rank
      final idx = await db
          .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' AND name='idx_journal_tasks'")
          .get();
      expect(idx, hasLength(1));
      expect(idx.first.read<String>('sql'), contains('task_priority_rank'));

      await db.close();
    });
  });
}
