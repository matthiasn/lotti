import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package.
import '../../../tool/async/unawaited_guard.dart';

GuardResult scanFixture(
  Map<String, String> files, {
  Map<String, int> baseline = const {},
}) {
  final root = Directory.systemTemp.createTempSync('unawaited_guard');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final entry in files.entries) {
    File('${root.path}/${entry.key}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return scan(
    root: Directory('${root.path}/lib'),
    baseline: baseline,
    repoRoot: root.path,
  );
}

void main() {
  group('countUnawaited', () {
    test('counts top-level unawaited calls only', () {
      expect(
        countUnawaited('''
void f() {
  unawaited(a());
  unawaited(Future<void>.value());
  service.unawaited(b());
  service..unawaited(c());
  // unawaited(c());
  const s = 'unawaited(d())';
}
'''),
        2,
      );
    });
  });

  group('countUnawaited — prefixes', () {
    test('a dart:async import prefix counts, another object does not', () {
      expect(
        countUnawaited('''
import 'dart:async' as async;
void f() {
  async.unawaited(a());
  other.unawaited(b());
}
'''),
        1,
      );
    });

    test("a part file takes its library's prefix", () {
      expect(
        countUnawaited(
          "part of 'lib.dart';\nvoid f() { async.unawaited(a()); }",
          librarySource: "import 'dart:async' as async;\npart 'part.dart';",
        ),
        1,
      );
    });
  });

  group('scan', () {
    const twoCalls = {
      'lib/a.dart': 'void f() { unawaited(x()); unawaited(y()); }',
    };

    test('a file at its entry passes', () {
      expect(
        scanFixture(twoCalls, baseline: {'lib/a.dart': 2}).violations,
        isEmpty,
      );
    });

    test('growth and new files fail as growth', () {
      final grew = scanFixture(twoCalls, baseline: {'lib/a.dart': 1});
      expect(grew.violations.single.grew, isTrue);
      expect(grew.violations.single.message, contains('grew from 1 to 2'));

      final fresh = scanFixture(twoCalls);
      expect(fresh.violations.single.grew, isTrue);
      expect(fresh.violations.single.message, contains('introduces 2'));
    });

    test('a shrink fails until the baseline records it', () {
      final shrank = scanFixture(twoCalls, baseline: {'lib/a.dart': 3});
      expect(shrank.violations.single.grew, isFalse);
      expect(shrank.violations.single.message, contains('--update-baseline'));

      final gone = scanFixture(
        {'lib/a.dart': 'void f() {}'},
        baseline: {'lib/a.dart': 1},
      );
      expect(gone.violations.single.grew, isFalse);
    });

    test('generated files are skipped', () {
      expect(
        scanFixture({
          'lib/a.g.dart': 'void f() { unawaited(x()); }',
        }).counts,
        isEmpty,
      );
    });
  });

  test('the baseline round-trips deterministically', () {
    final dir = Directory.systemTemp.createTempSync('unawaited_baseline');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/b.json')
      ..writeAsStringSync(encodeBaseline({'lib/b.dart': 2, 'lib/a.dart': 1}));

    expect(readBaseline(file), {'lib/a.dart': 1, 'lib/b.dart': 2});
    expect(file.readAsStringSync(), contains('"_total": 3'));
  });
}
