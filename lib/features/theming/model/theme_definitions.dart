import 'package:flutter/material.dart';

/// Hard-coded light-mode surface colors used by `withOverrides`.
///
/// `withOverrides` in `lib/themes/theme_overrides.dart` copies these into the
/// light `ColorScheme` (and scaffold/canvas/card backgrounds) so the app shows
/// clean white surfaces in light mode. The values form a tonal ramp from pure
/// white ([surface]) to the most elevated container
/// ([surfaceContainerHighest]); dark mode keeps the design-system surfaces and
/// ignores these.
class LightModeSurfaces {
  LightModeSurfaces._();

  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFEFEFEF);
  static const Color surfaceContainerHighest = Color(0xFFE8E8E8);
}
