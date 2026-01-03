import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_filter_tabs.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/progress_indicator.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Header for a checklist card.
///
/// Layout varies based on state:
/// - **Expanded**: Title row with chevron/menu, then progress/filters row
/// - **Collapsed**: Single row with title, progress, chevron, menu
/// - **Sorting**: Single row with drag handle, title, progress
class ChecklistCardHeader extends StatelessWidget {
  const ChecklistCardHeader({
    required this.title,
    required this.isExpanded,
    required this.isSortingMode,
    required this.isEditingTitle,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.filter,
    required this.onToggleExpand,
    required this.onTitleTap,
    required this.onTitleSave,
    required this.onTitleCancel,
    required this.onFilterChanged,
    this.reorderIndex,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
    super.key,
  });

  final String title;
  final bool isExpanded;
  final bool isSortingMode;
  final bool isEditingTitle;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final ChecklistFilter filter;
  final int? reorderIndex;
  final VoidCallback onToggleExpand;
  final VoidCallback onTitleTap;
  final StringCallback onTitleSave;
  final VoidCallback onTitleCancel;
  final ValueChanged<ChecklistFilter> onFilterChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;

  @override
  Widget build(BuildContext context) {
    if (isSortingMode) {
      return _SortingModeHeader(
        title: title,
        completedCount: completedCount,
        totalCount: totalCount,
        completionRate: completionRate,
        reorderIndex: reorderIndex,
      );
    }

    return _UnifiedHeader(
      title: title,
      isExpanded: isExpanded,
      isEditingTitle: isEditingTitle,
      completedCount: completedCount,
      totalCount: totalCount,
      completionRate: completionRate,
      filter: filter,
      onToggleExpand: onToggleExpand,
      onTitleTap: onTitleTap,
      onTitleSave: onTitleSave,
      onTitleCancel: onTitleCancel,
      onFilterChanged: onFilterChanged,
      onDelete: onDelete,
      onExportMarkdown: onExportMarkdown,
      onShareMarkdown: onShareMarkdown,
    );
  }
}

/// Unified header that animates smoothly between expanded and collapsed states.
/// This keeps the chevron as the same widget instance so its rotation animates.
class _UnifiedHeader extends StatelessWidget {
  const _UnifiedHeader({
    required this.title,
    required this.isExpanded,
    required this.isEditingTitle,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.filter,
    required this.onToggleExpand,
    required this.onTitleTap,
    required this.onTitleSave,
    required this.onTitleCancel,
    required this.onFilterChanged,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
  });

  final String title;
  final bool isExpanded;
  final bool isEditingTitle;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final ChecklistFilter filter;
  final VoidCallback onToggleExpand;
  final VoidCallback onTitleTap;
  final StringCallback onTitleSave;
  final VoidCallback onTitleCancel;
  final ValueChanged<ChecklistFilter> onFilterChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Title, Chevron, Menu (always present)
        // Use GestureDetector instead of InkWell to avoid hover effects
        GestureDetector(
          onTap: isExpanded ? null : onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.cardPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  // Title (editable in expanded mode, plain text in collapsed)
                  Expanded(
                    child: isExpanded && !isEditingTitle
                        ? GestureDetector(
                            onTap: onTitleTap,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.text,
                              child: _TitleText(title: title),
                            ),
                          )
                        : isExpanded && isEditingTitle
                            ? TitleTextField(
                                initialValue: title,
                                onSave: onTitleSave,
                                resetToInitialValue: true,
                                onCancel: onTitleCancel,
                              )
                            : _TitleText(title: title),
                  ),
                  // Progress (visible in collapsed mode, hidden in expanded unless total > 0)
                  if (!isExpanded || totalCount == 0)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: !isExpanded ? 1.0 : 0.0,
                      child: _ProgressIndicatorRow(
                        completedCount: completedCount,
                        totalCount: totalCount,
                        completionRate: completionRate,
                        alwaysShow: true,
                      ),
                    ),
                  const SizedBox(width: 10),
                  // Chevron (same widget instance, animates rotation)
                  _Chevron(
                    isExpanded: isExpanded,
                    onToggleExpand: onToggleExpand,
                  ),
                  // Menu
                  _HeaderMenu(
                    onDelete: onDelete,
                    onExportMarkdown: onExportMarkdown,
                    onShareMarkdown: onShareMarkdown,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Divider 1: Between title row and progress/filters row
        // Only show when expanded AND has items (no divider for empty checklist)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
          crossFadeState: isExpanded && totalCount > 0
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        // Row 2: Progress + Filters (only when expanded AND has items)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
          crossFadeState: isExpanded && totalCount > 0
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.cardPadding,
              right: AppTheme.cardPadding,
              top: 12,
              bottom: 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Progress indicator - align text baseline with filter tabs
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ProgressIndicatorRow(
                    completedCount: completedCount,
                    totalCount: totalCount,
                    completionRate: completionRate,
                    alwaysShow: false,
                  ),
                ),
                const Spacer(),
                // Filter tabs
                ChecklistFilterTabs(
                  filter: filter,
                  onFilterChanged: onFilterChanged,
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        // Divider 2: Between progress/filters row and body
        // Only show when expanded AND has items
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
          crossFadeState: isExpanded && totalCount > 0
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Divider(
            height: 1,
            thickness: 1,
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Sorting mode header: `DragHandle` `Title` `Progress`
class _SortingModeHeader extends StatelessWidget {
  const _SortingModeHeader({
    required this.title,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    this.reorderIndex,
  });

  final String title;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final dragHandleIcon = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(
        Icons.drag_indicator,
        size: 28,
        color: context.colorScheme.outline.withValues(alpha: 0.7),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: AppTheme.cardPadding,
      ),
      child: Row(
        children: [
          // Large drag handle for sorting - wrapped in ReorderableDragStartListener
          if (reorderIndex != null)
            ReorderableDragStartListener(
              index: reorderIndex!,
              child: dragHandleIcon,
            )
          else
            dragHandleIcon,
          // Title
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Progress (always visible in collapsed/sorting)
          _ProgressIndicatorRow(
            completedCount: completedCount,
            totalCount: totalCount,
            completionRate: completionRate,
            alwaysShow: true,
          ),
        ],
      ),
    );
  }
}

/// Title text widget.
class _TitleText extends StatelessWidget {
  const _TitleText({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Chevron icon with rotation animation.
class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.isExpanded,
    required this.onToggleExpand,
  });

  final bool isExpanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: isExpanded ? 0.0 : -0.25,
      duration: checklistChevronRotationDuration,
      child: IconButton(
        onPressed: onToggleExpand,
        icon: Icon(
          Icons.expand_more,
          size: 22,
          color: context.colorScheme.outline,
        ),
        tooltip: isExpanded ? 'Collapse' : 'Expand',
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// Progress indicator row showing ring and completion text.
class _ProgressIndicatorRow extends StatelessWidget {
  const _ProgressIndicatorRow({
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.alwaysShow,
  });

  final int completedCount;
  final int totalCount;
  final double completionRate;
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    // In expanded mode, hide when total = 0
    // In collapsed/sorting mode, always show
    if (!alwaysShow && totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChecklistProgressIndicator(completionRate: completionRate),
        const SizedBox(width: 8),
        Text(
          context.messages.checklistCompletedShort(completedCount, totalCount),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// Header menu with export, share, and delete options.
class _HeaderMenu extends StatelessWidget {
  const _HeaderMenu({
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: context.colorScheme.surfaceContainerHighest,
          elevation: 8,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'More',
        position: PopupMenuPosition.under,
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
        onSelected: (value) async {
          Future<void> deleteAction() async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(context.messages.checklistDelete),
                  content: Text(context.messages.checklistItemDeleteWarning),
                  actions: [
                    LottiTertiaryButton(
                      label: context.messages.checklistItemDeleteCancel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    LottiTertiaryButton(
                      label: context.messages.checklistItemDeleteConfirm,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
              },
            );
            if (result ?? false) {
              onDelete?.call();
            }
          }

          final actions = <String, Future<void> Function()>{
            'export': () async => onExportMarkdown?.call(),
            'share': () async => onShareMarkdown?.call(),
            'delete': deleteAction,
          };
          await actions[value]?.call();
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          if (onExportMarkdown != null)
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(MdiIcons.exportVariant, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.messages.checklistExportAsMarkdown,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          if (onShareMarkdown != null)
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.ios_share, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Share',
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.messages.checklistDelete,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
