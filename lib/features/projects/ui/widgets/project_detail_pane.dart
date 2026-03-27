import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/review_sessions_panel.dart';
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
    super.key,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final bool showLeadingBorder;

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
              _DetailHeader(record: widget.record),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HealthPanel(record: widget.record),
                    const SizedBox(height: 16),
                    TextSection(
                      title: context.messages.projectShowcaseDescriptionTitle,
                      body: widget.record.project.entryText?.plainText ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextSection(
                      title: context.messages.projectShowcaseAiReportTitle,
                      body: widget.record.aiSummary,
                      trailingLabel: showcaseUpdatedLabel(
                        context,
                        updatedAt: widget.record.reportUpdatedAt,
                        currentTime: widget.currentTime,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.messages.projectShowcaseRecommendationsTitle,
                      style: context
                          .designTokens
                          .typography
                          .styles
                          .subtitle
                          .subtitle2
                          .copyWith(
                            color: ShowcasePalette.highText(context),
                          ),
                    ),
                    const SizedBox(height: 8),
                    RecommendationsList(items: widget.record.recommendations),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 720) {
                          return Column(
                            children: [
                              ProjectTasksPanel(record: widget.record),
                              const SizedBox(height: 16),
                              ReviewSessionsPanel(record: widget.record),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ProjectTasksPanel(record: widget.record),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ReviewSessionsPanel(record: widget.record),
                            ),
                          ],
                        );
                      },
                    ),
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
  const _DetailHeader({required this.record});

  final ProjectRecord record;

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
              CategoryTag(
                label: record.category.name,
                icon: record.category.icon?.iconData ?? Icons.label_outline,
                color: colorFromCssHex(
                  record.category.color ?? defaultCategoryColorHex,
                ),
              ),
              if (record.project.data.targetDate case final targetDate?) ...[
                const SizedBox(width: 8),
                _OutlinedMetaTag(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(targetDate),
                ),
              ],
              const Spacer(),
              ProjectStatusPill(
                status: record.project.data.status,
                large: true,
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
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ShowcasePalette.lowText(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: ShowcasePalette.lowText(context),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: ShowcasePalette.lowText(context),
            ),
          ),
        ],
      ),
    );
  }
}
