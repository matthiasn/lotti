import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'theming_state.freezed.dart';

/// Custom "Polished" theme colors for a modern, well-funded look.
/// Clean whites in light mode, rich darks in dark mode, with vibrant amber accents.
class PolishedThemeColors {
  PolishedThemeColors._();

  // Light mode accent colors
  static const Color lightPrimary = Color(0xFFD97706); // Rich amber
  static const Color lightPrimaryContainer =
      Color(0xFFFEF3C7); // Soft amber tint
  static const Color lightSecondary = Color(0xFF0369A1); // Deep sky blue
  static const Color lightSecondaryContainer = Color(0xFFE0F2FE); // Light blue
  static const Color lightTertiary = Color(0xFF059669); // Emerald
  static const Color lightTertiaryContainer =
      Color(0xFFD1FAE5); // Light emerald
  static const Color lightError = Color(0xFFDC2626); // Modern red

  // Dark mode accent colors
  static const Color darkPrimary = Color(0xFFFBBF24); // Vibrant amber
  static const Color darkPrimaryContainer = Color(0xFF78350F); // Dark amber
  static const Color darkSecondary = Color(0xFF38BDF8); // Sky blue
  static const Color darkSecondaryContainer = Color(0xFF0C4A6E); // Dark blue
  static const Color darkTertiary = Color(0xFF34D399); // Light emerald
  static const Color darkTertiaryContainer = Color(0xFF064E3B); // Dark emerald
  static const Color darkError = Color(0xFFF87171); // Soft red

  /// Light mode FlexSchemeColor
  static const FlexSchemeColor light = FlexSchemeColor(
    primary: lightPrimary,
    primaryContainer: lightPrimaryContainer,
    secondary: lightSecondary,
    secondaryContainer: lightSecondaryContainer,
    tertiary: lightTertiary,
    tertiaryContainer: lightTertiaryContainer,
    error: lightError,
  );

  /// Dark mode FlexSchemeColor
  static const FlexSchemeColor dark = FlexSchemeColor(
    primary: darkPrimary,
    primaryContainer: darkPrimaryContainer,
    secondary: darkSecondary,
    secondaryContainer: darkSecondaryContainer,
    tertiary: darkTertiary,
    tertiaryContainer: darkTertiaryContainer,
    error: darkError,
  );
}

/// Light mode surface overrides - forces white backgrounds instead of grey
class LightModeSurfaces {
  LightModeSurfaces._();

  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFEFEFEF);
  static const Color surfaceContainerHighest = Color(0xFFE8E8E8);
}

/// Shared FlexSubThemesData configuration for the Polished theme
class PolishedSubThemes {
  PolishedSubThemes._();

  /// Creates FlexSubThemesData with mode-specific values
  static FlexSubThemesData create({required bool isDark}) => FlexSubThemesData(
        blendOnLevel: isDark ? 20 : 10,
        blendOnColors: !isDark,
        useM2StyleDividerInM3: true,
        elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
        elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
        segmentedButtonSchemeColor: SchemeColor.primary,
        inputDecoratorSchemeColor: SchemeColor.primary,
        inputDecoratorBackgroundAlpha: isDark ? 43 : 21,
        inputDecoratorRadius: 12,
        inputDecoratorUnfocusedHasBorder: false,
        inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
        popupMenuRadius: 8,
        popupMenuElevation: 3,
        drawerIndicatorSchemeColor: SchemeColor.primary,
        bottomNavigationBarMutedUnselectedLabel: false,
        bottomNavigationBarMutedUnselectedIcon: false,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
        navigationBarIndicatorSchemeColor: SchemeColor.primary,
        navigationBarIndicatorOpacity: 1,
        navigationBarElevation: 0,
        navigationBarHeight: 70,
        navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
        navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
        navigationRailIndicatorSchemeColor: SchemeColor.primary,
        navigationRailIndicatorOpacity: 1,
      );
}

/// Marker for custom themes that don't use FlexScheme enum
const String polishedThemeName = 'Polished';

/// Standard FlexScheme themes
final Map<String, FlexScheme> themes = {
  'Material': FlexScheme.material,
  'Material High Contrast': FlexScheme.materialHc,
  'Deep Blue': FlexScheme.deepBlue,
  'Flutter Dash': FlexScheme.flutterDash,
  'Grey Law': FlexScheme.greyLaw,
  'Indigo': FlexScheme.indigo,
  'Mallard Green': FlexScheme.mallardGreen,
  'Mandy Red': FlexScheme.mandyRed,
  'Blue Whale': FlexScheme.blueWhale,
  'Damask': FlexScheme.damask,
  'Amber': FlexScheme.amber,
  'Shark': FlexScheme.shark,
  'Sakura': FlexScheme.sakura,
  'San Juan Blue': FlexScheme.sanJuanBlue,
  'Blumine Blue': FlexScheme.blumineBlue,
  'Aqua Blue': FlexScheme.aquaBlue,
  'Wasabi': FlexScheme.wasabi,
  'Vesuvius Burn': FlexScheme.vesuviusBurn,
  'Outer Space': FlexScheme.outerSpace,
  'Hippie Blue': FlexScheme.hippieBlue,
  'Money': FlexScheme.money,
};

/// All available theme names including custom themes (cached)
final List<String> allThemeNames = [polishedThemeName, ...themes.keys];

@freezed
abstract class ThemingState with _$ThemingState {
  factory ThemingState({
    required bool enableTooltips,
    ThemeData? darkTheme,
    ThemeData? lightTheme,
    String? darkThemeName,
    String? lightThemeName,
    ThemeMode? themeMode,
  }) = _ThemingState;
}
