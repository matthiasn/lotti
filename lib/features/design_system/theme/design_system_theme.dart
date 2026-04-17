import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemTheme {
  const DesignSystemTheme._();

  static ThemeData light() => _build(dsTokensLight, Brightness.light);

  static ThemeData dark() => _build(dsTokensDark, Brightness.dark);

  static ThemeData _build(DsTokens tokens, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.colors.interactive.enabled,
      onPrimary: tokens.colors.text.onInteractiveAlert,
      secondary: tokens.colors.surface.active,
      onSecondary: tokens.colors.text.highEmphasis,
      error: tokens.colors.alert.error.defaultColor,
      onError: tokens.colors.text.onInteractiveAlert,
      surface: tokens.colors.background.level01,
      onSurface: tokens.colors.text.highEmphasis,
      primaryContainer: tokens.colors.background.level02,
      onPrimaryContainer: tokens.colors.text.highEmphasis,
      secondaryContainer: tokens.colors.background.level03,
      onSecondaryContainer: tokens.colors.text.highEmphasis,
      tertiary: tokens.colors.background.alternative01,
      onTertiary: tokens.colors.text.highEmphasis,
      tertiaryContainer: tokens.colors.background.level03,
      onTertiaryContainer: tokens.colors.text.highEmphasis,
      errorContainer: tokens.colors.alert.error.hover,
      onErrorContainer: tokens.colors.text.onInteractiveAlert,
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
          bodyLarge: tokens.typography.styles.body.bodyLarge,
          bodyMedium: tokens.typography.styles.body.bodyMedium,
          bodySmall: tokens.typography.styles.body.bodySmall,
          labelLarge: tokens.typography.styles.subtitle.subtitle2,
          labelMedium: tokens.typography.styles.others.caption,
          // labelSmall is Material's slot for chips, badges, navigation
          // labels, and other dense UI text. The "overline" token is a
          // wide-tracked (letterSpacing: 8.0) display style intended only
          // for the design system's overline component — using it here
          // makes every count/chip/badge in the app render with extreme
          // letter spacing. Use the caption style instead.
          labelSmall: tokens.typography.styles.others.caption,
        ).apply(
          bodyColor: tokens.colors.text.highEmphasis,
          displayColor: tokens.colors.text.highEmphasis,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
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
