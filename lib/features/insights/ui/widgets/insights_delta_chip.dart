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

/// Whether a rising value is good, bad, or neither — which decides the accent
/// colour a [InsightsDeltaChip] paints the change (the arrow/sign always show
/// the true direction regardless).
enum InsightsTrendValence {
  /// More is better (activity/output): up reads green, down reads clay.
  moreIsBetter,

  /// More is worse (cost, energy, carbon): up reads clay, down reads green.
  lessIsBetter,

  /// Direction carries no good/bad meaning (tokens, requests): never coloured.
  neutral,
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
    this.valence = InsightsTrendValence.moreIsBetter,
    super.key,
  });

  final int current;
  final int previous;

  /// Larger type for the headline KPI use; the table keeps the compact size.
  final bool prominent;

  /// Whether rising is good/bad/neither — flips or drops the accent colour
  /// while the arrow + sign keep showing the true direction. Defaults to
  /// [InsightsTrendValence.moreIsBetter] (the counts-are-good Insights case).
  final InsightsTrendValence valence;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    if (current == 0 && previous == 0) return const SizedBox.shrink();

    final neutral = tokens.colors.text.mediumEmphasis;
    // The chip text is small (caption/bodySmall), so the accent must clear WCAG
    // AA 4.5:1. The light-theme green `hover` step is only ~4.0:1 on the card
    // and fails; its darker `pressed` step clears ~6:1. The dark theme is the
    // mirror image — there `hover` is already a high-contrast light green and
    // `pressed` is a washed-out pastel — so pick the step per theme: the
    // darker green in light, the more saturated green in dark. Direction never
    // rides on color alone regardless (the arrow glyph and +/- sign remain).
    final light = Theme.of(context).brightness == Brightness.light;
    final good = light
        ? tokens.colors.alert.success.pressed
        : tokens.colors.alert.success.hover;
    final bad = light
        ? tokens.colors.alert.error.pressed
        : tokens.colors.alert.error.hover;
    // Map the true direction to an accent through the valence: an increase is
    // "good" only when more is better; when more is worse (cost/energy/carbon)
    // an increase reads clay; a value-free metric stays neutral either way.
    final up = switch (valence) {
      InsightsTrendValence.moreIsBetter => good,
      InsightsTrendValence.lessIsBetter => bad,
      InsightsTrendValence.neutral => neutral,
    };
    final down = switch (valence) {
      InsightsTrendValence.moreIsBetter => bad,
      InsightsTrendValence.lessIsBetter => good,
      InsightsTrendValence.neutral => neutral,
    };
    // Raw (unrounded) change drives the dead-band; the rounded value is what we
    // show. previous == 0 → no baseline to divide by.
    final raw = previous == 0 ? null : (current - previous) / previous * 100;
    final pct = raw?.round();

    final String text;
    final Color color;
    final IconData? glyph;
    if (raw == null) {
      // No previous time, but the current period has some → brand new. Neutral
      // (not positive-green): "new" is a state, not a win.
      text = messages.insightsDeltaNew;
      color = neutral;
      glyph = null;
    } else if (raw.abs() < 1) {
      // Sub-1% swing: keep the figure but render it neutrally (no arrow, no
      // colour) so rounding noise on a small base never reads as a real trend
      // or — worse — flips sign with the same confident weight as a big move.
      text = pct! > 0 ? '+$pct%' : '$pct%';
      color = neutral;
      glyph = null;
    } else if (pct! > 0) {
      text = '+$pct%';
      color = up;
      glyph = Icons.arrow_upward_rounded;
    } else {
      text = '$pct%'; // already carries the minus sign
      color = down;
      glyph = Icons.arrow_downward_rounded;
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
