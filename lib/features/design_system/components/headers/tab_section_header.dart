import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';

/// Compact header used by the Tasks and Projects tabs: a title row (with an
/// optional trailing widget like a notification bell) and a search row with
/// an optional trailing filter button.
///
/// The two rows are wrapped in [ProjectsOverviewContentWidth] so they align
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
    this.titleTrailing,
    this.titleSuffix,
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

  /// Optional inline suffix rendered after [title] — used by Tasks to show
  /// "Tasks · {savedFilterName}" when a saved filter is active.
  final Widget? titleSuffix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final topPadding = isCompact
        ? tokens.spacing.step5 + tokens.spacing.step2
        : tokens.spacing.step3;
    final highText = tokens.colors.text.highEmphasis;
    final accent = tokens.colors.interactive.enabled;

    final effectiveTitleTrailing =
        titleTrailing ??
        Icon(
          Icons.notifications_none_rounded,
          size: 34,
          color: highText,
        );

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProjectsOverviewContentWidth(
            child: Row(
              children: [
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
                effectiveTitleTrailing,
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          ProjectsOverviewContentWidth(
            child: Row(
              children: [
                Expanded(
                  child: DesignSystemSearch(
                    hintText: searchHint,
                    size: DesignSystemSearchSize.small,
                    initialText: query,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                    onSearchPressed: onSearchPressed,
                  ),
                ),
                SizedBox(width: tokens.spacing.step4),
                IconButton(
                  tooltip: filterTooltip,
                  onPressed: onFilterPressed,
                  icon: Icon(
                    Icons.filter_list_rounded,
                    size: 24,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
        ],
      ),
    );
  }
}
