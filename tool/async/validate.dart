// Checks that no file in lib/ changes its count of unawaited futures without
// the baseline recording it.
//
// Usage:
//   dart run tool/async/validate.dart [--update-baseline]
//
// Exits 0 when every file matches its baseline entry, 1 otherwise. See
// `unawaited_guard.dart` for the rule.

import 'dart:io';

import 'unawaited_guard.dart';

const _baselinePath = 'tool/async/baseline.json';

const _usage =
    '''
Checks that unawaited(...) in lib/ only shrinks, and that a shrink is recorded.

Usage: dart run tool/async/validate.dart [--update-baseline]

  --update-baseline   Rewrite $_baselinePath from the current tree, recording
                      the files that shrank. It refuses while any file grew;
                      only a missing baseline file may be seeded.
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
  final grew = result.violations.where((v) => v.grew).toList();
  final shrank = result.violations.where((v) => !v.grew).toList();

  if (grew.isNotEmpty && !seeding) {
    stderr.writeln('unawaited check failed:\n');
    for (final v in grew) {
      stderr.writeln('  $v\n');
    }
    stderr.writeln(
      updating
          ? 'Not updating the baseline: it only ever shrinks.'
          : 'A fire-and-forget future loses its errors and its ordering.',
    );
    exit(1);
  }
  if (shrank.isNotEmpty && !updating) {
    stderr.writeln('unawaited check failed — the baseline is behind:\n');
    for (final v in shrank) {
      stderr.writeln('  $v\n');
    }
    exit(1);
  }
  if (updating) baselineFile.writeAsStringSync(encodeBaseline(result.counts));
  stdout.writeln(
    '${updating ? 'Baseline updated' : 'unawaited check passed'}: '
    '${result.counts.length} files still carry ${result.total} unawaited '
    'futures.',
  );
}
