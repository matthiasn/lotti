import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_summary_card.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_meta.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// The scrollable body of the read-first project detail surface (used on
/// mobile and in the desktop right pane).
///
/// Lays out, top to bottom: a Task-style header (quiet category breadcrumb,
/// title, and shared metadata pills that double as edit affordances when their
/// `on*Tap` callbacks are supplied), the description,
/// [ProjectTasksSliverPanel], and the shared-style
/// [ProjectAgentSummaryCard]. The optional `on*Tap` callbacks let the host page
/// open pickers and trigger immediate saves; with them omitted it renders as a
/// pure read-only showcase. On wide windows, the header and scrollable body use
/// the shared detail reading measure instead of stretching report text and cards edge to
/// edge. [hasProjectAgent] distinguishes a resolving agent from a project that
/// has none; [onAssignAgent] lets that empty state provision an existing
/// project without leaving the workspace.
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
    this.onAssignAgent,
    this.agentIdentity,
    this.agentActions,
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
  final Future<void> Function()? onAssignAgent;
  final AgentIdentityEntity? agentIdentity;
  final Widget? agentActions;
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
  bool _isAssigningAgent = false;

  Future<void> _handleAddTask() async {
    final onAddTask = widget.onAddTask;
    if (onAddTask == null ||
        widget.isSaving ||
        _isAddingTask ||
        _isDeleting ||
        _isAssigningAgent) {
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

  Future<void> _handleAssignAgent() async {
    final onAssignAgent = widget.onAssignAgent;
    if (onAssignAgent == null ||
        widget.isSaving ||
        _isAddingTask ||
        _isDeleting ||
        _isAssigningAgent) {
      return;
    }

    setState(() => _isAssigningAgent = true);
    try {
      await onAssignAgent();
    } finally {
      if (mounted) setState(() => _isAssigningAgent = false);
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
    final isMutating =
        widget.isSaving || _isAddingTask || _isDeleting || _isAssigningAgent;
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

    return PopScope(
      canPop: !isMutating,
      child: ColoredBox(
        color: ShowcasePalette.page(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (splitController == null)
              DetailContentWidth(
                child: Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DesignSystemBackControl(
                      foregroundColor: ShowcasePalette.highText(context),
                      onTap: isMutating ? null : widget.onBack,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: DesignSystemScrollbar(
                controller: _scrollController,
                size: splitController == null
                    ? DesignSystemScrollbarSize.small
                    : DesignSystemScrollbarSize.defaultSize,
                child: DetailContentWidth(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: splitController == null
                              ? tokens.spacing.step2
                              : tokens.spacing.step5,
                          bottom: splitController == null
                              ? tokens.spacing.step12 + tokens.spacing.step8
                              : tokens.spacing.step6,
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
                                trailing: menuItems.isEmpty || isMutating
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
                            ProjectTasksSliverPanel(
                              record: widget.record,
                              onTaskTap: isMutating ? null : widget.onTaskTap,
                              onAddTask: widget.onAddTask == null
                                  ? null
                                  : _handleAddTask,
                              isAddTaskEnabled: !isMutating,
                              isAddingTask: _isAddingTask,
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: tokens.spacing.step5),
                            ),
                            SliverToBoxAdapter(
                              child: ProjectAgentSummaryCard(
                                projectId: widget.record.project.meta.id,
                                record: widget.record,
                                identity: widget.agentIdentity,
                                hasProjectAgent: widget.hasProjectAgent,
                                isMutating: isMutating,
                                onAssignAgent: widget.onAssignAgent == null
                                    ? null
                                    : _handleAssignAgent,
                                onRefresh: widget.onRefreshReport,
                                onCancelScheduledWake:
                                    widget.onCancelScheduledReportWake,
                                onViewBlocker:
                                    isMutating ||
                                        firstBlockedTask == null ||
                                        widget.onTaskTap == null
                                    ? null
                                    : () => widget.onTaskTap!(firstBlockedTask),
                                actions: widget.agentActions,
                                isRefreshing: widget.isRefreshingReport,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final titleStyle = tokens.typography.styles.heading.heading2.copyWith(
      color: ShowcasePalette.highText(context),
      height: 1.15,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category != null) ...[
          TaskHierarchyCrumb(
            category: DesktopTaskHeaderCategory(
              label: category.name,
              color: colorFromCssHex(
                category.color ?? defaultCategoryColorHex,
              ),
            ),
            project: null,
            onCategoryTap: isInteractive ? onCategoryTap : null,
            onProjectTap: null,
            showProjectSegment: false,
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
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
            if (category == null && onCategoryTap != null)
              DsPill(
                variant: DsPillVariant.muted,
                label: context.messages.habitCategoryLabel,
                onTap: isInteractive ? onCategoryTap : null,
                leading: Icon(
                  Icons.category_outlined,
                  size: kTaskChipGlyphSize,
                  color: ShowcasePalette.mediumText(context),
                ),
              ),
            if (record.project.data.targetDate case final targetDate?)
              DsPill(
                variant: DsPillVariant.filled,
                bordered: true,
                label: DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(targetDate),
                onTap: isInteractive ? onTargetDateTap : null,
                leading: Icon(
                  Icons.calendar_today_outlined,
                  size: kTaskChipGlyphSize,
                  color: ShowcasePalette.mediumText(context),
                ),
              )
            else if (onTargetDateTap != null)
              DsPill(
                variant: DsPillVariant.muted,
                label: context.messages.projectTargetDateLabel,
                onTap: isInteractive ? onTargetDateTap : null,
                leading: Icon(
                  Icons.calendar_today_outlined,
                  size: kTaskChipGlyphSize,
                  color: ShowcasePalette.mediumText(context),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
