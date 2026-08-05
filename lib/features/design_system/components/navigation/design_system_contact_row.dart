import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// One glyph-only destination in a [DesignSystemContactRow].
///
/// [icon] is a widget rather than an `IconData` because the row mixes font
/// glyphs with bundled vector marks — a brand logo that no icon font ships
/// still belongs in the same row as the ones that do. The row supplies the
/// size and colour through an ambient [IconTheme], so a font glyph needs no
/// explicit styling; a vector asset reads the same theme to tint itself.
class DesignSystemContactAction {
  const DesignSystemContactAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconKey,
  });

  /// The glyph. Rendered inside the row's [IconTheme], centred in a tap
  /// target of [DesignSystemFiveSlotNavBar.minTapTarget].
  final Widget icon;

  /// Tooltip text and accessible name. A glyph-only control has no visible
  /// label, so this is the only thing a screen reader can announce.
  final String label;

  final VoidCallback onPressed;

  /// Optional key placed on the action's tap target, so tests and
  /// screenshot harnesses can address a specific glyph without depending on
  /// which icon font or asset backs it.
  final Key? iconKey;
}

/// The support footer: a labelled primary contact affordance on one side and
/// a set of glyph-only external destinations on the other, under a rule.
///
/// Both navigation surfaces host it — the desktop sidebar pins it beneath
/// Settings, the mobile More sheet closes with it — so the two never drift
/// apart in wording, order, or behaviour.
///
/// ## Layout
///
/// The label and the glyph group are laid out as two units in a [Wrap], not
/// as a [Row]. Where they both fit, the wrap's `spaceBetween` pushes them to
/// opposite edges and the section reads as one line. Where they do not — the
/// sidebar can be dragged down to `minSidebarWidth` (200), and a long
/// translation at a large text scale eats the rest — the glyph group drops to
/// its own line intact instead of the label being ellipsised down to nothing
/// or the glyphs overflowing. Splitting the group as a unit is the reason for
/// the wrap: individual glyphs wrapping would leave a ragged 2-then-1 stack.
///
/// **One line is the case that has to fit, not merely the lucky one**, and the
/// width for it is hard-won. The desktop rail is 256 px at its default and the
/// row needs 226 of them — 94 for the label, its leading glyph and the ink
/// inset around them, plus 132 for three
/// [DesignSystemFiveSlotNavBar.minTapTarget] glyphs. Two decisions bought that:
/// the glyphs take the navigation tap floor rather than
/// [TapTargets.minimum] (48 px targets overflowed by 18), and the sidebar
/// renders this band **full-bleed** rather than inside its 16 px gutters
/// (`DesktopNavigationSidebar.footerBand`), which is worth 32 px. Padded and at
/// 48 px it missed by 20; padded alone it still missed by 1.7. The remaining
/// ~30 px of slack is what a longer translation spends before wrapping.
class DesignSystemContactRow extends StatelessWidget {
  const DesignSystemContactRow({
    required this.label,
    required this.labelIcon,
    required this.onLabelPressed,
    required this.actions,
    this.labelKey,
    super.key,
  });

  /// The written affordance — "Contact Us" and its translations.
  final String label;

  /// Leading glyph on the written affordance. It is the only thing marking
  /// that row as a control while the pointer is elsewhere, since a caption-tier
  /// action carries neither fill nor border at rest.
  final IconData labelIcon;

  /// Invoked when the written affordance is activated.
  final VoidCallback onLabelPressed;

  /// The glyph-only destinations, rendered in order from the label outwards.
  final List<DesignSystemContactAction> actions;

  /// Optional key on the label's tap target, for the same reason as
  /// [DesignSystemContactAction.iconKey].
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The rule runs the full width it is given; only the content below it
        // is inset. On the desktop rail that is the point of the band — a
        // divider stopping short of both edges reads as a row that failed to
        // line up rather than as the foot of the panel.
        const DesignSystemDivider(),
        SizedBox(height: tokens.spacing.step2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: tokens.spacing.step2,
            children: [
              // `IntrinsicWidth` because `DesignSystemInlineAction` ends in an
              // `Align` that takes every pixel a bounded parent offers — which is
              // what lets its ink shrink-wrap inside a stretching column, but in
              // a `Wrap` would hand the label the whole run and push the glyphs
              // to a second line at every width.
              IntrinsicWidth(
                child: DesignSystemInlineAction(
                  key: labelKey,
                  onTap: onLabelPressed,
                  semanticsLabel: label,
                  label: label,
                  leadingIcon: labelIcon,
                ),
              ),
              IconTheme.merge(
                data: IconThemeData(
                  size: IconSizes.m,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      _ContactIconAction(action: action),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single glyph destination: compact glyph, tooltip doubling as the
/// accessible name, one explicit `Semantics(button:)` node over an excluded
/// visual subtree.
///
/// **Deliberately not `DesignSystemIconAction`, and not a candidate for being
/// folded into it.** That control pins its target to [TapTargets.minimum] and
/// documents the 48×48 result as a *layout* commitment belonging in card
/// headers and panel corners — it says in as many words not to put it in a
/// dense row. This footer is a dense row, in a rail whose usable width is 224
/// px: three of those targets plus a label do not fit, and the row would wrap
/// at the default sidebar width. It takes
/// [DesignSystemFiveSlotNavBar.minTapTarget] instead — the floor the rest of
/// this app's navigation chrome already uses, and still above the 44 px
/// platform guidance for touch.
///
/// The other divergence is the glyph itself: a `Widget` rather than an
/// `IconData`, so a bundled vector mark can sit beside font icons.
class _ContactIconAction extends StatelessWidget {
  const _ContactIconAction({required this.action});

  final DesignSystemContactAction action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      container: true,
      button: true,
      label: action.label,
      onTap: action.onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: action.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: action.iconKey,
              borderRadius: BorderRadius.circular(tokens.radii.smallChips),
              onTap: action.onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: DesignSystemFiveSlotNavBar.minTapTarget,
                  minHeight: DesignSystemFiveSlotNavBar.minTapTarget,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: action.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
