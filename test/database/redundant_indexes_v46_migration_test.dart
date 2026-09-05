// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// The nine indexes v46 drops. Each duplicated an index SQLite already had:
/// single-column DESC twins, primary-key indexes on the definition tables,
/// prefix-shadowed single-column `linked_entries` indexes, and a boolean
/// column index.
const _redundant = <String>{
  'idx_journal_date_from_desc',
  'idx_journal_date_to_desc',
  'idx_habit_definitions_id',
  'idx_category_definitions_id',
  'idx_label_definitions_id',
  'idx_dashboard_definitions_id',
  'idx_linked_entries_from_id',
  'idx_linked_entries_to_id',
  'idx_linked_entries_hidden',
};

/// A neighbour that must survive for every family the drop touches, so the
/// step is proven to remove exactly the redundant shape and not the index
/// that covers it.
const _kept = <String>{
  'idx_journal_date_from_asc',
  'idx_journal_date_to_asc',
  'idx_habit_definitions_name',
  'idx_category_definitions_name',
  'idx_label_definitions_name',
  'idx_dashboard_definitions_name',
  'idx_linked_entries_from_id_hidden',
  'idx_linked_entries_to_id_hidden',
  'idx_linked_entries_type',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync('lotti_v46_mig_');
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

  /// A v45-shaped database reduced to the tables the dropped indexes sit on,
  /// carrying every redundant index next to the index that covers it.
  void createV45Schema(Database sqlite) {
    sqlite.execute('''
      CREATE TABLE journal (
        id TEXT PRIMARY KEY,
        serialized TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        date_from INTEGER NOT NULL,
        date_to INTEGER NOT NULL,
        deleted BOOLEAN NOT NULL DEFAULT FALSE,
        type TEXT NOT NULL,
        subtype TEXT
      )
    ''');
    sqlite.execute(
      'CREATE INDEX idx_journal_date_from_asc ON journal (date_from ASC)',
    );
    sqlite.execute(
      'CREATE INDEX idx_journal_date_from_desc ON journal (date_from DESC)',
    );
    sqlite.execute(
      'CREATE INDEX idx_journal_date_to_asc ON journal (date_to ASC)',
    );
    sqlite.execute(
      'CREATE INDEX idx_journal_date_to_desc ON journal (date_to DESC)',
    );

    for (final table in [
      'habit_definitions',
      'category_definitions',
      'label_definitions',
      'dashboard_definitions',
    ]) {
      sqlite.execute('''
        CREATE TABLE $table (
          id TEXT NOT NULL,
          name TEXT NOT NULL,
          serialized TEXT NOT NULL,
          PRIMARY KEY (id)
        )
      ''');
      sqlite.execute('CREATE INDEX idx_${table}_id ON $table (id)');
      sqlite.execute('CREATE INDEX idx_${table}_name ON $table (name)');
    }

    sqlite.execute('''
      CREATE TABLE linked_entries (
        id TEXT NOT NULL UNIQUE,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        type TEXT NOT NULL,
        serialized TEXT NOT NULL,
        hidden BOOLEAN DEFAULT FALSE,
        PRIMARY KEY (id),
        UNIQUE(from_id, to_id, type)
      )
    ''');
    sqlite.execute(
      'CREATE INDEX idx_linked_entries_from_id ON linked_entries (from_id)',
    );
    sqlite.execute(
      'CREATE INDEX idx_linked_entries_to_id ON linked_entries (to_id)',
    );
    sqlite.execute(
      'CREATE INDEX idx_linked_entries_type ON linked_entries (type)',
    );
    sqlite.execute(
      'CREATE INDEX idx_linked_entries_hidden ON linked_entries (hidden)',
    );
    sqlite.execute('''
      CREATE INDEX idx_linked_entries_from_id_hidden
        ON linked_entries (from_id, hidden)
    ''');
    sqlite.execute('''
      CREATE INDEX idx_linked_entries_to_id_hidden
        ON linked_entries (to_id, hidden)
    ''');
  }

  Future<Set<String>> indexNames(JournalDb db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  group('Redundant indexes v46 migration', () {
    test('drops the nine redundant indexes and keeps their covering '
        'neighbours', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v46.db'));
      final sqlite = sqlite3.open(dbFile.path);
      createV45Schema(sqlite);
      sqlite.execute('PRAGMA user_version = 45');
      sqlite.close();

      final db = JournalDb(overriddenFilename: 'test_v46.db');
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), db.schemaVersion);
      expect(db.schemaVersion, 46);

      final names = await indexNames(db);
      expect(names.intersection(_redundant), isEmpty);
      expect(names.containsAll(_kept), isTrue, reason: '$names');
    });

    test('a database that never had them upgrades cleanly', () async {
      final dbFile = File(p.join(testDirectory!.path, 'test_v46_bare.db'));
      final sqlite = sqlite3.open(dbFile.path);
      sqlite.execute('''
        CREATE TABLE journal (
          id TEXT PRIMARY KEY,
          serialized TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          date_from INTEGER NOT NULL,
          date_to INTEGER NOT NULL,
          deleted BOOLEAN NOT NULL DEFAULT FALSE,
          type TEXT NOT NULL,
          subtype TEXT
        )
      ''');
      sqlite.execute('PRAGMA user_version = 45');
      sqlite.close();

      final db = JournalDb(overriddenFilename: 'test_v46_bare.db');
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').get();
      expect(version.first.read<int>('user_version'), 46);
    });

    test('a fresh database is created without them', () async {
      final db = JournalDb(inMemoryDatabase: true);
      addTearDown(db.close);

      final names = await indexNames(db);
      expect(names.intersection(_redundant), isEmpty);
      expect(names.containsAll(_kept), isTrue, reason: '$names');
    });
  });
}
