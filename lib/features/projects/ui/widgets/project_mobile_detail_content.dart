import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

class ProjectMobileDetailContent extends StatefulWidget {
  const ProjectMobileDetailContent({
    required this.record,
    required this.currentTime,
    this.onBack,
    this.onCategoryTap,
    this.onTargetDateTap,
    this.onStatusTap,
    this.onRefreshReport,
    this.isRefreshingReport = false,
    this.onTaskTap,
    super.key,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final VoidCallback? onBack;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onTargetDateTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onRefreshReport;
  final bool isRefreshingReport;
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

    return ColoredBox(
      color: ShowcasePalette.page(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step4,
              tokens.spacing.step5,
              0,
            ),
            child: DesignSystemShowcaseMobileDetailHeader(
              foregroundColor: ShowcasePalette.highText(context),
              onBack: widget.onBack,
            ),
          ),
          Expanded(
            child: DesignSystemScrollbar(
              controller: _scrollController,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.step5,
                      tokens.spacing.step3,
                      tokens.spacing.step5,
                      tokens.spacing.step6,
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _ProjectMobileHeader(
                            record: widget.record,
                            onCategoryTap: widget.onCategoryTap,
                            onTargetDateTap: widget.onTargetDateTap,
                            onStatusTap: widget.onStatusTap,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: tokens.spacing.step5),
                        ),
                        SliverToBoxAdapter(
                          child: HealthPanel(record: widget.record),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: tokens.spacing.step6),
                        ),
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
                            recommendations: widget.record.recommendations,
                            trailingLabel: showcaseUpdatedLabel(
                              context,
                              updatedAt: widget.record.reportUpdatedAt,
                              currentTime: widget.currentTime,
                            ),
                            nextWakeAt: widget.record.reportNextWakeAt,
                            onRefresh: widget.onRefreshReport,
                            isRefreshing: widget.isRefreshingReport,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: tokens.spacing.step6),
                        ),
                        ProjectTasksSliverPanel(
                          record: widget.record,
                          onTaskTap: widget.onTaskTap,
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
    final healthMetrics = record.healthMetrics;
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
                    child: Text(
                      record.project.data.title,
                      style: titleStyle,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  statusPill,
                ],
              )
            else ...[
              Text(
                record.project.data.title,
                style: titleStyle,
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
                if (healthMetrics != null)
                  ProjectHealthBandTag(band: healthMetrics.band),
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
