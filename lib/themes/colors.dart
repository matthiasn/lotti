import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

// Legacy colors (keeping for backward compatibility)
final Color oldPrimaryColor = colorFromCssHex('#82E6CE');
final Color oldPrimaryColorLight = colorFromCssHex('#CFF3EA');
final Color alarm = colorFromCssHex('#FF7373');
final Color nickel = colorFromCssHex('#B4B2B2');

final Color successColor = colorFromCssHex('#34C191');
final Color failColor = colorFromCssHex('#FF7373');

final Color habitSkipColor = successColor
    .lighten()
    .desaturate()
    .mix(failColor.lighten().desaturate().complement());

const tagColor = Color.fromRGBO(155, 200, 246, 1);
const tagTextColor = Color.fromRGBO(51, 51, 51, 1);
const personTagColor = Color.fromRGBO(55, 201, 154, 1);
const storyTagColor = Color.fromRGBO(200, 120, 0, 1);
const starredGold = Color.fromRGBO(255, 215, 0, 1);

// Task status colors - light mode
const taskStatusDarkRed = Color(0xFFC62828);
const taskStatusDarkGreen = Color(0xFF2E7D32);
const taskStatusDarkOrange = Color(0xFFE65100);
const taskStatusDarkBlue = Color(0xFF1565C0);

// Task status colors - dark mode
const Color taskStatusOrange = Colors.orange;
const Color taskStatusLightGreenAccent = Colors.lightGreenAccent;
const Color taskStatusBlue = Colors.blue;
const Color taskStatusRed = Colors.red;
const Color taskStatusGreen = Colors.green;

// Sync filter colors
const Color syncAlertAccentColor = Colors.amber;
const Color syncAlertForegroundColor = Colors.black;

const Color syncPendingAccentColor = Colors.orange;
const Color syncPendingForegroundColor = Colors.white;

const Color syncSuccessAccentColor = Colors.green;
const Color syncSuccessForegroundColor = Colors.white;

final Color syncPendingCountAccentColor =
    TinyColor.fromColor(syncPendingAccentColor).lighten().color;

Color syncErrorCountAccentColor(ColorScheme colorScheme) =>
    TinyColor.fromColor(colorScheme.error).lighten().color;

final Color secondaryTextColor = oldPrimaryColor.desaturate(70).darken(20);
final Color chartTextColor = nickel;

// Modern gradient color palette - Enhanced with more sophisticated colors
class ModernGradientColors {
  // Primary gradient colors - More sophisticated purple-blue
  static const Color primaryStart = Color(0xFF667eea);
  static const Color primaryEnd = Color(0xFF764ba2);

  // Dark mode specific gradients - More sophisticated
  static const Color darkPrimaryStart = Color(0xFF2c3e50);
  static const Color darkPrimaryEnd = Color(0xFF34495e);
}

// Modern gradient themes - Enhanced with more sophisticated gradients
class ModernGradientThemes {
  /// Creates a modern primary gradient
  static LinearGradient primaryGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [
              ModernGradientColors.darkPrimaryStart,
              ModernGradientColors.darkPrimaryEnd
            ]
          : [
              ModernGradientColors.primaryStart,
              ModernGradientColors.primaryEnd
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Creates a modern accent gradient
  static LinearGradient accentGradient(BuildContext context) {
    return LinearGradient(
      colors: [
        context.colorScheme.inversePrimary.withAlpha(50),
        context.colorScheme.inversePrimary.withAlpha(75),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Creates a modern card gradient with enhanced sophistication
  static LinearGradient cardGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return LinearGradient(
        colors: [
          context.colorScheme.surface,
          context.colorScheme.surfaceContainer.withValues(alpha: 0.4),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return LinearGradient(
      colors: [
        Color.lerp(
            context.colorScheme.surfaceContainer,
            context.colorScheme.surfaceContainerHigh,
            GradientConstants.darkCardBlendFactor)!,
        Color.lerp(
            context.colorScheme.surface,
            context.colorScheme.surfaceContainer,
            GradientConstants.darkCardEndBlendFactor)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Creates a subtle background gradient
  static LinearGradient backgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: [
        context.colorScheme.surface,
        if (isDark)
          context.colorScheme.surfaceContainer.withValues(alpha: 0.15)
        else
          context.colorScheme.surfaceContainer.withValues(alpha: 0.08),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }
}
