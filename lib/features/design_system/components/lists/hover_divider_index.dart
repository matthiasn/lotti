import 'package:flutter/material.dart';

/// The divider state a list shell hands to one row.
///
/// Bundles the three values that always travel together from a
/// [HoverDividerIndex] owner to a row's `DesignSystemListItem`. Lists whose
/// rows are built by a caller-supplied builder (`DefinitionsListPage`) pass
/// this instead of three separate parameters, so the builder signature stays
/// stable as the treatment grows and a page cannot declare a parameter it
/// then forgets to use.
///
/// Forwarding is still per-field — `DesignSystemListItem` takes the three
/// separately, as the lists that own their own row loop (Config Flags,
/// Maintenance, Matrix sync) pass them. Each page's test covers that its row
/// forwards all three.
@immutable
class ListRowDivider {
  const ListRowDivider({
    required this.showDivider,
    required this.color,
    required this.onHoverChanged,
  });

  /// Whether the row draws a hairline beneath it — false for the last row
  /// of a card. Stays stable across hover; see [HoverDividerIndex].
  final bool showDivider;

  /// [Colors.transparent] while this hairline brackets the hovered row,
  /// `null` to keep the row's own design-system default.
  final Color? color;

  /// The row reports pointer enter/leave here.
  final ValueChanged<bool> onHoverChanged;
}

/// Coordinates hover-driven divider fading across a vertical run of
/// `DesignSystemListItem`s (or any list of rows that expose `onHoverChanged`
/// and a `dividerColor`).
///
/// Mix this into the `State` of a widget that lays out indexed rows. Track
/// each row's hover with [onRowHoverChanged] and colour each row's divider
/// with [hoverDividerColorFor]. The hovered row's bracketing hairlines (the
/// divider beneath it and the divider beneath the row above it) both fade to
/// [Colors.transparent], so the hovered row is never bisected by a hairline.
///
/// Crucially the caller keeps `showDivider` stable and only swaps the
/// colour, so hovering never adds/removes a 1&nbsp;px divider and the layout
/// never shifts.
///
/// Consumers: the Config Flags list (`_FlagsList`), the Advanced →
/// Maintenance list (`MaintenanceBody`), the Matrix sync maintenance list
/// (`MatrixSyncMaintenanceBody`), and `DefinitionsListPage` — which owns
/// the index on behalf of every settings definition list (categories,
/// labels, habits, measurables, dashboards) and hands each row a
/// [ListRowDivider] through `itemBuilder`, built by [dividerFor].
///
/// Only rows that report hover can drive this: `DesignSystemListItem`
/// fires `onHoverChanged` only when it has an `onTap`. A list of
/// non-tappable rows (the Logging settings switches, say) has no hover
/// state to bracket in the first place, so it needs no fading.
mixin HoverDividerIndex<T extends StatefulWidget> on State<T> {
  /// Index of the currently-hovered row, or `null` when no row is hovered.
  int? _hoveredIndex;

  /// The divider beneath [index] fades whenever either that row or the row
  /// below it (`index + 1`) is hovered, so both hairlines bracketing a
  /// hovered row disappear. Returns `null` to keep the caller's default
  /// divider colour when neither side is hovered.
  Color? hoverDividerColorFor(int index) =>
      (_hoveredIndex == index || _hoveredIndex == index + 1)
      ? Colors.transparent
      : null;

  /// Bundles the divider state for the row at [index] into a single
  /// [ListRowDivider], for shells that hand rows to a caller-supplied
  /// builder. [showDivider] is the caller's own last-row decision — the
  /// mixin only colours the hairline, it never decides whether one exists.
  ListRowDivider dividerFor(int index, {required bool showDivider}) =>
      ListRowDivider(
        showDivider: showDivider,
        color: hoverDividerColorFor(index),
        onHoverChanged: (hovered) => onRowHoverChanged(index, hovered: hovered),
      );

  /// Records pointer enter/leave for the row at [index]. Retargets rather
  /// than accumulates: entering a row overrides the previous one, and a
  /// leave only clears state when it matches the currently-hovered row. That
  /// makes it order-independent across a row-to-row move — whether the enter
  /// or the leave fires first, the state settles on the newly entered row.
  void onRowHoverChanged(int index, {required bool hovered}) {
    // A MouseRegion/InkWell can dispatch a hover-exit callback while the
    // row is being torn down (e.g. during a settings route transition),
    // so guard against `setState()` after dispose.
    if (!mounted) return;
    setState(() {
      if (hovered) {
        _hoveredIndex = index;
      } else if (_hoveredIndex == index) {
        _hoveredIndex = null;
      }
    });
  }
}
