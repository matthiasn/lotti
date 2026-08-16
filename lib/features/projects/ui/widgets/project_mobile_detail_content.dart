import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// The scrollable body of the read-first project detail surface (used on
/// mobile and in the desktop right pane).
///
/// Lays out, top to bottom: a header (title + status pill + category/target-date
/// meta tags that double as edit affordances when their `on*Tap` callbacks are
/// supplied), the [HealthPanel], the agent [ExpandableReportSection] (with
/// refresh / cancel-scheduled-wake controls and a live countdown), and the
/// [ProjectTasksSliverPanel]. The optional `on*Tap` callbacks let the host page
/// open pickers and trigger immediate saves; with them omitted it renders as a
/// pure read-only showcase. [currentTime] feeds the report's relative "updated
/// X ago" label. On wide windows, the header and scrollable body use the shared
/// detail reading measure instead of stretching report text and cards edge to
/// edge. [hasProjectAgent] distinguishes an unassessed agent from a project
/// that cannot produce a report yet.
class ProjectMobileDetailContent extends StatefulWidget {
  const ProjectMobileDetailContent({
    required this.record,
    required this.currentTime,
    this.onBack,
    this.onCategoryTap,
    this.onTargetDateTap,
    this.onStatusTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    this.onAddTask,
    this.onRefreshReport,
    this.onCancelScheduledReportWake,
    this.hasProjectAgent = true,
    this.isRefreshingReport = false,
    this.isSaving = false,
    this.onTaskTap,
    super.key,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final VoidCallback? onBack;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final FutureOr<void> Function()? onDelete;
  final Future<void> Function()? onAddTask;
  final VoidCallback? onRefreshReport;
  final VoidCallback? onCancelScheduledReportWake;
  final bool hasProjectAgent;
  final bool isRefreshingReport;
  final bool isSaving;
  final ValueChanged<TaskSummary>? onTaskTap;

  @override
  State<ProjectMobileDetailContent> createState() =>
      _ProjectMobileDetailContentState();
}

class _ProjectMobileDetailContentState
    extends State<ProjectMobileDetailContent> {
  late final ScrollController _scrollController = ScrollController();
  bool _isAddingTask = false;
  bool _isDeleting = false;

  Future<void> _handleAddTask() async {
    final onAddTask = widget.onAddTask;
    if (onAddTask == null || widget.isSaving || _isAddingTask || _isDeleting) {
      return;
    }

    setState(() => _isAddingTask = true);
    try {
      await onAddTask();
    } finally {
      if (mounted) setState(() => _isAddingTask = false);
    }
  }

  Future<void> _handleDelete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || widget.isSaving || _isAddingTask || _isDeleting) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await onDelete();
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    final description = widget.record.project.entryText?.plainText.trim() ?? '';
    final blockedTasks = widget.record.highlightedTaskSummaries
        .where((summary) => summary.task.data.status is TaskBlocked)
        .toList(growable: false);
    final firstBlockedTask = blockedTasks.isEmpty ? null : blockedTasks.first;
    final isMutating = widget.isSaving || _isAddingTask || _isDeleting;
    final menuItems = <DesignSystemContextMenuItem>[
      if (widget.onEdit != null)
        DesignSystemContextMenuItem(
          label: context.messages.projectActionEdit,
          icon: Icons.edit_outlined,
          onTap: isMutating ? null : widget.onEdit,
        ),
      if (widget.onArchive != null)
        DesignSystemContextMenuItem(
          label: context.messages.projectActionArchive,
          icon: Icons.archive_outlined,
          onTap: isMutating ? null : widget.onArchive,
        ),
      if (widget.onDelete != null)
        DesignSystemContextMenuItem(
          label: context.messages.projectActionDelete,
          icon: Icons.delete_outline,
          onTap: isMutating ? null : _handleDelete,
          isDestructive: true,
        ),
    ];

    return ColoredBox(
      color: ShowcasePalette.page(context),
      child: DetailContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (splitController == null)
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step3),
                child: DesignSystemBackControl(
                  foregroundColor: ShowcasePalette.highText(context),
                  onTap: widget.onBack,
                ),
              ),
            Expanded(
              child: DesignSystemScrollbar(
                controller: _scrollController,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: splitController == null
                            ? tokens.spacing.step2
                            : tokens.spacing.step5,
                        bottom: tokens.spacing.step6,
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _ProjectMobileHeader(
                              record: widget.record,
                              onCategoryTap: widget.onCategoryTap,
                              onTargetDateTap: widget.onTargetDateTap,
                              onStatusTap: widget.onStatusTap,
                              isInteractive: !isMutating,
                              trailing: menuItems.isEmpty
                                  ? null
                                  : DesignSystemContextMenuButton(
                                      items: menuItems,
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).showMenuTooltip,
                                      iconColor: ShowcasePalette.highText(
                                        context,
                                      ),
                                    ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: tokens.spacing.step4),
                          ),
                          SliverToBoxAdapter(
                            child: widget.record.healthMetrics == null
                                ? ProjectHealthEmptyState(
                                    onRunReport: isMutating
                                        ? null
                                        : widget.onRefreshReport,
                                    hasAgent: widget.hasProjectAgent,
                                    isRunningReport: widget.isRefreshingReport,
                                  )
                                : HealthPanel(
                                    record: widget.record,
                                    onViewBlockerPressed:
                                        firstBlockedTask == null ||
                                            widget.onTaskTap == null
                                        ? null
                                        : () => widget.onTaskTap!(
                                            firstBlockedTask,
                                          ),
                                  ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: tokens.spacing.step5),
                          ),
                          if (description.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _ProjectDescription(
                                description: description,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: tokens.spacing.step6),
                            ),
                          ],
                          SliverToBoxAdapter(
                            child: ExpandableReportSection(
                              title:
                                  context.messages.projectShowcaseAiReportTitle,
                              body:
                                  widget.record.aiSummary.isEmpty &&
                                      widget.record.reportContent.isEmpty
                                  ? context.messages.agentReportNone
                                  : widget.record.aiSummary,
                              fullContent: widget.record.reportContent,
                              trailingLabel:
                                  widget.record.reportUpdatedAt == null
                                  ? null
                                  : showcaseUpdatedLabel(
                                      context,
                                      updatedAt: widget.record.reportUpdatedAt!,
                                      currentTime: widget.currentTime,
                                    ),
                              nextWakeAt: widget.record.reportNextWakeAt,
                              onRefresh: isMutating
                                  ? null
                                  : widget.onRefreshReport,
                              onCancelScheduledWake: isMutating
                                  ? null
                                  : widget.onCancelScheduledReportWake,
                              isRefreshing: widget.isRefreshingReport,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: tokens.spacing.step5),
                          ),
                          ProjectTasksSliverPanel(
                            record: widget.record,
                            onTaskTap: widget.onTaskTap,
                            onAddTask: widget.onAddTask == null
                                ? null
                                : _handleAddTask,
                            isAddTaskEnabled: !widget.isSaving && !_isDeleting,
                            isAddingTask: _isAddingTask,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDescription extends StatelessWidget {
  const _ProjectDescription({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.messages.projectShowcaseDescriptionTitle,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: ShowcasePalette.highText(context),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            description,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: ShowcasePalette.highText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectMobileHeader extends StatelessWidget {
  const _ProjectMobileHeader({
    required this.record,
    this.onCategoryTap,
    this.onTargetDateTap,
    this.onStatusTap,
    this.isInteractive = true,
    this.trailing,
  });

  final ProjectRecord record;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;
  final bool isInteractive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = record.category;
    final titleStyle = tokens.typography.styles.heading.heading3.copyWith(
      color: ShowcasePalette.highText(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                end: trailing == null
                    ? 0
                    : tokens.spacing.step9 + tokens.spacing.step2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  record.project.data.title,
                  style: titleStyle,
                ),
              ),
            ),
            if (trailing != null)
              PositionedDirectional(
                top: -tokens.spacing.step2,
                end: 0,
                child: trailing!,
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ProjectStatusPill(
              status: record.project.data.status,
              onTap: isInteractive ? onStatusTap : null,
            ),
            if (category != null)
              CategoryTag(
                label: category.name,
                icon: category.icon?.iconData ?? Icons.label_outline,
                color: colorFromCssHex(
                  category.color ?? defaultCategoryColorHex,
                ),
                onTap: isInteractive ? onCategoryTap : null,
              )
            else if (onCategoryTap != null)
              OutlinedMetaTag(
                icon: Icons.label_outline,
                label: context.messages.habitCategoryLabel,
                onTap: isInteractive ? onCategoryTap : null,
                isPlaceholder: true,
              ),
            if (record.project.data.targetDate case final targetDate?)
              OutlinedMetaTag(
                icon: Icons.watch_later_outlined,
                label: DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(targetDate),
                onTap: isInteractive ? onTargetDateTap : null,
              )
            else if (onTargetDateTap != null)
              OutlinedMetaTag(
                icon: Icons.watch_later_outlined,
                label: context.messages.projectTargetDateLabel,
                onTap: isInteractive ? onTargetDateTap : null,
                isPlaceholder: true,
              ),
          ],
        ),
      ],
    );
  }
}
