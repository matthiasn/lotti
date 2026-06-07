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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // mediumEmphasis for inactive pills: lowEmphasis is near-illegible on
    // the light theme (32% black) and faint on dark.
    final foreground = active
        ? tokens.colors.text.highEmphasis
        : tokens.colors.text.mediumEmphasis;

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: active,
      child: Material(
        color: active ? tokens.colors.surface.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          hoverColor: tokens.colors.surface.hover,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              border: outlined || active
                  ? Border.all(color: tokens.colors.decorative.level02)
                  : Border.all(color: Colors.transparent),
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
  }
}
