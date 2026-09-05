import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A single-select row of pill chips (design plan §0.2 / §6 — kill the
/// default `ChoiceChip` wrap grid; one horizontal row, scroll if needed,
/// selected = `surface.active` + teal text).
///
/// The row never wraps into a ragged grid. When the chips would overflow
/// the available width it scrolls horizontally instead, so the choices
/// stay on one line and the selection affordance stays consistent.
class DsChoicePills<T> extends StatelessWidget {
  const DsChoicePills({
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
    this.leading,
    super.key,
  });

  /// The currently selected value, or `null` when nothing is selected.
  final T? value;

  /// The full set of choices, in display order.
  final List<T> values;

  /// The localized label for a choice.
  final String Function(T value) labelFor;

  /// Called when the user taps a choice with that choice. Single-select: the
  /// already-selected choice is a no-op (a cadence or interaction type is
  /// always set, never cleared from here).
  final ValueChanged<T> onSelected;

  /// Optional leading widget rendered before the chips (e.g. a section
  /// label that should travel with the row when it scrolls).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.step2;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: gap)],
          for (var i = 0; i < values.length; i++) ...[
            if (i != 0) SizedBox(width: gap),
            DsPill(
              variant: DsPillVariant.filled,
              label: labelFor(values[i]),
              selected: values[i] == value,
              onTap: () => onSelected(values[i]),
            ),
          ],
        ],
      ),
    );
  }
}
