/// Seeds a raw SQLite database with the fresh-install `JournalDb` schema of
/// a past version, as it actually shipped.
///
/// The schemas live in `test/database/schemas/journal_v<N>.sql`, extracted
/// from `lib/database/database.drift` in git history by
/// `tool/db_schema/extract_journal_schema.dart`. A migration test that
/// starts from one of these starts from what a real device installed at
/// that version has — every column, every index — so the migration ladder
/// (and the index reconcile that ends it) runs against the real thing
/// rather than a hand-written subset that happens to have the columns the
/// step under test touches.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../tool/db_schema/drift_ddl.dart';

const journalSchemaDirectory = 'test/database/schemas';

/// The committed schema file for journal [version].
File journalSchemaFile(int version) =>
    File(p.join(journalSchemaDirectory, 'journal_v$version.sql'));

/// Every committed journal schema, keyed by version, ascending.
Map<int, File> committedJournalSchemas() {
  final pattern = RegExp(r'^journal_v(\d+)\.sql$');
  final files = <int, File>{};
  for (final entity in Directory(journalSchemaDirectory).listSync()) {
    if (entity is! File) continue;
    final match = pattern.firstMatch(p.basename(entity.path));
    if (match == null) continue;
    files[int.parse(match.group(1)!)] = entity;
  }
  return Map.fromEntries(
    files.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// Creates every table and index of journal schema [version] in [sqlite]
/// and stamps `PRAGMA user_version` with it, so opening the file with
/// `JournalDb` runs the migration from exactly that version.
void createJournalSchema(Database sqlite, int version) {
  final file = journalSchemaFile(version);
  if (!file.existsSync()) {
    throw StateError(
      'No committed schema for journal v$version; run '
      'dart run tool/db_schema/extract_journal_schema.dart '
      '--version $version --ref <commit where that version was current>',
    );
  }
  extractDriftDdl(file.readAsStringSync()).forEach(sqlite.execute);
  sqlite.execute('PRAGMA user_version = $version');
}
