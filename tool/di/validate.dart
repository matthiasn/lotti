// Checks that no file outside the composition root grows its `getIt` use.
//
// Usage:
//   dart run tool/di/validate.dart [--update-baseline]
//
// Exits 0 when every file is at or below its baseline, 1 otherwise. See
// `getit_guard.dart` for the rules and the reasoning behind the ratchet.

import 'dart:io';

import 'getit_guard.dart';

const _baselinePath = 'tool/di/baseline.json';

const _usage =
    '''
Checks that getIt use outside the composition root only shrinks.

Usage: dart run tool/di/validate.dart [--update-baseline]

  --update-baseline   Rewrite $_baselinePath from the current tree. Run this
                      after migrating a batch, so the ratchet tightens. It
                      refuses while any file is above its baseline.
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
  // Only a missing file may be seeded from the tree as it stands; once a
  // baseline exists, updating can tighten it but never loosen it.
  final seeding = updating && !baselineFile.existsSync();
  final result = scan(
    root: lib,
    baseline: readBaseline(baselineFile),
    repoRoot: Directory.current.path,
  );

  if (result.violations.isNotEmpty && !seeding) {
    stderr.writeln('getIt check failed:\n');
    for (final violation in result.violations) {
      stderr.writeln('  $violation\n');
    }
    stderr.writeln(
      updating
          ? 'Not updating the baseline: it only ever goes down, so it cannot '
                'absorb a file that grew.'
          : 'GetIt belongs to the composition root '
                '(${compositionRoot.join(', ')}).',
    );
    exit(1);
  }

  // Self-tightening: a file below its entry fails until the baseline records
  // it, so the change that removes a lookup is the one that locks it in.
  if (!updating) {
    final baseline = readBaseline(baselineFile);
    final behind = [
      for (final MapEntry(key: path, value: was) in baseline.entries)
        if ((result.debt[path]?.lookups ?? 0) < was.lookups ||
            (result.debt[path]?.isRegistered ?? 0) < was.isRegistered)
          path,
    ]..sort();
    if (behind.isNotEmpty) {
      stderr
        ..writeln('getIt check failed — the baseline is behind the tree:\n')
        ..writeln(behind.map((p) => '  $p').join('\n'))
        ..writeln(
          '\nThese files shed getIt use. Tighten the baseline: dart run '
          'tool/di/validate.dart --update-baseline',
        );
      exit(1);
    }
  }

  if (updating) {
    baselineFile.writeAsStringSync(encodeBaseline(result.debt));
  }
  stdout.writeln(
    '${updating ? 'Baseline updated' : 'getIt check passed'}: '
    '${result.debt.length} files still carry ${result.totalLookups} lookups '
    'and ${result.totalIsRegistered} isRegistered checks.',
  );
}
