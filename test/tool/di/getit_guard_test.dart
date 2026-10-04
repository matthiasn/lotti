import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Relative import: the guard is a repo tool, not part of the `lotti` package.
//
// NOTE: the `getIt<…>` strings in the fixtures below are *data* — the input this
// guard exists to detect. A migration sweep that rewrites them would leave every
// test here passing vacuously. Leave them as literals.
import '../../../tool/di/getit_guard.dart';

/// Wraps statements in a function, so the fixture is valid Dart: the guard
/// counts on parsed source, and the analyzer gate guarantees real files parse.
String body(String statements) => 'void f() { $statements }';

/// Builds a throwaway tree with [files] laid out under `lib/` and scans it.
GuardResult scanFixture(
  Map<String, String> files, {
  Map<String, GetItDebt> baseline = const {},
}) {
  final root = Directory.systemTemp.createTempSync('getit_guard_test');
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
  group('counting', () {
    test('counts every lookup form and isRegistered separately', () {
      final result = scanFixture({
        'lib/features/a/ui/page.dart': '''
final db = getIt<JournalDb>();
final nav = getIt.get<NavService>();
final tearOff = getIt.get<ProfileContext>;
final old = GetIt.I<Foo>();
final older = GetIt.instance.get<Bar>();
if (getIt.isRegistered<DomainLogger>()) {}
''',
      });

      expect(result.debt, {
        'lib/features/a/ui/page.dart': (lookups: 5, isRegistered: 1),
      });
      expect(result.totalLookups, 5);
      expect(result.totalIsRegistered, 1);
    });

    test('ignores lookalike identifiers and whole-line comments', () {
      // `myGetIt<…>` and `forgetIt<…>` are other names; prose in a doc comment
      // describing a lookup is not one.
      final result = scanFixture({
        'lib/a.dart': '''
/// Resolves the logger with `getIt<DomainLogger>()` when wired.
// final db = getIt<JournalDb>();
final a = myGetIt<Foo>();
final b = forgetIt<Bar>();
''',
      });

      expect(result.debt, isEmpty);
    });

    test('ignores trailing comments, block comments and string literals', () {
      expect(
        countGetIt('''
final a = 1; // getIt<A>()
/* getIt<B>() and getIt.isRegistered<C>() */
final s = 'getIt<D>()';
final t = """getIt.get<E>()""";
final r = r'GetIt.I';
'''),
        (lookups: 0, isRegistered: 0),
      );
    });

    test('counts a lookup inside a string interpolation', () {
      // Interpolated code runs; it is a real lookup.
      expect(
        countGetIt(r"final s = 'db: ${getIt<JournalDb>()}';"),
        (lookups: 1, isRegistered: 0),
      );
    });

    test('a member named getIt on another object is not the locator', () {
      expect(
        countGetIt('final a = locator.getIt<A>(); final b = x?.getIt<B>();'),
        (lookups: 0, isRegistered: 0),
      );
    });

    test('comment and string mentions never fail the ratchet', () {
      const page = 'lib/features/a/ui/page.dart';
      const mentions = '''
final a = 1; // was getIt<A>()
/* getIt<B>() */
final s = 'getIt<C>()';
''';
      // At its baseline: the mentions add nothing on top of the one lookup.
      final atBaseline = scanFixture(
        {page: 'final x = getIt<X>();\n$mentions'},
        baseline: {page: (lookups: 1, isRegistered: 0)},
      );
      expect(atBaseline.violations, isEmpty);

      // A new file with only mentions carries no debt at all.
      final fresh = scanFixture({'lib/features/b/ui/new_page.dart': mentions});
      expect(fresh.debt, isEmpty);
      expect(fresh.violations, isEmpty);
    });

    test('skips the composition root and generated files', () {
      final result = scanFixture({
        for (final path in compositionRoot) path: body('getIt<JournalDb>();'),
        'lib/features/a/state/c.g.dart': body('getIt<JournalDb>();'),
        'lib/features/a/state/c.freezed.dart': body('getIt<JournalDb>();'),
      });

      expect(result.debt, isEmpty);
      expect(result.violations, isEmpty);
    });
  });

  group('ratchet', () {
    const page = 'lib/features/a/ui/page.dart';

    test('a file at its baseline passes', () {
      final result = scanFixture(
        {page: body('getIt<A>(); getIt<B>(); getIt.isRegistered<C>();')},
        baseline: {page: (lookups: 2, isRegistered: 1)},
      );

      expect(result.violations, isEmpty);
    });

    test('a file below its baseline passes and reports its smaller debt', () {
      final result = scanFixture(
        {page: body('getIt<A>();')},
        baseline: {page: (lookups: 3, isRegistered: 2)},
      );

      expect(result.violations, isEmpty);
      expect(result.debt[page], (lookups: 1, isRegistered: 0));
    });

    test('a new file may not introduce a lookup', () {
      final result = scanFixture({page: body('getIt<JournalDb>();')});

      expect(result.violations.single.path, page);
      expect(result.violations.single.message, contains('introduces 1'));
    });

    test('lookups and isRegistered checks are ratcheted independently', () {
      // Trading a lookup for an isRegistered check is still growth.
      final result = scanFixture(
        {
          page: body(
            'getIt<A>(); getIt.isRegistered<B>(); getIt.isRegistered<C>();',
          ),
        },
        baseline: {page: (lookups: 2, isRegistered: 1)},
      );

      expect(result.violations.single.message, contains('grew from 1 to 2'));
      expect(result.violations.single.message, contains('isRegistered'));
    });

    test('a migrating file that grows reports both counts', () {
      final result = scanFixture(
        {page: body('getIt<A>(); getIt<B>(); getIt<C>();')},
        baseline: {page: (lookups: 2, isRegistered: 0)},
      );

      expect(
        result.violations.single.message,
        contains('lookups grew from 2 to 3'),
      );
    });
  });

  group('paths', () {
    test('Windows paths become the same posix keys as everywhere else', () {
      expect(
        repoRelative(
          r'C:\src\lotti\lib\features\a\ui\page.dart',
          r'C:\src\lotti',
          context: p.windows,
        ),
        'lib/features/a/ui/page.dart',
      );
      expect(
        repoRelative(
          r'C:\src\lotti\lib\get_it.dart',
          r'C:\src\lotti\',
          context: p.windows,
        ),
        'lib/get_it.dart',
      );
    });

    test('every part of lib/get_it.dart belongs to the composition root', () {
      // A part is the same library as get_it.dart; leaving one out would
      // record composition-root code as debt to migrate away.
      final parts = RegExp("^part '([^']+)';", multiLine: true)
          .allMatches(File('lib/get_it.dart').readAsStringSync())
          .map((m) => 'lib/${m.group(1)}')
          .toList();

      expect(parts, isNotEmpty);
      expect(compositionRoot, containsAll(parts));
    });
  });

  group('baseline file', () {
    test('round-trips, omits zero counts, and is deterministic', () {
      final debt = <String, GetItDebt>{
        'lib/z.dart': (lookups: 0, isRegistered: 2),
        'lib/a.dart': (lookups: 3, isRegistered: 0),
      };
      final encoded = encodeBaseline(debt);

      expect(encoded, contains('"lib/a.dart": {"lookups": 3}'));
      expect(encoded, contains('"lib/z.dart": {"isRegistered": 2}'));
      expect(encoded, isNot(contains('_total')));
      expect(
        encoded.indexOf('lib/a.dart'),
        lessThan(encoded.indexOf('lib/z.dart')),
      );

      final dir = Directory.systemTemp.createTempSync('getit_baseline');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/baseline.json')
        ..writeAsStringSync(encoded);
      expect(readBaseline(file), debt);
      expect(encodeBaseline(readBaseline(file)), encoded);
    });

    test('a missing baseline tolerates no debt', () {
      expect(readBaseline(File('/nonexistent/baseline.json')), isEmpty);
    });
  });
}
