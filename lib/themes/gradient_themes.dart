import 'package:lotti/themes/colors.dart';
import 'package:material_ui/material_ui.dart';

// The soft shadow under the About page's app-icon tile.
class GradientConstants {
  static const double enhancedShadowLightAlpha = 0.06;
  static const double enhancedShadowBlurLight = 8;
  static const double enhancedShadowOffsetY = 2;
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
