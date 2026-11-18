import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The one surface onboarding offers a choice on — a chip, a provider card:
/// quiet and outlined on the panel's own surface, the [selected] one marked
/// by the accent on its outline and a check at its end. Never a solid fill,
/// which is the main button's alone, and never colour alone.
///
/// [child] is what the surface holds; [trailing], when the surface is not a
/// choice but an action, takes the check's place. With [selected] null it
/// is such an action; with [onTap] null as well, it only shows what was
/// chosen elsewhere.
class OnboardingSelectableSurface extends StatelessWidget {
  const OnboardingSelectableSurface({
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
    this.trailing,
    this.padding,
    this.focused = false,
    super.key,
  });

  /// What a screen reader says it is.
  final String label;

  /// Null where the surface only shows a choice made elsewhere.
  final VoidCallback? onTap;
  final Widget child;

  /// Whether it is the chosen one; null for an action rather than a choice.
  final bool? selected;

  /// Ends an action surface, in place of a choice's check.
  final IconData? trailing;

  /// Its inside padding; defaults to the chip's.
  final EdgeInsetsGeometry? padding;

  /// Draws the accent outline for keyboard focus, as the chosen one has.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final chosen = selected ?? false;
    final accent = tokens.colors.interactive.enabled;
    final radius = BorderRadius.circular(tokens.radii.m);
    final end = chosen ? LottiIcons.confirm : trailing;

    // A choice is read as its label alone. A surface that only shows
    // something keeps what it holds readable — the key step's card carries
    // the state of the connection, a rejection included.
    final display = onTap == null;
    return Semantics(
      container: true,
      button: !display,
      selected: selected,
      label: display ? null : label,
      onTap: onTap,
      child: ExcludeSemantics(
        excluding: !display,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            canRequestFocus: onTap != null,
            borderRadius: radius,
            focusColor: tokens.colors.surface.focusPressed,
            hoverColor: tokens.colors.surface.hover,
            child: Ink(
              decoration: BoxDecoration(
                color: tokens.colors.background.level01,
                borderRadius: radius,
                // One width chosen or not, so choosing moves nothing.
                border: Border.all(
                  color: chosen || focused
                      ? accent
                      : tokens.colors.decorative.level03,
                  width: spacing.step1,
                ),
              ),
              child: Padding(
                padding:
                    padding ??
                    EdgeInsets.symmetric(
                      horizontal: spacing.step4,
                      vertical: spacing.step3,
                    ),
                child: Row(
                  children: [
                    Expanded(child: child),
                    // The end keeps its room when empty, so choosing never
                    // rewraps the label.
                    SizedBox(width: spacing.step3),
                    SizedBox.square(
                      dimension: spacing.step5,
                      child: end == null
                          ? null
                          : Icon(
                              end,
                              size: spacing.step5,
                              color: chosen
                                  ? accent
                                  : tokens.colors.text.mediumEmphasis,
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
  }
}

/// The one chip onboarding offers a choice or a shortcut on: an area to
/// pick, the area a task lands in, a starter suggestion, "Add your own" — an
/// [OnboardingSelectableSurface] holding a label, led by an [icon].
///
/// [dense] is the pill that sits in a wrap and hugs its label; otherwise it
/// fills its cell. Only the padding and the width differ: the label, the
/// corners and the outline are one.
class OnboardingChoiceChip extends StatelessWidget {
  const OnboardingChoiceChip({
    required this.label,
    required this.onTap,
    this.selected,
    this.icon,
    this.trailing,
    this.dense = false,
    this.wrapLabel = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  /// Whether the chip is the chosen one; null for a chip that is an action
  /// rather than a choice.
  final bool? selected;

  /// Leads the label.
  final IconData? icon;

  /// Ends an action chip: where a tap takes the user.
  final IconData? trailing;

  /// The pill of a wrap rather than the chip of a grid.
  final bool dense;

  /// Lets a long label wrap instead of ending in an ellipsis: for a chip
  /// that has the row to itself.
  final bool wrapLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final text = Text(
      label,
      overflow: wrapLabel ? null : TextOverflow.ellipsis,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    final surface = OnboardingSelectableSurface(
      label: label,
      onTap: onTap,
      selected: selected,
      trailing: trailing,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.step4,
        vertical: dense ? spacing.step3 : spacing.step4,
      ),
      child: Row(
        children: [
          if (icon case final icon?) ...[
            Icon(
              icon,
              size: spacing.step5,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(width: spacing.step3),
          ],
          Flexible(child: text),
        ],
      ),
    );
    // A pill is as wide as its label; a grid chip fills its cell.
    return dense ? IntrinsicWidth(child: surface) : surface;
  }
}
