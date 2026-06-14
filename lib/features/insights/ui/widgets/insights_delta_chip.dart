import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Percent change from [previous] to [current], rounded. Null when there is
/// no previous baseline to divide by (`previous == 0`).
int? insightsDeltaPercent(int current, int previous) {
  if (previous == 0) return null;
  return ((current - previous) / previous * 100).round();
}

/// Current-vs-previous change indicator: the percent change with a leading
/// +/- sign so direction is never carried by color alone (color-blind- and
/// low-vision-safe) — muted green up, muted clay down (semantic
/// success/error tokens, the latter chosen so it never reads as the gold/amber
/// category hue). Renders nothing when both values are zero.
///
/// When [muted] (an in-progress period, where the delta is a partial-sample
/// preview), the colour is dropped to neutral so a half-finished week doesn't
/// shout "decline"; the arrow still conveys direction.
class InsightsDeltaChip extends StatelessWidget {
  const InsightsDeltaChip({
    required this.current,
    required this.previous,
    this.muted = false,
    super.key,
  });

  final int current;
  final int previous;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    if (current == 0 && previous == 0) return const SizedBox.shrink();

    final neutral = tokens.colors.text.mediumEmphasis;
    // The higher-contrast (hover) step of the semantic accents: the default
    // green fails the 4.5:1 small-text bar on the light card, and the stronger
    // step clears it in both themes (darker on light, lighter on dark).
    final up = muted ? neutral : tokens.colors.alert.success.hover;
    final down = muted ? neutral : tokens.colors.alert.error.hover;
    final pct = insightsDeltaPercent(current, previous);

    final String text;
    final Color color;
    if (pct == null) {
      // No previous time, but the current period has some → brand new. Kept
      // neutral (not positive-green): "new" is a state, not a win.
      text = messages.insightsDeltaNew;
      color = neutral;
    } else if (pct > 0) {
      text = '+$pct%';
      color = up;
    } else if (pct < 0) {
      text = '$pct%'; // already carries the minus sign
      color = down;
    } else {
      text = '0%';
      color = neutral;
    }

    // Body-size mono (tabular figures): a leading +/- sign carries direction in
    // text — readable when the colour is muted, and never reliant on hue alone.
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: monoMetaStyle(
        tokens,
        tokens.colors,
        base: tokens.typography.styles.body.bodySmall,
        color: color,
      ),
    );
  }
}
