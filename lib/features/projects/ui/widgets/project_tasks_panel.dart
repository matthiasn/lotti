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
      header: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
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
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: ShowcasePalette.highText(context),
                          ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  CountDotBadge(
                    count: record.highlightedTaskSummaries.length,
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
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
      ),
      itemCount: record.highlightedTaskSummaries.length,
      itemBuilder: (_, index) {
        final summary = record.highlightedTaskSummaries[index];
        return TaskSummaryRow(
          summary: summary,
          topInset: tokens.spacing.step2,
          bottomInset: index == record.highlightedTaskSummaries.length - 1
              ? 0
              : tokens.spacing.step2,
          onTap: onTaskTap,
        );
      },
    );
  }
}

/// A row displaying a single task's title, estimated duration, and status.
class TaskSummaryRow extends StatelessWidget {
  const TaskSummaryRow({
    required this.summary,
    this.topInset = 0,
    this.bottomInset = 0,
    this.onTap,
    super.key,
  });

  final TaskSummary summary;
  final double topInset;
  final double bottomInset;
  final ValueChanged<TaskSummary>? onTap;

  @override
  Widget build(BuildContext context) {
    return _TaskSummaryRowSurface(
      summary: summary,
      topInset: topInset,
      bottomInset: bottomInset,
      onTap: onTap,
    );
  }
}

class _TaskSummaryRowSurface extends StatefulWidget {
  const _TaskSummaryRowSurface({
    required this.summary,
    required this.topInset,
    required this.bottomInset,
    this.onTap,
  });

  final TaskSummary summary;
  final double topInset;
  final double bottomInset;
  final ValueChanged<TaskSummary>? onTap;

  @override
  State<_TaskSummaryRowSurface> createState() => _TaskSummaryRowSurfaceState();
}

class _TaskSummaryRowSurfaceState extends State<_TaskSummaryRowSurface> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final oneLiner = widget.summary.oneLiner?.trim();

    final tokens = context.designTokens;
    final backgroundColor = _hovered
        ? ShowcasePalette.hoverFill(context)
        : null;

    final child = Stack(
      clipBehavior: Clip.none,
      children: [
        if (backgroundColor != null)
          Positioned(
            top: -widget.topInset,
            right: 0,
            bottom: -widget.bottomInset,
            left: 0,
            child: DecoratedBox(
              key: ValueKey(
                'task-summary-row-background-${widget.summary.task.meta.id}',
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
            ),
          ),
        Padding(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.summary.task.data.title,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: ShowcasePalette.highText(context),
                                fontWeight: tokens.typography.weight.regular,
                              ),
                        ),
                        if (oneLiner != null && oneLiner.isNotEmpty) ...[
                          SizedBox(height: tokens.spacing.step1),
                          Text(
                            oneLiner,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: ShowcasePalette.highText(
                                    context,
                                  ).withValues(alpha: 0.32),
                                  fontWeight: tokens.typography.weight.regular,
                                ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step4),
                    Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: ShowcasePalette.lowText(context),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              showcaseFormatDuration(
                                widget.summary.estimatedDuration,
                              ),
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: ShowcasePalette.lowText(context),
                                    fontWeight:
                                        tokens.typography.weight.regular,
                                  ),
                            ),
                          ],
                        ),
                        TaskStatePill(
                          status: widget.summary.task.data.status,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: tokens.typography.lineHeight.caption,
                color: ShowcasePalette.mediumText(context),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTap!(widget.summary),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onHover: (value) {
          if (_hovered != value) {
            setState(() {
              _hovered = value;
            });
          }
        },
        child: child,
      ),
    );
  }
}
