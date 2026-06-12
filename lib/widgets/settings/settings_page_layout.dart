import 'package:flutter/material.dart';
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';

/// Shared layout rules for the settings definition pages (lists and
/// detail forms), so search fields, grouped lists, form sections, and the
/// sticky action bar all align with the `SettingsPageHeader` title at every
/// pane width.
///
/// The header computes a responsive horizontal padding from the pane width
/// ([SettingsHeaderDimensions.horizontalPadding]); content below historically
/// used assorted fixed paddings (16/20px) and drifted out of alignment on
/// wide panes. These helpers re-anchor everything on the header's grid.
abstract final class SettingsPageLayout {
  /// Upper bound for form/list content width. Wide desktop panes keep the
  /// content column anchored to the header's left padding instead of
  /// stretching fields into kilometer-wide slabs; the right side pads out
  /// with whitespace. Chosen to comfortably fit two-column form rows while
  /// staying scannable — same spirit as the day-planning bar's 560 action
  /// cap, but wider because settings forms host full-width inputs.
  static const double maxContentWidth = 840;

  /// Resolved horizontal insets for content at the given pane [width]:
  /// the start inset always matches the header title's padding; the end
  /// inset grows once the remaining span would exceed [maxContentWidth].
  static EdgeInsetsDirectional contentInsets(double width) {
    final start = SettingsHeaderDimensions.horizontalPadding(width);
    final available = width - start * 2;
    final end = available > maxContentWidth
        ? width - start - maxContentWidth
        : start;
    return EdgeInsetsDirectional.only(start: start, end: end);
  }
}

/// Applies [SettingsPageLayout.contentInsets] to a sliver, measuring the
/// actual pane width via [SliverLayoutBuilder] (not the screen width, which
/// would be wrong inside the desktop split pane).
class SettingsContentSliver extends StatelessWidget {
  const SettingsContentSliver({required this.sliver, super.key});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final insets = SettingsPageLayout.contentInsets(
          constraints.crossAxisExtent,
        );
        return SliverPadding(
          padding: EdgeInsetsDirectional.only(
            start: insets.start,
            end: insets.end,
          ),
          sliver: sliver,
        );
      },
    );
  }
}

/// Box-world counterpart of [SettingsContentSliver] — used by the sticky
/// glass action bar so its buttons share the content column's edges.
class SettingsContentArea extends StatelessWidget {
  const SettingsContentArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = SettingsPageLayout.contentInsets(constraints.maxWidth);
        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: insets.start,
            end: insets.end,
          ),
          child: child,
        );
      },
    );
  }
}
