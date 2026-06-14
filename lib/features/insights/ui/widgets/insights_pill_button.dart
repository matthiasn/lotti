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
    // The on/off state is encoded four ways so it survives at a glance, for
    // low-vision users, and on a static screenshot: a brand-accent border, a
    // heavier 1.5px stroke, the stronger accent fill, and semibold text. An
    // inactive outlined pill keeps a quiet resting border so it still reads as
    // a button.
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
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          hoverColor: tokens.colors.surface.hover,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              // A heavier active border adds a non-color "this is on" cue that
              // survives for low-vision users and on a static screenshot.
              border: Border.all(
                color: borderColor,
                width: active ? 1.5 : 1.0,
              ),
            ),
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
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: foreground,
                        fontWeight: active
                            ? tokens.typography.weight.semiBold
                            : null,
                      ),
                    ),
                  ),
                ],
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
