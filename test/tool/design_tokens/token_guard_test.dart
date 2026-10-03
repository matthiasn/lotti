import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package.
// The raw values in the fixtures below are *data* — the input this guard
// exists to detect. A token-migration sweep must leave them as they are.
import '../../../tool/design_tokens/token_guard.dart';

Map<TokenCategory, int> count(String body) =>
    countRawValues('void f() {\n$body\n}');

GuardResult scanFixture(
  Map<String, String> files, {
  Map<String, Map<TokenCategory, int>> baseline = const {},
}) {
  final root = Directory.systemTemp.createTempSync('token_guard');
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
  group('countRawValues', () {
    test('spacing: numeric EdgeInsets and SizedBox gaps, const or not', () {
      expect(
        count('''
          EdgeInsets.all(8);
          const EdgeInsets.symmetric(horizontal: 12);
          EdgeInsetsDirectional.only(start: -4);
          SizedBox(height: 16);
          const SizedBox(width: 8.5);
        '''),
        {
          TokenCategory.spacing: 5,
          TokenCategory.typography: 0,
          TokenCategory.color: 0,
        },
      );
    });

    test('spacing tokens and non-numeric gaps do not count', () {
      expect(
        count('''
          EdgeInsets.all(tokens.spacing.step3);
          EdgeInsets.zero;
          SizedBox(height: tokens.spacing.step4);
          SizedBox(child: child);
          SizedBox.shrink();
        ''')[TokenCategory.spacing],
        0,
      );
    });

    test('typography: a TextStyle counts once, a stray fontSize too', () {
      expect(
        count('''
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
          TextStyle(color: c);
          base.copyWith(fontSize: 14);
        ''')[TokenCategory.typography],
        3,
      );
    });

    test('color: literals and Material swatches, not transparent', () {
      expect(
        count('''
          Color(0xFF123456);
          const Color(0x80000000);
          Color.fromARGB(255, 1, 2, 3);
          Color.fromRGBO(1, 2, 3, 0.5);
          Colors.red;
          Colors.blueGrey.shade200;
          Colors.transparent;
          Color(value);
          tokens.colors.background.level01;
        ''')[TokenCategory.color],
        6,
      );
    });

    test('comments and strings never count', () {
      expect(
        count('''
          // EdgeInsets.all(8); TextStyle(fontSize: 12); Colors.red;
          final s = 'SizedBox(height: 4) Color(0xFF000000)';
        ''').values,
        everyElement(0),
      );
    });
  });

  group('scan', () {
    const file = 'lib/features/a/ui/page.dart';
    const raw = 'void f() { EdgeInsets.all(8); Colors.red; }';

    test('skips the token definitions and generated files', () {
      final result = scanFixture({
        'lib/features/design_system/theme/spacing.dart': raw,
        'lib/features/a/ui/page.g.dart': raw,
      });

      expect(result.counts, isEmpty);
      expect(result.violations, isEmpty);
    });

    test('a file at its baseline passes; categories ratchet independently', () {
      final atBaseline = scanFixture(
        {file: raw},
        baseline: {
          file: {TokenCategory.spacing: 1, TokenCategory.color: 1},
        },
      );
      expect(atBaseline.violations, isEmpty);

      // Swapping a colour for a second spacing value is still growth.
      final traded = scanFixture(
        {file: 'void f() { EdgeInsets.all(8); EdgeInsets.all(4); }'},
        baseline: {
          file: {TokenCategory.spacing: 1, TokenCategory.color: 1},
        },
      );
      expect(
        traded.violations.single.message,
        contains('spacing values grew from 1 to 2'),
      );
    });

    test('a new file may not introduce raw values', () {
      final result = scanFixture({file: raw});

      expect(result.violations.map((v) => v.message), [
        contains('introduces 1 raw spacing value'),
        contains('introduces 1 raw color value'),
      ]);
    });
  });

  test('the baseline round-trips deterministically, without zero counts', () {
    final dir = Directory.systemTemp.createTempSync('token_baseline');
    addTearDown(() => dir.deleteSync(recursive: true));
    final counts = {
      'lib/z.dart': {
        TokenCategory.spacing: 0,
        TokenCategory.typography: 2,
        TokenCategory.color: 0,
      },
      'lib/a.dart': {
        TokenCategory.spacing: 3,
        TokenCategory.typography: 0,
        TokenCategory.color: 1,
      },
    };
    final encoded = encodeBaseline(counts);
    final file = File('${dir.path}/baseline.json')..writeAsStringSync(encoded);

    expect(encoded, contains('"lib/z.dart": {"typography":2}'));
    expect(readBaseline(file), counts);
    expect(encodeBaseline(readBaseline(file)), encoded);
  });
}
