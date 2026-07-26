// Validates the OKF knowledge bundle in `knowledge/`.
//
// Usage:
//   dart run tool/okf/validate.dart [bundle-dir] [--warnings-as-errors]
//
// Exits 0 when the bundle is conformant, 1 otherwise. See `okf_validator.dart`
// for what is checked and why, and `knowledge/conventions/knowledge-bundle.md`
// for how the bundle is meant to be maintained.

import 'dart:io';

import 'okf_validator.dart';

String _toRepoRelative(String bundleRoot) {
  final cwd = Directory.current.path;
  final relative = repoRelativeBundleRoot(bundleRoot, workingDirectory: cwd);
  if (relative != null) return relative;

  // Reporting hundreds of false failures would be worse than refusing.
  stderr.writeln(
    'error: bundle directory `$bundleRoot` is outside the working directory '
    '`$cwd`, so references to repository files cannot be resolved; run from '
    'the repository root or pass a relative path',
  );
  exit(1);
}

void main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final strict = args.contains('--warnings-as-errors');
  final bundleRoot = _toRepoRelative(
    positional.isEmpty ? 'knowledge' : positional.first,
  );

  final bundleDir = Directory(bundleRoot);
  if (!bundleDir.existsSync()) {
    stderr.writeln('error: bundle directory `$bundleRoot` does not exist');
    exit(1);
  }

  final files = <String, String>{};
  for (final entity in bundleDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path
        .substring(bundleDir.path.length)
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp('^/'), '');
    files[relative] = entity.path.endsWith('.md')
        ? entity.readAsStringSync()
        : '';
  }

  final result = validateBundle(files);
  final repoIssues = validateRepoReferences(
    files: files,
    bundleRoot: bundleRoot,
    repoFileExists: (path) =>
        File(path).existsSync() || Directory(path).existsSync(),
  );

  final issues = [...result.issues, ...repoIssues]
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final issue in issues) {
    (issue.isError ? stderr : stdout).writeln('$bundleRoot/$issue');
  }

  final errorCount = issues.where((i) => i.isError).length;
  final warningCount = issues.length - errorCount;
  stdout
    ..writeln()
    ..writeln(
      'OKF $okfVersion: checked ${result.conceptCount} concepts in '
      '$bundleRoot/ — $errorCount error(s), $warningCount warning(s)',
    );

  if (errorCount > 0 || (strict && warningCount > 0)) exit(1);
}
