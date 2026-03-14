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

    testDirectory = Directory.systemTemp.createTempSync('lotti_def_idx_mig_');

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

  group('Definition and link indices v34', () {
    test('adds the definition list and link recency indexes', () async {
      final dbFile = File(
        p.join(testDirectory!.path, 'test_v34_definition_idx.db'),
      );
      final sqlite = sqlite3.open(dbFile.path);

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS habit_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL,
          active BOOLEAN NOT NULL
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS label_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS dashboard_definitions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          last_reviewed INTEGER NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          serialized TEXT NOT NULL,
          active BOOLEAN NOT NULL
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS tag_entities (
          id TEXT NOT NULL UNIQUE,
          tag TEXT NOT NULL,
          type TEXT NOT NULL,
          inactive BOOLEAN DEFAULT FALSE,
          private BOOLEAN NOT NULL DEFAULT FALSE,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted BOOLEAN DEFAULT FALSE,
          serialized TEXT NOT NULL,
          PRIMARY KEY (id),
          UNIQUE(tag, type)
        )
      ''');

      sqlite.execute('''
        CREATE TABLE IF NOT EXISTS linked_entries (
          id TEXT NOT NULL UNIQUE,
          from_id TEXT NOT NULL,
          to_id TEXT NOT NULL,
          type TEXT NOT NULL,
          serialized TEXT NOT NULL,
          hidden BOOLEAN DEFAULT FALSE,
          created_at INTEGER,
          updated_at INTEGER,
          PRIMARY KEY (id),
          UNIQUE(from_id, to_id, type)
        )
      ''');

      sqlite.execute('PRAGMA user_version = 33');
      sqlite.dispose();

      final db = JournalDb(
        overriddenFilename: 'test_v34_definition_idx.db',
      );

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);
      expect(db.schemaVersion, 37);

      final indexes = await db.customSelect('''
        SELECT name, sql FROM sqlite_master
        WHERE type = 'index'
          AND name IN (
            'idx_habit_definitions_deleted_private',
            'idx_label_definitions_deleted_private_name',
            'idx_dashboard_definitions_deleted_private_name',
            'idx_tag_entities_deleted_private_tag',
            'idx_linked_entries_from_id_hidden_created_at_desc'
          )
        ORDER BY name
      ''').get();

      expect(indexes, hasLength(5));

      final byName = {
        for (final row in indexes)
          row.read<String>('name'): row.read<String>('sql'),
      };

      expect(
        byName['idx_habit_definitions_deleted_private'],
        contains('habit_definitions'),
      );
      expect(
        byName['idx_label_definitions_deleted_private_name'],
        contains('name COLLATE NOCASE ASC'),
      );
      expect(
        byName['idx_dashboard_definitions_deleted_private_name'],
        contains('name COLLATE NOCASE ASC'),
      );
      expect(
        byName['idx_tag_entities_deleted_private_tag'],
        contains('tag COLLATE NOCASE ASC'),
      );
      expect(
        byName['idx_linked_entries_from_id_hidden_created_at_desc'],
        contains('created_at COLLATE BINARY DESC'),
      );

      await db.close();
    });
  });
}
