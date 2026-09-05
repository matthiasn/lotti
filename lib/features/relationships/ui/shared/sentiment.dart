import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The single sentiment → color mapping for the relationships surface
/// (design plan §0.6). One helper, used by the list rows, the detail beats
/// and the composer — no per-screen color tables, no literal hexes at the
/// call sites.
///
/// The mapping is fixed by the design plan:
///   delightful → `interactive.enabled` (teal `#5ED4B7`)
///   good       → `alert.success.defaultColor` (`#7AB889`)
///   neutral    → foreground at 38% alpha (recedes; "nothing to report")
///   strained   → `alert.warning.defaultColor`
///   difficult  → `alert.error.defaultColor`
Color sentimentColor(DsTokens tokens, CheckInSentiment sentiment) {
  final colors = tokens.colors;
  return switch (sentiment) {
    CheckInSentiment.delightful => colors.interactive.enabled,
    CheckInSentiment.good => colors.alert.success.defaultColor,
    CheckInSentiment.neutral => sentimentNeutralColor(tokens),
    CheckInSentiment.strained => colors.alert.warning.defaultColor,
    CheckInSentiment.difficult => colors.alert.error.defaultColor,
  };
}

/// The neutral sentiment's recede tone — foreground at 38% alpha. Exposed on
/// its own because the unset/null sentiment bead reuses it.
Color sentimentNeutralColor(DsTokens tokens) =>
    tokens.colors.text.highEmphasis.withValues(alpha: 0.38);

/// The tint used for the 16%-tint sentiment pills (design plan §0.6). Same
/// hue as [sentimentColor], at the canonical 16% wash.
Color sentimentPillFill(DsTokens tokens, CheckInSentiment sentiment) =>
    sentimentColor(tokens, sentiment).withValues(alpha: 0.16);

/// The sentiment dot/bead paint color for a nullable sentiment. `null`
/// renders as the neutral tone so an unset sentiment still reads as a
/// quiet bead rather than disappearing (the detail beat rail uses this).
Color sentimentDotColor(DsTokens tokens, CheckInSentiment? sentiment) =>
    sentiment == null
    ? sentimentNeutralColor(tokens)
    : sentimentColor(tokens, sentiment);

/// The accent ring drawn around the selected sentiment dot in the composer
/// (design plan §3.4: "selected dot gets a 2px gap ring in its own color").
Color sentimentRingColor(DsTokens tokens, CheckInSentiment sentiment) =>
    sentimentColor(tokens, sentiment);
