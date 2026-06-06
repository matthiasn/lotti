import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';

extension _AnyTypography on glados.Any {
  glados.Generator<DsTokens> get dsTokens =>
      glados.AnyUtils(this).choose(const [dsTokensLight, dsTokensDark]);

  glados.Generator<TextStyle?> get baseStyle =>
      glados.CombinableAny(this).combine3(
        glados.any.bool,
        glados.IntAnys(this).intInRange(8, 32),
        glados.AnyUtils(
          this,
        ).choose(const [FontWeight.w300, FontWeight.w400, FontWeight.w700]),
        (bool hasBase, int size, FontWeight weight) => hasBase
            ? TextStyle(
                fontSize: size.toDouble(),
                fontWeight: weight,
                fontFamily: 'NotMono',
                letterSpacing: 1.5,
              )
            : null,
      );

  glados.Generator<Color?> get maybeColor => glados.AnyUtils(this).choose(
    const [null, Color(0xFF123456), Colors.red, Color(0x80FFFFFF)],
  );
}

void main() {
  group('monoMetaStyle', () {
    test('defaults to the caption base and low-emphasis color', () {
      const tokens = dsTokensLight;
      final style = monoMetaStyle(tokens, tokens.colors);

      expect(style.fontFamily, 'Inconsolata');
      expect(style.letterSpacing, 0);
      expect(style.color, tokens.colors.text.lowEmphasis);
      expect(
        style.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
    });

    test('a custom base keeps its size/weight; a custom color wins', () {
      const tokens = dsTokensDark;
      const base = TextStyle(fontSize: 19, fontWeight: FontWeight.w700);
      const color = Color(0xFFABCDEF);

      final style = monoMetaStyle(
        tokens,
        tokens.colors,
        base: base,
        color: color,
      );

      expect(style.fontSize, 19);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, color);
      expect(style.fontFamily, 'Inconsolata');
      expect(style.letterSpacing, 0);
    });

    glados.Glados3(
      glados.any.dsTokens,
      glados.any.baseStyle,
      glados.any.maybeColor,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'always forces the mono family and zero letter-spacing, and resolves '
      'the documented color fallback',
      (tokens, base, color) {
        final style = monoMetaStyle(
          tokens,
          tokens.colors,
          base: base,
          color: color,
        );

        expect(style.fontFamily, 'Inconsolata');
        expect(style.letterSpacing, 0);
        expect(style.color, color ?? tokens.colors.text.lowEmphasis);
        expect(
          style.fontSize,
          (base ?? tokens.typography.styles.others.caption).fontSize,
        );
      },
      tags: 'glados',
    );
  });
}
