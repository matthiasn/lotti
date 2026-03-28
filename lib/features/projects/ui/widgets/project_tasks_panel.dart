import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A panel listing highlighted tasks for a project with total duration.
class ProjectTasksPanel extends StatelessWidget {
  const ProjectTasksPanel({
    required this.record,
    this.onTaskTap,
    super.key,
  });

  final ProjectRecord record;
  final ValueChanged<TaskSummary>? onTaskTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ShowcasePanel(
      header: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    context.messages.projectShowcaseProjectTasksTab,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: ShowcasePalette.highText(context),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                CountDotBadge(
                  count: record.highlightedTaskSummaries.length,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Icon(
            Icons.timer_outlined,
            size: tokens.typography.lineHeight.subtitle2,
            color: ShowcasePalette.timeGreen(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            showcaseFormatDuration(
              record.highlightedTasksTotalDuration,
            ),
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: ShowcasePalette.timeGreen(context),
            ),
          ),
        ],
      ),
      itemCount: record.highlightedTaskSummaries.length,
      itemBuilder: (_, index) => TaskSummaryRow(
        summary: record.highlightedTaskSummaries[index],
        onTap: onTaskTap,
      ),
    );
  }
}

/// A row displaying a single task's title, estimated duration, and status.
class TaskSummaryRow extends StatelessWidget {
  const TaskSummaryRow({
    required this.summary,
    this.onTap,
    super.key,
  });

  final TaskSummary summary;
  final ValueChanged<TaskSummary>? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.task.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: ShowcasePalette.highText(context),
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: tokens.typography.size.caption,
                      color: ShowcasePalette.lowText(context),
                    ),
                    SizedBox(width: tokens.spacing.step1),
                    Text(
                      showcaseFormatDuration(summary.estimatedDuration),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ShowcasePalette.lowText(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          TaskStatePill(status: summary.task.data.status),
          SizedBox(width: tokens.spacing.step3),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: tokens.typography.lineHeight.caption,
            color: ShowcasePalette.mediumText(context),
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
        onTap: () => onTap!(summary),
        child: child,
      ),
    );
  }
}
