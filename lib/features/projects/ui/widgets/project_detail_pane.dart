import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// The right-hand detail pane showing all information for a selected project.
class ProjectDetailPane extends StatefulWidget {
  const ProjectDetailPane({
    required this.record,
    required this.currentTime,
    this.showLeadingBorder = true,
    this.onCategoryTap,
    this.onTargetDateTap,
    this.onStatusTap,
    super.key,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final bool showLeadingBorder;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;

  @override
  State<ProjectDetailPane> createState() => _ProjectDetailPaneState();
}

class _ProjectDetailPaneState extends State<ProjectDetailPane> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcasePalette.page(context),
        border: Border(
          left: widget.showLeadingBorder
              ? BorderSide(color: ShowcasePalette.border(context))
              : BorderSide.none,
        ),
      ),
      child: DesignSystemScrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailHeader(
                record: widget.record,
                onCategoryTap: widget.onCategoryTap,
                onTargetDateTap: widget.onTargetDateTap,
                onStatusTap: widget.onStatusTap,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step5,
                  tokens.spacing.step5,
                  tokens.spacing.step5,
                  tokens.spacing.step8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HealthPanel(record: widget.record),
                    SizedBox(height: tokens.spacing.step5),
                    TextSection(
                      title: context.messages.projectShowcaseDescriptionTitle,
                      body: widget.record.project.entryText?.plainText ?? '',
                    ),
                    SizedBox(height: tokens.spacing.step5),
                    ExpandableReportSection(
                      title: context.messages.projectShowcaseAiReportTitle,
                      body: widget.record.aiSummary.isEmpty
                          ? context.messages.agentReportNone
                          : widget.record.aiSummary,
                      fullContent: widget.record.reportContent,
                      recommendations: widget.record.recommendations,
                      trailingLabel: showcaseUpdatedLabel(
                        context,
                        updatedAt: widget.record.reportUpdatedAt,
                        currentTime: widget.currentTime,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step5),
                    ProjectTasksPanel(record: widget.record),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.project.data.title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: ShowcasePalette.highText(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: ShowcasePalette.mediumText(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (record.category case final category?)
                CategoryTag(
                  label: category.name,
                  icon: category.icon?.iconData ?? Icons.label_outline,
                  color: colorFromCssHex(
                    category.color ?? defaultCategoryColorHex,
                  ),
                  onTap: onCategoryTap,
                ),
              if (record.project.data.targetDate case final targetDate?) ...[
                SizedBox(width: tokens.spacing.step3),
                _OutlinedMetaTag(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(targetDate),
                  onTap: onTargetDateTap,
                ),
              ],
              const Spacer(),
              ProjectStatusPill(
                status: record.project.data.status,
                large: true,
                onTap: onStatusTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlinedMetaTag extends StatelessWidget {
  const _OutlinedMetaTag({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final child = Container(
      constraints: BoxConstraints(
        minHeight: tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: ShowcasePalette.lowText(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tokens.typography.size.caption,
            color: ShowcasePalette.lowText(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: ShowcasePalette.lowText(context),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        child: child,
      ),
    );
  }
}
