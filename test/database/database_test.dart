// Migration-path tests for the `JournalDb` shell (`lib/database/database.dart`).
//
// Query-surface tests for the part-file mixins live in the
// `database_*_test.dart` mirror files in this directory; shared setup and
// entity builders live in `test_utils.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import 'test_utils.dart';

void main() {
  // Exercises the early `onUpgrade` cascade (from < 19 .. from < 25) by
  // opening a raw v18 schema with JournalDb. A file-based DB is required
  // because in-memory databases only ever run `onCreate`, never
  // `onUpgrade`. `documentsDirectoryProvider` avoids the path_provider
  // channel mock by pointing the connection straight at a temp directory.
  group('JournalDb early migration (v18 -> current) -', () {
    late Directory migrationDir;

    setUp(() {
      migrationDir = Directory.systemTemp.createTempSync('lotti_mig18_');
      // Register a Directory so the pre-migration `createDbBackup` succeeds
      // (it resolves the docs dir via getIt<Directory>), exercising the
      // backup success log path.
      getIt.registerSingleton<Directory>(migrationDir);
    });

    tearDown(() {
      if (getIt.isRegistered<Directory>()) {
        getIt.unregister<Directory>();
      }
      if (migrationDir.existsSync()) {
        migrationDir.deleteSync(recursive: true);
      }
    });

    test(
      'adds category/linked-entries columns, indices, and category table',
      () async {
        final dbFile = File(path.join(migrationDir.path, 'test_v18.db'));
        final sqlite = sqlite3.open(dbFile.path);

        // v18 journal: NO category, project_id, or due_at columns (all added
        // by later migrations). task_priority/task_priority_rank are included
        // up-front: the `from < 25` step recreates `idx_journal_tasks` using
        // the current (v42) index definition, which references
        // `task_priority_rank`. A column-period-accurate v18 schema would make
        // that historical step fail (the column is otherwise not added until
        // v29), so the fixture seeds the columns to let the full early cascade
        // run. The v29 step is idempotent via `_columnExists`, so pre-seeding
        // is safe.
        // ignore: cascade_invocations
        sqlite
          ..execute('''
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
            task_priority TEXT,
            task_priority_rank INTEGER,
            flag INTEGER DEFAULT 0,
            schema_version INTEGER DEFAULT 0
          )
        ''')
          // v18 linked_entries: NO hidden, created_at, or updated_at columns.
          ..execute('''
          CREATE TABLE IF NOT EXISTS linked_entries (
            id TEXT NOT NULL UNIQUE,
            from_id TEXT NOT NULL,
            to_id TEXT NOT NULL,
            type TEXT NOT NULL,
            serialized TEXT NOT NULL,
            PRIMARY KEY (id),
            UNIQUE(from_id, to_id, type)
          )
        ''')
          // Seed one task row so later backfill UPDATEs run against real data.
          ..execute(
            'INSERT INTO journal '
            '(id, serialized, created_at, updated_at, date_from, date_to, '
            'type, task, task_status) '
            "VALUES ('mig-task', '{}', 0, 0, 0, 0, 'Task', 1, 'OPEN')",
          )
          ..execute('PRAGMA user_version = 18')
          ..dispose();

        // Create the default-named db file so the pre-migration backup (which
        // copies `journalDbFileName` from the docs dir) succeeds, covering the
        // backup success log branch.
        await createPlaceholderDbFile(migrationDir);

        final db = JournalDb(
          overriddenFilename: 'test_v18.db',
          documentsDirectoryProvider: () async => migrationDir,
        );
        addTearDown(db.close);

        // Migration ran to the current schema version.
        final versionResult = await db
            .customSelect('PRAGMA user_version')
            .get();
        expect(
          versionResult.first.read<int>('user_version'),
          db.schemaVersion,
        );

        Future<bool> journalHasColumn(String column) async {
          final rows = await db
              .customSelect('PRAGMA table_info(journal)')
              .get();
          return rows.any((r) => r.read<String>('name') == column);
        }

        Future<bool> linkedHasColumn(String column) async {
          final rows = await db
              .customSelect('PRAGMA table_info(linked_entries)')
              .get();
          return rows.any((r) => r.read<String>('name') == column);
        }

        // from < 21 added journal.category.
        expect(await journalHasColumn('category'), isTrue);
        // from < 22 added linked_entries.hidden.
        expect(await linkedHasColumn('hidden'), isTrue);
        // from < 23 added linked_entries timestamps.
        expect(await linkedHasColumn('created_at'), isTrue);
        expect(await linkedHasColumn('updated_at'), isTrue);

        // from < 19 created the category_definitions table.
        final catTable = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='category_definitions'",
            )
            .get();
        expect(catTable, hasLength(1));

        // from < 24 / from < 25 created composite + journal indices.
        final indices = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND name IN ('idx_linked_entries_from_id_hidden', "
              "'idx_journal_tab', 'idx_journal_tasks', "
              "'idx_journal_type_subtype')",
            )
            .get();
        final indexNames = indices.map((r) => r.read<String>('name')).toSet();
        expect(indexNames, contains('idx_journal_tab'));
        expect(indexNames, contains('idx_journal_tasks'));
        expect(indexNames, contains('idx_journal_type_subtype'));
        expect(
          indexNames,
          contains('idx_linked_entries_from_id_hidden'),
        );

        // The seeded task survived and was backfilled (e.g. project_id col
        // exists and the row is still queryable).
        expect(await journalHasColumn('project_id'), isTrue);
        final taskRow = await db
            .customSelect(
              "SELECT id FROM journal WHERE id = 'mig-task'",
            )
            .get();
        expect(taskRow, hasLength(1));
      },
    );
  });
}
