import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The most lines a hand-written Dart file in `lib/` may have.
const lineLimit = 1000;

const _baselinePath = 'test/architecture/file_size_baseline.json';

/// Lines in [source], counted as `wc -l` does for a file ending in a newline.
int lineCount(String source) {
  if (source.isEmpty) return 0;
  final newlines = '\n'.allMatches(source).length;
  return source.endsWith('\n') ? newlines : newlines + 1;
}

/// Generated sources restate the hand-written ones, and the l10n catalogues
/// grow with every label by design.
bool isExempt(String path) =>
    path.startsWith('lib/l10n/') ||
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

/// The files in [sizes] that break the ratchet: one above [lineLimit] that
/// [baseline] does not list, or one that grew past its baseline entry.
List<String> sizeViolations(
  Map<String, int> sizes,
  Map<String, int> baseline,
) => [
  for (final MapEntry(key: path, value: lines) in sizes.entries)
    if (baseline[path] case final cap? when lines > cap)
      _grew(path, cap, lines)
    else if (!baseline.containsKey(path) && lines > lineLimit)
      _overLimit(path, lines),
];

String _grew(String path, int cap, int lines) =>
    '$path: grew from $cap to $lines lines. It is held at its size until '
    'someone splits it; move the new code into a file of its own.';

String _overLimit(String path, int lines) =>
    '$path: $lines lines, over the $lineLimit-line limit. Split it before it '
    'becomes the next file nobody can review.';

/// Keeps the files that are already too big from growing, and new files from
/// joining them.
///
/// The codebase review found the hardest files to change concentrated in
/// goals and the agent runtime — a 3,600-line page, 2,000-line workflows —
/// and growing. Splitting them is their owners' work; this guard stops the
/// list getting longer meanwhile. Each file in [_baselinePath] may shrink,
/// never grow, and every other file stays at or below [lineLimit].
void main() {
  group('sizeViolations', () {
    test('a new file over the limit fails, one at the limit passes', () {
      expect(
        sizeViolations({
          'lib/a.dart': lineLimit,
          'lib/b.dart': lineLimit + 1,
        }, const {}),
        [contains('lib/b.dart: ${lineLimit + 1} lines, over the')],
      );
    });

    test('a listed file may stay or shrink, never grow', () {
      const baseline = {'lib/big.dart': 2000, 'lib/other.dart': 1500};
      expect(
        sizeViolations({
          'lib/big.dart': 2000,
          'lib/other.dart': 1200,
        }, baseline),
        isEmpty,
      );
      expect(
        sizeViolations({'lib/big.dart': 2001}, baseline),
        [contains('lib/big.dart: grew from 2000 to 2001 lines')],
      );
    });

    test('lines are counted as wc -l counts them', () {
      expect(lineCount(''), 0);
      expect(lineCount('a\n'), 1);
      expect(lineCount('a\nb'), 2);
      expect(lineCount('a\n\nb\n'), 3);
    });

    test('generated sources and l10n catalogues are exempt', () {
      expect(isExempt('lib/l10n/app_localizations_de.dart'), isTrue);
      expect(isExempt('lib/classes/task.freezed.dart'), isTrue);
      expect(isExempt('lib/classes/task.g.dart'), isTrue);
      expect(isExempt('lib/classes/task.dart'), isFalse);
    });
  });

  test('no file in lib/ outgrows the limit or its baseline entry', () {
    final decoded =
        jsonDecode(File(_baselinePath).readAsStringSync())
            as Map<String, dynamic>;
    final baseline = (decoded['files'] as Map<String, dynamic>).map(
      (path, lines) => MapEntry(path, lines as int),
    );

    final sizes = <String, int>{
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !isExempt(file.path.replaceAll(r'\', '/')))
          file.path.replaceAll(r'\', '/'): lineCount(file.readAsStringSync()),
    };

    expect(
      sizeViolations(sizes, baseline),
      isEmpty,
      reason: 'Baseline: $_baselinePath',
    );
    expect(
      baseline.keys.where((path) => !sizes.containsKey(path)),
      isEmpty,
      reason:
          'These baseline entries name files that no longer exist; delete '
          'them from $_baselinePath.',
    );
  });
}
