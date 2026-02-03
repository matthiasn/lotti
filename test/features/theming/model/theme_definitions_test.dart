import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';

void main() {
  group('Theme Definitions', () {
    group('gameyThemeName constant', () {
      test('has expected value', () {
        expect(gameyThemeName, equals('🎮 Gamey'));
      });

      test('is in specialThemes set', () {
        expect(specialThemes.contains(gameyThemeName), isTrue);
      });

      test('is a valid theme name', () {
        expect(isValidThemeName(gameyThemeName), isTrue);
      });
    });

    group('specialThemes set', () {
      test('contains gamey theme', () {
        expect(specialThemes, contains(gameyThemeName));
      });

      test('has expected size', () {
        expect(specialThemes.length, equals(1));
      });
    });

    group('gameyBaseScheme constant', () {
      test('is blueWhale', () {
        expect(gameyBaseScheme, equals(FlexScheme.blueWhale));
      });
    });

    group('isGameyTheme function', () {
      test('returns true for gamey theme name', () {
        expect(isGameyTheme(gameyThemeName), isTrue);
        expect(isGameyTheme('🎮 Gamey'), isTrue);
      });

      test('returns false for standard theme names', () {
        expect(isGameyTheme('Grey Law'), isFalse);
        expect(isGameyTheme('Material'), isFalse);
        expect(isGameyTheme('Deep Blue'), isFalse);
        expect(isGameyTheme('Indigo'), isFalse);
      });

      test('returns false for null', () {
        expect(isGameyTheme(null), isFalse);
      });

      test('returns false for empty string', () {
        expect(isGameyTheme(''), isFalse);
      });

      test('returns false for non-existent theme names', () {
        expect(isGameyTheme('NonExistent'), isFalse);
        expect(isGameyTheme('Gamey'), isFalse); // Missing emoji
        expect(isGameyTheme('gamey'), isFalse); // Case sensitive
      });
    });

    group('isValidThemeName function', () {
      test('returns true for special themes', () {
        expect(isValidThemeName(gameyThemeName), isTrue);
      });

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
      test('includes special themes first', () {
        expect(allThemeNames.first, equals(gameyThemeName));
      });

      test('includes all standard themes', () {
        for (final themeName in themes.keys) {
          expect(allThemeNames, contains(themeName));
        }
      });

      test('has correct total count', () {
        expect(
            allThemeNames.length, equals(specialThemes.length + themes.length));
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

      test('does not contain special themes', () {
        for (final specialTheme in specialThemes) {
          expect(themes.containsKey(specialTheme), isFalse);
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
