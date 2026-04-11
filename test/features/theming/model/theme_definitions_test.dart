import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
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

      test('has non-null FlexScheme value', () {
        expect(themes[defaultThemeName], isNotNull);
      });
    });

    group('themes map', () {
      test('contains expected number of standard themes', () {
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
