import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Toggle row for settings definition forms: title + optional subtitle on
/// the left, a [DesignSystemToggle] on the right. The whole row is
/// tappable. Sits inside a `SettingsFormSection` card, which provides the
/// surrounding padding.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Optional leading glyph, rendered at medium emphasis.
  final IconData? icon;

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final interactive = enabled && onChanged != null;

    return InkWell(
      onTap: interactive ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.step2),
        child: Row(
          // Anchor leading icons and the toggle to the title line rather
          // than the row center, so two-line rows don't float their glyph
          // beside the subtitle.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  top:
                      (tokens.typography.lineHeight.subtitle2 - spacing.step5) /
                      2,
                ),
                child: Icon(
                  icon,
                  size: spacing.step5,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(width: spacing.step3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: spacing.step1),
                    Text(
                      subtitle!,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: spacing.step3),
            // The row's InkWell handles taps; the toggle still gets its own
            // handler so direct hits behave identically.
            DesignSystemToggle(
              value: value,
              semanticsLabel: title,
              enabled: interactive,
              onChanged: interactive ? onChanged! : (_) {},
            ),
          ],
        ),
      ),
    );
  }
}
