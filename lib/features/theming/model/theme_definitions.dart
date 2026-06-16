import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Hard-coded light-mode surface colors that replace the grey surfaces a
/// `FlexScheme` would otherwise derive.
///
/// `withOverrides` in `lib/themes/theme_overrides.dart` copies these into the
/// light `ColorScheme` (and scaffold/canvas/card backgrounds) so the app shows
/// clean white surfaces regardless of which theme the user selected. The
/// values form a tonal ramp from pure white ([surface]) to the most elevated
/// container ([surfaceContainerHighest]); dark mode keeps the scheme-derived
/// surfaces and ignores these.
class LightModeSurfaces {
  LightModeSurfaces._();

  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFEFEFEF);
  static const Color surfaceContainerHighest = Color(0xFFE8E8E8);
}

/// Maps the user-facing theme name to the underlying `FlexScheme` used to
/// build its `ThemeData`.
///
/// Keys are the display labels shown in the theme picker and the values stored
/// in settings; `ThemingController._buildTheme` looks the selected name up here
/// and falls back to [FlexScheme.greyLaw] for an unknown or null name. Adding a
/// theme is just a new entry here.
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

/// The display names of all selectable themes, in [themes] insertion order.
///
/// Used to populate the theme picker.
List<String> get allThemeNames => themes.keys.toList();

/// Whether `themeName` is a known key in [themes].
///
/// `ThemingController.setLightTheme`/`setDarkTheme` gate on this so an unknown
/// name (e.g. from a stale synced setting) is ignored rather than applied.
bool isValidThemeName(String? themeName) =>
    themeName != null && themes.containsKey(themeName);

/// Theme name applied when no preference is stored or a stored name is invalid.
///
/// Used as the initial state in `ThemingController.build` and as the fallback
/// when loading or syncing settings.
const String defaultThemeName = 'Grey Law';
