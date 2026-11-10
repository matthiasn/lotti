import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A list of rows on one rounded card: a `background.level02` fill at
/// `radii.l`, no border, and a [DesignSystemDivider] between each two rows.
///
/// The surface for a short list read as one thing rather than a stack of
/// boxed cards — the companion's lists of tasks and the day page's agenda
/// share it. The card is a [Material], so a row's ink paints on it, and it
/// clips its rows, so that ink and a full-bleed edge marker stop at the
/// rounded corners.
///
/// Each row travels with the divider above it under the row's own key (or
/// its index when it has none). Keyed rows therefore keep their state when a
/// row is inserted or removed above them, instead of each being rebuilt as
/// the row that now sits in its slot.
class DsRowsCard extends StatelessWidget {
  const DsRowsCard({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A Material, not a decorated box: ink from a row (a tap, an editable
    // title) paints on the card itself instead of on whatever lies behind
    // the opaque fill.
    return Material(
      color: tokens.colors.background.level02,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in rows.indexed)
            KeyedSubtree(
              key: ValueKey<Object>(row.key ?? index),
              // The same shape at every index, so a row that moves to the
              // top keeps its element rather than changing widget type.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (index > 0) const DesignSystemDivider(), row],
              ),
            ),
        ],
      ),
    );
  }
}
