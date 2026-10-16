import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The single sentiment → color mapping for the relationships surface
/// (design plan §0.6). One helper, used by the list rows, the detail beats
/// and the composer — no per-screen color tables, no literal hexes at the
/// call sites.
///
/// The mapping is fixed by the design plan:
///   delightful → `alert.success.defaultColor`
///   good       → `alert.success.defaultColor` at the muted alpha
///
/// Delightful used to borrow `interactive.enabled`, the colour that means
/// "you can press this" (design panel 2026-10-15); the two good feelings
/// now share the success family and differ by strength, and their words
/// and glyphs carry the rest.
///   neutral    → foreground at 38% alpha (recedes; "nothing to report")
///   strained   → `alert.warning.defaultColor`
///   difficult  → `alert.error.defaultColor`
Color sentimentColor(DsTokens tokens, CheckInSentiment sentiment) {
  final colors = tokens.colors;
  return switch (sentiment) {
    CheckInSentiment.delightful => colors.alert.success.defaultColor,
    CheckInSentiment.good => colors.alert.success.defaultColor.withValues(
      alpha: SurfaceAlphas.linework,
    ),
    CheckInSentiment.neutral => sentimentNeutralColor(tokens),
    CheckInSentiment.strained => colors.alert.warning.defaultColor,
    CheckInSentiment.difficult => colors.alert.error.defaultColor,
  };
}

/// The neutral sentiment's recede tone — foreground at 38% alpha. Exposed on
/// its own because the unset/null sentiment bead reuses it.
Color sentimentNeutralColor(DsTokens tokens) =>
    tokens.colors.text.highEmphasis.withValues(alpha: 0.38);

/// The face a feeling wears beside its word: a smile for the good ones, the
/// level mouth otherwise — the icon set holds no frown, and a smile on
/// *Difficult* would say the opposite of the word.
IconData sentimentGlyph(CheckInSentiment sentiment) => switch (sentiment) {
  CheckInSentiment.delightful || CheckInSentiment.good => LottiIcons.moodGood,
  _ => LottiIcons.moodNeutral,
};
