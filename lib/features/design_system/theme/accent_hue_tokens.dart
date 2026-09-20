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

/// Six identity hues for a person's avatar, one per persona slot.
///
/// A person's accent is identity, not status. The People surfaces used to
/// draw it from `alert.warning.ink`, `alert.info.ink`, `alert.success.ink`
/// and `interactive.enabled` — so a person could wear the exact orange the
/// overdue pill wears, or the teal that means "you can press this", and the
/// colour said something about them that was not true. A semantic token
/// borrowed for decoration stops being semantic.
///
/// These are deliberately **lower chroma than the alert ramp** (0.095 dark /
/// 0.105 light, against the alert colours' far more saturated values). Status
/// colours are few and loud; identity colours are many and quiet, and the
/// difference in saturation is what keeps a ring of six from reading as six
/// warnings. Hue angles are spread to stay clear of the semantic anchors
/// (error ~25, warning ~68, success ~145, info ~235, interactive ~175).
///
/// Hand-authored for the same reason [GoalAccentHues] is — the Figma export
/// carries no persona ramp — and with the same intent: they graduate into
/// `tokens.json` and this file dissolves into the generated palette.
/// Maintainer-approved 2026-09-20.
///
/// | hue    | dark `oklch(0.76 0.095 h)` | light `oklch(0.52 0.105 h)` |
/// |--------|----------------------------|------------------------------|
/// | rose   | `h 10`  → `#E698A3`        | `#9B4D5B`                    |
/// | amber  | `h 75`  → `#D5A96A`        | `#8C5F0E`                    |
/// | fern   | `h 140` → `#91C086`        | `#46773B`                    |
/// | teal   | `h 195` → `#5EC4C4`        | `#007B7C`                    |
/// | azure  | `h 255` → `#88B4ED`        | `#3C6AA4`                    |
/// | violet | `h 310` → `#C4A0DF`        | `#7B5696`                    |
abstract final class PersonaAccentHues {
  static const List<Color> _dark = [
    Color(0xFFE698A3),
    Color(0xFFD5A96A),
    Color(0xFF91C086),
    Color(0xFF5EC4C4),
    Color(0xFF88B4ED),
    Color(0xFFC4A0DF),
  ];

  static const List<Color> _light = [
    Color(0xFF9B4D5B),
    Color(0xFF8C5F0E),
    Color(0xFF46773B),
    Color(0xFF007B7C),
    Color(0xFF3C6AA4),
    Color(0xFF7B5696),
  ];

  /// The ramp for [brightness], in a stable order — an avatar's hue is
  /// chosen by index, so the order is part of the contract: reordering it
  /// would recolour every person already on screen.
  static List<Color> ramp(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;
}
