/// Extracts plain SQLite DDL from a `.drift` schema file.
///
/// A `.drift` file is the fresh-install truth for a Drift database whose
/// `onCreate` is `createAll()`: every `CREATE TABLE` / `CREATE INDEX` in it,
/// in order, is what a new install gets. The file at any past commit is
/// therefore the schema a device installed at that version started from —
/// which is what a migration test has to begin with, rather than a
/// hand-written approximation.
///
/// Drift's own tooling (`drift_dev schema dump`) would do this from the
/// Dart side, but the version that resolves in this repository does not
/// build, so the DDL is lifted from the file directly. The only
/// Drift-specific syntax in the DDL region is the `) as DataClassName;`
/// suffix, which raw SQLite rejects and which is removed here.
library;

/// Returns the DDL statements of [driftSource], one per entry, each ending
/// with `;`, with comments and Drift data-class suffixes removed.
///
/// Everything from the first named query (`name:` on its own line) onward is
/// dropped: named queries are Dart-side accessors, not schema.
List<String> extractDriftDdl(String driftSource) {
  final ddlRegion = StringBuffer();
  for (final line in driftSource.split('\n')) {
    if (_namedQueryStart.hasMatch(line)) break;
    final withoutComment = line.replaceFirst(_lineComment, '');
    ddlRegion.writeln(withoutComment);
  }

  final withoutBlockComments = ddlRegion.toString().replaceAll(
    _blockComment,
    '',
  );

  final statements = <String>[];
  for (final raw in withoutBlockComments.split(';')) {
    final statement = raw.replaceFirst(_dataClassSuffix, ')').trim();
    if (statement.isEmpty) continue;
    statements.add('$statement;');
  }
  return statements;
}

/// Renders [statements] as the canonical text of a committed schema file:
/// a header naming the origin, then one statement per block.
String renderSchemaFile({
  required List<String> statements,
  required int version,
  required String gitRef,
}) {
  final buffer = StringBuffer()
    ..writeln('-- JournalDb fresh-install schema at schemaVersion $version.')
    ..writeln('-- Extracted from lib/database/database.drift at $gitRef')
    ..writeln('-- by tool/db_schema/extract_journal_schema.dart. Do not edit.')
    ..writeln();
  for (final statement in statements) {
    buffer
      ..writeln(statement)
      ..writeln();
  }
  return buffer.toString();
}

final RegExp _namedQueryStart = RegExp(r'^[A-Za-z0-9_]+:\s*$');
final RegExp _lineComment = RegExp(r'--.*$');
final RegExp _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
final RegExp _dataClassSuffix = RegExp(r'\)\s+as\s+[A-Za-z0-9_]+\s*$');
