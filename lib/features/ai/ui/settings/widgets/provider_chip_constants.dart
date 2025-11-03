import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

/// Constants for provider filter chip styling
class ProviderChipConstants {
  // Modal sizing
  static const double modalHeightFactor = 0.65;

  // Chip styling
  static const double chipFontSize = 13;
  static const double chipBorderRadius = 20;
  static const double chipHorizontalPadding = 12;
  static const double chipVerticalPadding = 6;
  static const double chipBorderWidth = 1.5;
  static const double chipLetterSpacing = 0.2;
  static const FontWeight chipFontWeight = FontWeight.w600;

  // Spacing
  static const double chipSpacing = 6;

  // Alpha values for backgrounds
  static const double surfaceAlpha = 0.5;
  static const double primaryContainerAlpha = 0.7;
  static const double primaryAlpha = 0.8;
  static const double primaryContainerBorderAlpha = 0.3;
  static const double onSurfaceVariantAlpha = 0.8;

  // Provider-specific colors - selected state
  static const double selectedAlphaDark = 0.35;
  static const double selectedAlphaLight = 0.22;

  // Provider-specific colors - unselected state
  static const double unselectedAlphaDark = 0.25;
  static const double unselectedAlphaLight = 0.15;

  // Border alpha values
  static const double selectedBorderAlpha = 0.55;
  static const double unselectedBorderAlpha = 0.35;

  // Avatar styling
  static const double avatarSize = 8;
  static const double avatarGradientAlpha = 0.75;
  static const double avatarShadowAlpha = 0.35;
  static const double avatarShadowBlurRadius = 4;
  static const Offset avatarShadowOffset = Offset(0, 2);

  /// Provider-specific colors that work in both light and dark themes
  static const Map<InferenceProviderType, ({Color dark, Color light})>
      providerColors = {
    InferenceProviderType.anthropic: (
      dark: Color(0xFFD4A574),
      light: Color(0xFFB8864E), // Warm bronze
    ),
    InferenceProviderType.openAi: (
      dark: Color(0xFF6BCF7F),
      light: Color(0xFF4CAF50), // Green
    ),
    InferenceProviderType.gemini: (
      dark: Color(0xFF73B6F5),
      light: Color(0xFF2196F3), // Blue
    ),
    InferenceProviderType.ollama: (
      dark: Color(0xFFFF9F68),
      light: Color(0xFFFF7043), // Orange
    ),
    InferenceProviderType.openRouter: (
      dark: Color(0xFF4ECDC4),
      light: Color(0xFF00BCD4), // Teal
    ),
    InferenceProviderType.genericOpenAi: (
      dark: Color(0xFFA78BFA),
      light: Color(0xFF9C27B0), // Purple
    ),
    InferenceProviderType.nebiusAiStudio: (
      dark: Color(0xFFF06292),
      light: Color(0xFFE91E63), // Pink
    ),
    InferenceProviderType.whisper: (
      dark: Color(0xFFFF8A65),
      light: Color(0xFFFF5722), // Deep Orange
    ),
    InferenceProviderType.gemma3n: (
      dark: Color(0xFF81C784),
      light: Color(0xFF66BB6A), // Light Green
    ),
  };

  /// Get provider color for the current theme
  static Color getProviderColor(
    InferenceProviderType type, {
    required bool isDark,
  }) {
    final colors = providerColors[type];
    if (colors == null) {
      // Fallback color if provider type not found
      return isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    }
    return isDark ? colors.dark : colors.light;
  }
}
