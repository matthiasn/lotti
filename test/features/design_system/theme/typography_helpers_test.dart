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

  group('calm typography', () {
    test('eyebrow is 11/600 with 0.04em tracking and low-emphasis default', () {
      const tokens = dsTokensDark;
      final style = calmEyebrowStyle(tokens);

      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, closeTo(11 * 0.04, 1e-9));
      expect(style.color, tokens.colors.text.lowEmphasis);
      expect(
        style.fontFamily,
        tokens.typography.styles.others.overline.fontFamily,
      );
    });

    test('page title is 23/600 with -0.015em tracking', () {
      const tokens = dsTokensLight;
      final style = calmPageTitleStyle(tokens);

      expect(style.fontSize, 23);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, closeTo(23 * -0.015, 1e-9));
      expect(style.color, tokens.colors.text.highEmphasis);
    });

    test('hero is 34/500 with -0.02em tracking', () {
      const tokens = dsTokensLight;
      final style = calmHeroStyle(tokens);

      expect(style.fontSize, 34);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.letterSpacing, closeTo(34 * -0.02, 1e-9));
      expect(style.color, tokens.colors.text.highEmphasis);
    });

    test('display moment is 26/600 with -0.02em tracking', () {
      const tokens = dsTokensDark;
      final style = calmDisplayStyle(tokens);

      expect(style.fontSize, 26);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, closeTo(26 * -0.02, 1e-9));
      expect(style.color, tokens.colors.text.highEmphasis);
    });

    test('greeting is 12/500 with low-emphasis default', () {
      const tokens = dsTokensLight;
      final style = calmGreetingStyle(tokens);

      expect(style.fontSize, tokens.typography.styles.others.caption.fontSize);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.color, tokens.colors.text.lowEmphasis);
    });

    glados.Glados2(
      glados.any.dsTokens,
      glados.any.maybeColor,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'calm invariants hold for both themes: no style exceeds 600 weight, '
      'eyebrow tracking stays tight, and the color override always wins',
      (tokens, color) {
        final styles = [
          calmEyebrowStyle(tokens, color: color),
          calmPageTitleStyle(tokens, color: color),
          calmHeroStyle(tokens, color: color),
          calmDisplayStyle(tokens, color: color),
          calmGreetingStyle(tokens, color: color),
        ];

        for (final style in styles) {
          // Calm rule: one title weight (600), never 700.
          expect(
            style.fontWeight!.value,
            lessThanOrEqualTo(FontWeight.w600.value),
            reason: 'calm styles never use 700 weight',
          );
          if (color != null) {
            expect(style.color, color);
          }
        }

        // Eyebrows must not inherit the legacy +8 tracking.
        expect(
          calmEyebrowStyle(tokens, color: color).letterSpacing,
          lessThan(1),
        );
      },
      tags: 'glados',
    );
  });
}
