import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Builder that transforms a base ThemeData into a gamey-styled theme.
///
/// This adds vibrant colors, playful styling, and enhanced visual elements
/// while preserving the base theme's structure.
class GameyThemeBuilder {
  GameyThemeBuilder._();

  /// Build a gamey-enhanced theme from a base theme.
  static ThemeData build(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final colorScheme = _buildColorScheme(base.colorScheme, isDark: isDark);

    return base.copyWith(
      colorScheme: colorScheme,
      cardTheme: _buildCardTheme(base.cardTheme, colorScheme, isDark: isDark),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      filledButtonTheme: _buildFilledButtonTheme(colorScheme),
      floatingActionButtonTheme: _buildFabTheme(colorScheme),
      chipTheme: _buildChipTheme(base.chipTheme, colorScheme, isDark: isDark),
      progressIndicatorTheme: _buildProgressIndicatorTheme(colorScheme),
      sliderTheme: _buildSliderTheme(base.sliderTheme, colorScheme),
    );
  }

  static ColorScheme _buildColorScheme(
    ColorScheme base, {
    required bool isDark,
  }) {
    return base.copyWith(
      primary: GameyColors.primaryBlue,
      onPrimary: Colors.white,
      primaryContainer:
          isDark ? GameyColors.primaryBlueLight : GameyColors.primaryBlue,
      secondary: GameyColors.primaryGreen,
      onSecondary: Colors.white,
      secondaryContainer:
          isDark ? GameyColors.primaryGreenLight : GameyColors.primaryGreen,
      tertiary: GameyColors.primaryPurple,
      onTertiary: Colors.white,
      tertiaryContainer:
          isDark ? GameyColors.primaryPurpleLight : GameyColors.primaryPurple,
      surface: isDark ? GameyColors.surfaceDark : GameyColors.surfaceLight,
      surfaceContainerLowest:
          isDark ? GameyColors.surfaceDarkLow : GameyColors.surfaceLight,
      surfaceContainerLow:
          isDark ? GameyColors.surfaceDark : GameyColors.surfaceLightElevated,
      surfaceContainer: isDark
          ? GameyColors.surfaceDarkElevated
          : GameyColors.surfaceLightElevated,
      surfaceContainerHigh:
          isDark ? GameyColors.surfaceDarkElevated : const Color(0xFFF0F0F0),
      surfaceContainerHighest:
          isDark ? const Color(0xFF3A3A4C) : const Color(0xFFE8E8E8),
      error: GameyColors.primaryRed,
      onError: Colors.white,
    );
  }

  static CardThemeData _buildCardTheme(
    CardThemeData base,
    ColorScheme colorScheme, {
    required bool isDark,
  }) {
    return base.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surfaceContainer,
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(
    ColorScheme colorScheme,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static FilledButtonThemeData _buildFilledButtonTheme(
    ColorScheme colorScheme,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData _buildFabTheme(
    ColorScheme colorScheme,
  ) {
    return FloatingActionButtonThemeData(
      backgroundColor: GameyColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  static ChipThemeData _buildChipTheme(
    ChipThemeData base,
    ColorScheme colorScheme, {
    required bool isDark,
  }) {
    return base.copyWith(
      backgroundColor: colorScheme.surfaceContainerHigh,
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  static ProgressIndicatorThemeData _buildProgressIndicatorTheme(
    ColorScheme colorScheme,
  ) {
    return ProgressIndicatorThemeData(
      color: GameyColors.primaryGreen,
      linearTrackColor: colorScheme.surfaceContainerHigh,
      circularTrackColor: colorScheme.surfaceContainerHigh,
    );
  }

  static SliderThemeData _buildSliderTheme(
    SliderThemeData base,
    ColorScheme colorScheme,
  ) {
    return base.copyWith(
      activeTrackColor: GameyColors.primaryBlue,
      inactiveTrackColor: colorScheme.surfaceContainerHigh,
      thumbColor: GameyColors.primaryBlue,
      overlayColor: GameyColors.primaryBlue.withValues(alpha: 0.2),
    );
  }
}
