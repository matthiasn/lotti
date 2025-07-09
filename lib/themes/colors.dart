// ignore_for_file: equal_keys_in_map
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

final Color secondaryTextColor = oldPrimaryColor.desaturate(70).darken(20);
final Color chartTextColor = nickel;

// Modern gradient color palette - Enhanced with more sophisticated colors
class ModernGradientColors {
  // Primary gradient colors - More sophisticated purple-blue
  static const Color primaryStart = Color(0xFF667eea);
  static const Color primaryEnd = Color(0xFF764ba2);
  
  // Secondary gradient colors - Vibrant pink-red
  static const Color secondaryStart = Color(0xFFf093fb);
  static const Color secondaryEnd = Color(0xFFf5576c);
  
  // Accent gradient colors - Bright cyan-blue
  static const Color accentStart = Color(0xFF4facfe);
  static const Color accentEnd = Color(0xFF00f2fe);
  
  // Success gradient colors - Fresh green
  static const Color successStart = Color(0xFF43e97b);
  static const Color successEnd = Color(0xFF38f9d7);
  
  // Warning gradient colors - Warm orange-yellow
  static const Color warningStart = Color(0xFFfa709a);
  static const Color warningEnd = Color(0xFFfee140);
  
  // Error gradient colors - Vibrant red-orange
  static const Color errorStart = Color(0xFFff6b6b);
  static const Color errorEnd = Color(0xFFee5a24);
  
  // Neutral gradient colors - Soft mint
  static const Color neutralStart = Color(0xFFa8edea);
  static const Color neutralEnd = Color(0xFFfed6e3);
  
  // New sophisticated gradients
  static const Color elegantStart = primaryStart;
  static const Color elegantEnd = primaryEnd;
  
  static const Color sunsetStart = Color(0xFFffecd2);
  static const Color sunsetEnd = Color(0xFFfcb69f);
  
  static const Color oceanStart = Color(0xFFa8edea);
  static const Color oceanEnd = Color(0xFFfed6e3);
  
  static const Color forestStart = Color(0xFFd299c2);
  static const Color forestEnd = Color(0xFFfef9d7);
  
  // Dark mode specific gradients - More sophisticated
  static const Color darkPrimaryStart = Color(0xFF2c3e50);
  static const Color darkPrimaryEnd = Color(0xFF34495e);
  
  static const Color darkAccentStart = Color(0xFF667eea);
  static const Color darkAccentEnd = Color(0xFF764ba2);
  
  static const Color darkElegantStart = Color(0xFF1a1a2e);
  static const Color darkElegantEnd = Color(0xFF16213e);
  
  static const Color darkOceanStart = Color(0xFF0f3460);
  static const Color darkOceanEnd = Color(0xFF533483);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [
              ModernGradientColors.darkAccentStart,
              ModernGradientColors.darkAccentEnd
            ]
          : [ModernGradientColors.accentStart, ModernGradientColors.accentEnd],
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
        Color.lerp(context.colorScheme.surfaceContainer,
            context.colorScheme.surfaceContainerHigh, GradientConstants.darkCardBlendFactor)!,
        Color.lerp(context.colorScheme.surface,
            context.colorScheme.surfaceContainer, GradientConstants.darkCardEndBlendFactor)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates a modern success gradient
  static LinearGradient successGradient() {
    return const LinearGradient(
      colors: [
        ModernGradientColors.successStart,
        ModernGradientColors.successEnd
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates a modern warning gradient
  static LinearGradient warningGradient() {
    return const LinearGradient(
      colors: [
        ModernGradientColors.warningStart,
        ModernGradientColors.warningEnd
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates a modern error gradient
  static LinearGradient errorGradient() {
    return const LinearGradient(
      colors: [ModernGradientColors.errorStart, ModernGradientColors.errorEnd],
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
  
  /// Creates an elegant gradient for premium features
  static LinearGradient elegantGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [
              ModernGradientColors.darkElegantStart,
              ModernGradientColors.darkElegantEnd
            ]
          : [
              ModernGradientColors.elegantStart,
              ModernGradientColors.elegantEnd
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates a sunset gradient for warm features
  static LinearGradient sunsetGradient() {
    return const LinearGradient(
      colors: [
        ModernGradientColors.sunsetStart,
        ModernGradientColors.sunsetEnd
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates an ocean gradient for calm features
  static LinearGradient oceanGradient() {
    return const LinearGradient(
      colors: [
        ModernGradientColors.oceanStart,
        ModernGradientColors.oceanEnd
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates a forest gradient for natural features
  static LinearGradient forestGradient() {
    return const LinearGradient(
      colors: [
        ModernGradientColors.forestStart,
        ModernGradientColors.forestEnd
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Creates a sophisticated dark gradient
  static LinearGradient darkOceanGradient() {
    return const LinearGradient(
      colors: [
        ModernGradientColors.darkOceanStart,
        ModernGradientColors.darkOceanEnd
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
