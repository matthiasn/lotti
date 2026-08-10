import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The resolved look of one banner: an accent hue and its three washes —
/// the card fill, the 1 px border, the persona-chip fill and the CTA-pill
/// fill are the SAME hue at descending strengths, so a banner reads as one
/// colour statement (the design handover's surface recipe). Every value
/// binds to a design-system token; no banner ever introduces a colour or an
/// alpha of its own.
typedef GoalBannerStyle = ({
  Color accent,
  Color fill,
  Color border,
  Color chipFill,
  Color controlFill,
});

/// Resolves a banner's style from its register and accent preset.
///
/// **The register tints the default accent** (handover, "register → accent
/// mapping"): doing well reads green-family before a word of the copy is
/// read, a restart reads calm teal (a beginning, never a verdict), urgency
/// reads ember, and roast gets its lime. The model's `calm`/`ember`/`neon`
/// picks ride that register default — they are the same three families —
/// while the two *energy variants*, `tide` and `aurora`, deliberately
/// override the hue.
GoalBannerStyle goalBannerStyle({
  required GoalNudgeTone tone,
  required GoalBannerAccent accent,
  required DsColors colors,
  required Brightness brightness,
}) {
  final registerHue = switch (tone) {
    // A beginning, not a verdict: the established "an agent wrote this"
    // teal — the warmest register belongs to the emptiest window.
    GoalNudgeTone.encourage => colors.aiCard.accent,
    // Green at a glance — doing well must be visible pre-reading.
    GoalNudgeTone.celebrate => colors.alert.success.defaultColor,
    GoalNudgeTone.nudge => colors.alert.warning.defaultColor,
    GoalNudgeTone.roast => GoalAccentHues.neon(brightness),
  };
  final hue = switch (accent) {
    GoalBannerAccent.tide => colors.alert.info.defaultColor,
    GoalBannerAccent.aurora => GoalAccentHues.aurora(brightness),
    GoalBannerAccent.calm ||
    GoalBannerAccent.ember ||
    GoalBannerAccent.neon => registerHue,
  };
  return (
    accent: hue,
    // Opaque: the tint composited onto the card surface, so the card needs
    // no knowledge of what sits behind it.
    fill: Color.alphaBlend(
      hue.withValues(alpha: SurfaceAlphas.tint),
      colors.background.level02,
    ),
    border: hue.withValues(alpha: SurfaceAlphas.washBorder),
    chipFill: hue.withValues(alpha: SurfaceAlphas.washChip),
    controlFill: hue.withValues(alpha: SurfaceAlphas.washControl),
  );
}
