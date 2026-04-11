import 'package:flutter/material.dart';

/// Shared color palette for the agents feature.
///
/// These colors are used for charts, status indicators, feedback categories,
/// and other agent-specific UI elements. They remain constant regardless of
/// theme to ensure consistent chart readability.
///
/// Where possible, prefer design-system tokens via `context.designTokens`
/// (e.g. `colors.alert.success.defaultColor`) for general UI. This palette
/// exists for compile-time const contexts (chart widgets) and for domain
/// colors with no direct design-system equivalent (e.g. purple, cyan).
class AgentPalette {
  AgentPalette._();

  /// Success / completed — green
  static const Color green = Color(0xFF58CC02);

  /// Info / active — blue
  static const Color blue = Color(0xFF1CB0F6);

  /// Level / progression — purple
  static const Color purple = Color(0xFF6B4CE5);

  /// Streak / in-progress — orange
  static const Color orange = Color(0xFFFF9600);

  /// Warning / failure — red
  static const Color red = Color(0xFFFF4B4B);

  /// AI / communication — cyan
  static const Color cyan = Color(0xFF00BCD4);

  /// Timeliness / productive — yellow
  static const Color yellow = Color(0xFFFFD93D);

  /// Neutral / general — silver
  static const Color silver = Color(0xFFC0C0C0);

  /// Dark elevated surface for card gradients
  static const Color surfaceDarkElevated = Color(0xFF2A2A3C);
}

/// Builds a subtle dark gradient from [AgentPalette.surfaceDarkElevated]
/// tinted toward [accentColor].
LinearGradient agentCardDarkGradient(Color accentColor) {
  return LinearGradient(
    colors: [
      AgentPalette.surfaceDarkElevated,
      Color.lerp(
            AgentPalette.surfaceDarkElevated,
            accentColor,
            0.08,
          ) ??
          AgentPalette.surfaceDarkElevated,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
