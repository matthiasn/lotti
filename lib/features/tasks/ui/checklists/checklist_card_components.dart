import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

class Header extends StatelessWidget {
  const Header({
    required this.title,
    required this.isExpanded,
    required this.isEditingTitle,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.filter,
    required this.chevronDuration,
    required this.filterStripDuration,
    required this.onToggleExpand,
    required this.onTitleTap,
    required this.onTitleSave,
    required this.onTitleCancel,
    required this.onFilterChanged,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
    super.key,
  });

  final String title;
  final bool isExpanded;
  final bool isEditingTitle;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final ChecklistFilter filter;
  final Duration chevronDuration;
  final Duration filterStripDuration;
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
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Single title row — progress ring always visible here.
        GestureDetector(
          onTap: isExpanded ? null : onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.step5,
              right: tokens.spacing.step3,
              top: tokens.spacing.step1,
              bottom: isExpanded ? tokens.spacing.step3 : tokens.spacing.step1,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Row(
                children: [
                  Expanded(
                    child: isExpanded && !isEditingTitle
                        ? GestureDetector(
                            onTap: onTitleTap,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.text,
                              child: _TitleText(title: title, tokens: tokens),
                            ),
                          )
                        : isExpanded && isEditingTitle
                        ? TitleTextField(
                            initialValue: title,
                            onSave: onTitleSave,
                            resetToInitialValue: true,
                            onCancel: onTitleCancel,
                          )
                        : _TitleText(title: title, tokens: tokens),
                  ),
                  // Progress ring — always visible in header row.
                  _ProgressRow(
                    completedCount: completedCount,
                    totalCount: totalCount,
                    completionRate: completionRate,
                    tokens: tokens,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  // Chevron — collapsed points right, expanded points down.
                  AnimatedRotation(
                    turns: isExpanded ? 0.0 : -0.25,
                    duration: chevronDuration,
                    child: IconButton(
                      tooltip: isExpanded
                          ? context.messages.checklistCollapseTooltip
                          : context.messages.checklistExpandTooltip,
                      onPressed: onToggleExpand,
                      icon: Icon(
                        Icons.expand_more,
                        size: 24,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ),
                  // Menu — only shown when at least one action is available.
                  if (onDelete != null ||
                      onExportMarkdown != null ||
                      onShareMarkdown != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    _HeaderMenu(
                      onDelete: onDelete,
                      onExportMarkdown: onExportMarkdown,
                      onShareMarkdown: onShareMarkdown,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Filter strip — full-width grey background, only when expanded and
        // has items.
        AnimatedCrossFade(
          duration: filterStripDuration,
          sizeCurve: Curves.easeInOut,
          crossFadeState: isExpanded && totalCount > 0
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _FilterStrip(
            filter: filter,
            tokens: tokens,
            onFilterChanged: onFilterChanged,
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sorting mode header — drag handle + title + progress, no chevron/menu.
// ─────────────────────────────────────────────────────────────────────────────

class SortingHeader extends StatelessWidget {
  const SortingHeader({
    required this.title,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    this.reorderIndex,
    super.key,
  });

  final String title;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final handle = Padding(
      padding: EdgeInsets.only(right: tokens.spacing.step3),
      child: Icon(
        Icons.drag_indicator,
        size: 28,
        color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.7),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: tokens.spacing.step3,
        horizontal: tokens.spacing.step5,
      ),
      child: Row(
        children: [
          if (reorderIndex != null)
            ReorderableDragStartListener(index: reorderIndex!, child: handle)
          else
            handle,
          Expanded(
            child: Text(
              title,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _ProgressRow(
            completedCount: completedCount,
            totalCount: totalCount,
            completionRate: completionRate,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring + "N/M done" label
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.tokens,
  });

  final int completedCount;
  final int totalCount;
  final double completionRate;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildChecklistProgressRing(
          completionRate: completionRate,
          lowEmphasisColor: tokens.colors.text.lowEmphasis,
          semanticsLabel: context.messages.checklistProgressSemantics,
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          context.messages.checklistCompletedShort(completedCount, totalCount),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter strip — full-width grey background row with Open / All tabs + divider.
// Matches the Widgetbook design exactly.
// ─────────────────────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.filter,
    required this.tokens,
    required this.onFilterChanged,
  });

  final ChecklistFilter filter;
  final DsTokens tokens;
  final ValueChanged<ChecklistFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40,
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha: 0.06,
          ),
          child: Row(
            children: [
              _FilterTab(
                label: context.messages.taskStatusOpen,
                isSelected: filter == ChecklistFilter.openOnly,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.openOnly),
              ),
              _FilterTab(
                label: context.messages.taskStatusDone,
                isSelected: filter == ChecklistFilter.doneOnly,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.doneOnly),
              ),
              _FilterTab(
                label: context.messages.taskStatusAll,
                isSelected: filter == ChecklistFilter.all,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.all),
              ),
              const Spacer(),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: tokens.colors.decorative.level01,
        ),
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final DsTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: SizedBox(
        width: 64,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.24)
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: isSelected
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.text.lowEmphasis,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 3,
                color: isSelected ? accentColor : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Title text
// ─────────────────────────────────────────────────────────────────────────────

class _TitleText extends StatelessWidget {
  const _TitleText({required this.title, required this.tokens});

  final String title;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
        color: tokens.colors.text.highEmphasis,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header menu — export, share, delete
// ─────────────────────────────────────────────────────────────────────────────

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
    final tokens = context.designTokens;
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
        tooltip: context.messages.checklistMoreTooltip,
        icon: const Icon(Icons.more_vert, size: 20),
        position: PopupMenuPosition.under,
        onSelected: (value) async {
          Future<void> deleteAction() async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(context.messages.checklistDelete),
                content: Text(context.messages.checklistItemDeleteWarning),
                actions: [
                  LottiTertiaryButton(
                    label: context.messages.checklistItemDeleteCancel,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  LottiTertiaryButton(
                    label: context.messages.checklistItemDeleteConfirm,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            );
            if (confirmed ?? false) onDelete?.call();
          }

          if (value == 'export') {
            onExportMarkdown?.call();
          } else if (value == 'share') {
            onShareMarkdown?.call();
          } else if (value == 'delete') {
            await deleteAction();
          }
        },
        itemBuilder: (context) => [
          if (onExportMarkdown != null)
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  const Icon(MdiIcons.exportVariant, size: 18),
                  SizedBox(width: tokens.spacing.step3),
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
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  const Icon(Icons.ios_share, size: 18),
                  SizedBox(width: tokens.spacing.step3),
                  Flexible(
                    child: Text(
                      context.messages.checklistShare,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: tokens.spacing.step3),
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

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring helper
// ─────────────────────────────────────────────────────────────────────────────

/// Bright green progress ring used in checklist headers.
Widget buildChecklistProgressRing({
  required double completionRate,
  required Color lowEmphasisColor,
  required String semanticsLabel,
  double size = 20,
  double strokeWidth = 3,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      color: successColor,
      backgroundColor: lowEmphasisColor.withValues(alpha: 0.3),
      value: completionRate,
      strokeWidth: strokeWidth,
      semanticsLabel: semanticsLabel,
    ),
  );
}
