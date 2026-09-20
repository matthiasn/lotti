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
/// Two things keep these apart from the semantic ramp, and the second one
/// took a correction: they are **lower chroma** (0.095 dark / 0.105 light,
/// against the alert colours' far more saturated values), and their **hue
/// angles are chosen to maximise the distance to the nearest semantic
/// anchor** — error ~25, warning ~68, success ~145, interactive ~172, info
/// ~235. An evenly spread ramp is not good enough: the first version of
/// this table put a hue 5° from success and another 7° from warning, so an
/// overdue person could sit beside a not-enrolled person wearing almost the
/// success green. Every hue below is at least 25° from every anchor.
///
/// Hand-authored for the same reason [GoalAccentHues] is — the Figma export
/// carries no persona ramp — and with the same intent: they graduate into
/// `tokens.json` and this file dissolves into the generated palette.
/// Maintainer-approved 2026-09-20.
///
/// | hue     | angle | nearest anchor | dark      | light     |
/// |---------|-------|----------------|-----------|-----------|
/// | rose    | 0     | 25°            | `#E398AE` | `#994D66` |
/// | citron  | 100   | 32°            | `#BFB36A` | `#776A0A` |
/// | lagoon  | 200   | 28°            | `#5DC3C9` | `#007A81` |
/// | indigo  | 265   | 30°            | `#94B0EE` | `#4B67A5` |
/// | orchid  | 300   | 65°            | `#BAA4E5` | `#735A9C` |
/// | fuchsia | 335   | 50°            | `#D79AC9` | `#8D5081` |
abstract final class PersonaAccentHues {
  static const List<Color> _dark = [
    Color(0xFFE398AE),
    Color(0xFFBFB36A),
    Color(0xFF5DC3C9),
    Color(0xFF94B0EE),
    Color(0xFFBAA4E5),
    Color(0xFFD79AC9),
  ];

  static const List<Color> _light = [
    Color(0xFF994D66),
    Color(0xFF776A0A),
    Color(0xFF007A81),
    Color(0xFF4B67A5),
    Color(0xFF735A9C),
    Color(0xFF8D5081),
  ];

  /// The ramp for [brightness], in a stable order — an avatar's hue is
  /// chosen by index, so the order is part of the contract: reordering it
  /// would recolour every person already on screen.
  static List<Color> ramp(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;
}
