import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package.
// The `developer.log(` strings in the fixtures below are *data* — the input
// this guard exists to detect. Leave them as literals.
import '../../../tool/logging/developer_log_guard.dart';

List<DeveloperLogViolation> scanFixture(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('developer_log_guard');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final entry in files.entries) {
    File('${root.path}/${entry.key}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }
  return scan(root: Directory('${root.path}/lib'), repoRoot: root.path);
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

  group('countDevLoggerUses', () {
    test('counts calls, tear-offs and type uses', () {
      expect(
        countDevLoggerUses('''
void f() {
  DevLogger.log(name: 'a', message: 'b');
  final emit = DevLogger.warning;
  DevLogger.suppressOutput = true;
}
'''),
        3,
      );
    });

    test('ignores comments, strings and members sharing the name', () {
      expect(
        countDevLoggerUses('''
// DevLogger.log(name: 'a', message: 'b');
void f(Object o) {
  print('DevLogger.log');
  o.DevLogger;
}
'''),
        0,
      );
    });
  });

  group('scan', () {
    const usesDevLogger = '''
void f() {
  DevLogger.log(name: 'a', message: 'b');
}
''';

    test('skips the logging layer and generated files', () {
      final violations = scanFixture({
        'lib/services/domain_logging.dart': _prefixed,
        'lib/features/a/state/x.g.dart': _prefixed,
      });

      expect(violations, isEmpty);
    });

    test('resolves a part file through its library on disk', () {
      final violations = scanFixture({
        'lib/features/a/lib.dart':
            "import 'dart:developer' as developer;\npart 'part.dart';\n",
        'lib/features/a/part.dart':
            "part of 'lib.dart';\nvoid f() { developer.log('x'); }\n",
      });

      expect(violations.map((v) => v.path), ['lib/features/a/part.dart']);
      expect(violations.single.message, contains('has 1 `dart:developer`'));
    });

    test('DevLogger is allowed only beneath the logging pipeline', () {
      final violations = scanFixture({
        'lib/database/common.dart': usesDevLogger,
        'lib/services/dev_logger.dart': usesDevLogger,
        'lib/services/logging_service.dart': usesDevLogger,
        'lib/services/entities_cache_service.dart': usesDevLogger,
        'lib/features/a/x.dart': usesDevLogger,
      });

      expect(violations.map((v) => v.path), [
        'lib/features/a/x.dart',
        'lib/services/entities_cache_service.dart',
      ]);
      expect(
        violations.map((v) => v.message),
        everyElement(contains('uses `DevLogger` 1 time;')),
      );
    });

    test('a part file under lib/features/ using DevLogger is flagged', () {
      final violations = scanFixture({
        'lib/features/a/lib.dart': "part 'part.dart';\n",
        'lib/features/a/part.dart': "part of 'lib.dart';\n$usesDevLogger",
      });

      expect(violations.map((v) => v.path), ['lib/features/a/part.dart']);
      expect(violations.single.message, contains('uses `DevLogger` 1 time;'));
    });

    test('a member access ?.DevLogger is not a DevLogger use', () {
      final violations = scanFixture({
        'lib/features/a/x.dart': 'void f(dynamic o) { o?.DevLogger; }\n',
      });

      expect(violations, isEmpty);
    });

    test('lib/database/ may use DevLogger but not dart:developer', () {
      final violations = scanFixture({'lib/database/common.dart': _prefixed});

      expect(violations.map((v) => v.path), ['lib/database/common.dart']);
      expect(violations.single.message, contains('has 2 `dart:developer`'));
    });

    test('a file with both kinds yields one violation for each', () {
      final violations = scanFixture({
        'lib/features/a/x.dart': '''
import 'dart:developer' as developer;

void f() {
  developer.log('a');
  DevLogger.log(name: 'a', message: 'b');
  DevLogger.warning(name: 'a', message: 'b');
}
''',
      });

      expect(violations.map((v) => v.path), [
        'lib/features/a/x.dart',
        'lib/features/a/x.dart',
      ]);
      expect(
        violations.first.message,
        contains('has 1 `dart:developer` log call.'),
      );
      expect(violations.last.message, contains('uses `DevLogger` 2 times;'));
    });

    test('a file without dart:developer logging passes', () {
      final violations = scanFixture({
        'lib/features/a/x.dart': "void f() { print('a'); }\n",
      });

      expect(violations, isEmpty);
    });

    test('any file outside the logging layer that logs is a violation', () {
      final violations = scanFixture({'lib/features/a/x.dart': _prefixed});

      expect(violations.single.path, 'lib/features/a/x.dart');
      expect(violations.single.message, contains('has 2'));
      expect(violations.single.message, contains('DomainLogger'));
    });
  });
}
