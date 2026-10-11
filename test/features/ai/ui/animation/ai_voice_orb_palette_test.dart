import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_orb_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AiVoiceOrbPalette.fromTokens', () {
    test('on dark keeps the original look: the accent, white glints and the '
        'accent deepened for the halo', () {
      final palette = AiVoiceOrbPalette.fromTokens(dsTokensDark);
      final accent = dsTokensDark.colors.interactive.enabled;
      expect(palette.onLightSurface, isFalse);
      expect(palette.body, accent);
      expect(palette.glint, dsTokensDark.colors.text.highEmphasis);
      expect(palette.halo, AiVoiceOrbPalette.deepened(accent));
      expect(palette.halo.r, closeTo(accent.r * 0.72, 1e-9));
    });

    test('on light the energy gets lighter, never darker: a lit glint above '
        'the body, never the near-black text ink, and the halo between', () {
      final palette = AiVoiceOrbPalette.fromTokens(dsTokensLight);
      final accent = dsTokensLight.colors.interactive.enabled;
      expect(palette.onLightSurface, isTrue);
      expect(palette.body, accent);
      expect(palette.glint, isNot(dsTokensLight.colors.text.highEmphasis));
      expect(
        palette.glint.computeLuminance(),
        greaterThan(palette.body.computeLuminance()),
      );
      // The same hue, lit to where the dark theme's accent sits.
      final glintHsl = HSLColor.fromColor(palette.glint);
      expect(
        glintHsl.hue,
        closeTo(HSLColor.fromColor(accent).hue, 0.5),
      );
      expect(
        glintHsl.lightness,
        closeTo(AiVoiceOrbPalette.lightGlintLightness, 0.01),
      );
      expect(palette.halo, Color.lerp(palette.body, palette.glint, 0.5));
    });

    test('an accent handed in tints the body, the glint and the halo', () {
      const accent = Color(0xFF3366CC);
      final dark = AiVoiceOrbPalette.fromTokens(dsTokensDark, accent: accent);
      final light = AiVoiceOrbPalette.fromTokens(dsTokensLight, accent: accent);
      expect(dark.body, accent);
      expect(light.body, accent);
      expect(
        HSLColor.fromColor(light.glint).hue,
        closeTo(HSLColor.fromColor(accent).hue, 0.5),
      );
    });

    test('palettes compare by value', () {
      expect(
        AiVoiceOrbPalette.fromTokens(dsTokensLight),
        AiVoiceOrbPalette.fromTokens(dsTokensLight),
      );
      expect(
        AiVoiceOrbPalette.fromTokens(dsTokensLight).hashCode,
        AiVoiceOrbPalette.fromTokens(dsTokensLight).hashCode,
      );
      expect(
        AiVoiceOrbPalette.fromTokens(dsTokensLight),
        isNot(AiVoiceOrbPalette.fromTokens(dsTokensDark)),
      );
    });
  });
}
