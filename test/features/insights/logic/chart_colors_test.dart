import 'dart:ui' show Brightness, Color;

import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/logic/chart_colors.dart';

/// HSL values survive the Color round-trip only up to 8-bit RGB
/// quantization (~1/255 per channel).
const double _quantization = 1.5 / 255;

extension _AnyColor on glados.Any {
  glados.Generator<Color> get color => combine3(
    intInRange(0, 256),
    intInRange(0, 256),
    intInRange(0, 256),
    (int r, int g, int b) => Color.fromARGB(255, r, g, b),
  );
}

void main() {
  group('mutedChartColor', () {
    test('keeps hue but clamps saturation and lightness', () {
      const garish = Color(0xFFFF0000); // fully saturated red
      final mutedDark = HSLColor.fromColor(
        mutedChartColor(garish, Brightness.dark),
      );
      expect(mutedDark.hue, closeTo(0, 1));
      expect(mutedDark.saturation, lessThanOrEqualTo(0.52 + _quantization));
      expect(
        mutedDark.lightness,
        inInclusiveRange(0.42 - _quantization, 0.62 + _quantization),
      );

      final mutedLight = HSLColor.fromColor(
        mutedChartColor(garish, Brightness.light),
      );
      expect(
        mutedLight.lightness,
        inInclusiveRange(0.36 - _quantization, 0.56 + _quantization),
      );
    });

    test('near-white input becomes visible on light background', () {
      const nearWhite = Color(0xFFFFFFF0);
      final muted = HSLColor.fromColor(
        mutedChartColor(nearWhite, Brightness.light),
      );
      expect(muted.lightness, lessThanOrEqualTo(0.56 + _quantization));
    });

    test('near-black input becomes visible on dark background', () {
      const nearBlack = Color(0xFF050505);
      final muted = HSLColor.fromColor(
        mutedChartColor(nearBlack, Brightness.dark),
      );
      expect(muted.lightness, greaterThanOrEqualTo(0.42 - _quantization));
    });
  });

  group('neutralChartColor', () {
    test('is a pure gray in both themes', () {
      for (final brightness in Brightness.values) {
        final hsl = HSLColor.fromColor(neutralChartColor(brightness));
        expect(hsl.saturation, 0);
        expect(hsl.alpha, 1);
      }
    });
  });

  group('chartColorFor / swatchColorFor', () {
    test('null hex falls back to neutral gray', () {
      expect(
        chartColorFor(null, Brightness.dark),
        neutralChartColor(Brightness.dark),
      );
      expect(
        swatchColorFor(null, Brightness.light),
        neutralChartColor(Brightness.light),
      );
    });

    test('invalid hex falls back to neutral, never pink', () {
      final color = chartColorFor('not-a-color', Brightness.dark);
      expect(HSLColor.fromColor(color).saturation, lessThanOrEqualTo(0.52));
      expect(
        swatchColorFor('not-a-color', Brightness.dark),
        neutralChartColor(Brightness.dark),
      );
    });

    test('swatch keeps the raw saturated category color', () {
      expect(
        swatchColorFor('#FF0000', Brightness.dark),
        const Color(0xFFFF0000),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados<Color>(glados.any.color).test(
    'muted colors always land inside the legibility band, fully opaque',
    (base) {
      for (final brightness in Brightness.values) {
        final hsl = HSLColor.fromColor(mutedChartColor(base, brightness));
        expect(hsl.alpha, 1);
        expect(hsl.saturation, lessThanOrEqualTo(0.52 + _quantization));
        if (brightness == Brightness.dark) {
          expect(
            hsl.lightness,
            inInclusiveRange(0.42 - _quantization, 0.62 + _quantization),
          );
        } else {
          expect(
            hsl.lightness,
            inInclusiveRange(0.36 - _quantization, 0.56 + _quantization),
          );
        }
      }
    },
    tags: 'glados',
  );

  glados.Glados<Color>(glados.any.color).test(
    'muting is deterministic and preserves hue',
    (base) {
      final first = mutedChartColor(base, Brightness.dark);
      final second = mutedChartColor(base, Brightness.dark);
      expect(first, second);
      final baseHsl = HSLColor.fromColor(base);
      // Hue is meaningless for grays; only assert when saturated enough.
      if (baseHsl.saturation > 0.05) {
        final mutedHue = HSLColor.fromColor(first).hue;
        expect(mutedHue, closeTo(baseHsl.hue, 1));
      }
    },
    tags: 'glados',
  );
}
