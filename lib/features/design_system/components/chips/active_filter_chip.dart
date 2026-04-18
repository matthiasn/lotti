import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Pill-shaped chip used by the Tasks/Projects tab active-filter rows.
///
/// Matches the Figma reference: dark surface, accent-tinted outline, icon
/// in the accent colour, high-emphasis label text, and a filled ✕ on the
/// trailing end that removes the filter. Tapping anywhere on the chip
/// removes the filter.
class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    required this.label,
    required this.accentColor,
    required this.onRemove,
    this.leadingIcon,
    this.avatar,
    super.key,
  }) : assert(
         leadingIcon == null || avatar == null,
         'Use either leadingIcon or avatar, not both.',
       );

  final String label;
  final Color accentColor;
  final VoidCallback onRemove;
  final IconData? leadingIcon;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final backgroundColor = tokens.colors.surface.enabled;
    final labelColor = tokens.colors.text.highEmphasis;
    final removeIconColor = tokens.colors.text.mediumEmphasis;

    final accessory = avatar != null
        ? SizedBox.square(
            dimension: 14,
            child: ClipOval(child: avatar),
          )
        : leadingIcon != null
        ? Icon(leadingIcon, size: 14, color: accentColor)
        : null;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accentColor),
        borderRadius: radius,
      ),
      child: Ink(
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: accentColor),
            borderRadius: radius,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (accessory != null) ...[
                  accessory,
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.cancel_rounded,
                  size: 14,
                  color: removeIconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
