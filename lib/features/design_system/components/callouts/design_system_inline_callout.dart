import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The design-system's inline message callout: a `background.level02` surface
/// with an alert-toned hairline border and leading glyph, and high-emphasis
/// body text.
///
/// Something to *read*, not something to press — deliberately distinct from
/// the hairline card grammar sections use, so a band cannot carry two
/// dialects of "this is a surface". Promoted from the sync feature (where the
/// roster's paused banner and the add-device security warning shared it) so
/// the next inline-warning surface reuses instead of re-inventing.
///
/// The tone follows the alert ramp's contract: the border and glyph are
/// non-text and carry the tone's `defaultColor` (≥ 3:1 as a graphical
/// object), while the body text stays `text.highEmphasis` — a callout's
/// message must never depend on an alert hue for its legibility.
class DesignSystemInlineCallout extends StatelessWidget {
  const DesignSystemInlineCallout({
    required this.icon,
    required this.text,
    super.key,
    this.tone,
    this.trailing,
  });

  /// Leading glyph, drawn in the callout's tone.
  final IconData icon;

  /// The message. High-emphasis body text; wraps freely.
  final String text;

  /// Border and glyph colour; defaults to the warning tone.
  final Color? tone;

  /// Optional action on the trailing edge — the one thing the callout is
  /// asking for, where it asks for something (the goal cards' "Mark done").
  /// Null keeps the read-only band this component started as.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tone ?? tokens.colors.alert.warning.defaultColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        // The stroke is bound to the sizing token, not left on Border.all's
        // implicit default: the two are equal today only by coincidence, and
        // retuning BorderWidths.hairline must retune this frame with it.
        // ignore: avoid_redundant_argument_values
        border: Border.all(color: color, width: BorderWidths.hairline),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: IconSizes.l, color: color),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                text,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
            if (trailing case final trailing?) ...[
              SizedBox(width: tokens.spacing.step3),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}
