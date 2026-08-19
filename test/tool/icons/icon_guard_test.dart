import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package,
// so it has no `package:` URI.
//
// NOTE: the `Icons.` / `MdiIcons.` strings in the fixtures below are *data* —
// they are the input this guard exists to detect. A find-and-replace across the
// repo will happily rewrite them into `LottiIcons.` and leave every test here
// passing vacuously against input that contains nothing to find. That happened
// once during the migration. Leave them as literals.
import '../../../tool/icons/icon_guard.dart';

/// Builds a throwaway tree with [files] laid out under `lib/` and scans it.
///
/// Each test gets its own directory so a stray file cannot leak between them.
GuardResult scanFixture(
  Map<String, String> files, {
  Map<String, int> baseline = const {},
}) {
  final root = Directory.systemTemp.createTempSync('icon_guard_test');
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
  group('legacy family detection', () {
    test('counts Material and MDI references but not the Lucide binding', () {
      final result = scanFixture({
        'lib/a.dart': 'Icon(Icons.check); Icon(Icons.close);',
        'lib/b.dart': 'Icon(MdiIcons.star);',
      });

      expect(result.debt, {'lib/a.dart': 2, 'lib/b.dart': 1});
      expect(result.totalDebt, 3);
    });

    test(
      'does not mistake LucideIcons or CupertinoIcons for the Material family',
      () {
        // The whole guard rests on this lookbehind: without it every migrated
        // call site would keep counting as debt and the ratchet could never
        // reach zero.
        final result = scanFixture({
          tokenFile: 'const a = LucideIcons.check;',
          'lib/b.dart': 'Icon(CupertinoIcons.back);',
        });

        expect(result.debt, isEmpty);
        expect(result.violations, isEmpty);
      },
    );

    test('ignores generated sources', () {
      // A generated file restates its hand-written source, so counting it would
      // double-report one call site and drift the baseline on every codegen run.
      final result = scanFixture({
        'lib/a.g.dart': 'Icon(Icons.check);',
        'lib/a.freezed.dart': 'Icon(Icons.close);',
        'lib/a.gr.dart': 'Icon(Icons.add);',
      });

      expect(result.debt, isEmpty);
    });
  });

  group('the ratchet', () {
    test('tolerates debt that stays at or below its baseline', () {
      final result = scanFixture(
        {'lib/a.dart': 'Icon(Icons.check); Icon(Icons.close);'},
        baseline: {'lib/a.dart': 2},
      );

      expect(result.violations, isEmpty);
      expect(result.debt['lib/a.dart'], 2);
    });

    test('reports a file whose debt grew, naming both counts', () {
      final result = scanFixture(
        {'lib/a.dart': 'Icon(Icons.check); Icon(Icons.close);'},
        baseline: {'lib/a.dart': 1},
      );

      expect(result.violations, hasLength(1));
      expect(result.violations.single.path, 'lib/a.dart');
      expect(result.violations.single.message, contains('grew from 1 to 2'));
    });

    test('reports a file introducing icons that had none in the baseline', () {
      final result = scanFixture(
        {'lib/new.dart': 'Icon(Icons.check);'},
        baseline: {'lib/a.dart': 5},
      );

      expect(result.violations, hasLength(1));
      expect(result.violations.single.path, 'lib/new.dart');
      expect(result.violations.single.message, contains('introduces 1'));
      expect(result.violations.single.message, contains('LottiIcons'));
    });

    test('a migrated file drops out of the debt map entirely', () {
      final result = scanFixture(
        {'lib/a.dart': 'Icon(LottiIcons.confirm);'},
        baseline: {'lib/a.dart': 7},
      );

      expect(result.debt.containsKey('lib/a.dart'), isFalse);
      expect(result.violations, isEmpty);
    });
  });

  group('Lucide containment', () {
    test('the token file may bind Lucide glyphs', () {
      final result = scanFixture({
        tokenFile: 'static const confirm = LucideIcons.check;',
      });

      expect(result.violations, isEmpty);
    });

    test('an allow-listed domain glyph map may reference Lucide', () {
      final path = domainGlyphAllowlist.first;
      final result = scanFixture({path: 'const m = {A.b: LucideIcons.leaf};'});

      expect(result.violations, isEmpty);
    });

    test('feature code may not reach past the tokens to Lucide', () {
      final result = scanFixture({
        'lib/features/x/widget.dart': 'Icon(LucideIcons.check);',
      });

      expect(result.violations, hasLength(1));
      expect(
        result.violations.single.message,
        contains('references `LucideIcons` directly'),
      );
    });

    test('containment is not ratcheted — a baseline cannot license it', () {
      // Debt is forgiven per-file while the migration runs; reaching past the
      // token layer is a design error and is never forgiven.
      final result = scanFixture(
        {'lib/features/x/widget.dart': 'Icon(LucideIcons.check);'},
        baseline: {'lib/features/x/widget.dart': 99},
      );

      expect(result.violations, hasLength(1));
      expect(result.violations.single.message, contains('LucideIcons'));
    });
  });

  group('baseline serialisation', () {
    test('round-trips through encode and read', () {
      final file = File(
        '${Directory.systemTemp.createTempSync('icon_baseline').path}/b.json',
      );
      addTearDown(() => file.parent.deleteSync(recursive: true));

      const debt = {'lib/b.dart': 2, 'lib/a.dart': 5};
      file.writeAsStringSync(encodeBaseline(debt));

      expect(readBaseline(file), debt);
    });

    test('encodes deterministically so a re-run produces no diff', () {
      expect(
        encodeBaseline({'lib/b.dart': 2, 'lib/a.dart': 5}),
        encodeBaseline({'lib/a.dart': 5, 'lib/b.dart': 2}),
      );
    });

    test('records the total, so a reviewer sees the trend in the diff', () {
      expect(
        encodeBaseline({'lib/a.dart': 5, 'lib/b.dart': 2}),
        contains('"_total": 7'),
      );
    });

    test('a missing baseline tolerates no debt at all', () {
      expect(readBaseline(File('/definitely/not/here.json')), isEmpty);
    });
  });
}
