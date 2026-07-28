/// Sizing design tokens: icon dimensions and border strokes.
///
/// Hand-authored rather than generated, for the same reasons as
/// `motion_tokens.dart`: these values are brightness-invariant (identical in
/// light and dark, so nothing lerps), and sizing is not a Figma *variable* in
/// this repo's export — the generator reads exactly `color` / `typography` /
/// `spacing` / `borderRadius`, and fabricating variable entries in
/// `tokens.json` would misrepresent the export. A small named `const` set is
/// the honest representation and the single source of truth.
///
/// Before these existed, call sites borrowed `tokens.spacing.stepN` as glyph
/// and stroke dimensions — which type-checked, but meant an icon resized
/// whenever the *gap* scale was retuned. Pick by role, not by number.
library;

/// Icon dimensions, smallest to largest.
///
/// Pick by role: [xs]/[s] ride inside caption and meta rows, [m] is the
/// control-glyph tier (corner icon buttons), [l] leads callouts and banners
/// (the Material default optical size), and the hero tiers above it belong to
/// empty states and illustrative motifs.
abstract final class IconSizes {
  /// 12 — inline caption glyphs riding a text line.
  static const double xs = 12;

  /// 16 — list and meta-row glyphs.
  static const double s = 16;

  /// 18 — control glyphs: corner icon buttons, dense actions.
  static const double m = 18;

  /// 24 — leading glyphs on callouts, banners and headers.
  static const double l = 24;

  /// 32 — empty-state support glyphs.
  static const double xl = 32;

  /// 40 — illustrative motif glyphs (the smaller device of a pair).
  static const double xxl = 40;

  /// 48 — hero glyphs: the larger motif device, empty-state leads.
  static const double xxxl = 48;
}

/// Border stroke widths.
abstract final class BorderWidths {
  /// 1 — the default hairline: card outlines, callout frames, field shells.
  static const double hairline = 1;

  /// 2 — emphasized strokes: attention frames, active gate edges, painter
  /// linework.
  static const double emphasis = 2;
}
