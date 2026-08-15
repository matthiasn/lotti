import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/notifications/ui/widgets/notification_bell.dart';

/// The shared header action button used by tab headers (and their collapsed
/// compact bars): an [IconButton] that carries the design-system "activated"
/// treatment — accent glyph over [DesignSystemListPalette.activatedFill] —
/// while [active] narrows the list.
///
/// One component instead of per-surface copies, so the expanded header and the
/// compact bar can never drift apart in how they announce an active filter.
class TabHeaderIconButton extends StatelessWidget {
  const TabHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Whether the control's concern is actively narrowing the list.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final glyph = Icon(
      icon,
      // The control-glyph tier. Both former call sites hardcoded 20, which is
      // off the ramp entirely; `m` is the role these buttons actually play.
      size: IconSizes.m,
      color: active
          ? tokens.colors.interactive.enabled
          : tokens.colors.text.mediumEmphasis,
    );

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: active
          ? IconButton.styleFrom(
              backgroundColor: DesignSystemListPalette.activatedFill(tokens),
            )
          : null,
      icon: glyph,
    );
  }
}

/// Compact header used by the Tasks and Projects tabs: a title row (with
/// optional leading and trailing controls) and a search row with an optional
/// trailing filter button.
///
/// The two rows are wrapped in [DetailContentWidth] so they align
/// with the list content below — any full-bleed element (divider, chip row,
/// etc.) is expected to be rendered outside this widget so it can span the
/// full pane width.
class TabSectionHeader extends StatelessWidget {
  const TabSectionHeader({
    required this.title,
    required this.query,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onSearchPressed,
    required this.onFilterPressed,
    required this.filterTooltip,
    this.filtersActive = false,
    this.titleLeading,
    this.titleTrailing,
    this.titleSuffix,
    this.searchFocusNode,
    super.key,
  });

  final String title;
  final String query;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onSearchPressed;
  final VoidCallback onFilterPressed;
  final String filterTooltip;
  final Widget? titleTrailing;
  final Widget? titleLeading;
  final FocusNode? searchFocusNode;

  /// Optional inline suffix rendered after [title] — used by Tasks to show
  /// "Tasks · {savedFilterName}" when a saved filter is active.
  final Widget? titleSuffix;

  /// Whether any list filter is currently narrowing the results.
  ///
  /// Drives the filter affordance: neutral at rest, accent with a tonal fill
  /// while active — so an invisibly filtered list can't masquerade as the
  /// full feed. Accent is reserved for state, not decoration.
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final topPadding = isCompact
        ? tokens.spacing.step5 + tokens.spacing.step2
        : tokens.spacing.step3;
    final highText = tokens.colors.text.highEmphasis;

    final effectiveTitleTrailing = titleTrailing ?? const NotificationBell();

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailContentWidth(
            child: Row(
              children: [
                if (titleLeading != null) ...[
                  SizedBox.square(
                    dimension: TapTargets.minimum,
                    child: Center(child: titleLeading),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                ],
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.heading.heading3
                              .copyWith(color: highText),
                        ),
                      ),
                      if (titleSuffix != null) ...[
                        SizedBox(width: tokens.spacing.step3),
                        Flexible(child: titleSuffix!),
                      ],
                    ],
                  ),
                ),
                // Both header rows terminate in the SAME square slot, so the
                // bell and the funnel share one optical right edge instead of
                // ending at whatever inset each control's own padding
                // happens to produce.
                SizedBox.square(
                  dimension: TapTargets.minimum,
                  child: Center(child: effectiveTitleTrailing),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          DetailContentWidth(
            child: Row(
              children: [
                Expanded(
                  child: DesignSystemSearch(
                    focusNode: searchFocusNode,
                    hintText: searchHint,
                    size: DesignSystemSearchSize.small,
                    initialText: query,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                    onSearchPressed: onSearchPressed,
                  ),
                ),
                SizedBox(width: tokens.spacing.step4),
                SizedBox.square(
                  dimension: TapTargets.minimum,
                  child: Center(
                    child: TabHeaderIconButton(
                      icon: Icons.filter_list_rounded,
                      tooltip: filterTooltip,
                      onPressed: onFilterPressed,
                      active: filtersActive,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
      ),
    );
  }
}
