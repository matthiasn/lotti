/// Writes the JournalDb fresh-install schema at a past version as plain DDL.
///
/// Usage:
///
/// ```sh
/// dart run tool/db_schema/extract_journal_schema.dart --version 45 --ref <sha>
/// ```
///
/// The `--ref` must be a commit at which `lib/database/database.dart` declared
/// `schemaVersion => <version>` — the last such commit before the next
/// version was introduced gives the schema as it shipped — or the literal
/// `WORKTREE` to read the uncommitted files, which is how the file for a
/// version being introduced is produced before its commit exists. The tool
/// checks the declared version before writing, so a schema file can never
/// carry the wrong version number.
///
/// Output goes to `test/database/schemas/journal_v<version>.sql`, which
/// `test/database/journal_schema_history_test.dart` migrates to the current
/// version and diffs against a fresh install. When `schemaVersion` is bumped,
/// run this for the version being left behind (`--ref HEAD` before the bump
/// commit, or the bump commit's parent afterwards) and commit the file.
library;

import 'dart:io';

import 'drift_ddl.dart';

const _driftPath = 'lib/database/database.drift';
const _databasePath = 'lib/database/database.dart';
const _outputDirectory = 'test/database/schemas';

void main(List<String> args) {
  final version = _argument(args, '--version');
  final ref = _argument(args, '--ref');
  if (version == null || ref == null) {
    stderr.writeln(
      'usage: dart run tool/db_schema/extract_journal_schema.dart '
      '--version <n> --ref <git ref>',
    );
    exitCode = 64;
    return;
  }

  final declared = RegExp(
    r'int get schemaVersion => (\d+);',
  ).firstMatch(_read(ref, _databasePath))?.group(1);
  if (declared != version) {
    stderr.writeln(
      'Refusing to write: $ref declares schemaVersion $declared, '
      'not $version.',
    );
    exitCode = 65;
    return;
  }

  final statements = extractDriftDdl(_read(ref, _driftPath));
  final resolved = ref == worktreeRef
      ? 'the working tree'
      : Process.runSync('git', [
          'rev-parse',
          '--short',
          ref,
        ]).stdout.toString().trim();
  final output = File('$_outputDirectory/journal_v$version.sql')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      renderSchemaFile(
        statements: statements,
        version: int.parse(version),
        gitRef: resolved,
      ),
    );
  stdout.writeln(
    'Wrote ${output.path}: ${statements.length} statements from $resolved',
  );
}

String? _argument(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

/// The `--ref` value that reads the uncommitted working tree.
const worktreeRef = 'WORKTREE';

String _read(String ref, String path) =>
    ref == worktreeRef ? File(path).readAsStringSync() : _gitShow(ref, path);

String _gitShow(String ref, String path) {
  final result = Process.runSync('git', ['show', '$ref:$path']);
  if (result.exitCode != 0) {
    stderr.writeln(result.stderr);
    throw StateError('git show $ref:$path failed');
  }
  return result.stdout.toString();
}
