// Checks that `lib/` reaches icons through `LottiIcons` rather than picking
// Material or MDI glyphs at the call site.
//
// Usage:
//   dart run tool/icons/validate.dart [--update-baseline]
//
// Exits 0 when no file has grown its legacy-icon debt and Lucide stays bound in
// the design system, 1 otherwise. See `icon_guard.dart` for the rules and the
// reasoning behind the ratchet.

import 'dart:io';

import 'icon_guard.dart';

const _baselinePath = 'tool/icons/baseline.json';

const _usage =
    '''
Checks icon-token discipline in lib/.

Usage: dart run tool/icons/validate.dart [--update-baseline]

  --update-baseline   Rewrite $_baselinePath from the current tree. Run this
                      after migrating a batch, so the ratchet tightens.
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

  final repoRoot = Directory.current.path;
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('error: no `lib/` here — run from the repository root');
    exit(1);
  }

  final baselineFile = File(_baselinePath);
  final result = scan(
    root: lib,
    baseline: updating ? const {} : readBaseline(baselineFile),
    repoRoot: repoRoot,
  );

  if (updating) {
    baselineFile.writeAsStringSync(encodeBaseline(result.debt));
    stdout.writeln(
      'Baseline updated: ${result.debt.length} files still carry '
      '${result.totalDebt} legacy icon references.',
    );
    // Lucide containment is a hard rule, never ratcheted — updating the
    // baseline must not launder it away.
    if (result.violations.isEmpty) return;
  }

  final blocking = updating
      ? result.violations
            .where((v) => v.message.contains('LucideIcons'))
            .toList()
      : result.violations;

  if (blocking.isEmpty) {
    stdout.writeln(
      'Icon check passed. ${result.debt.length} files still to migrate '
      '(${result.totalDebt} references).',
    );
    return;
  }

  stderr.writeln('Icon check failed:\n');
  for (final violation in blocking) {
    stderr.writeln('  $violation\n');
  }
  stderr.writeln(
    'Icons come from `LottiIcons` '
    '(lib/features/design_system/theme/icon_tokens.dart). If a migration '
    'legitimately reduced a file, re-run with --update-baseline to tighten '
    'the ratchet.',
  );
  exit(1);
}
