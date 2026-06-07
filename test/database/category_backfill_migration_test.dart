// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Migration tests for v43 — `journal.category` backfill.
///
/// The v21 migration added the denormalized `category` column with
/// DEFAULT '' but never backfilled it, so entries created before 2024-07
/// (and never re-saved) carry '' in the column while their serialized
/// JSON `meta.categoryId` holds the real id. Column readers (Insights
/// time analysis, time-history header) silently attributed that history
/// to "Uncategorized". v43 backfills the column from the JSON once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync('lotti_v43_category_');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory != null && testDirectory!.existsSync()) {
      testDirectory!.deleteSync(recursive: true);
    }
  });

  /// Minimal v42-style schema: just the columns the v43 backfill reads.
  void createV42Schema(Database sqlite) {
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
        category TEXT NOT NULL DEFAULT '',
        flag INTEGER DEFAULT 0,
        schema_version INTEGER DEFAULT 0
      )
    ''');
    sqlite.execute('''
      CREATE TABLE IF NOT EXISTS config_flags (
        name TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL UNIQUE,
        status BOOLEAN NOT NULL DEFAULT FALSE,
        PRIMARY KEY (name)
      )
    ''');
  }

  void insertV42Entry(
    Database sqlite, {
    required String id,
    required String columnCategory,
    String? jsonCategoryId,
  }) {
    final categoryPayload = jsonCategoryId != null
        ? ',"categoryId":"$jsonCategoryId"'
        : '';
    final serialized = '{"meta":{"id":"$id"$categoryPayload}}';
    sqlite.execute(
      'INSERT INTO journal (id, serialized, created_at, updated_at, '
      'date_from, date_to, type, category) '
      "VALUES (?, ?, 0, 0, 0, 60, 'JournalEntry', ?)",
      [id, serialized, columnCategory],
    );
  }

  group('Category backfill migration v43', () {
    test(
      'backfills empty category columns from JSON, leaves everything '
      'else untouched',
      () async {
        final dbFile = File(p.join(testDirectory!.path, 'test_v43.db'));
        final sqlite = sqlite3.open(dbFile.path);
        createV42Schema(sqlite);
        // Pre-migration column state, JSON truth in serialized:
        insertV42Entry(
          sqlite,
          id: 'stale',
          columnCategory: '',
          jsonCategoryId: 'cat-from-json',
        );
        insertV42Entry(
          sqlite,
          id: 'fresh',
          columnCategory: 'cat-already-set',
          jsonCategoryId: 'cat-json-must-not-win',
        );
        insertV42Entry(sqlite, id: 'uncategorized', columnCategory: '');
        sqlite.execute('PRAGMA user_version = 42');
        sqlite.dispose();

        final db = JournalDb(overriddenFilename: 'test_v43.db');
        addTearDown(db.close);

        final version = await db.customSelect('PRAGMA user_version').get();
        expect(version.first.read<int>('user_version'), db.schemaVersion);
        expect(db.schemaVersion, 43);

        final rows = await db
            .customSelect('SELECT id, category FROM journal ORDER BY id')
            .get();
        final byId = {
          for (final row in rows)
            row.read<String>('id'): row.read<String>('category'),
        };
        // Stale column gets the JSON id; populated column keeps its value;
        // genuinely uncategorized rows stay ''.
        expect(byId['stale'], 'cat-from-json');
        expect(byId['fresh'], 'cat-already-set');
        expect(byId['uncategorized'], '');

        // The same migration creates the insights covering index so the
        // overlap scan stays index-only as lifetime history grows.
        final indexRows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'idx_journal_insights_time'",
            )
            .get();
        expect(indexRows, hasLength(1));
      },
    );
  });
}
