import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The filled font is generated, and its codepoints are assigned *positionally*:
/// `svgtofont` numbers glyphs alphabetically from `0xea01`, so adding one glyph
/// silently renumbers every glyph after it. Nothing in Dart would fail — the
/// constants keep compiling and the app just draws the wrong pictures.
///
/// So these derive the expected codepoints from the checked-in SVG sources
/// rather than restating the constants, which is the one thing that actually
/// catches the renumbering.
void main() {
  const svgDir = 'tool/icons/filled_font/svg';

  // Written out because the Dart class cannot be enumerated at runtime; the
  // pairing test below is what keeps this list honest against the sources.
  const bindings = <String, IconData>{
    'bookmark': LottiIconsFilled.bookmark,
    'circle': LottiIconsFilled.circle,
    'flag': LottiIconsFilled.flag,
    'folder': LottiIconsFilled.folder,
    'heart': LottiIconsFilled.heart,
    'moon': LottiIconsFilled.moon,
    'square': LottiIconsFilled.square,
    'star': LottiIconsFilled.star,
  };

  test('every source SVG has a binding, and vice versa', () {
    final sources = Directory(svgDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.svg'))
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toSet();

    expect(
      sources,
      bindings.keys.toSet(),
      reason: 'a glyph was added or removed without updating the Dart bindings',
    );
  });

  test("codepoints follow the generator's alphabetical numbering", () {
    final names = bindings.keys.toList()..sort();
    for (var i = 0; i < names.length; i++) {
      expect(
        bindings[names[i]]!.codePoint,
        0xea01 + i,
        reason:
            '`${names[i]}` should be 0x${(0xea01 + i).toRadixString(16)}. If a '
            'glyph was added, every later codepoint shifts — regenerate the '
            'bindings from dist/LottiFilled.svg rather than editing one.',
      );
    }
  });

  test('every filled glyph resolves to the generated font, not a fallback', () {
    for (final entry in bindings.entries) {
      expect(
        entry.value.fontFamily,
        'LottiFilled',
        reason: '${entry.key} would render as tofu from any other family',
      );
    }
  });

  test('the font asset the bindings point at is bundled', () {
    // A binding to a font pubspec does not ship renders as blank space in
    // release while looking perfect in a test that loaded it from disk.
    expect(
      File('assets/fonts/LottiFilled/LottiFilled.ttf').existsSync(),
      isTrue,
    );
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/fonts/LottiFilled/LottiFilled.ttf'),
    );
  });

  test('each filled glyph is genuinely filled, not a copied outline', () {
    // The whole point is `fill="currentColor"`; a source left at `fill="none"`
    // would build, bind and render — as the outline, making the toggle a no-op
    // again in exactly the way this font exists to prevent.
    for (final name in bindings.keys) {
      final svg = File('$svgDir/$name.svg').readAsStringSync();
      expect(
        svg,
        contains('fill="currentColor"'),
        reason: '$name is not filled',
      );
      expect(
        svg,
        isNot(contains('fill="none"')),
        reason: '$name kept fill:none',
      );
    }
  });
}
