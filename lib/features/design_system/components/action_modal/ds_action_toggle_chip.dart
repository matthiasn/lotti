import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A two-state pill for a boolean the modal owns — starred, private, flagged.
///
/// These are *states*, not actions: rendering them as menu rows made the
/// `•••` sheet claim three tappable verbs whose titles never changed and
/// whose current value was legible only from an icon's fill. As chips they
/// read at a glance and toggle in place, so the sheet stays open while the
/// user sets more than one.
///
/// Off is an outline on nothing — `decorative.level01` border, medium-emphasis
/// ink. On is the interactive hue: a `surface.selected` fill, a teal border,
/// teal ink and (where the icon set has one) a filled glyph. Both transitions
/// run on [MotionDurations.short2] / [MotionCurves.standard], the same 100 ms
/// state change as the rows beneath.
class DsActionToggleChip extends StatelessWidget {
  const DsActionToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final String label;

  /// The glyph for the *current* state. Callers pass the filled variant when
  /// [selected] and the outlined one otherwise, so fill and tint say the same
  /// thing.
  final IconData icon;

  final bool selected;
  final VoidCallback onToggle;

  /// Border alpha of the selected chip. The fill alone (16 % teal on a
  /// near-black sheet) left the pill's edge invisible, so an on-chip read as
  /// a soft smudge rather than a pressed control.
  static const double selectedBorderAlpha = 0.4;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final foreground = selected ? accent : tokens.colors.text.mediumEmphasis;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);

    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      // The tap action has to be republished here: `excludeSemantics` drops
      // the InkWell's node, and with it the activation a screen reader needs.
      // Without this the chip announces as a toggled button that cannot be
      // toggled.
      onTap: onToggle,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: MotionDurations.short2,
            curve: MotionCurves.standard,
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
            // step3 top and bottom around a 20pt line box: the 36pt pill the
            // design calls for, expressed as its parts rather than pinned to
            // a magic height that would not survive a text-scale bump.
            constraints: BoxConstraints(
              minHeight:
                  tokens.typography.lineHeight.bodySmall +
                  tokens.spacing.step3 * 2,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.colors.surface.selected
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: selectedBorderAlpha)
                    : tokens.colors.decorative.level01,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: IconSizes.s, color: foreground),
                SizedBox(width: tokens.spacing.step3),
                Text(
                  label,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
