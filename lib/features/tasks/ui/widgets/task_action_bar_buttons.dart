// The action bar's labelled triggers. Its Track time primary is the design
// system's `DesignSystemTimerPill`; the round affordances beside it use
// `DsGlassRoundButton` and the shared glass-chip styling from
// `glass_action_bar.dart`.
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:material_ui/material_ui.dart';

/// Labeled "Add" trigger for the action bar, on a tonal pill treatment.
///
/// The bare "+" circle was the page's most prominent creation control and
/// the one that broke the page's own glyph grammar: everywhere else "+"
/// means creates-in-place, while this one opens the Add sheet. A label
/// resolves the lie the way the sheet's own title does — trigger and
/// destination say the same word. The bar renders this pill wherever the
/// row has width for it and falls back to the bare circle only below the
/// narrow-width threshold.
class AddMenuPill extends StatelessWidget {
  const AddMenuPill({
    required this.label,
    required this.onPressed,
    this.icon = LottiIcons.add,
    this.tooltip,
    super.key,
  });

  /// Leading glyph. The full-sheet "Add" wears the plus; the first-run
  /// "Attach" wears the paperclip, because on this page "+" is the
  /// commits-immediately glyph and this trigger opens a sheet.
  final IconData icon;
  final String label;

  /// Optional long-form scent: names what the sheet actually holds, so a
  /// pointer hover (or assistive tech) can route between the card and the
  /// sheet BEFORE the tap. The visible label stays the one word the sheet
  /// titles itself with.
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    // Tonal surface fill, quiet border, neutral high-emphasis ink: the bar
    // keeps a single accent budget, spent on the Track time primary.
    final style = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    final pill = Semantics(
      button: true,
      label: tooltip ?? label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Container(
            height: TaskActionBar.buttonSize,
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            decoration: BoxDecoration(
              color: tokens.colors.surface.enabled,
              borderRadius: radius,
              border: Border.all(color: tokens.colors.decorative.level02),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: TaskActionBar.iconSize,
                  color: tokens.colors.text.highEmphasis,
                ),
                SizedBox(width: spacing.step2),
                Text(label, style: style),
                SizedBox(width: spacing.step2),
                // The opens-further-UI marker, in the exact caret grammar
                // the Open/Medium chips use for "tap reveals options". The
                // page teaches that a plain glyph+word commits immediately;
                // this trigger opens a sheet and must say so from the
                // pixels — the tooltip never surfaces on touch.
                Icon(
                  LottiIcons.expand,
                  size: TaskActionBar.iconSize,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return pill;
    // The Semantics above already carries the long label; without the
    // exclusion the tooltip would announce it a second time.
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: pill,
    );
  }
}
