// Migrates every committed historical JournalDb schema to the current
// version and diffs the result against a fresh install.
//
// `test/database/schemas/journal_v<N>.sql` is the fresh-install schema at
// version N, lifted from `lib/database/database.drift` at the last commit
// where that version was current (see `tool/db_schema/`). A device that
// installed at N and upgrades today starts from exactly that, so this is the
// migration ladder tested against what actually shipped rather than a
// hand-written approximation — the check drift_dev's `SchemaVerifier` would
// run if its CLI built in this repository.
//
// The comparison is structural — tables, columns, foreign keys, the
// implicit indexes behind table-level UNIQUE and PRIMARY KEY constraints,
// and explicit indexes — normalised for the cosmetic differences between
// `createAll()` and `ALTER TABLE` / `CREATE INDEX` statements: column
// order, declared type spelling within one affinity, and boolean default
// spelling. Anything else — a column, default, constraint or index that a
// fresh install has and a migrated database does not, or the reverse —
// fails the test with a readable diff.
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../tool/db_schema/drift_ddl.dart';
import 'schema_fixtures.dart';

/// Tables an upgraded database may still carry that a fresh install never
/// creates. Each entry needs a reason; an unexplained extra table is a
/// finding, not a tolerance.
const _legacyTablesLeftInPlace = <String, String>{
  'tag_entities':
      'tags were removed from the schema in v25; the table was left in '
      'place on existing installs rather than dropping user data',
  'tagged':
      'the tag assignment table from the same removal, kept for the same '
      'reason',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync('lotti_schema_hist_');
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

  final schemaFiles = committedJournalSchemas();

  test('at least one historical schema is committed', () {
    expect(schemaFiles, isNotEmpty);
  });

  test(
    'the committed schema for the current version matches database.drift',
    () async {
      // The maintenance hook: bumping `schemaVersion` without committing the
      // schema being left behind, or editing `database.drift` without
      // re-extracting the current one, fails here.
      final db = JournalDb(inMemoryDatabase: true);
      addTearDown(db.close);
      final current = journalSchemaFile(db.schemaVersion);
      expect(
        current.existsSync(),
        isTrue,
        reason:
            'run: dart run tool/db_schema/extract_journal_schema.dart '
            '--version ${db.schemaVersion} --ref HEAD',
      );
      expect(
        extractDriftDdl(current.readAsStringSync()),
        extractDriftDdl(
          File('lib/database/database.drift').readAsStringSync(),
        ),
      );
    },
  );

  group('a database installed at', () {
    for (final entry in schemaFiles.entries) {
      final version = entry.key;
      test(
        'v$version migrates to a schema identical to a fresh install',
        () async {
          final dbFile = File(
            p.join(testDirectory.path, 'journal_v$version.db'),
          );
          final sqlite = sqlite3.open(dbFile.path);
          createJournalSchema(sqlite, version);
          sqlite.close();

          final migrated = JournalDb(
            overriddenFilename: 'journal_v$version.db',
          );
          addTearDown(migrated.close);
          final fresh = JournalDb(inMemoryDatabase: true);
          addTearDown(fresh.close);

          final versionRow = await migrated
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(versionRow.read<int>('user_version'), migrated.schemaVersion);

          final differences = _diff(
            fresh: await _Schema.of(fresh),
            migrated: await _Schema.of(migrated),
          );
          expect(
            differences,
            isEmpty,
            reason:
                'migrated v$version differs from a fresh install:\n'
                '${differences.join('\n')}',
          );
        },
      );
    }
  });
}

List<String> _diff({required _Schema fresh, required _Schema migrated}) {
  final differences = <String>[];

  for (final table in fresh.tables.keys) {
    if (!migrated.tables.containsKey(table)) {
      differences.add('table $table: missing after migration');
    }
  }
  for (final table in migrated.tables.keys) {
    if (fresh.tables.containsKey(table)) continue;
    if (_legacyTablesLeftInPlace.containsKey(table)) continue;
    differences.add(
      'table $table: present after migration, not in a fresh install',
    );
  }

  for (final table in fresh.tables.keys) {
    final freshColumns = fresh.tables[table]!;
    final migratedColumns = migrated.tables[table];
    if (migratedColumns == null) continue;
    for (final column in freshColumns.keys) {
      final expected = freshColumns[column]!;
      final actual = migratedColumns[column];
      if (actual == null) {
        differences.add('column $table.$column: missing after migration');
      } else if (actual != expected) {
        differences.add(
          'column $table.$column: fresh $expected, migrated $actual',
        );
      }
    }
    for (final column in migratedColumns.keys) {
      if (!freshColumns.containsKey(column)) {
        differences.add(
          'column $table.$column: present after migration, not in a fresh '
          'install',
        );
      }
    }
  }

  for (final table in fresh.constraints.keys) {
    final expected = fresh.constraints[table]!;
    final actual = migrated.constraints[table];
    if (actual == null) continue; // the missing table is reported above
    for (final constraint in expected.difference(actual)) {
      differences.add(
        'constraint on $table: $constraint missing after migration',
      );
    }
    for (final constraint in actual.difference(expected)) {
      differences.add(
        'constraint on $table: $constraint present after migration, not in a '
        'fresh install',
      );
    }
  }

  for (final index in fresh.indexes.keys) {
    final expected = fresh.indexes[index]!;
    final actual = migrated.indexes[index];
    if (actual == null) {
      differences.add('index $index: missing after migration');
    } else if (actual != expected) {
      differences.add('index $index: fresh $expected, migrated $actual');
    }
  }
  for (final index in migrated.indexes.keys) {
    if (fresh.indexes.containsKey(index)) continue;
    final table = migrated.indexes[index]!.table;
    if (_legacyTablesLeftInPlace.containsKey(table)) continue;
    differences.add(
      'index $index on $table: present after migration, not in a fresh '
      'install',
    );
  }

  return differences;
}

/// A structural snapshot of a database: every user table with its columns
/// and constraints (foreign keys, and the implicit indexes behind table-level
/// UNIQUE and PRIMARY KEY clauses, which `PRAGMA table_info` does not show),
/// and every explicitly created index with its normalised definition.
class _Schema {
  const _Schema({
    required this.tables,
    required this.constraints,
    required this.indexes,
  });

  static Future<_Schema> of(JournalDb db) async {
    final tables = <String, Map<String, _Column>>{};
    final constraints = <String, Set<String>>{};
    final tableRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    for (final row in tableRows) {
      final table = row.read<String>('name');
      final columns = <String, _Column>{};
      for (final info
          in await db.customSelect('PRAGMA table_info("$table")').get()) {
        columns[info.read<String>('name')] = _Column(
          affinity: _affinity(info.read<String>('type')),
          notNull: info.read<int>('notnull') == 1,
          defaultValue: _normaliseDefault(
            info.readNullable<String>('dflt_value'),
          ),
          primaryKey: info.read<int>('pk') > 0,
        );
      }
      tables[table] = columns;
      constraints[table] = await _constraintsOf(db, table);
    }

    final indexes = <String, _Index>{};
    final indexRows = await db
        .customSelect(
          "SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'index' "
          'AND sql IS NOT NULL ORDER BY name',
        )
        .get();
    for (final row in indexRows) {
      indexes[row.read<String>('name')] = _Index(
        table: row.read<String>('tbl_name'),
        definition: _normaliseIndexSql(row.read<String>('sql')),
      );
    }
    return _Schema(tables: tables, constraints: constraints, indexes: indexes);
  }

  /// Foreign keys as `fk(col->table.col, delete:x, update:y)` and constraint
  /// indexes as `unique(a,b)` / `pk(a,b)`, so a missing cascade or a dropped
  /// UNIQUE clause shows up by name.
  static Future<Set<String>> _constraintsOf(JournalDb db, String table) async {
    final result = <String>{};
    for (final fk
        in await db.customSelect('PRAGMA foreign_key_list("$table")').get()) {
      result.add(
        'fk(${fk.read<String>('from')}->${fk.read<String>('table')}.'
        '${fk.read<String>('to')}, delete:${fk.read<String>('on_delete')}, '
        'update:${fk.read<String>('on_update')})',
      );
    }
    for (final index
        in await db.customSelect('PRAGMA index_list("$table")').get()) {
      final origin = index.read<String>('origin');
      if (origin == 'c') continue; // explicit CREATE INDEX, compared by name
      final name = index.read<String>('name');
      final columns =
          (await db.customSelect('PRAGMA index_info("$name")').get())
              .map((row) => row.readNullable<String>('name') ?? '<expr>')
              .join(',');
      result.add('$origin($columns)');
    }
    return result;
  }

  final Map<String, Map<String, _Column>> tables;
  final Map<String, Set<String>> constraints;
  final Map<String, _Index> indexes;
}

@immutable
class _Column {
  const _Column({
    required this.affinity,
    required this.notNull,
    required this.defaultValue,
    required this.primaryKey,
  });

  final String affinity;
  final bool notNull;
  final String? defaultValue;
  final bool primaryKey;

  @override
  bool operator ==(Object other) =>
      other is _Column &&
      other.affinity == affinity &&
      other.notNull == notNull &&
      other.defaultValue == defaultValue &&
      other.primaryKey == primaryKey;

  @override
  int get hashCode => Object.hash(affinity, notNull, defaultValue, primaryKey);

  @override
  String toString() =>
      '$affinity${notNull ? ' NOT NULL' : ''}'
      '${defaultValue == null ? '' : ' DEFAULT $defaultValue'}'
      '${primaryKey ? ' PRIMARY KEY' : ''}';
}

@immutable
class _Index {
  const _Index({required this.table, required this.definition});

  final String table;
  final String definition;

  @override
  bool operator ==(Object other) =>
      other is _Index && other.table == table && other.definition == definition;

  @override
  int get hashCode => Object.hash(table, definition);

  @override
  String toString() => definition;
}

/// SQLite type affinity of a declared type, so `BOOLEAN`, `INTEGER` and
/// `DATETIME` (all INTEGER affinity, and all used interchangeably between
/// `.drift` DDL and Drift's generated `ALTER TABLE`) compare equal.
String _affinity(String declared) {
  final upper = declared.toUpperCase();
  if (upper.contains('INT') ||
      upper.contains('BOOL') ||
      upper.contains('DATE')) {
    return 'INTEGER';
  }
  if (upper.contains('CHAR') ||
      upper.contains('CLOB') ||
      upper.contains('TEXT')) {
    return 'TEXT';
  }
  if (upper.contains('BLOB') || upper.isEmpty) return 'BLOB';
  if (upper.contains('REAL') ||
      upper.contains('FLOA') ||
      upper.contains('DOUB')) {
    return 'REAL';
  }
  return 'NUMERIC';
}

String? _normaliseDefault(String? raw) {
  if (raw == null) return null;
  final value = raw.trim().toLowerCase();
  if (value == 'false') return '0';
  if (value == 'true') return '1';
  if (value == "''") return "''";
  return value;
}

/// Lower-cases, collapses whitespace, and strips the tokens that vary
/// between the `.drift` DDL and the raw `CREATE INDEX` strings in the
/// migration steps without changing what the index is.
String _normaliseIndexSql(String sql) {
  return sql
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' if not exists', '')
      .replaceAll('"', '')
      .replaceAll(RegExp(r'\s*\(\s*'), '(')
      .replaceAll(RegExp(r'\s*\)\s*'), ')')
      .replaceAll(RegExp(r'\s*,\s*'), ',')
      .replaceAll(' collate binary', '')
      .replaceAll(' asc', '')
      .replaceAll(RegExp(r'\s*=\s*'), '=')
      .trim();
}
