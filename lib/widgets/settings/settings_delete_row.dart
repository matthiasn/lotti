import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Full-width destructive action row placed at the end of a settings
/// editor form — the platform-conventional home for Delete.
///
/// Living in the scrollable form (rather than the sticky action bar)
/// keeps the bar's actions at intrinsic width on narrow phones and all
/// locales, separates the destructive path from the save flow entirely,
/// and stays discoverable as a labeled, full-width row.
class SettingsDeleteRow extends StatelessWidget {
  const SettingsDeleteRow({
    required this.label,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final foreground = enabled
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.text.lowEmphasis;
    // Radius matches the field family so the row reads as part of the
    // form, just charged.
    final radius = BorderRadius.circular(spacing.step5);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          child: Container(
            height: spacing.step9,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: foreground.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: spacing.step5,
                  color: foreground,
                ),
                SizedBox(width: spacing.step2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
