import 'package:flutter/material.dart';

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
/// never shifts. Shared by the Config Flags list (`_FlagsList`) and the
/// Advanced → Maintenance list (`MaintenanceBody`).
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
