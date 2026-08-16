import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_style.dart';

import '../../../widget_test_utils.dart';

void main() {
  final tokens = resolveTestTheme().extension<DsTokens>()!;
  final colors = tokens.colors;

  NudgeBannerStyle style(
    NudgeTone tone, [
    NudgeBannerAccent accent = NudgeBannerAccent.calm,
  ]) => nudgeBannerStyle(
    tone: tone,
    accent: accent,
    colors: colors,
    brightness: Brightness.dark,
  );

  test('the register tints the accent: doing well reads green, a restart '
      'reads teal, urgency ember, roast lime', () {
    expect(style(NudgeTone.encourage).accent, colors.aiCard.accent);
    expect(
      style(NudgeTone.celebrate).accent,
      colors.alert.success.defaultColor,
    );
    expect(
      style(NudgeTone.nudge).accent,
      colors.alert.warning.defaultColor,
    );
    expect(
      style(NudgeTone.roast).accent,
      GoalAccentHues.neon(Brightness.dark),
    );
  });

  test('calm/ember/neon accent picks ride the register default — they are '
      'the register families, not overrides', () {
    for (final accent in [
      NudgeBannerAccent.calm,
      NudgeBannerAccent.ember,
      NudgeBannerAccent.neon,
    ]) {
      expect(
        style(NudgeTone.celebrate, accent).accent,
        colors.alert.success.defaultColor,
        reason: '$accent must not override the celebrate register',
      );
    }
  });

  test('tide and aurora are energy variants that DO override the register '
      'hue', () {
    expect(
      style(NudgeTone.nudge, NudgeBannerAccent.tide).accent,
      colors.alert.info.defaultColor,
    );
    expect(
      style(NudgeTone.encourage, NudgeBannerAccent.aurora).accent,
      GoalAccentHues.aurora(Brightness.dark),
    );
  });

  test('the neon and aurora hues resolve per brightness — deeper on light '
      'surfaces for contrast', () {
    expect(
      GoalAccentHues.neon(Brightness.dark),
      isNot(GoalAccentHues.neon(Brightness.light)),
    );
    expect(
      GoalAccentHues.aurora(Brightness.dark),
      isNot(GoalAccentHues.aurora(Brightness.light)),
    );
  });

  test('one hue, three washes: border, chip and control carry the accent '
      'hue at the token alphas, and the fill is opaque over the card '
      'surface', () {
    final s = style(NudgeTone.nudge);
    int rgb(Color c) => c.toARGB32() & 0x00FFFFFF;
    expect(rgb(s.border), rgb(s.accent));
    expect(rgb(s.chipFill), rgb(s.accent));
    expect(rgb(s.controlFill), rgb(s.accent));
    expect(s.border.a, closeTo(SurfaceAlphas.washBorder, 0.01));
    expect(s.chipFill.a, closeTo(SurfaceAlphas.washChip, 0.01));
    expect(s.controlFill.a, closeTo(SurfaceAlphas.washControl, 0.01));
    // The fill is pre-composited onto background.level02 — fully opaque,
    // so the card needs no knowledge of what sits behind it.
    expect(s.fill.a, 1.0);
    expect(
      s.fill,
      Color.alphaBlend(
        s.accent.withValues(alpha: SurfaceAlphas.tint),
        colors.background.level02,
      ),
    );
  });
}
