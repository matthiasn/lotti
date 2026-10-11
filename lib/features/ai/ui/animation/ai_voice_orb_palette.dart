import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The voice orb's colours by role, for the surface it sits on.
///
/// The orb is drawn as light: its body is the accent, its glints — the
/// crossings and the travelling pressure lobes — the brightest thing in it,
/// and a soft halo around each strand. On a dark surface that is the accent,
/// white and a deepened accent, as it always was. On a light surface the
/// same roles must still get *lighter* where the energy is: a near-black
/// glint (the text ink) drew the peaks as soot, and a deepened halo laid a
/// grey haze over a pale sheet. There the glint is the accent at the dark
/// theme's lightness — the same hue, lit — and the halo the mid-way lit
/// teal between body and glint.
///
/// Derived from the tokens handed in, never from the ambient theme: a host
/// may draw the orb on a surface of another theme (onboarding's previews).
@immutable
class AiVoiceOrbPalette {
  const AiVoiceOrbPalette({
    required this.body,
    required this.glint,
    required this.halo,
    required this.onLightSurface,
  });

  /// The palette for [tokens]' surface, tinted by [accent] — the tokens'
  /// own interactive accent when null.
  factory AiVoiceOrbPalette.fromTokens(DsTokens tokens, {Color? accent}) {
    final body = accent ?? tokens.colors.interactive.enabled;
    final light =
        ThemeData.estimateBrightnessForColor(
          tokens.colors.background.level01,
        ) ==
        Brightness.light;
    if (!light) {
      return AiVoiceOrbPalette(
        body: body,
        glint: tokens.colors.text.highEmphasis,
        // What the shader always used for its atmosphere, now handed in.
        halo: deepened(body),
        onLightSurface: false,
      );
    }
    final glint = HSLColor.fromColor(
      body,
    ).withLightness(lightGlintLightness).toColor();
    return AiVoiceOrbPalette(
      body: body,
      glint: glint,
      halo: Color.lerp(body, glint, 0.5)!,
      onLightSurface: true,
    );
  }

  /// The dark surface's halo: the accent deepened to this share of itself.
  static const double darkHaloScale = 0.72;

  /// [body] deepened by [darkHaloScale] — the dark surface's halo.
  static Color deepened(Color body) => Color.from(
    alpha: 1,
    red: body.r * darkHaloScale,
    green: body.g * darkHaloScale,
    blue: body.b * darkHaloScale,
  );

  /// The light surface's glint: the accent's hue at this lightness — where
  /// the dark theme's accent sits, so the lit teal is the brand's own.
  static const double lightGlintLightness = 0.60;

  final Color body;
  final Color glint;
  final Color halo;

  /// Whether the orb sits on a light surface, where the shader narrows and
  /// softens its halos and its glints.
  final bool onLightSurface;

  @override
  bool operator ==(Object other) =>
      other is AiVoiceOrbPalette &&
      other.body == body &&
      other.glint == glint &&
      other.halo == halo &&
      other.onLightSurface == onLightSurface;

  @override
  int get hashCode => Object.hash(body, glint, halo, onLightSurface);
}
