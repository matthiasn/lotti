import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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

/// The support footer: one right-aligned group of glyph-only destinations.
///
/// Both navigation surfaces host it — the desktop sidebar pins it beneath
/// Settings, the mobile More sheet closes with it — so the two never drift
/// apart in wording, order, or behaviour.
///
/// **There is deliberately no rule above the group.** These are the quietest
/// controls either surface has, and a divider gave them the weight of a
/// section boundary — announcing a separation between Settings and four
/// external links that neither surface actually has. Distance carries it
/// instead.
///
/// Every destination, including email, uses the same compact navigation target
/// and ambient [IconTheme]. Keeping all four in one [Row] makes their spacing
/// uniform and lets one trailing [Align] move the group as a unit. At the
/// sidebar's 200 px minimum, four 44 px targets still fit inside the band's
/// token inset without wrapping or overflow.
class DesignSystemContactRow extends StatelessWidget {
  const DesignSystemContactRow({
    required this.actions,
    super.key,
  });

  /// The glyph-only destinations, rendered in the order supplied.
  final List<DesignSystemContactAction> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      // The horizontal inset is `step3` rather than the rail's `step5` gutter
      // for a measured reason: four 44 px targets need 176 px, and the 200 px
      // minimum sidebar leaves only 168 px inside a `step5` gutter. The group
      // would wrap. The leading gap replaces the rule that used to sit here —
      // it is the whole separation now, so it is the band's own spacing rather
      // than something the host happens to supply.
      padding: EdgeInsets.only(
        left: tokens.spacing.step3,
        right: tokens.spacing.step3,
        top: tokens.spacing.step2,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        // Shrink-wraps vertically. Without this the band takes every pixel the
        // host offers, which on the desktop rail means swallowing the space
        // above Settings rather than sitting at the foot of it.
        heightFactor: 1,
        child: IconTheme.merge(
          data: IconThemeData(
            size: IconSizes.m,
            color: tokens.colors.text.mediumEmphasis,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions) _ContactIconAction(action: action),
            ],
          ),
        ),
      ),
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
/// dense row. This footer is a dense row, in a rail whose usable width is 184
/// px at its minimum: four of those targets would not fit. It takes
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
