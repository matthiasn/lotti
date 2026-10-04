// Checks that no import in lib/ breaks the declared layer order further.
//
// Usage:
//   dart run tool/architecture/validate.dart [--update-baseline]
//
// Exits 0 when the tree's layer breaks are exactly the baseline's, 1
// otherwise. See `layer_guard.dart` for the order and the rules.

import 'dart:io';

import 'layer_guard.dart';

const _baselinePath = 'tool/architecture/baseline.json';

const _usage =
    '''
Checks that imports in lib/ follow the layer order in layer_guard.dart.

Usage: dart run tool/architecture/validate.dart [--update-baseline]

  --update-baseline   Rewrite $_baselinePath from the current tree, dropping
                      the breaks that are gone. It refuses while the tree has
                      a break the baseline does not list; only a missing
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

  if (result.unranked.isNotEmpty) {
    stderr
      ..writeln('Layer check failed: no rank for')
      ..writeln(result.unranked.map((u) => '  $u').join('\n'))
      ..writeln(
        '\nAdd a new feature to featureOrder, or a new top-level path to '
        'foundation or shell, in tool/architecture/layer_guard.dart.',
      );
    exit(1);
  }

  if (result.added.isNotEmpty && !seeding) {
    stderr.writeln(
      'Layer check failed — imports that break the layer order:\n',
    );
    result.added.forEach((path, targets) {
      for (final t in targets.toList()..sort()) {
        stderr.writeln(
          t.endsWith(':ui')
              ? '  $path: non-UI code imports the UI of ${t.split(':').first}'
              : '  $path: imports $t, which ranks above it',
        );
      }
    });
    stderr.writeln(
      updating
          ? '\nNot updating the baseline: it only ever shrinks.'
          : '\nMove the shared type down to the lower feature or to lib/, or '
                'invert the dependency through an interface the lower layer '
                'owns. The order and the reasoning are in '
                'tool/architecture/layer_guard.dart.',
    );
    exit(1);
  }

  if (result.removed.isNotEmpty && !updating) {
    stderr.writeln(
      'Layer check failed — the baseline lists breaks that are gone:\n',
    );
    result.removed.forEach((path, targets) {
      stderr.writeln('  $path: ${(targets.toList()..sort()).join(', ')}');
    });
    stderr.writeln(
      '\nTighten it: dart run tool/architecture/validate.dart '
      '--update-baseline',
    );
    exit(1);
  }

  if (updating) baselineFile.writeAsStringSync(encodeBaseline(result.current));
  stdout.writeln(
    '${updating ? 'Baseline updated' : 'Layer check passed'}: '
    '${result.total} imports in ${result.current.length} files still break '
    'the layer order.',
  );
}
