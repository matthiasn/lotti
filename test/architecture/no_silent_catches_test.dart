import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every swallowed exception in `lib/` says why.
///
/// `empty_catches` exempts `catch (_) {}`, so a swallow costs nothing to
/// write and nothing to review: a failure hidden that way surfaces later,
/// far from its cause. An empty catch must carry a comment naming the reason
/// (teardown, best-effort telemetry, a fallback that follows), or log what it
/// caught.
void main() {
  test('no catch (_) {} in lib/ without a reason', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('.g.dart') ||
          file.path.endsWith('.freezed.dart')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*\}').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
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
