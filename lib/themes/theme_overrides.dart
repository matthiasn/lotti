import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/themes/theme_constants.dart';
import 'package:lotti/themes/theme_text_styles.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

ThemeData withOverrides(ThemeData themeData) {
  final isDark = themeData.brightness == Brightness.dark;

  // LIGHT MODE: Force clean white backgrounds instead of grey
  // DARK MODE: Use scheme-derived surface for consistency
  final scaffoldColor = isDark
      ? themeData.colorScheme.surface
      : LightModeSurfaces.surface;

  // Update colorScheme for light mode to use white surfaces
  final updatedColorScheme = isDark
      ? themeData.colorScheme
      : themeData.colorScheme.copyWith(
          surface: LightModeSurfaces.surface,
          surfaceContainerLowest: LightModeSurfaces.surfaceContainerLowest,
          surfaceContainerLow: LightModeSurfaces.surfaceContainerLow,
          surfaceContainer: LightModeSurfaces.surfaceContainer,
          surfaceContainerHigh: LightModeSurfaces.surfaceContainerHigh,
          surfaceContainerHighest: LightModeSurfaces.surfaceContainerHighest,
        );

  return themeData.copyWith(
    colorScheme: updatedColorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    canvasColor: scaffoldColor,
    cardTheme: themeData.cardTheme.copyWith(
      clipBehavior: Clip.hardEdge,
      elevation: isDark ? 2 : 0,
      color: isDark ? null : LightModeSurfaces.surface,
      shadowColor: isDark ? null : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
    ),
    appBarTheme: themeData.appBarTheme.copyWith(
      backgroundColor: scaffoldColor,
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    sliderTheme: themeData.sliderTheme.copyWith(
      activeTrackColor: themeData.colorScheme.secondary,
      inactiveTrackColor: themeData.colorScheme.secondary.withAlpha(
        AppTheme.alphaSliderInactiveTrack,
      ),
      thumbColor: themeData.colorScheme.secondary,
      thumbShape: const RoundSliderThumbShape(),
      overlayColor: themeData.colorScheme.secondary.withAlpha(
        AppTheme.alphaSliderOverlay,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      clipBehavior: Clip.hardEdge,
      elevation: 0,
      backgroundColor: isDark ? null : LightModeSurfaces.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? null : LightModeSurfaces.surface,
      elevation: isDark ? 8 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: themeData.textTheme.copyWith(
      titleMedium: themeData.textTheme.titleMedium?.copyWith(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.w500, // Slightly bolder
      ),
      bodyLarge: themeData.textTheme.bodyLarge?.copyWith(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: themeData.textTheme.bodyMedium?.copyWith(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.w400,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        alignment: Alignment.center,
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.resolveWith(
          (states) => const TextStyle(
            fontSize: fontSizeSmall,
            fontWeight: FontWeight.w500, // Slightly bolder
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color: themeData.colorScheme.tertiary,
            width: 1.5, // Slightly thicker
          );
        }),
        shape: WidgetStateProperty.resolveWith((states) {
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              inputBorderRadius,
            ),
          );
        }),
        padding: WidgetStateProperty.resolveWith((states) {
          return const EdgeInsets.symmetric(
            horizontal: 8, // Increased padding
            vertical: 4,
          );
        }),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: themeData.primaryColor.withAlpha(20), // Subtle fill
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          inputBorderRadius,
        ),
        borderSide: BorderSide(
          color: themeData.colorScheme.outline.withAlpha(60), // More subtle
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          inputBorderRadius,
        ),
        borderSide: BorderSide(
          color: themeData.colorScheme.error,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          inputBorderRadius,
        ),
        borderSide: BorderSide(
          color: themeData.primaryColor,
          width: 2.5, // Slightly thicker
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.resolveWith((states) {
          return const TextStyle(
            fontSize: fontSizeMediumLarge,
            fontWeight: FontWeight.w500, // Slightly bolder
          );
        }),
        padding: WidgetStateProperty.resolveWith((states) {
          return const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          );
        }),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.pressed) ? 2 : 4;
        }),
        shape: WidgetStateProperty.resolveWith((states) {
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // More rounded
          );
        }),
        padding: WidgetStateProperty.resolveWith((states) {
          return const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          );
        }),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: themeData.colorScheme.primary,
      contentTextStyle: TextStyle(
        color: themeData.colorScheme.onPrimary,
        fontSize: fontSizeMedium,
      ),
      actionTextColor: themeData.colorScheme.onPrimary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{},
    ),
    extensions: <ThemeExtension>[
      const WoltModalSheetThemeData(
        animationStyle: WoltModalSheetAnimationStyle(
          paginationAnimationStyle: WoltModalSheetPaginationAnimationStyle(
            modalSheetHeightTransitionCurve: Interval(0, 0.1),
          ),
        ),
      ),
      GptMarkdownThemeData(
        brightness: themeData.brightness,
        linkColor: themeData.colorScheme.primary,
        h1: themeData.textTheme.titleLarge?.copyWith(
          fontSize: fontSizeMediumLarge,
          fontWeight: FontWeight.w600,
        ),
        h2: themeData.textTheme.titleMedium?.copyWith(
          fontSize: fontSizeMedium + 2,
          fontWeight: FontWeight.w500,
        ),
        h3: themeData.textTheme.titleSmall?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w500,
        ),
        h4: themeData.textTheme.bodyLarge?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w500,
        ),
        h5: themeData.textTheme.bodyMedium?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w400,
        ),
        h6: themeData.textTheme.bodySmall?.copyWith(
          fontSize: fontSizeSmall,
          fontWeight: FontWeight.w400,
        ),
      ),
      if (isDark) dsTokensDark else dsTokensLight,
    ],
  );
}

extension AppThemeExtension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

extension TextThemeExtension on TextStyle {
  TextStyle get withTabularFigures => copyWith(
    fontFeatures: const [
      FontFeature.tabularFigures(),
    ],
  );
}
