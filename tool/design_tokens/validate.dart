// Checks that no file outside the token definitions grows its raw spacing,
// typography or colour values.
//
// Usage:
//   dart run tool/design_tokens/validate.dart [--update-baseline]
//
// Exits 0 when every file is at or below its baseline in every category, 1
// otherwise. See `token_guard.dart` for what counts and why.

import 'dart:io';

import 'token_guard.dart';

const _baselinePath = 'tool/design_tokens/baseline.json';

const _usage =
    '''
Checks that raw spacing, typography and colour values only shrink.

Usage: dart run tool/design_tokens/validate.dart [--update-baseline]

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
    stderr.writeln('design-token check failed:\n');
    for (final violation in result.violations) {
      stderr.writeln('  $violation\n');
    }
    stderr.writeln(
      updating
          ? 'Not updating the baseline: it only ever goes down.'
          : 'Spacing, typography and colour come from the design-system '
                'tokens (see knowledge/features/design_system/).',
    );
    exit(1);
  }

  if (updating) baselineFile.writeAsStringSync(encodeBaseline(result.counts));
  final totals = TokenCategory.values
      .map((c) => '${c.name} ${result.total(c)}')
      .join(', ');
  stdout.writeln(
    '${updating ? 'Baseline updated' : 'Design-token check passed'}: '
    '${result.counts.length} files still carry raw values ($totals).',
  );
}
