import 'package:lotti/features/agents/ui/agent_surface_menu.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// Checklist card header row: the (tappable, inline-editable) title, the
/// progress ring with "N/M done" label, an expand/collapse chevron, and an
/// overflow menu (export/share/delete) shown only when an action is wired up.
/// When expanded with items, an animated Open/Done/All filter strip drops in
/// below the row.
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
            // State-invariant padding: a bottom inset that differed between
            // expanded (step3) and collapsed (step1) made the header row's
            // box jump by the difference the instant a toggle started, while
            // the strip below was still animating — the accordion header must
            // stay pinned in the same spot regardless of state.
            padding: EdgeInsets.only(
              left: tokens.spacing.step5,
              right: tokens.spacing.step3,
              top: tokens.spacing.step1,
              bottom: tokens.spacing.step3,
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
                        LottiIcons.expand,
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
          // Collapse height only. Targeting SizedBox.shrink would also animate
          // the header toward zero width and briefly squeeze its text/icons.
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sorting mode header — drag handle + title + progress, no chevron/menu.
// ─────────────────────────────────────────────────────────────────────────────

/// Compact header shown while checklists are being reordered: a drag handle,
/// the title, and the progress ring — no chevron or menu. When [reorderIndex]
/// is set the handle becomes a `ReorderableDragStartListener` for that slot.
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
        LottiIcons.drag,
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
          // Tabular figures so the "N/M done" label keeps a constant width as
          // the counts change (e.g. 6/11 → 7/11) instead of the header
          // breathing horizontally with each check-off.
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
            fontFeatures: numericBadgeFontFeatures,
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
    final messages = context.messages;
    // The design system's filter chips, not a filled tab band: Open / Done /
    // All filters the list, and DesignSystemChip is the filter control.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.cardPadding,
            vertical: tokens.spacing.step3,
          ),
          child: Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              for (final (value, label) in [
                (ChecklistFilter.openOnly, messages.taskStatusOpen),
                (ChecklistFilter.doneOnly, messages.taskStatusDone),
                (ChecklistFilter.all, messages.taskStatusAll),
              ])
                DesignSystemChip(
                  key: ValueKey('checklist-filter-${value.name}'),
                  label: label,
                  selected: filter == value,
                  size: DesignSystemChipSize.compactPill,
                  onPressed: () => onFilterChanged(value),
                ),
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
    return AgentSurfaceMenuButton(
      semanticsLabel: context.messages.checklistMoreTooltip,
      items: [
        // Copy, not share: this item writes markdown to the clipboard, while
        // the item below hands it to the OS share sheet — two actions, two
        // glyphs.
        if (onExportMarkdown != null)
          DesignSystemContextMenuItem(
            icon: LottiIcons.copy,
            label: context.messages.checklistExportAsMarkdown,
            onTap: onExportMarkdown,
          ),
        if (onShareMarkdown != null)
          DesignSystemContextMenuItem(
            icon: LottiIcons.share,
            label: context.messages.checklistShare,
            onTap: onShareMarkdown,
          ),
        if (onDelete != null)
          DesignSystemContextMenuItem(
            icon: LottiIcons.delete,
            label: context.messages.checklistDelete,
            isDestructive: true,
            startsGroup: true,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                title: context.messages.checklistDelete,
                message: context.messages.checklistItemDeleteWarning,
                cancelLabel: context.messages.checklistItemDeleteCancel,
                confirmLabel: context.messages.checklistItemDeleteConfirm,
              );
              if (confirmed) onDelete?.call();
            },
          ),
      ],
      triggerBuilder: (context, open) => DesignSystemIconAction(
        icon: LottiIcons.moreVertical,
        tooltip: context.messages.checklistMoreTooltip,
        onPressed: open,
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
