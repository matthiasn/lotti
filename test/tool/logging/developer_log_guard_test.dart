import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package.
// The `developer.log(` strings in the fixtures below are *data* — the input
// this guard exists to detect. Leave them as literals.
import '../../../tool/logging/developer_log_guard.dart';

GuardResult scanFixture(
  Map<String, String> files, {
  Map<String, int> baseline = const {},
}) {
  final root = Directory.systemTemp.createTempSync('developer_log_guard');
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

const _prefixed = """
import 'dart:developer' as developer;

void f() {
  developer.log('a');
  developer.log('b', name: 'X');
}
""";

void main() {
  group('countDeveloperLogs', () {
    test('counts calls through whatever prefix the import chose', () {
      expect(countDeveloperLogs(_prefixed), 2);
      expect(
        countDeveloperLogs(
          "import 'dart:developer' as dev;\nvoid f() { dev.log('x'); }",
        ),
        1,
      );
    });

    test('counts bare calls under an unprefixed import', () {
      expect(
        countDeveloperLogs(
          "import 'dart:developer';\nvoid f() { log('x'); log('y'); }",
        ),
        2,
      );
    });

    test('counts tear-offs, which can log just the same', () {
      expect(
        countDeveloperLogs(
          "import 'dart:developer' as developer;\n"
          "void f() { final emit = developer.log; emit('x'); }",
        ),
        1,
      );
      expect(
        countDeveloperLogs(
          "import 'dart:developer';\n"
          "void f() { final emit = log; emit('x'); }",
        ),
        1,
      );
    });

    test('a named argument called log is not the function', () {
      expect(
        countDeveloperLogs(
          "import 'dart:developer';\nvoid f() { g(log: true); }",
        ),
        0,
      );
    });

    test('ignores comments, strings, other loggers and files without it', () {
      expect(
        countDeveloperLogs("""
import 'dart:developer' as developer;

// developer.log('commented out');
/* developer.log('block') */
void f(Logger other) {
  final s = "developer.log('in a string')";
  other.log('not dart:developer');
}
"""),
        0,
      );
      expect(countDeveloperLogs("void f() { log('x'); }"), 0);
    });

    test("a part file counts through its library's import", () {
      expect(
        countDeveloperLogs(
          "part of 'lib.dart';\nvoid f() { developer.log('x'); }",
          librarySource:
              "import 'dart:developer' as developer;\npart 'part.dart';",
        ),
        1,
      );
    });
  });

  group('scan', () {
    test('skips the logging layer and generated files', () {
      final result = scanFixture({
        'lib/services/domain_logging.dart': _prefixed,
        'lib/features/a/state/x.g.dart': _prefixed,
      });

      expect(result.counts, isEmpty);
      expect(result.violations, isEmpty);
    });

    test('resolves a part file through its library on disk', () {
      final result = scanFixture({
        'lib/features/a/lib.dart':
            "import 'dart:developer' as developer;\npart 'part.dart';\n",
        'lib/features/a/part.dart':
            "part of 'lib.dart';\nvoid f() { developer.log('x'); }\n",
      });

      expect(result.counts, {'lib/features/a/part.dart': 1});
    });

    test('a file at or below its baseline passes', () {
      final result = scanFixture(
        {'lib/features/a/x.dart': _prefixed},
        baseline: {'lib/features/a/x.dart': 3},
      );

      expect(result.violations, isEmpty);
      expect(result.total, 2);
    });

    test('a new file may not introduce one; a migrating file may not grow', () {
      final fresh = scanFixture({'lib/features/a/new.dart': _prefixed});
      expect(fresh.violations.single.message, contains('introduces 2'));

      final grown = scanFixture(
        {'lib/features/a/x.dart': _prefixed},
        baseline: {'lib/features/a/x.dart': 1},
      );
      expect(grown.violations.single.message, contains('grew from 1 to 2'));
    });
  });

  test('the baseline round-trips deterministically', () {
    final dir = Directory.systemTemp.createTempSync('developer_log_baseline');
    addTearDown(() => dir.deleteSync(recursive: true));
    final counts = {'lib/z.dart': 1, 'lib/a.dart': 4};
    final encoded = encodeBaseline(counts);
    final file = File('${dir.path}/baseline.json')..writeAsStringSync(encoded);

    expect(readBaseline(file), counts);
    expect(encodeBaseline(readBaseline(file)), encoded);
    expect(encoded, contains('"_total": 5'));
  });
}
