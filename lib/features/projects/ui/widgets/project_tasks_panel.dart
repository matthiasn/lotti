import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A panel listing highlighted tasks for a project with total duration.
class ProjectTasksPanel extends StatelessWidget {
  const ProjectTasksPanel({required this.record, super.key});

  final ProjectRecord record;

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
                const SizedBox(width: 8),
                CountDotBadge(
                  count: record.highlightedTaskSummaries.length,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: ShowcasePalette.timeGreen(context),
          ),
          const SizedBox(width: 2),
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
      itemBuilder: (_, index) =>
          TaskSummaryRow(summary: record.highlightedTaskSummaries[index]),
    );
  }
}

/// A row displaying a single task's title, estimated duration, and status.
class TaskSummaryRow extends StatelessWidget {
  const TaskSummaryRow({required this.summary, super.key});

  final TaskSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: ShowcasePalette.lowText(context),
                    ),
                    const SizedBox(width: 2),
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
          const SizedBox(width: 12),
          TaskStatePill(status: summary.task.data.status),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: ShowcasePalette.mediumText(context),
          ),
        ],
      ),
    );
  }
}
