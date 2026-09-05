import 'package:flutter/foundation.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Platform-aware emoji font fallback chain for the app's text themes.
///
/// Skia does not auto-fall-back to a system color emoji font on Linux, so
/// without this list any glyph that `Inter` cannot render shows as tofu.
/// macOS/iOS pick up `Apple Color Emoji`, Windows uses `Segoe UI Emoji`,
/// and Linux/Android use `Noto Color Emoji`. Listing all three is harmless
/// on platforms that ignore the missing entries — fontconfig (or the
/// equivalent on each OS) resolves the first family that exists locally.
const List<String> _emojiFontFallback = <String>[
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Noto Color Emoji',
];

List<String>? _getEmojiFontFallback() {
  // kIsWeb is a compile-time constant, so the web branch cannot be exercised
  // from VM-run unit tests; it is a known untested (trivial) branch.
  if (kIsWeb) return null;
  return _emojiFontFallback;
}

/// Builds the app's Material [ThemeData] from the design-system tokens.
///
/// Maps the light/dark `DsTokens` onto a Material 3 `ColorScheme` and
/// `TextTheme`, and registers the active `DsTokens` as a theme extension so
/// widgets can resolve raw tokens via `context.designTokens`. Use the
/// [light] and [dark] factories rather than constructing it directly.
class DesignSystemTheme {
  const DesignSystemTheme._();

  /// The light-mode theme derived from `dsTokensLight`.
  static ThemeData light() => _build(dsTokensLight, Brightness.light);

  /// The dark-mode theme derived from `dsTokensDark`.
  static ThemeData dark() => _build(dsTokensDark, Brightness.dark);

  static ThemeData _build(DsTokens tokens, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.colors.interactive.enabled,
      onPrimary: tokens.colors.text.onInteractiveAlert,
      // Solid accents, not overlays: Material consumers treat secondary and
      // tertiary as paintable semantic colors (slider thumbs, status
      // indicators, watch states). The 24%-alpha `surface.active` and the
      // near-page `alternative01` background rendered them all but invisible.
      secondary: tokens.colors.interactive.hover,
      onSecondary: tokens.colors.text.onInteractiveAlert,
      error: tokens.colors.alert.error.defaultColor,
      onError: tokens.colors.text.onInteractiveAlert,
      surface: tokens.colors.background.level01,
      onSurface: tokens.colors.text.highEmphasis,
      primaryContainer: tokens.colors.background.level02,
      onPrimaryContainer: tokens.colors.text.highEmphasis,
      secondaryContainer: tokens.colors.background.level03,
      onSecondaryContainer: tokens.colors.text.highEmphasis,
      tertiary: tokens.colors.alert.info.defaultColor,
      onTertiary: tokens.colors.text.onInteractiveAlert,
      tertiaryContainer: tokens.colors.background.level03,
      onTertiaryContainer: tokens.colors.text.highEmphasis,
      // A subtle wash, not a solid fill: consumers paint errorContainer as
      // banner and badge backgrounds (often with further alpha), and its
      // foreground must survive over what is effectively the page surface.
      // 0x2E is the token set's own surface-wash alpha (see the generated
      // proposalKind surfaces); `ink` is the error foreground designed for
      // exactly such barely-tinted surfaces.
      errorContainer: tokens.colors.alert.error.defaultColor.withAlpha(0x2E),
      onErrorContainer: tokens.colors.alert.error.ink,
      // The full Material container ramp. Left unset, the low/mid/high slots
      // fall back to `surface`, so every legacy consumer of them — chat
      // inputs, agent cards, selection surfaces — collapsed onto the page
      // background. `level03` is a divider gray, not a surface, so the ramp
      // tops out at `level02` rather than borrowing it.
      surfaceContainerLowest: tokens.colors.background.level01,
      surfaceContainerLow: tokens.colors.background.level02,
      surfaceContainer: tokens.colors.background.level02,
      surfaceContainerHigh: tokens.colors.background.level02,
      surfaceContainerHighest: tokens.colors.background.level02,
      onSurfaceVariant: tokens.colors.text.mediumEmphasis,
      outline: tokens.colors.decorative.level01,
      outlineVariant: tokens.colors.decorative.level02,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: tokens.colors.background.level03,
      onInverseSurface: tokens.colors.text.highEmphasis,
      inversePrimary: tokens.colors.interactive.hover,
      surfaceTint: tokens.colors.interactive.enabled,
    );

    final textTheme =
        TextTheme(
          displayLarge: tokens.typography.styles.display.display0,
          displayMedium: tokens.typography.styles.display.display1,
          displaySmall: tokens.typography.styles.display.display2,
          headlineLarge: tokens.typography.styles.heading.heading1,
          headlineMedium: tokens.typography.styles.heading.heading2,
          headlineSmall: tokens.typography.styles.heading.heading3,
          titleLarge: tokens.typography.styles.subtitle.subtitle1,
          titleMedium: tokens.typography.styles.subtitle.subtitle2,
          // Mapped rather than left to the Material default: an unmapped slot
          // would render in Flutter's fallback font and scale, off the token
          // ramp, for every legacy `textTheme.titleSmall` consumer.
          titleSmall: tokens.typography.styles.subtitle.subtitle2,
          bodyLarge: tokens.typography.styles.body.bodyLarge,
          bodyMedium: tokens.typography.styles.body.bodyMedium,
          bodySmall: tokens.typography.styles.body.bodySmall,
          labelLarge: tokens.typography.styles.subtitle.subtitle2,
          labelMedium: tokens.typography.styles.others.caption,
          labelSmall: tokens.typography.styles.others.overline,
        ).apply(
          bodyColor: tokens.colors.text.highEmphasis,
          displayColor: tokens.colors.text.highEmphasis,
          // Applied at the theme level so the ambient DefaultTextStyle carries
          // the emoji fallback: token styles pin `Inter` without a fallback of
          // their own, and TextStyle.merge inherits the fallback from the
          // ambient style — which is how emoji (e.g. the sync verification
          // row) render on Linux instead of as tofu.
          fontFamilyFallback: _getEmojiFontFallback(),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // The legacy accent slot. Unset, a dark ThemeData resolves it to
      // `colorScheme.surface`, turning every `Theme.of(context).primaryColor`
      // consumer — app-bar titles, focused input borders — page-colored on a
      // page-colored background.
      primaryColor: tokens.colors.interactive.enabled,
      scaffoldBackgroundColor: tokens.colors.background.level01,
      canvasColor: tokens.colors.background.level01,
      disabledColor: tokens.colors.text.lowEmphasis,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        tokens,
      ],
    );
  }
}
