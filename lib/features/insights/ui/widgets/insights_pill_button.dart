import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The single "pick one of N" pill idiom for the Insights dashboard —
/// shared by the range presets, the custom-date button, and the chart
/// mode toggle so every selector speaks one visual language (instead of
/// mixing custom pills with a default-Material `SegmentedButton`).
class InsightsPillButton extends StatelessWidget {
  const InsightsPillButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.outlined = false,
    this.semanticsLabel,
    this.tooltip,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  /// Persistent border, marking the control as a button even when
  /// inactive (used by the custom-range/date button).
  final bool outlined;
  final String? semanticsLabel;

  /// Plain-language hover/long-press hint (e.g. "This month so far"), so
  /// terse pill labels like MTD/YTD/Compare don't depend on prior knowledge.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Active keeps high-emphasis ink (11:1 on the accent fill); inactive is
    // mediumEmphasis (lowEmphasis is near-illegible on the light theme at 32%
    // black and faint on dark). The accent rides the border/fill, NOT the
    // text — brand teal on the teal-tinted fill would drop the small label
    // below AA.
    final foreground = active
        ? tokens.colors.text.highEmphasis
        : tokens.colors.text.mediumEmphasis;
    // The on/off state is encoded three width-invariant ways so it survives at
    // a glance and for low-vision users without reflowing the row when toggled
    // (a bold label or a thicker stroke changes the pill's width and makes the
    // header jump under the pointer): a brand-accent border colour, the
    // stronger accent fill, and high-emphasis ink. Border width and font weight
    // stay constant across states. An inactive outlined pill keeps a quiet
    // resting border so it still reads as a button.
    final borderColor = active
        ? tokens.colors.interactive.enabled
        : outlined
        ? tokens.colors.decorative.level02
        : Colors.transparent;

    final pill = Semantics(
      label: semanticsLabel,
      button: true,
      selected: active,
      child: Material(
        // The stronger `active` tint (vs the near-threshold `selected` step)
        // gives the selected pill real presence at the compact header width.
        color: active ? tokens.colors.surface.active : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          hoverColor: tokens.colors.surface.hover,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              // Constant 1.5px stroke in every state: only the colour changes,
              // so toggling never reflows the pill width.
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            // Center (widthFactor 1) so the label sits mid-height when the pill
            // is stretched to a taller row height (e.g. the header), while
            // still hugging its content width everywhere else.
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: tokens.spacing.step5, color: foreground),
                      SizedBox(width: tokens.spacing.step2),
                    ],
                    // Flexible so an extreme pane resize ellipsizes the label
                    // instead of overflowing the pill.
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        // Weight stays constant across states — bolding the
                        // active label would widen the pill and jump the row.
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return pill;
    return Tooltip(message: tooltip, child: pill);
  }
}
