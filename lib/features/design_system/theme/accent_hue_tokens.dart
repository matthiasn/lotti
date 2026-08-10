import 'dart:ui';

/// Hand-authored accent hues the Figma export does not carry yet.
///
/// The goal-agent banner registers (ADR 0058: personality from type, colour
/// and motion only) need two hues with no counterpart in the generated
/// palette: a **neon lime** for the roast register and an **aurora violet**
/// for the decorative energy variant. Maintainer-approved 2026-08-10 as a
/// hand-authored token pair — the same posture as `alpha_tokens.dart` — with
/// the explicit intent that they graduate into the Figma export /
/// `tokens.json` pipeline and this file then dissolves into the generated
/// palette.
///
/// Values derive from the design handover's oklch definitions; the light
/// variants deepen lightness so the hue keeps contrast on light surfaces:
///
/// | hue    | dark (source oklch)         | light (derived oklch)       |
/// |--------|-----------------------------|------------------------------|
/// | neon   | `84% 0.19 127` → `#A9E043` | `56% 0.16 127` → `#5B8400`  |
/// | aurora | `76% 0.12 305` → `#C39DEE` | `52% 0.13 305` → `#7B52A4`  |
abstract final class GoalAccentHues {
  static const Color _neonDark = Color(0xFFA9E043);
  static const Color _neonLight = Color(0xFF5B8400);
  static const Color _auroraDark = Color(0xFFC39DEE);
  static const Color _auroraLight = Color(0xFF7B52A4);

  /// The roast register's lime — full cheese, per the handover.
  static Color neon(Brightness brightness) =>
      brightness == Brightness.dark ? _neonDark : _neonLight;

  /// The decorative violet energy variant.
  static Color aurora(Brightness brightness) =>
      brightness == Brightness.dark ? _auroraDark : _auroraLight;
}
