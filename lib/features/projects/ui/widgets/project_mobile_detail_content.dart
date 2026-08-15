import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/project_data.dart';
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
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
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
/// edge.
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
  final VoidCallback? onDelete;
  final VoidCallback? onAddTask;
  final VoidCallback? onRefreshReport;
  final VoidCallback? onCancelScheduledReportWake;
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
    final menuItems = <DesignSystemContextMenuItem>[
      if (widget.onEdit != null)
        DesignSystemContextMenuItem(
          label: context.messages.projectActionEdit,
          icon: Icons.edit_outlined,
          onTap: widget.isSaving ? null : widget.onEdit,
        ),
      if (widget.onArchive != null)
        DesignSystemContextMenuItem(
          label: context.messages.projectActionArchive,
          icon: Icons.archive_outlined,
          onTap: widget.isSaving ? null : widget.onArchive,
        ),
      if (widget.onDelete != null)
        DesignSystemContextMenuItem(
          label: context.messages.projectActionDelete,
          icon: Icons.delete_outline,
          onTap: widget.isSaving ? null : widget.onDelete,
          isDestructive: true,
        ),
    ];

    return ColoredBox(
      color: ShowcasePalette.page(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailContentWidth(
            child: Padding(
              padding: EdgeInsets.only(
                top: tokens.spacing.step4,
              ),
              child: DesignSystemShowcaseMobileDetailHeader(
                foregroundColor: ShowcasePalette.highText(context),
                onBack: widget.onBack,
                showBackControl: splitController == null,
                trailing: menuItems.isEmpty
                    ? const SizedBox.shrink()
                    : DesignSystemContextMenuButton(
                        items: menuItems,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).showMenuTooltip,
                        iconColor: ShowcasePalette.highText(context),
                      ),
              ),
            ),
          ),
          Expanded(
            child: DetailContentWidth(
              child: DesignSystemScrollbar(
                controller: _scrollController,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: tokens.spacing.step3,
                        bottom: tokens.spacing.step6,
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _ProjectMobileHeader(
                              record: widget.record,
                              onCategoryTap: widget.isSaving
                                  ? null
                                  : widget.onCategoryTap,
                              onTargetDateTap: widget.isSaving
                                  ? null
                                  : widget.onTargetDateTap,
                              onStatusTap: widget.isSaving
                                  ? null
                                  : widget.onStatusTap,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: tokens.spacing.step5),
                          ),
                          SliverToBoxAdapter(
                            child: widget.record.healthMetrics == null
                                ? ProjectHealthEmptyState(
                                    onRunReport: widget.onRefreshReport,
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
                            child: SizedBox(height: tokens.spacing.step6),
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
                              trailingLabel: showcaseUpdatedLabel(
                                context,
                                updatedAt: widget.record.reportUpdatedAt,
                                currentTime: widget.currentTime,
                              ),
                              nextWakeAt: widget.record.reportNextWakeAt,
                              onRefresh: widget.onRefreshReport,
                              onCancelScheduledWake:
                                  widget.onCancelScheduledReportWake,
                              isRefreshing: widget.isRefreshingReport,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(height: tokens.spacing.step6),
                          ),
                          ProjectTasksSliverPanel(
                            record: widget.record,
                            onTaskTap: widget.onTaskTap,
                            onAddTask: widget.onAddTask,
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
  });

  final ProjectRecord record;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = record.category;
    final titleStyle = tokens.typography.styles.heading.heading3.copyWith(
      color: ShowcasePalette.highText(context),
    );
    final statusPill = ProjectStatusPill(
      status: record.project.data.status,
      large: true,
      onTap: onStatusTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final statusOnNextLine = _shouldWrapStatusPill(
          context,
          maxWidth: constraints.maxWidth,
          title: record.project.data.title,
          status: record.project.data.status,
          titleStyle: titleStyle,
          tokens: tokens,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!statusOnNextLine)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        record.project.data.title,
                        style: titleStyle,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  statusPill,
                ],
              )
            else ...[
              Semantics(
                header: true,
                child: Text(
                  record.project.data.title,
                  style: titleStyle,
                ),
              ),
              SizedBox(height: tokens.spacing.step3),
              Align(
                alignment: Alignment.centerRight,
                child: statusPill,
              ),
            ],
            SizedBox(height: tokens.spacing.step3),
            Wrap(
              spacing: tokens.spacing.step3,
              runSpacing: tokens.spacing.step3,
              children: [
                if (category != null)
                  CategoryTag(
                    label: category.name,
                    icon: category.icon?.iconData ?? Icons.label_outline,
                    color: colorFromCssHex(
                      category.color ?? defaultCategoryColorHex,
                    ),
                    onTap: onCategoryTap,
                  )
                else if (onCategoryTap != null)
                  OutlinedMetaTag(
                    icon: Icons.label_outline,
                    label: context.messages.habitCategoryLabel,
                    onTap: onCategoryTap,
                    isPlaceholder: true,
                  ),
                if (record.project.data.targetDate case final targetDate?)
                  OutlinedMetaTag(
                    icon: Icons.watch_later_outlined,
                    label: DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(targetDate),
                    onTap: onTargetDateTap,
                  )
                else if (onTargetDateTap != null)
                  OutlinedMetaTag(
                    icon: Icons.watch_later_outlined,
                    label: context.messages.projectTargetDateLabel,
                    onTap: onTargetDateTap,
                    isPlaceholder: true,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

bool _shouldWrapStatusPill(
  BuildContext context, {
  required double maxWidth,
  required String title,
  required ProjectStatus status,
  required TextStyle titleStyle,
  required DsTokens tokens,
}) {
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final titlePainter = TextPainter(
    text: TextSpan(text: title, style: titleStyle),
    textDirection: textDirection,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();

  final statusPainter = TextPainter(
    text: TextSpan(
      text: showcaseProjectStatusLabel(context, status),
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(height: 1),
    ),
    textDirection: textDirection,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();

  final statusWidth =
      tokens.spacing.step3 +
      tokens.typography.lineHeight.caption +
      tokens.spacing.step1 +
      statusPainter.width +
      tokens.spacing.step1 +
      tokens.typography.lineHeight.caption +
      tokens.spacing.step3;

  return titlePainter.width + tokens.spacing.step4 + statusWidth > maxWidth;
}
