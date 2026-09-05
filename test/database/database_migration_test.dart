// Tests for the migration strategy's index reconcile
// (`lib/database/database_migration.dart`): the definition normaliser it
// compares with, and the reconcile's behaviour on a real upgrade.
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'schema_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normaliseIndexDefinition', () {
    test('ignores the spelling that does not change an index', () {
      const declared = '''
CREATE INDEX idx_journal_tasks_priority_date ON journal(
  task_priority_rank COLLATE BINARY ASC,
  date_from COLLATE BINARY DESC,
  id COLLATE BINARY ASC
)
WHERE type = 'Task'
  AND task = 1
  AND deleted = FALSE;''';
      const asMigrationWroteIt =
          'CREATE INDEX IF NOT EXISTS "idx_journal_tasks_priority_date" '
          'ON journal ( task_priority_rank ASC, date_from DESC, id ) '
          "where type='Task' and task=1 and deleted=false";
      expect(
        normaliseIndexDefinition(declared),
        normaliseIndexDefinition(asMigrationWroteIt),
      );
    });

    test('keeps what does change an index', () {
      const base = 'CREATE INDEX i ON t(a, b DESC) WHERE x = 1';
      for (final changed in const [
        'CREATE INDEX i ON t(b DESC, a) WHERE x = 1', // column order
        'CREATE INDEX i ON t(a, b) WHERE x = 1', // direction
        'CREATE UNIQUE INDEX i ON t(a, b DESC) WHERE x = 1', // uniqueness
        'CREATE INDEX i ON t(a, b DESC) WHERE x = 2', // predicate
        'CREATE INDEX i ON t(a, b DESC)', // partial vs full
        'CREATE INDEX i ON t(a, b DESC, c) WHERE x = 1', // extra column
      ]) {
        expect(
          normaliseIndexDefinition(base),
          isNot(normaliseIndexDefinition(changed)),
          reason: changed,
        );
      }
    });
  });

  group('index reconcile on upgrade', () {
    late Directory testDirectory;
    Directory? previousDirectory;

    setUp(() {
      if (getIt.isRegistered<Directory>()) {
        previousDirectory = getIt<Directory>();
        getIt.unregister<Directory>();
      }
      testDirectory = Directory.systemTemp.createTempSync('lotti_reconcile_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async => switch (call.method) {
              'getApplicationDocumentsDirectory' ||
              'getApplicationSupportDirectory' ||
              'getTemporaryDirectory' => testDirectory.path,
              _ => null,
            },
          );
      getIt.registerSingleton<Directory>(testDirectory);
      DevLogger.capturedLogs.clear();
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
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    Future<String> indexSql(JournalDb db, String name) async {
      final row = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = ?",
            variables: [Variable.withString(name)],
          )
          .getSingle();
      return row.read<String>('sql');
    }

    test(
      'an index reshaped under the same name is rebuilt to the declared '
      'definition',
      () async {
        final dbFile = File(p.join(testDirectory.path, 'reshaped.db'));
        final sqlite = sqlite3.open(dbFile.path);
        createJournalSchema(sqlite, 46);
        // Same name, fewer columns: what an install would carry if a past
        // migration had created this index in an older shape.
        sqlite
          ..execute('DROP INDEX idx_journal_tab')
          ..execute('CREATE INDEX idx_journal_tab ON journal(type)')
          ..close();

        final db = JournalDb(overriddenFilename: 'reshaped.db');
        addTearDown(db.close);
        await db.customSelect('PRAGMA user_version').get();

        final sql = await indexSql(db, 'idx_journal_tab');
        expect(sql, contains('starred'));
        expect(sql, contains('date_from COLLATE BINARY DESC'));
        expect(
          DevLogger.capturedLogs.any(
            (line) => line.contains('Recreating index idx_journal_tab'),
          ),
          isTrue,
          reason: DevLogger.capturedLogs.join('\n'),
        );
      },
    );

    test(
      'an install whose indexes already match is not rebuilt for spelling',
      () async {
        final dbFile = File(p.join(testDirectory.path, 'matching.db'));
        final sqlite = sqlite3.open(dbFile.path);
        createJournalSchema(sqlite, 46);
        sqlite.close();

        final db = JournalDb(overriddenFilename: 'matching.db');
        addTearDown(db.close);
        await db.customSelect('PRAGMA user_version').get();

        // v47 declares one new index; nothing that already existed is touched.
        expect(
          DevLogger.capturedLogs.where(
            (line) =>
                line.contains('Recreating index') ||
                line.contains('Dropping undeclared index'),
          ),
          isEmpty,
          reason: DevLogger.capturedLogs.join('\n'),
        );
        expect(
          DevLogger.capturedLogs.where(
            (line) => line.contains('Creating declared index'),
          ),
          hasLength(1),
        );
      },
    );
  });
}
