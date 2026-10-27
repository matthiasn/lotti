import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The banner's secondary controls — Rate and Snooze — in one quiet voice,
/// so the accent-washed CTA pill stays the only filled, pressable-looking
/// element on the surface (design handover 1a).
///
/// Both are the same component: the [DesignSystemButtonVariant.quiet]
/// caption-tier [DesignSystemButton] with a leading glyph, in the neutral
/// medium-emphasis ink, on the [TapTargets.minimum] floor — a dismissal and
/// a verdict beside a primary, neither of which may out-shout it. Rate is
/// labelled for the same reason Snooze is: a lone glyph reads as a state,
/// not an action, and on touch there is no hover to explain it. Snooze ends
/// its label on the host's trailing edge, where the row's other trailing
/// content ends. Shared by the goal banner card and the dock, at every
/// width.
///
/// On a [compact] host above [TextScales.large] the pair is its glyphs
/// alone, each a [DesignSystemIconAction] carrying its label as tooltip and
/// semantics: two scaled labels beside the persona chip no longer fit a
/// phone's caption row, and an overflowing row serves a large-text user
/// worse than a glyph whose name a screen reader still announces. A wide
/// host keeps the labels at every scale — it has the room, and a large-text
/// reader is exactly who needs the word.
///
/// Rate shows only while [ratingDue], but keeps its footprint while hidden,
/// so nothing to its right moves when it appears or goes: the card's header
/// never reflows after a rating, and the dock's CTA pill holds one position
/// across tenants whether or not each has been rated.
class NudgeBannerQuietActions extends StatelessWidget {
  const NudgeBannerQuietActions({
    required this.ratingDue,
    required this.onRate,
    required this.onSnooze,
    this.compact = false,
    this.snoozeKey,
    super.key,
  });

  /// Whether this activation still awaits its one rating.
  final bool ratingDue;

  final VoidCallback onRate;
  final VoidCallback onSnooze;

  /// A narrow host (phone width): the pair falls back to glyphs above the
  /// large text scale instead of overflowing its row.
  final bool compact;

  /// Identifies the Snooze control for callers that locate it.
  final Key? snoozeKey;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final glyphsOnly =
        compact && MediaQuery.textScalerOf(context).scale(1) > TextScales.large;

    final rate = glyphsOnly
        ? DesignSystemIconAction(
            icon: LottiIcons.star,
            tooltip: messages.nudgeBannerRateTooltip,
            onPressed: onRate,
          )
        : Tooltip(
            message: messages.nudgeBannerRateTooltip,
            child: DesignSystemButton(
              label: messages.nudgeBannerRateLabel,
              leadingIcon: LottiIcons.star,
              variant: DesignSystemButtonVariant.quiet,
              size: DesignSystemButtonSize.dense,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: onRate,
            ),
          );
    final snooze = glyphsOnly
        ? DesignSystemIconAction(
            key: snoozeKey,
            icon: LottiIcons.snooze,
            tooltip: messages.nudgeBannerSnoozeLabel,
            onPressed: onSnooze,
          )
        : DesignSystemButton(
            key: snoozeKey,
            label: messages.nudgeBannerSnoozeLabel,
            leadingIcon: LottiIcons.snooze,
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.dense,
            tapTargetSize: MaterialTapTargetSize.padded,
            alignsLabelToTrailingEdge: true,
            onPressed: onSnooze,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(
          visible: ratingDue,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: rate,
        ),
        snooze,
      ],
    );
  }
}
