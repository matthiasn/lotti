import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Pill-shaped chip used by the Tasks/Projects tab active-filter rows.
///
/// A neutral raised plate with an accent-tinted outline, the icon in the
/// accent colour, high-emphasis label text, and a filled ✕ on the trailing
/// end. Tapping anywhere on the chip removes the filter. Colour is reserved
/// for the chip's own semantics (status, priority) — the plate never tints,
/// so a red priority and a green status read as themselves.
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
    // A NEUTRAL plate, not `surface.selected`: the fill was constant across
    // every chip, so it carried no information — while its tint fought the
    // accent of any chip that isn't the same hue (a red P0 chip sat on a
    // mint plate). The accent outline and glyph carry the semantics; the
    // plate only lifts the chip off the page surface.
    final backgroundColor = tokens.colors.background.level02;
    final labelColor = tokens.colors.text.highEmphasis;
    final removeIconColor = tokens.colors.text.mediumEmphasis;

    final accessory = avatar != null
        ? SizedBox.square(
            dimension: IconSizes.xs + tokens.spacing.step1,
            child: ClipOval(child: avatar),
          )
        : leadingIcon != null
        ? Icon(
            leadingIcon,
            size: IconSizes.xs + tokens.spacing.step1,
            color: accentColor,
          )
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
            // The leading edge gets step2 + step1 (6px): the trailing ✕ is
            // a filled 20px glyph with generous internal margins, so a
            // bare step2 on the left reads tighter than the right.
            // step2 vertically (not step1): resolves the chip to the same
            // height as DesignSystemChipSize.compactPill, so the two chip
            // families in one wrap stop measuring differently.
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step2 + tokens.spacing.step1,
              tokens.spacing.step2,
              tokens.spacing.step2,
              tokens.spacing.step2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (accessory != null) ...[
                  accessory,
                  SizedBox(width: tokens.spacing.step2),
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
                SizedBox(width: tokens.spacing.step2),
                // The filled disc at 20 is a deliberate, separately-tested
                // decision (see active_filter_chip_test.dart): the remove
                // affordance must be unambiguous. It sits between icon-ramp
                // steps, so it stays an explicit constant here rather than
                // being snapped to a neighbouring tier that would weaken it.
                Icon(
                  LottiIcons.closeCircled,
                  size: 20,
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
