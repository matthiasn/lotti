import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

/// Provider colour identity + the two layout constants still used by the AI
/// provider / capability filter chips.
///
/// The chips themselves are design-system `DesignSystemChip`s now, so the chip
/// surface, border, label and selected styling all come from design tokens.
/// What remains here is the per-provider colour (carried on the chip's avatar
/// dot) and the row spacing.
class ProviderChipConstants {
  /// Gap (and run-gap) between chips in the provider / capability filter rows.
  static const double chipSpacing = 6;

  /// Alpha applied to the trailing stop of the avatar dot's gradient, so the
  /// provider colour fades slightly across the dot.
  static const double avatarGradientAlpha = 0.75;

  /// Provider-specific colors that work in both light and dark themes
  static const Map<InferenceProviderType, ({Color dark, Color light})>
  providerColors = {
    InferenceProviderType.alibaba: (
      dark: Color(0xFFFFAB40),
      light: Color(0xFFFF6D00), // Alibaba Orange
    ),
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
    InferenceProviderType.melious: (
      dark: Color(0xFF64D8A9),
      light: Color(0xFF0E9F6E), // Green
    ),
    InferenceProviderType.nebiusAiStudio: (
      dark: Color(0xFFF06292),
      light: Color(0xFFE91E63), // Pink
    ),
    InferenceProviderType.omlx: (
      dark: Color(0xFF7DD3FC),
      light: Color(0xFF0284C7), // Sky blue
    ),
    InferenceProviderType.whisper: (
      dark: Color(0xFFFF8A65),
      light: Color(0xFFFF5722), // Deep Orange
    ),
    InferenceProviderType.voxtral: (
      dark: Color(0xFFFF6B6B),
      light: Color(0xFFE53935), // Red/Coral
    ),
    InferenceProviderType.mlxAudio: (
      dark: Color(0xFF4ECDC4),
      light: Color(0xFF00BCD4), // Teal
    ),
    InferenceProviderType.mistral: (
      dark: Color(0xFFFFB74D),
      light: Color(0xFFFF9800), // Mistral Orange/Gold
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
