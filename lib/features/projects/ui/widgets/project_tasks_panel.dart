import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Triage rank for ordering the project detail task list: blocked first (needs
/// attention), then in-progress, then to-do, with finished work (done/rejected)
/// last — mirroring the overview's "what needs me" ordering.
int _taskStatusRank(TaskStatus status) => switch (status) {
  TaskBlocked() => 0,
  TaskInProgress() => 1,
  TaskOpen() || TaskGroomed() || TaskOnHold() => 2,
  TaskDone() || TaskRejected() => 3,
};

/// The alert-palette colour for a task status, used for the per-row status dot
/// so the task column scans by colour weight (blocked/red → in-progress/amber →
/// done/green → to-do/grey), echoing the overview's health vocabulary.
Color _taskStatusColor(BuildContext context, TaskStatus status) =>
    switch (status) {
      TaskBlocked() || TaskRejected() => ShowcasePalette.error(context),
      TaskInProgress() || TaskOnHold() => ShowcasePalette.amber(context),
      TaskDone() || TaskGroomed() => ShowcasePalette.timeGreen(context),
      TaskOpen() => ShowcasePalette.lowText(context),
    };

/// Returns [summaries] ordered by [_taskStatusRank], stable within a rank.
List<TaskSummary> triageSortedTaskSummaries(List<TaskSummary> summaries) {
  final indexed = [for (var i = 0; i < summaries.length; i++) (i, summaries[i])]
    ..sort((a, b) {
      final byRank = _taskStatusRank(
        a.$2.task.data.status,
      ).compareTo(_taskStatusRank(b.$2.task.data.status));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final entry in indexed) entry.$2];
}

/// The four triage buckets the detail task list is grouped under, in scan
/// order: blocked work that needs action, active work, queued work, finished
/// work. Each bucket owns one alert colour so the list reads as a triaged
/// board rather than a flat log.
enum TaskTriageGroup { needsAttention, inProgress, toDo, done }

/// Maps a task [status] to its triage bucket (blocked → needs attention,
/// in-progress → in progress, open/groomed/on-hold → to do, done/rejected →
/// done). Mirrors [_taskStatusRank] so a triage-sorted list groups contiguously.
TaskTriageGroup _taskTriageGroup(TaskStatus status) => switch (status) {
  TaskBlocked() => TaskTriageGroup.needsAttention,
  TaskInProgress() => TaskTriageGroup.inProgress,
  TaskOpen() || TaskGroomed() || TaskOnHold() => TaskTriageGroup.toDo,
  TaskDone() || TaskRejected() => TaskTriageGroup.done,
};

/// Partitions [summaries] into contiguous triage buckets in scan order,
/// preserving order within a bucket and omitting empty buckets. Pairs each
/// bucket with its [TaskTriageGroup] so the list renders one coloured header
/// per bucket. Sorts internally, so callers need not pre-sort.
List<(TaskTriageGroup, List<TaskSummary>)> partitionTaskTriageGroups(
  List<TaskSummary> summaries,
) {
  final groups = <(TaskTriageGroup, List<TaskSummary>)>[];
  for (final summary in triageSortedTaskSummaries(summaries)) {
    final group = _taskTriageGroup(summary.task.data.status);
    if (groups.isNotEmpty && groups.last.$1 == group) {
      groups.last.$2.add(summary);
    } else {
      groups.add((group, [summary]));
    }
  }
  return groups;
}

/// Label + dot colour for a triage [group] header. Colours echo the alert
/// vocabulary used by the per-row status dots and the overview.
(String, Color) taskTriageGroupAttributes(
  BuildContext context,
  TaskTriageGroup group,
) => switch (group) {
  TaskTriageGroup.needsAttention => (
    context.messages.projectShowcaseTaskGroupNeedsAttention,
    ShowcasePalette.error(context),
  ),
  TaskTriageGroup.inProgress => (
    context.messages.projectShowcaseTaskGroupInProgress,
    ShowcasePalette.amber(context),
  ),
  TaskTriageGroup.toDo => (
    context.messages.projectShowcaseTaskGroupToDo,
    ShowcasePalette.lowText(context),
  ),
  TaskTriageGroup.done => (
    context.messages.projectShowcaseTaskGroupDone,
    ShowcasePalette.timeGreen(context),
  ),
};

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
    final summaries = triageSortedTaskSummaries(
      record.highlightedTaskSummaries,
    );

    return ShowcasePanel(
      header: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: _ProjectTasksPanelHeader(record: record),
      ),
      itemCount: summaries.length,
      itemBuilder: (_, index) {
        final summary = summaries[index];
        return TaskSummaryRow(
          summary: summary,
          topInset: tokens.spacing.step2,
          bottomInset: index == summaries.length - 1 ? 0 : tokens.spacing.step2,
          onTap: onTaskTap,
        );
      },
    );
  }
}

/// Sliver form of [ProjectTasksPanel] for use inside a `CustomScrollView`.
///
/// Renders the same header (task count + total estimated duration) and
/// [TaskSummaryRow] list as a [DecoratedSliver] with manual dividers, so the
/// project detail body can scroll the task list as part of the outer scroll
/// view rather than nesting a second scrollable.
class ProjectTasksSliverPanel extends StatelessWidget {
  const ProjectTasksSliverPanel({
    required this.record,
    required this.categoryColor,
    this.onTaskTap,
    super.key,
  });

  final ProjectRecord record;

  /// Category colour used to tint the card surface, matching the overview.
  final Color categoryColor;
  final ValueChanged<TaskSummary>? onTaskTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Triage groups — blocked (needs attention) first, then in-progress,
    // to-do, done last — turn the flat task log into a triaged board: each
    // bucket gets a status-coloured header, so the page's largest region
    // scans by status instead of reading as one grey wall.
    final groups = partitionTaskTriageGroups(
      record.highlightedTaskSummaries,
    );

    return DecoratedSliver(
      decoration: BoxDecoration(
        // The task list stays neutral grey — it's the user's content but not
        // the coloured hero; the leading per-row status dots carry its colour.
        color: ShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step2,
                tokens.spacing.step5,
                tokens.spacing.step2,
              ),
              child: Row(
                children: [
                  // A category accent ties the task card to the project's
                  // colour (it can't carry a full sliver rail like the boxed
                  // Health/AI cards).
                  Container(
                    width: tokens.spacing.step1 + tokens.spacing.step1,
                    height: tokens.typography.lineHeight.subtitle1,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(tokens.radii.xs),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(child: _ProjectTasksPanelHeader(record: record)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              thickness: 1,
              color: ShowcasePalette.border(context),
            ),
          ),
          for (final (group, groupSummaries) in groups) ...[
            SliverToBoxAdapter(
              child: _TaskGroupHeader(
                group: group,
                count: groupSummaries.length,
              ),
            ),
            SliverList.builder(
              itemCount: groupSummaries.length,
              itemBuilder: (context, index) {
                final summary = groupSummaries[index];
                final isLastInGroup = index == groupSummaries.length - 1;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TaskSummaryRow(
                      summary: summary,
                      topInset: tokens.spacing.step2,
                      bottomInset: tokens.spacing.step2,
                      onTap: onTaskTap,
                    ),
                    // Hairline dividers separate rows WITHIN a bucket; the next
                    // coloured group header separates one bucket from the next.
                    if (!isLastInGroup) ...[
                      SizedBox(height: tokens.spacing.step2),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: ShowcasePalette.border(context),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                    ],
                  ],
                );
              },
            ),
          ],
          SliverToBoxAdapter(
            child: SizedBox(height: tokens.spacing.step3),
          ),
        ],
      ),
    );
  }
}

/// A status-coloured section header dividing the task list into triage buckets
/// ("Needs attention / In progress / To do / Done"), so the list's dominant
/// region reads as a triaged board rather than a flat log. Renders a coloured
/// dot, the bucket label, its count, and a trailing hairline rule.
class _TaskGroupHeader extends StatelessWidget {
  const _TaskGroupHeader({
    required this.group,
    required this.count,
  });

  final TaskTriageGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (label, color) = taskTriageGroupAttributes(context, group);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step2,
      ),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step2,
            height: tokens.spacing.step2,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label.toUpperCase(),
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            '$count',
            style: tokens.typography.styles.others.caption.copyWith(
              color: ShowcasePalette.mediumText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: ShowcasePalette.border(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTasksPanelHeader extends StatelessWidget {
  const _ProjectTasksPanelHeader({
    required this.record,
  });

  final ProjectRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
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
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
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
          color: ShowcasePalette.mediumText(context),
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          showcaseFormatDuration(
            record.highlightedTasksTotalDuration,
          ),
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: ShowcasePalette.mediumText(context),
          ),
        ),
      ],
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
    final oneLiner = widget.summary.oneLiner;

    final tokens = context.designTokens;
    // A blocked task carries a resting attention wash so the row that needs
    // action reads before its text does (same cue as the overview rows).
    final isBlocked = widget.summary.task.data.status is TaskBlocked;
    // Finished tasks recede (low-emphasis title) so the list scans as a
    // momentum queue; active work carries a heavier title.
    final isDone = widget.summary.task.data.status is TaskDone;
    final isUrgent =
        widget.summary.task.data.status is TaskBlocked ||
        widget.summary.task.data.status is TaskInProgress;
    final backgroundColor = _hovered
        ? ShowcasePalette.hoverFill(context)
        : isBlocked
        ? ShowcasePalette.attentionRowWash(context)
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
          // Two-zone row with a leading status dot: dot + title + agent
          // one-liner fill the left; status pill + estimate are right-aligned,
          // so the row uses the full width and the column scans by status colour.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step1),
                child: Container(
                  width: tokens.spacing.step3,
                  height: tokens.spacing.step3,
                  decoration: BoxDecoration(
                    color: _taskStatusColor(
                      context,
                      widget.summary.task.data.status,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.summary.task.data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: isDone
                            ? ShowcasePalette.lowText(context)
                            : ShowcasePalette.highText(context),
                        fontWeight: isUrgent
                            ? FontWeight.w600
                            : tokens.typography.weight.regular,
                      ),
                    ),
                    if (oneLiner != null && oneLiner.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.step1),
                      // The one-liner is AGENT-authored — a small teal sparkle
                      // marks it as AI, distinct from the user's own title.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: tokens.spacing.step1,
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              size: tokens.typography.size.caption,
                              color: ShowcasePalette.teal(context),
                            ),
                          ),
                          SizedBox(width: tokens.spacing.step1),
                          Expanded(
                            child: Text(
                              oneLiner,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: ShowcasePalette.lowText(context),
                                    fontWeight:
                                        tokens.typography.weight.regular,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TaskStatePill(
                    status: widget.summary.task.data.status,
                    compact: true,
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: tokens.typography.lineHeight.caption,
                        color: ShowcasePalette.lowText(context),
                      ),
                      SizedBox(width: tokens.spacing.step1),
                      Text(
                        showcaseFormatDuration(
                          widget.summary.estimatedDuration,
                        ),
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: ShowcasePalette.lowText(context),
                          fontWeight: tokens.typography.weight.regular,
                        ),
                      ),
                    ],
                  ),
                ],
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
