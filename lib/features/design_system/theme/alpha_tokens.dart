/// Opacity design tokens for deliberately faded fills.
///
/// Hand-authored rather than generated, for the same reasons as
/// `motion_tokens.dart` and `sizing_tokens.dart`: these values are
/// brightness-invariant (identical in light and dark, so nothing lerps), and
/// opacity is not a Figma *variable* in this repo's export — the generator
/// reads exactly `color` / `typography` / `spacing` / `borderRadius`.
///
/// **This group is deliberately small, and should stay small.** An alpha is
/// the right answer only when a call site needs *the same hue at reduced
/// strength* and no colour token expresses it. Text emphasis is not such a
/// case: `colors.text.{high,medium,low}Emphasis` is already the fade ramp for
/// type, and fading one of those further just re-derives a step that exists.
/// An error-toned container fill is not such a case either — the theme's
/// `colorScheme.errorContainer` is the design system's own error wash.
library;

/// Alphas applied to a surface or accent colour that must stay recognisably
/// the same hue while receding.
abstract final class SurfaceAlphas {
  /// 0.08 — a tone-tinted card fill, where the tint *is* the categorisation
  /// and must survive at card size without competing with the value on top.
  ///
  /// Not expressible as a `colorScheme.*Container`: only `errorContainer`
  /// carries its accent, while `primaryContainer` and `tertiaryContainer`
  /// resolve to neutral `background.level02`/`level03`. Binding those would
  /// collapse a three-tone scale into one red and two greys.
  static const double tint = 0.08;

  /// 0.4 — an accent that has already been satisfied: a passed station on a
  /// wizard track, keeping the hue so the track reads as one filled line
  /// while leaving exactly one full-strength "press this next" signal.
  static const double muted = 0.4;

  /// 0.7 — painter linework that frames content without competing with it
  /// (the scanner viewfinder's sweep line).
  ///
  /// Named for the fade rather than the role, because `colors.decorative.*`
  /// is an unrelated group of divider and border *colours* — pairing the two
  /// names in one expression would read as a tautology rather than a value
  /// and its opacity.
  static const double linework = 0.7;

  // ── The banner wash set (goal-agent voice surfaces, 2026-08-10) ─────────
  //
  // One accent hue, three strengths — the register-tinted card recipe from
  // the goal-agents design handover: the same hue as the card's tint carries
  // its border, its persona chip and its one pressable control, so a banner
  // reads as ONE colour statement at three intensities rather than three
  // decisions. Shared by the banner card, the dock, and the conversation
  // proposal card. Maintainer-approved addition (the alternative was bending
  // to `tint`/`muted`, which visibly breaks the recipe).

  /// 0.26 — the 1 px border of a register-tinted card: strong enough to
  /// hold the card's edge on `background.level02`, weak enough that the
  /// full-strength accent stays reserved for text and monograms.
  static const double washBorder = 0.26;

  /// 0.22 — the persona-chip fill behind an accent-coloured monogram.
  static const double washChip = 0.22;

  /// 0.20 — the resting fill of a pressable accent control (the banner's
  /// CTA pill): visibly a control, never louder than the copy above it.
  static const double washControl = 0.20;
}
