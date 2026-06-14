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

/// Current-vs-previous change indicator. Direction is encoded three ways so it
/// never depends on color alone (color-blind / low-vision / grayscale safe):
/// a leading arrow glyph, a +/- sign, AND a muted green-up / clay-down accent
/// (the clay chosen so it never reads as the gold/amber category hue). The
/// accent always stays — an in-progress period is signalled by the "same days"
/// qualifier next to it, not by draining the color (which erased direction at
/// a glance). Renders nothing when both values are zero.
class InsightsDeltaChip extends StatelessWidget {
  const InsightsDeltaChip({
    required this.current,
    required this.previous,
    this.prominent = false,
    super.key,
  });

  final int current;
  final int previous;

  /// Larger type for the headline KPI use; the table keeps the compact size.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    if (current == 0 && previous == 0) return const SizedBox.shrink();

    final neutral = tokens.colors.text.mediumEmphasis;
    // Higher-contrast (hover) accent step so the small text clears 4.5:1 in
    // both themes (default green fails on the light card).
    final up = tokens.colors.alert.success.hover;
    final down = tokens.colors.alert.error.hover;
    final pct = insightsDeltaPercent(current, previous);

    final String text;
    final Color color;
    final IconData? glyph;
    if (pct == null) {
      // No previous time, but the current period has some → brand new. Neutral
      // (not positive-green): "new" is a state, not a win.
      text = messages.insightsDeltaNew;
      color = neutral;
      glyph = null;
    } else if (pct > 0) {
      text = '+$pct%';
      color = up;
      glyph = Icons.arrow_upward_rounded;
    } else if (pct < 0) {
      text = '$pct%'; // already carries the minus sign
      color = down;
      glyph = Icons.arrow_downward_rounded;
    } else {
      text = '0%';
      color = neutral;
      glyph = null;
    }

    final base = prominent
        ? tokens.typography.styles.body.bodyMedium
        : tokens.typography.styles.body.bodySmall;
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: monoMetaStyle(tokens, tokens.colors, base: base, color: color),
    );
    if (glyph == null) return label;

    final glyphSize = prominent ? tokens.spacing.step5 : tokens.spacing.step4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(glyph, size: glyphSize, color: color),
        SizedBox(width: tokens.spacing.step1),
        label,
      ],
    );
  }
}
