import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A catch clause whose parameters are all underscores and whose block is
/// empty: `catch (_) {}`, `catch (_, _) {}`, and the same split over lines.
final _silentCatch = RegExp(r'catch\s*\(\s*_+\s*(?:,\s*_+\s*)?\)\s*\{\s*\}');

/// The 1-based lines in [source] where a silent catch starts.
List<int> silentCatchLines(String source) => [
  for (final match in _silentCatch.allMatches(source))
    '\n'.allMatches(source.substring(0, match.start)).length + 1,
];

/// Every swallowed exception in `lib/` says why.
///
/// `empty_catches` exempts handlers whose parameters are all underscores, so
/// such a swallow costs nothing to write and nothing to review: a failure
/// hidden that way surfaces later, far from its cause. An empty catch must
/// carry a comment naming the reason (teardown, best-effort telemetry, a
/// fallback that follows), or log what it caught.
void main() {
  test('the matcher finds every underscore-only empty handler', () {
    expect(
      silentCatchLines('''
try {} catch (_) {}
try {} catch (_, _) {}
try {} on StateError catch (_) {}
try {} catch (_) {
}
try {} catch (_) {
  // A reason.
}
try {} catch (error) {
  log(error);
}
'''),
      [1, 2, 3, 4],
    );
  });

  test('no underscore-only empty catch in lib/ without a reason', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('.g.dart') ||
          file.path.endsWith('.freezed.dart')) {
        continue;
      }
      for (final line in silentCatchLines(file.readAsStringSync())) {
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Give each swallowed exception a reason comment inside the block, '
          'or log it.',
    );
  });
}
