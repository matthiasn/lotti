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
/// strength* and no colour token expresses it. An error-toned container fill
/// is not such a case — the theme's `colorScheme.errorContainer` is the design
/// system's own error wash.
///
/// Text emphasis is *usually* not such a case either:
/// `colors.text.{high,medium,low}Emphasis` is already the fade ramp for type,
/// and fading one of those further normally just re-derives a step that
/// exists. [SecondaryGlyphAlpha] is the one sanctioned exception, and it is
/// there because the ramp genuinely stops short — see its doc.
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

/// The one approved step below `colors.text.lowEmphasis`.
///
/// The text ramp bottoms out at `lowEmphasis`, which is the right weight for a
/// glyph that is *the* thing in its slot — a row's trailing chevron, a meta
/// caption. It is too loud for a glyph that sits *beside* the row's real
/// action and must not compete with it.
///
/// The checklist row is the case that forced this. Its primary action is
/// checking the item off; the pencil is a secondary way into the editor,
/// sitting next to a 44pt checkbox. At `lowEmphasis` the pencil carried ~2.5x
/// the ink of the chevron it is meant to pair with and read as the loudest
/// mark on the row. Nothing in `colors.text.*` expresses "quieter than
/// lowEmphasis", so this is a real gap rather than a re-derivation of an
/// existing step.
///
/// Maintainer-approved (2026-08-19). Reach for it only for a genuinely
/// secondary affordance; if a glyph is the point of its slot, it belongs at a
/// `colors.text.*` tier instead.
abstract final class SecondaryGlyphAlpha {
  /// 0.55 — a secondary affordance beside a row's primary action: clearly
  /// present, never competing with it.
  static const double affordance = 0.55;

  /// 0.2 — a hint that only has to be findable once. The checklist row's drag
  /// handle: a long-press anywhere on the row starts the drag, so the grip is
  /// a reminder that the gesture exists, not the way to perform it. At any
  /// higher alpha its repeating texture pulls the eye off the title.
  static const double hint = 0.2;
}
