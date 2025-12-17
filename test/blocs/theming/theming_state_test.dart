import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/theming/theming_state.dart';

void main() {
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

    test('contains expected number of themes', () {
      expect(themes.length, equals(21));
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
        darkThemeName: 'Grey Law',
        lightThemeName: 'Grey Law',
        themeMode: ThemeMode.system,
      );

      expect(state.enableTooltips, isTrue);
      expect(state.darkThemeName, equals('Grey Law'));
      expect(state.lightThemeName, equals('Grey Law'));
      expect(state.themeMode, equals(ThemeMode.system));
    });
  });
}
