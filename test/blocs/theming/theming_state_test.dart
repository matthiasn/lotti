import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/theming/theming_state.dart';

void main() {
  group('PolishedThemeColors', () {
    group('light mode colors', () {
      test('lightPrimary is rich amber', () {
        expect(
          PolishedThemeColors.lightPrimary,
          equals(const Color(0xFFD97706)),
        );
      });

      test('light FlexSchemeColor has correct primary', () {
        expect(
          PolishedThemeColors.light.primary,
          equals(PolishedThemeColors.lightPrimary),
        );
      });

      test('light FlexSchemeColor has correct secondary', () {
        expect(
          PolishedThemeColors.light.secondary,
          equals(PolishedThemeColors.lightSecondary),
        );
      });

      test('light FlexSchemeColor has correct tertiary', () {
        expect(
          PolishedThemeColors.light.tertiary,
          equals(PolishedThemeColors.lightTertiary),
        );
      });
    });

    group('dark mode colors', () {
      test('darkPrimary is vibrant amber', () {
        expect(
          PolishedThemeColors.darkPrimary,
          equals(const Color(0xFFFBBF24)),
        );
      });

      test('dark FlexSchemeColor has correct primary', () {
        expect(
          PolishedThemeColors.dark.primary,
          equals(PolishedThemeColors.darkPrimary),
        );
      });

      test('dark FlexSchemeColor has correct secondary', () {
        expect(
          PolishedThemeColors.dark.secondary,
          equals(PolishedThemeColors.darkSecondary),
        );
      });

      test('dark FlexSchemeColor has correct tertiary', () {
        expect(
          PolishedThemeColors.dark.tertiary,
          equals(PolishedThemeColors.darkTertiary),
        );
      });
    });
  });

  group('LightModeSurfaces', () {
    test('surface is pure white', () {
      expect(
        LightModeSurfaces.surface,
        equals(const Color(0xFFFFFFFF)),
      );
    });

    test('surfaceContainerLowest is pure white', () {
      expect(
        LightModeSurfaces.surfaceContainerLowest,
        equals(const Color(0xFFFFFFFF)),
      );
    });

    test('surfaceContainerLow is very subtle grey', () {
      expect(
        LightModeSurfaces.surfaceContainerLow,
        equals(const Color(0xFFFAFAFA)),
      );
    });

    test('surfaceContainer is light grey', () {
      expect(
        LightModeSurfaces.surfaceContainer,
        equals(const Color(0xFFF5F5F5)),
      );
    });

    test('surfaceContainerHigh is slightly darker grey', () {
      expect(
        LightModeSurfaces.surfaceContainerHigh,
        equals(const Color(0xFFEFEFEF)),
      );
    });

    test('surfaceContainerHighest is the darkest surface grey', () {
      expect(
        LightModeSurfaces.surfaceContainerHighest,
        equals(const Color(0xFFE8E8E8)),
      );
    });
  });

  group('PolishedSubThemes', () {
    test('creates light mode sub themes with correct blendOnLevel', () {
      final subThemes = PolishedSubThemes.create(isDark: false);
      expect(subThemes.blendOnLevel, equals(10));
    });

    test('creates dark mode sub themes with correct blendOnLevel', () {
      final subThemes = PolishedSubThemes.create(isDark: true);
      expect(subThemes.blendOnLevel, equals(20));
    });

    test(
        'creates light mode sub themes with correct inputDecoratorBackgroundAlpha',
        () {
      final subThemes = PolishedSubThemes.create(isDark: false);
      expect(subThemes.inputDecoratorBackgroundAlpha, equals(21));
    });

    test(
        'creates dark mode sub themes with correct inputDecoratorBackgroundAlpha',
        () {
      final subThemes = PolishedSubThemes.create(isDark: true);
      expect(subThemes.inputDecoratorBackgroundAlpha, equals(43));
    });

    test('has consistent navigation bar settings', () {
      final lightSubThemes = PolishedSubThemes.create(isDark: false);
      final darkSubThemes = PolishedSubThemes.create(isDark: true);

      // These should be the same for both modes
      expect(lightSubThemes.navigationBarHeight, equals(70));
      expect(darkSubThemes.navigationBarHeight, equals(70));
      expect(lightSubThemes.navigationBarElevation, equals(0));
      expect(darkSubThemes.navigationBarElevation, equals(0));
      expect(
        lightSubThemes.navigationBarIndicatorSchemeColor,
        equals(SchemeColor.primary),
      );
      expect(
        darkSubThemes.navigationBarIndicatorSchemeColor,
        equals(SchemeColor.primary),
      );
    });
  });

  group('polishedThemeName', () {
    test('is "Polished"', () {
      expect(polishedThemeName, equals('Polished'));
    });
  });

  group('themes map', () {
    test('contains Grey Law', () {
      expect(themes.containsKey('Grey Law'), isTrue);
    });

    test('contains Indigo', () {
      expect(themes.containsKey('Indigo'), isTrue);
    });

    test('contains Amber', () {
      expect(themes.containsKey('Amber'), isTrue);
    });

    test('does not contain Polished (it is a custom theme)', () {
      expect(themes.containsKey('Polished'), isFalse);
    });
  });

  group('allThemeNames', () {
    test('includes Polished as first entry', () {
      expect(allThemeNames.first, equals('Polished'));
    });

    test('includes all standard themes', () {
      for (final themeName in themes.keys) {
        expect(allThemeNames.contains(themeName), isTrue);
      }
    });

    test('has one more entry than themes map (Polished)', () {
      expect(allThemeNames.length, equals(themes.length + 1));
    });

    test('Polished appears before Grey Law', () {
      final polishedIndex = allThemeNames.indexOf('Polished');
      final greyLawIndex = allThemeNames.indexOf('Grey Law');
      expect(polishedIndex, lessThan(greyLawIndex));
    });
  });

  group('ThemingState', () {
    test('can be created with required enableTooltips', () {
      final state = ThemingState(enableTooltips: true);
      expect(state.enableTooltips, isTrue);
    });

    test('optional fields default to null', () {
      final state = ThemingState(enableTooltips: false);
      expect(state.darkTheme, isNull);
      expect(state.lightTheme, isNull);
      expect(state.darkThemeName, isNull);
      expect(state.lightThemeName, isNull);
      expect(state.themeMode, isNull);
    });

    test('can be created with all fields', () {
      final state = ThemingState(
        enableTooltips: true,
        darkThemeName: 'Polished',
        lightThemeName: 'Polished',
        themeMode: ThemeMode.system,
      );

      expect(state.enableTooltips, isTrue);
      expect(state.darkThemeName, equals('Polished'));
      expect(state.lightThemeName, equals('Polished'));
      expect(state.themeMode, equals(ThemeMode.system));
    });
  });
}
