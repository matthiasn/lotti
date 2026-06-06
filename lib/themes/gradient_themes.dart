import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';

// Gradient and shadow constants - tuned for polished, modern look
class GradientConstants {
  // Shadow alpha values for enhanced cards - much more subtle
  static const double enhancedShadowLightAlpha = 0.06;
  static const double enhancedShadowSecondaryLightAlpha = 0.03;
  static const double enhancedShadowSecondaryDarkAlpha = 0.12;

  // Shadow blur and spread values - reduced for cleaner look
  static const double enhancedShadowBlurLight = 8;
  static const double enhancedShadowSecondaryBlurLight = 16;
  static const double enhancedShadowSecondaryBlurDark = 20;
  static const double enhancedShadowOffsetY = 2;
  static const double enhancedShadowSecondaryOffsetY = 4;
}

/// Gradient themes for consistent card styling across the app
class GradientThemes {
  /// Creates a subtle top-left to bottom-right gradient for cards
  static LinearGradient? cardGradient(BuildContext context) {
    return ModernGradientThemes.cardGradient(context);
  }

  /// Creates a modern primary gradient
  static LinearGradient primaryGradient(BuildContext context) {
    return ModernGradientThemes.primaryGradient(context);
  }

  /// Creates a modern accent gradient
  static LinearGradient accentGradient(BuildContext context) {
    return ModernGradientThemes.accentGradient(context);
  }

  /// Creates a background gradient
  static LinearGradient backgroundGradient(BuildContext context) {
    return ModernGradientThemes.backgroundGradient(context);
  }
}
