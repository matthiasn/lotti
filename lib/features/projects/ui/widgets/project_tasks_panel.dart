import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_groups.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The project's task list as a sliver: a header with the count, the total
/// estimate and the actions, then the tasks in collapsible groups.
///
/// Grouping and order come from [options] (creation month, newest first, by
/// default); [onOptionsChanged] wires the header's "Sort and group" control
/// and is omitted by read-only showcases. Finished tasks fold into one
/// trailing group that starts collapsed. Due-window groups re-evaluate at
/// local midnight while the panel stays mounted. The header survives a narrow pane, a phone
/// and large text: the title truncates before anything overflows, and in the
/// compact form (below [compactWidth], or at large text) the total estimate is
/// dropped and Add task turns icon-only.
class ProjectTasksSliverPanel extends StatefulWidget {
  const ProjectTasksSliverPanel({
    required this.record,
    required this.now,
    this.options = ProjectTaskListOptions.defaults,
    this.onOptionsChanged,
    this.onTaskTap,
    this.onAddTask,
    this.isAddTaskEnabled = true,
    this.isAddingTask = false,
    super.key,
  });

  /// Below this header width the header takes its compact form.
  ///
  /// Sits between a phone (a 430 pt screen leaves the header about 400 pt)
  /// and the narrowest desktop pane that still fits the full header: the
  /// list-and-detail showcase's 580 pt detail pane leaves it 516 pt, and the
  /// full header needs roughly 380 pt at the default text scale.
  static const double compactWidth = 480;

  /// From this text scale on the header takes its compact form at any width.
  static const double largeTextScale = 1.2;

  final ProjectRecord record;

  /// Reference time for the due-window groups.
  final DateTime now;
  final ProjectTaskListOptions options;
  final ValueChanged<ProjectTaskListOptions>? onOptionsChanged;
  final ValueChanged<TaskSummary>? onTaskTap;
  final VoidCallback? onAddTask;
  final bool isAddTaskEnabled;
  final bool isAddingTask;

  @override
  State<ProjectTasksSliverPanel> createState() =>
      _ProjectTasksSliverPanelState();
}

class _ProjectTasksSliverPanelState extends State<ProjectTasksSliverPanel> {
  /// Group ids the user folded; the trailing Done group starts folded.
  final _collapsed = <String>{const ProjectTaskDoneKey().id};

  /// The reference time for due windows: the host's [ProjectTasksSliverPanel.now]
  /// until local midnight passes while the panel stays mounted, then the
  /// clock's, so a task due yesterday moves to Overdue without waiting for an
  /// unrelated rebuild.
  late DateTime _now = widget.now;
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    _armDayTimer();
  }

  @override
  void didUpdateWidget(ProjectTasksSliverPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) _now = widget.now;
    if (oldWidget.now != widget.now ||
        oldWidget.options.groupBy != widget.options.groupBy) {
      _armDayTimer();
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  /// Only due windows depend on the date, so only that grouping keeps a
  /// timer; it re-arms itself for the following midnight after firing.
  void _armDayTimer() {
    _dayTimer?.cancel();
    _dayTimer = null;
    if (widget.options.groupBy != ProjectTaskGroupBy.dueWindow) return;
    final nextMidnight = DateTime(_now.year, _now.month, _now.day + 1);
    _dayTimer = Timer(
      nextMidnight.difference(_now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() => _now = clock.now());
        _armDayTimer();
      },
    );
  }

  void _toggle(ProjectTaskGroup group) {
    setState(() {
      if (!_collapsed.remove(group.key.id)) _collapsed.add(group.key.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final border = ShowcasePalette.border(context);
    final groups = groupProjectTasks(
      widget.record.highlightedTaskSummaries,
      options: widget.options,
      now: _now,
    );

    Widget divider() => Divider(
      height: BorderWidths.hairline,
      thickness: BorderWidths.hairline,
      color: border,
    );

    return DecoratedSliver(
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(color: border),
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
              child: _ProjectTasksPanelHeader(
                record: widget.record,
                onOptions: widget.onOptionsChanged == null
                    ? null
                    : () => widget.onOptionsChanged!(widget.options),
                onAddTask: widget.onAddTask,
                isAddTaskEnabled: widget.isAddTaskEnabled,
                isAddingTask: widget.isAddingTask,
              ),
            ),
          ),
          SliverToBoxAdapter(child: divider()),
          for (final (groupIndex, group) in groups.indexed) ...[
            if (group.hasHeader)
              SliverToBoxAdapter(
                child: _ProjectTaskGroupHeader(
                  key: ValueKey('project-task-group-${group.key.id}'),
                  group: group,
                  expanded: !_collapsed.contains(group.key.id),
                  onToggle: () => _toggle(group),
                ),
              )
            else if (group.tasks.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.step2)),
            if (!_collapsed.contains(group.key.id))
              SliverList.builder(
                itemCount: group.tasks.length,
                // Rows carry the task id so a row's element (and its hover
                // state) follows the task when a sort or grouping change
                // reorders the group, instead of staying with the index.
                findChildIndexCallback: (key) {
                  final index = group.tasks.indexWhere(
                    (summary) => projectTaskRowKey(summary) == key,
                  );
                  return index < 0 ? null : index;
                },
                itemBuilder: (context, index) {
                  final summary = group.tasks[index];
                  final last = index == group.tasks.length - 1;
                  return Column(
                    key: projectTaskRowKey(summary),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TaskSummaryRow(
                        summary: summary,
                        topInset: tokens.spacing.step2,
                        bottomInset: last ? 0 : tokens.spacing.step2,
                        onTap: widget.onTaskTap,
                      ),
                      if (!last) ...[
                        SizedBox(height: tokens.spacing.step2),
                        divider(),
                        SizedBox(height: tokens.spacing.step2),
                      ] else if (groupIndex < groups.length - 1) ...[
                        SizedBox(height: tokens.spacing.step2),
                        divider(),
                      ],
                    ],
                  );
                },
              )
            else if (groupIndex < groups.length - 1)
              SliverToBoxAdapter(child: divider()),
          ],
        ],
      ),
    );
  }
}

class _ProjectTasksPanelHeader extends StatelessWidget {
  const _ProjectTasksPanelHeader({
    required this.record,
    this.onOptions,
    this.onAddTask,
    this.isAddTaskEnabled = true,
    this.isAddingTask = false,
  });

  final ProjectRecord record;
  final VoidCallback? onOptions;
  final VoidCallback? onAddTask;
  final bool isAddTaskEnabled;
  final bool isAddingTask;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale >= ProjectTasksSliverPanel.largeTextScale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < ProjectTasksSliverPanel.compactWidth ||
            largeText;
        // The compact header keeps the title whole and lets the group headers
        // carry the estimates; the total would only push the title into an
        // ellipsis.
        final showDuration = !compact;
        final addTaskEnabled = !isAddingTask && isAddTaskEnabled;
        return Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  messages.projectShowcaseProjectTasksTab,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: ShowcasePalette.highText(context),
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            CountDotBadge(count: record.highlightedTaskSummaries.length),
            if (showDuration) ...[
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LottiIcons.timer,
                      size: tokens.typography.lineHeight.caption,
                      color: ShowcasePalette.timeGreen(context),
                    ),
                    SizedBox(width: tokens.spacing.step1),
                    Flexible(
                      child: Text(
                        showcaseFormatDuration(
                          record.highlightedTasksTotalDuration,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: ShowcasePalette.timeGreen(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            if (onOptions != null)
              DesignSystemIconAction(
                icon: LottiIcons.sort,
                tooltip: messages.projectTasksSortAndGroup,
                onPressed: onOptions,
              ),
            if (onAddTask != null) ...[
              SizedBox(width: tokens.spacing.step2),
              if (compact)
                DesignSystemIconAction(
                  icon: LottiIcons.add,
                  tooltip: messages.projectActionAddTask,
                  isBusy: isAddingTask,
                  onPressed: addTaskEnabled ? onAddTask : null,
                )
              else
                DesignSystemButton(
                  label: messages.projectActionAddTask,
                  leadingIcon: LottiIcons.add,
                  variant: DesignSystemButtonVariant.secondary,
                  size: DesignSystemButtonSize.dense,
                  tapTargetSize: MaterialTapTargetSize.padded,
                  isLoading: isAddingTask,
                  onPressed: addTaskEnabled ? onAddTask : null,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// A collapsible group heading: chevron, name, task count and total estimate.
class _ProjectTaskGroupHeader extends StatelessWidget {
  const _ProjectTaskGroupHeader({
    required this.group,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final ProjectTaskGroup group;
  final bool expanded;
  final VoidCallback onToggle;

  String _label(BuildContext context) {
    final messages = context.messages;
    return switch (group.key) {
      ProjectTaskMonthKey(:final firstDay) => DateFormat.yMMMM(
        Localizations.localeOf(context).toString(),
      ).format(firstDay),
      ProjectTaskStatusKey(:final status) => status.localizedLabel(context),
      ProjectTaskPriorityKey(:final priority) => priority.localizedLabel(
        context,
      ),
      ProjectTaskDueWindowKey(:final window) => switch (window) {
        ProjectDueWindow.overdue => messages.projectTasksDueOverdue,
        ProjectDueWindow.thisWeek => messages.projectTasksDueThisWeek,
        ProjectDueWindow.later => messages.projectTasksDueLater,
        ProjectDueWindow.none => messages.projectTasksDueNone,
      },
      ProjectTaskDoneKey() => messages.projectTasksGroupDone,
      ProjectTaskAllKey() => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final meta = tokens.typography.styles.others.caption.copyWith(
      color: ShowcasePalette.lowText(context),
    );
    final duration = group.totalDuration;
    return Semantics(
      button: true,
      expanded: expanded,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ShowcasePalette.border(context)),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step5,
              vertical: tokens.spacing.step3,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? LottiIcons.chevronDown : LottiIcons.chevronRight,
                  size: IconSizes.s,
                  color: ShowcasePalette.mediumText(context),
                ),
                SizedBox(width: tokens.spacing.step2),
                Flexible(
                  child: Text(
                    _label(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: ShowcasePalette.highText(context),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                Text(
                  '· ${context.messages.projectTasksGroupCount(group.tasks.length)}',
                  style: meta,
                ),
                if (duration > Duration.zero) ...[
                  SizedBox(width: tokens.spacing.step2),
                  Flexible(
                    child: Text(
                      '· ${showcaseFormatDuration(duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The key of the task list row that shows [summary], unique per task.
Key projectTaskRowKey(TaskSummary summary) =>
    ValueKey('project-task-row-${summary.task.meta.id}');

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
                                  color: ShowcasePalette.lowText(context),
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
                        if (widget.summary.estimatedDuration > Duration.zero)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LottiIcons.timer,
                                size: tokens.typography.lineHeight.caption,
                                color: ShowcasePalette.lowText(context),
                              ),
                              SizedBox(width: tokens.spacing.step1),
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
