// Checks that no file outside lib/services/ grows its dart:developer logging.
//
// Usage:
//   dart run tool/logging/validate.dart [--update-baseline]
//
// Exits 0 when every file is at or below its baseline, 1 otherwise. See
// `developer_log_guard.dart` for the rule and the reasoning behind it.

import 'dart:io';

import 'developer_log_guard.dart';

const _baselinePath = 'tool/logging/baseline.json';

const _usage =
    '''
Checks that dart:developer logging outside lib/services/ only shrinks.

Usage: dart run tool/logging/validate.dart [--update-baseline]

  --update-baseline   Rewrite $_baselinePath from the current tree. It refuses
                      while any file is above its baseline; only a missing
                      baseline file may be seeded from the tree.
''';

void main(List<String> args) {
  final unknown = args.where((a) => a != '--update-baseline').toList();
  if (unknown.isNotEmpty) {
    stderr
      ..writeln('error: unrecognised argument(s): ${unknown.join(', ')}')
      ..writeln()
      ..writeln(_usage);
    exit(1);
  }
  final updating = args.contains('--update-baseline');
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('error: no `lib/` here — run from the repository root');
    exit(1);
  }

  final baselineFile = File(_baselinePath);
  final seeding = updating && !baselineFile.existsSync();
  final result = scan(
    root: lib,
    baseline: readBaseline(baselineFile),
    repoRoot: Directory.current.path,
  );

  if (result.violations.isNotEmpty && !seeding) {
    stderr.writeln('dart:developer logging check failed:\n');
    for (final violation in result.violations) {
      stderr.writeln('  $violation\n');
    }
    stderr.writeln(
      updating
          ? 'Not updating the baseline: it only ever goes down.'
          : 'Log through DomainLogger; dart:developer belongs to '
                '${loggingLayer.join(', ')}.',
    );
    exit(1);
  }

  if (updating) baselineFile.writeAsStringSync(encodeBaseline(result.counts));
  stdout.writeln(
    '${updating ? 'Baseline updated' : 'dart:developer logging check passed'}: '
    '${result.counts.length} files still carry ${result.total} calls.',
  );
}
