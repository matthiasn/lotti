import 'package:flutter/material.dart';

/// Tells a grouped-list child which of the group's rounded corners it owns.
///
/// A grouped-list container (e.g. `DesignSystemGroupedList`) clips its
/// children with the group's corner radius, so a child that paints a
/// full-bleed decoration of its own (for example the keyboard-focus border
/// on a list item) would get cropped into the rounded corners. The container
/// wraps its first and last child in this scope so such decorations can
/// round themselves to match the clip.
class DesignSystemGroupedListCorners extends InheritedWidget {
  const DesignSystemGroupedListCorners({
    required this.borderRadius,
    required super.child,
    super.key,
  });

  /// The subset of the group's corner radius covering this child.
  final BorderRadius borderRadius;

  static BorderRadius? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesignSystemGroupedListCorners>()
      ?.borderRadius;

  @override
  bool updateShouldNotify(DesignSystemGroupedListCorners oldWidget) =>
      borderRadius != oldWidget.borderRadius;
}
