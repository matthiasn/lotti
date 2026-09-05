import 'package:flutter_test/flutter_test.dart';

import '../../../tool/db_schema/drift_ddl.dart';

void main() {
  group('extractDriftDdl', () {
    const source = '''
-- A leading comment.
CREATE TABLE journal (
  id TEXT NOT NULL, -- trailing comment
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (id)
) as JournalDbEntity;

/* A block
   comment. */
CREATE INDEX idx_journal_deleted ON journal (deleted)
WHERE deleted = FALSE;

CREATE TABLE plain (
  id TEXT NOT NULL
);

listEntries:
SELECT * FROM journal;

CREATE TABLE not_schema (id TEXT);
''';

    test(
      'keeps every DDL statement, in order, terminated with a semicolon',
      () {
        final statements = extractDriftDdl(source);
        expect(statements, hasLength(3));
        expect(statements[0], startsWith('CREATE TABLE journal ('));
        expect(statements[1], startsWith('CREATE INDEX idx_journal_deleted'));
        expect(statements[2], 'CREATE TABLE plain (\n  id TEXT NOT NULL\n);');
        expect(statements.every((s) => s.endsWith(';')), isTrue);
      },
    );

    test('strips the Drift data-class suffix raw SQLite rejects', () {
      final table = extractDriftDdl(source).first;
      expect(table, isNot(contains('as JournalDbEntity')));
      expect(table, endsWith('PRIMARY KEY (id)\n);'));
    });

    test('drops line and block comments', () {
      final joined = extractDriftDdl(source).join('\n');
      expect(joined, isNot(contains('comment')));
      expect(joined, isNot(contains('/*')));
    });

    test('stops at the first named query', () {
      final joined = extractDriftDdl(source).join('\n');
      expect(joined, isNot(contains('listEntries')));
      expect(joined, isNot(contains('not_schema')));
    });

    test('ignores whitespace-only fragments', () {
      expect(extractDriftDdl('\n\n;;\n  ;\n'), isEmpty);
    });
  });

  group('renderSchemaFile', () {
    test('writes a header naming version and origin, then the statements', () {
      final rendered = renderSchemaFile(
        statements: const [
          'CREATE TABLE a (id TEXT);',
          'CREATE INDEX i ON a (id);',
        ],
        version: 46,
        gitRef: 'b38c9aefa',
      );
      expect(
        rendered,
        startsWith('-- JournalDb fresh-install schema at schemaVersion 46.'),
      );
      expect(rendered, contains('at b38c9aefa'));
      expect(rendered, contains('Do not edit.'));
      // The rendered file round-trips through the extractor unchanged.
      expect(extractDriftDdl(rendered), [
        'CREATE TABLE a (id TEXT);',
        'CREATE INDEX i ON a (id);',
      ]);
    });
  });
}
