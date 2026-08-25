// Checks the release-note fragments in `changelog.d/`, and that the released
// version agrees across pubspec.yaml, CHANGELOG.md and the Flathub metainfo.
//
// Usage:
//   dart run tool/changelog/validate.dart [--strict]
//
// Exits 0 when nothing is wrong, 1 on any error — or on any warning under
// `--strict`. See `fragment_guard.dart` for the rules and why they exist, and
// `changelog.d/README.md` for how to write a fragment.

import 'dart:io';

import 'fragment_guard.dart';

const _usage = '''
Checks the unreleased notes in changelog.d/.

Usage: dart run tool/changelog/validate.dart [--strict]

  --strict   Treat warnings as errors.
''';

void main(List<String> args) {
  final unknown = args.where((a) => a != '--strict').toList();
  if (unknown.isNotEmpty) {
    stderr
      ..writeln('error: unrecognised argument(s): ${unknown.join(', ')}')
      ..writeln()
      ..writeln(_usage);
    exit(1);
  }
  final strict = args.contains('--strict');

  final root = Directory.current;
  if (!File('${root.path}/$pubspecPath').existsSync()) {
    stderr.writeln(
      'error: no `$pubspecPath` here — run from the repository root',
    );
    exit(1);
  }

  final result = scan(root: root);

  // Everything goes to one stream: split across stdout and stderr, the two
  // interleave unpredictably in a CI log and the issues stop being in file
  // order, which is the only order that helps someone fixing them.
  for (final issue in result.issues) {
    stderr.writeln('  $issue');
  }

  final errors = result.errors.length;
  final warnings = result.warnings.length;
  final fragments = result.fragmentCount;

  if (errors == 0 && warnings == 0) {
    stdout.writeln(
      fragments == 0
          ? 'changelog.d/ is empty — nothing waiting for a release.'
          : '$fragments unreleased '
                '${fragments == 1 ? 'fragment' : 'fragments'}, all well formed.',
    );
  } else {
    stderr.writeln(
      '\n$errors ${errors == 1 ? 'error' : 'errors'}, '
      '$warnings ${warnings == 1 ? 'warning' : 'warnings'} '
      'across $fragments ${fragments == 1 ? 'fragment' : 'fragments'}. '
      'See changelog.d/README.md.',
    );
  }

  if (errors > 0 || (strict && warnings > 0)) exit(1);
}
