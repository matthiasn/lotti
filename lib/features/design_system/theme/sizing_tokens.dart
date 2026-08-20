/// Sizing design tokens: controls, tap targets, icon dimensions, and strokes.
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

/// Visible control dimensions.
///
/// These describe the control itself, not the spacing around it. Keeping the
/// two separate lets a glyph grow into reclaimed inset without changing the
/// surrounding row geometry.
abstract final class ControlSizes {
  /// 24 — the compact checkbox box. This fills the component's existing
  /// 24-high row instead of spending four of those pixels on outer padding.
  static const double checkbox = 24;

  /// 40 — the filled tile behind a leading glyph on a list row, where the
  /// chip anchors the row's left edge and carries its own visual weight (the
  /// device roster's per-device tile).
  ///
  /// Sized as a container rather than borrowed from `spacing.step8`, which is
  /// the same 40 today but is a *gap* and retunes independently of it.
  static const double iconChip = 40;

  /// 28 — the compact chip riding inside a card row, where the full
  /// [iconChip] would out-weigh the title it leads.
  static const double iconChipCompact = 28;

  /// 64 — the square thumbnail standing in for a media entry that has been
  /// collapsed (the collapsed image card's preview).
  ///
  /// Larger than [iconChip] because this carries a real photograph rather than
  /// a glyph, and a 40-square reduces a screenshot to an unreadable smear.
  /// Bounded well below a card's full width because a run of collapsed images
  /// must still read as a list rather than a gallery — the point of collapsing
  /// is that the entry stops competing for the column.
  ///
  /// A container dimension, deliberately not borrowed from the spacing scale:
  /// it is the picture's size, and must not resize when gaps are retuned.
  static const double mediaThumbnail = 64;
}

/// Pointer interaction targets.
abstract final class TapTargets {
  /// 48 — the recommended mobile touch target.
  ///
  /// Components opt into this only where the containing layout already owns a
  /// 48-high slot; the target must not silently inflate compact list rhythm.
  ///
  /// `DesignSystemIconAction` is the exception, and takes the floor
  /// unconditionally: a glyph-only control has no label to borrow hit area
  /// from, so a compact target is its *only* target. It therefore occupies
  /// 48×48 and grows the row it sits in — which is why it belongs in card
  /// headers and panel corners rather than dense rows.
  static const double minimum = 48;
}

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
