import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/ui/app_fonts.dart';

/// The nine canonical [FontWeight] values, indexed 0..8 so a Glados [int]
/// generator can select one deterministically.
const _fontWeights = <FontWeight>[
  FontWeight.w100,
  FontWeight.w200,
  FontWeight.w300,
  FontWeight.w400,
  FontWeight.w500,
  FontWeight.w600,
  FontWeight.w700,
  FontWeight.w800,
  FontWeight.w900,
];

/// A bundle of the four forwarded `inconsolata` parameters, generated together
/// so a single [glados.Glados] run can exercise all of them at once.
typedef _FontParams = ({
  double fontSize,
  FontWeight fontWeight,
  Color color,
  double letterSpacing,
});

extension _AnyFontParams on glados.Any {
  /// Generates a realistic, finite set of `inconsolata` parameters.
  ///
  /// Ranges are kept finite (no NaN/Infinity) and within plausible UI values so
  /// the assertions stay meaningful: `fontSize` 1..100, `letterSpacing` -5..10,
  /// `fontWeight` one of the nine canonical weights, `color` any 32-bit ARGB.
  glados.Generator<_FontParams> get fontParams =>
      glados.any.combine4<double, int, int, double, _FontParams>(
        glados.DoubleAnys(this).doubleInRange(1, 100),
        glados.IntAnys(this).intInRange(0, _fontWeights.length),
        glados.IntAnys(this).intInRange(0, 0x100000000),
        glados.DoubleAnys(this).doubleInRange(-5, 10),
        (fontSize, weightIndex, colorValue, letterSpacing) => (
          fontSize: fontSize,
          fontWeight: _fontWeights[weightIndex % _fontWeights.length],
          color: Color(colorValue),
          letterSpacing: letterSpacing,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool originalAllow;

  setUp(() {
    originalAllow = GoogleFonts.config.allowRuntimeFetching;
  });

  tearDown(() {
    GoogleFonts.config.allowRuntimeFetching = originalAllow;
  });

  group('AppFonts.inconsolata — example tests', () {
    test(
      'falls back to a plain Inconsolata style without runtime fetching',
      () {
        GoogleFonts.config.allowRuntimeFetching = false;
        final style = AppFonts.inconsolata(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.red,
          letterSpacing: 1.2,
        );
        expect(style.fontFamily, 'Inconsolata');
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.color, Colors.red);
        expect(style.letterSpacing, 1.2);
      },
    );

    test('fallback path leaves unset parameters null', () {
      GoogleFonts.config.allowRuntimeFetching = false;
      final style = AppFonts.inconsolata();
      // The family is always set; everything else passes through untouched.
      expect(style.fontFamily, 'Inconsolata');
      expect(style.fontSize, isNull);
      expect(style.fontWeight, isNull);
      expect(style.color, isNull);
      expect(style.letterSpacing, isNull);
    });

    test('delegates to google_fonts when runtime fetching allowed', () {
      GoogleFonts.config.allowRuntimeFetching = true;
      // On the live path the helper returns exactly what GoogleFonts.inconsolata
      // returns for the same call, so the resolved family matches. We assert
      // family only and use the default (regular) weight: requesting a specific
      // variant schedules an async asset load that outlives the test and throws
      // in the sandbox (no font assets / network). The verbatim parameter
      // forwarding on this branch is a one-line pass-through in the source and
      // is exhaustively exercised on the testable fallback branch below.
      final gf = GoogleFonts.inconsolata();
      final style = AppFonts.inconsolata();
      expect(style.fontFamily, gf.fontFamily);
    });
  });

  group('AppFonts.inconsolata — properties', () {
    // Fallback path: with runtime fetching off, the helper builds a plain
    // TextStyle, so every provided parameter must round-trip verbatim. This is
    // the pure, side-effect-free branch — ideal for property exploration.
    glados.Glados<_FontParams>(
      glados.any.fontParams,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'forwards all parameters verbatim on the fallback path',
      (params) {
        GoogleFonts.config.allowRuntimeFetching = false;
        final style = AppFonts.inconsolata(
          fontSize: params.fontSize,
          fontWeight: params.fontWeight,
          color: params.color,
          letterSpacing: params.letterSpacing,
        );
        expect(style.fontFamily, 'Inconsolata', reason: '$params');
        expect(style.fontSize, params.fontSize, reason: '$params');
        expect(style.fontWeight, params.fontWeight, reason: '$params');
        expect(style.color, params.color, reason: '$params');
        expect(style.letterSpacing, params.letterSpacing, reason: '$params');
      },
      tags: 'glados',
    );
    // NOTE: the live (runtime-fetching) branch is intentionally not property-
    // tested. Exercising it for arbitrary weights schedules google_fonts'
    // async asset load, which throws after the test completes in the sandbox
    // (no assets / network). That branch is a verbatim one-line pass-through to
    // GoogleFonts.inconsolata; the wrapper's own forwarding logic is fully
    // covered by the fallback property above.
  });
}

// End of file
