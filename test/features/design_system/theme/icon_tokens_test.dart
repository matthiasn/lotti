import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// These are source-level assertions rather than runtime ones because Flutter
/// has no reflection: there is no way to enumerate `LottiIcons`' members at
/// runtime, and hand-listing 164 tokens in the test would just be the same file
/// written twice, drifting the moment someone adds a token.
///
/// `make icon_check` already makes a raw `Icons.` binding impossible *inside*
/// this file, so what is left to pin is what the guard cannot see: that every
/// glyph is a base outlined one, and that the vocabulary stays navigable.
void main() {
  const path = 'lib/features/design_system/theme/icon_tokens.dart';
  final source = File(path).readAsStringSync();
  final bindings = RegExp(
    r'static const IconData (\w+) = ([\w.]+);',
  ).allMatches(source).toList();

  test('the token file was found and parsed', () {
    // Every other test here reads `bindings`; if the regex silently matched
    // nothing they would all pass vacuously.
    expect(
      bindings,
      isNotEmpty,
      reason: 'no `static const IconData` bindings parsed out of $path',
    );
  });

  test('every token binds to a Lucide glyph', () {
    final foreign = <String>[
      for (final m in bindings)
        if (!m.group(2)!.startsWith('LucideIcons.'))
          '${m.group(1)} = ${m.group(2)}',
    ];

    expect(
      foreign,
      isEmpty,
      reason:
          'the point of the token layer is one icon family; these escape it',
    );
  });

  test('no token uses a weight-variant or directional Lucide glyph', () {
    // Lucide ships each glyph at nine stroke weights (`check100` … `check900`)
    // and in RTL-mirrored `…Dir` forms. Mixing those into the set would put
    // different stroke weights side by side in the same row, which is exactly
    // the inconsistency this migration exists to remove.
    final variant = RegExp(r'^LucideIcons\.\w*?([1-9]00|Dir)$');
    final offenders = <String>[
      for (final m in bindings)
        if (variant.hasMatch(m.group(2)!)) '${m.group(1)} = ${m.group(2)}',
    ];

    expect(offenders, isEmpty);
  });

  test('no two tokens share a name', () {
    final names = bindings.map((m) => m.group(1)!).toList();

    expect(names.toSet(), hasLength(names.length));
  });

  test('every token carries a doc comment saying what it means', () {
    // A token named for its intent is only useful if the intent is written
    // down; without this the set decays back into a glyph catalogue with
    // opaque names.
    final undocumented = <String>[];
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = RegExp(
        r'^\s*static const IconData (\w+) =',
      ).firstMatch(lines[i]);
      if (match == null) continue;
      if (i == 0 || !lines[i - 1].trimLeft().startsWith('///')) {
        undocumented.add(match.group(1)!);
      }
    }

    expect(undocumented, isEmpty);
  });
}
