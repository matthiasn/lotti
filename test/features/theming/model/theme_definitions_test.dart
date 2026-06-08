// glados re-exports package:test, which provides test/group/expect and the
// matchers used below; importing flutter_test alongside it would make those
// names ambiguous. The `Color` API used by the LightModeSurfaces checks comes
// in via flex_color_scheme's re-export of Flutter material.
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:glados/glados.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';

void main() {
  group('Theme Definitions', () {
    group('isValidThemeName function', () {
      test('returns true for standard themes', () {
        expect(isValidThemeName('Grey Law'), isTrue);
        expect(isValidThemeName('Material'), isTrue);
        expect(isValidThemeName('Deep Blue'), isTrue);
      });

      test('returns false for null', () {
        expect(isValidThemeName(null), isFalse);
      });

      test('returns false for non-existent theme names', () {
        expect(isValidThemeName('NonExistent'), isFalse);
        expect(isValidThemeName(''), isFalse);
      });

      // Property: validity is exactly membership in the themes map. For any
      // arbitrary string, isValidThemeName must agree with themes.containsKey,
      // guarding against accidental containsKey-true collisions for strings
      // that are not real theme names.
      Glados<String>(any.letterOrDigits).test(
        'agrees with themes.containsKey for any string',
        (input) {
          expect(isValidThemeName(input), equals(themes.containsKey(input)));
        },
        tags: 'glados',
      );
    });

    group('allThemeNames getter', () {
      test('includes all standard themes', () {
        for (final themeName in themes.keys) {
          expect(allThemeNames, contains(themeName));
        }
      });

      test('has correct total count', () {
        expect(allThemeNames.length, equals(themes.length));
      });
    });

    group('defaultThemeName constant', () {
      test('has expected value', () {
        expect(defaultThemeName, equals('Grey Law'));
      });

      test('is present in themes map', () {
        expect(themes.containsKey(defaultThemeName), isTrue);
      });

      test('maps to the expected FlexScheme value', () {
        // Pin the concrete scheme so an accidental remap of the default
        // theme entry is caught (a bare isNotNull would not notice).
        expect(themes[defaultThemeName], equals(FlexScheme.greyLaw));
      });
    });

    group('themes map', () {
      test('contains expected number of standard themes', () {
        // Intentionally a pinned count, not derived from `themes.length`
        // (that would be tautological). When a theme is added or removed,
        // update this number deliberately and confirm the new selection set
        // is correct.
        expect(themes.length, equals(21));
      });

      test('all themes have non-null FlexScheme values', () {
        for (final entry in themes.entries) {
          expect(
            entry.value,
            isNotNull,
            reason: '${entry.key} should have a non-null FlexScheme',
          );
        }
      });

      test('all themes are valid FlexScheme values', () {
        for (final entry in themes.entries) {
          expect(
            entry.value,
            isA<FlexScheme>(),
            reason: '${entry.key} should be a FlexScheme',
          );
        }
      });
    });

    group('LightModeSurfaces', () {
      test('surface is pure white', () {
        expect(
          LightModeSurfaces.surface.toARGB32(),
          equals(0xFFFFFFFF),
        );
      });

      test('surfaceContainerLowest is pure white', () {
        expect(
          LightModeSurfaces.surfaceContainerLowest.toARGB32(),
          equals(0xFFFFFFFF),
        );
      });

      test('surface colors have decreasing brightness', () {
        // Each surface level should be slightly darker than the previous
        final surfaces = [
          LightModeSurfaces.surfaceContainerLowest,
          LightModeSurfaces.surfaceContainerLow,
          LightModeSurfaces.surfaceContainer,
          LightModeSurfaces.surfaceContainerHigh,
          LightModeSurfaces.surfaceContainerHighest,
        ];

        for (var i = 0; i < surfaces.length - 1; i++) {
          final current = surfaces[i].computeLuminance();
          final next = surfaces[i + 1].computeLuminance();
          expect(
            current >= next,
            isTrue,
            reason:
                'Surface $i luminance ($current) should be >= surface ${i + 1} luminance ($next)',
          );
        }
      });
    });
  });
}
