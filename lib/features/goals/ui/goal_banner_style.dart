import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The resolved look of one accent preset: an accent hue and its faded
/// fill. Every value binds to an EXISTING design-system token (ADR 0058:
/// the model selects presets, code implements them) — no banner ever
/// introduces a colour of its own.
typedef GoalBannerAccentStyle = ({Color accent, Color fill});

/// Maps the code-owned accent catalog onto design-system tokens.
///
/// `calm` uses the AI-card accent pair (the established "an agent wrote
/// this" tint); the others bind semantic and decorative hues with the
/// [SurfaceAlphas.tint] card-fill alpha — the same hue receding, which is
/// exactly what that alpha token exists for.
GoalBannerAccentStyle goalBannerAccentStyle(
  GoalBannerAccent accent,
  DsColors colors,
) {
  Color tinted(Color color) => color.withValues(alpha: SurfaceAlphas.tint);
  return switch (accent) {
    GoalBannerAccent.calm => (
      accent: colors.aiCard.accent,
      fill: colors.aiCard.accentSoft,
    ),
    GoalBannerAccent.tide => (
      accent: colors.alert.info.defaultColor,
      fill: tinted(colors.alert.info.defaultColor),
    ),
    GoalBannerAccent.ember => (
      accent: colors.alert.warning.defaultColor,
      fill: tinted(colors.alert.warning.defaultColor),
    ),
    GoalBannerAccent.neon => (
      accent: colors.interactive.enabled,
      fill: tinted(colors.interactive.enabled),
    ),
    GoalBannerAccent.aurora => (
      accent: colors.decorative.level03,
      fill: tinted(colors.decorative.level02),
    ),
  };
}
