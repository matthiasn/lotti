import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/popovers/design_system_popover_anchor.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_groups.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/features/projects/ui/widgets/project_task_list_options_sheet.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// Asks the task list to focus [taskId]: scroll to it and light it up, or
/// with `scroll: false` only light it up where it is.
typedef ProjectTaskFocusRequest = void Function(String taskId, {bool scroll});

/// A request to bring one task's row into view and light it up.
///
/// Each request carries a fresh [request] number so asking for the same task
/// twice scrolls twice. With [scroll] off the row is only highlighted where
/// it is — the way a task just created from a next step is marked without
/// pulling the page away from the band that created it.
@immutable
class ProjectTaskFocus {
  const ProjectTaskFocus({
    required this.taskId,
    required this.request,
    this.scroll = true,
  });

  final String taskId;
  final int request;
  final bool scroll;

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskFocus &&
      other.taskId == taskId &&
      other.request == request &&
      other.scroll == scroll;

  @override
  int get hashCode => Object.hash(taskId, request, scroll);
}

/// The project's task list as a sliver: a header with the count, the total
/// estimate and the actions, then the tasks in collapsible groups whose
/// headers stay pinned while their group scrolls past.
///
/// Grouping, order and which groups are folded come from [options] (creation
/// month, newest first, Done folded, by default); [onOptionsChanged] receives
/// every change — a pick in the "Sort and group" control, a group folded or
/// unfolded — and is omitted by read-only showcases, which then show no
/// control and keep folds to themselves. The control opens as a popover on a
/// desktop-wide screen and as the shared sheet elsewhere. Finished tasks fold
/// into one trailing group. Due-window groups re-evaluate at local midnight
/// while the panel stays mounted. [focus] scrolls to and highlights one task
/// on request. The header survives a narrow pane, a phone and large text:
/// the title truncates before anything overflows, and in the compact form
/// (below [compactWidth], or at large text) the total estimate is dropped and
/// Add task turns icon-only.
class ProjectTasksSliverPanel extends StatefulWidget {
  const ProjectTasksSliverPanel({
    required this.record,
    required this.now,
    this.options = ProjectTaskListOptions.defaults,
    this.onOptionsChanged,
    this.focus,
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

  /// How long a focused row stays lit.
  static const Duration highlightDuration = Duration(seconds: 3);

  /// How many frames a scroll request keeps looking for a row that the lazy
  /// list has not built yet, stepping a viewport further each time.
  static const int maxScrollAttempts = 12;

  final ProjectRecord record;

  /// Reference time for the due-window groups.
  final DateTime now;
  final ProjectTaskListOptions options;
  final ValueChanged<ProjectTaskListOptions>? onOptionsChanged;
  final ProjectTaskFocus? focus;
  final ValueChanged<TaskSummary>? onTaskTap;
  final VoidCallback? onAddTask;
  final bool isAddTaskEnabled;
  final bool isAddingTask;

  @override
  State<ProjectTasksSliverPanel> createState() =>
      _ProjectTasksSliverPanelState();
}

class _ProjectTasksSliverPanelState extends State<ProjectTasksSliverPanel> {
  /// Folds made while the host offers no [ProjectTasksSliverPanel.onOptionsChanged]
  /// live here; otherwise the host's options are the only truth.
  ProjectTaskListOptions? _localOptions;

  ProjectTaskListOptions get _options => _localOptions ?? widget.options;

  String? _highlightedTaskId;
  Timer? _highlightTimer;
  int _scrollAttempts = 0;

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
    if (widget.focus case final focus?) _focus(focus);
  }

  @override
  void didUpdateWidget(ProjectTasksSliverPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) _now = widget.now;
    if (oldWidget.now != widget.now ||
        oldWidget.options.groupBy != widget.options.groupBy) {
      _armDayTimer();
    }
    if (oldWidget.options != widget.options) _localOptions = null;
    if (widget.focus case final focus? when focus != oldWidget.focus) {
      _focus(focus);
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  List<ProjectTaskGroup> _groups() => groupProjectTasks(
    widget.record.highlightedTaskSummaries,
    options: _options,
    now: _now,
  );

  void _focus(ProjectTaskFocus focus) {
    _highlightTimer?.cancel();
    _highlightedTaskId = focus.taskId;
    _highlightTimer = Timer(ProjectTasksSliverPanel.highlightDuration, () {
      if (!mounted) return;
      setState(() => _highlightedTaskId = null);
    });
    if (!focus.scroll) return;
    final group = _groups().firstWhereOrNull(
      (ProjectTaskGroup group) => group.tasks.any(
        (TaskSummary summary) => summary.task.meta.id == focus.taskId,
      ),
    );
    if (group == null) return;
    if (_options.isCollapsed(group.key.id)) {
      _setOptions(_options.toggleCollapsed(group.key.id));
    }
    _scrollAttempts = 0;
    _scrollToRow(focus.taskId, group.key.id);
  }

  /// Brings the row for [taskId] into view once the lazy list has built it.
  ///
  /// Group headers are always built, so the first attempt jumps to the
  /// group's header, which builds the rows after it; each later attempt steps
  /// one viewport further until the row exists or the attempts run out.
  void _scrollToRow(String taskId, String groupId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final row = _findContext(ValueKey('project-task-row-$taskId'));
      if (row != null) {
        Scrollable.ensureVisible(
          row,
          alignment: 0.2,
          duration: MotionDurations.medium2,
          curve: MotionCurves.standard,
        );
        return;
      }
      if (_scrollAttempts++ >= ProjectTasksSliverPanel.maxScrollAttempts) {
        return;
      }
      if (_scrollAttempts == 1) {
        final header = _findContext(ValueKey('project-task-group-$groupId'));
        if (header != null) Scrollable.ensureVisible(header);
      } else if (Scrollable.maybeOf(context)?.position case final position?) {
        position.jumpTo(
          (position.pixels + position.viewportDimension).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
      _scrollToRow(taskId, groupId);
    });
  }

  BuildContext? _findContext(Key key) {
    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == key) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  void _setOptions(ProjectTaskListOptions next) {
    if (widget.onOptionsChanged case final apply?) {
      apply(next);
    } else {
      setState(() => _localOptions = next);
    }
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

  void _toggle(ProjectTaskGroup group) =>
      _setOptions(_options.toggleCollapsed(group.key.id));

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final border = ShowcasePalette.border(context);
    final groups = _groups();

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
                options: _options,
                onOptionsChanged: widget.onOptionsChanged,
                onAddTask: widget.onAddTask,
                isAddTaskEnabled: widget.isAddTaskEnabled,
                isAddingTask: widget.isAddingTask,
              ),
            ),
          ),
          SliverToBoxAdapter(child: divider()),
          for (final (groupIndex, group) in groups.indexed)
            MultiSliver(
              // A group's header stays pinned while its rows scroll past and
              // is pushed out by the next group's header.
              pushPinnedChildren: true,
              children: [
                if (group.hasHeader)
                  SliverPinnedHeader(
                    child: _ProjectTaskGroupHeader(
                      key: ValueKey('project-task-group-${group.key.id}'),
                      group: group,
                      expanded: !_options.isCollapsed(group.key.id),
                      onToggle: () => _toggle(group),
                    ),
                  )
                else if (group.tasks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(height: tokens.spacing.step2),
                  ),
                if (!_options.isCollapsed(group.key.id))
                  SliverList.builder(
                    itemCount: group.tasks.length,
                    // Rows carry the task id so a row's element (and its
                    // hover state) follows the task when a sort or grouping
                    // change reorders the group, instead of staying with the
                    // index.
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
                            highlighted:
                                summary.task.meta.id == _highlightedTaskId,
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
            ),
        ],
      ),
    );
  }
}

class _ProjectTasksPanelHeader extends StatelessWidget {
  const _ProjectTasksPanelHeader({
    required this.record,
    required this.options,
    this.onOptionsChanged,
    this.onAddTask,
    this.isAddTaskEnabled = true,
    this.isAddingTask = false,
  });

  final ProjectRecord record;
  final ProjectTaskListOptions options;
  final ValueChanged<ProjectTaskListOptions>? onOptionsChanged;
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
            if (onOptionsChanged case final onChanged?)
              if (MediaQuery.sizeOf(context).width >= kDesktopBreakpoint)
                DesignSystemPopoverAnchor(
                  semanticsLabel: messages.projectTasksSortAndGroup,
                  builder: (context, {required toggle, required isOpen}) =>
                      DesignSystemIconAction(
                        icon: LottiIcons.sort,
                        tooltip: messages.projectTasksSortAndGroup,
                        onPressed: toggle,
                      ),
                  child: ProjectTaskListOptionsSheetContent(
                    options: options,
                    onChanged: onChanged,
                  ),
                )
              else
                DesignSystemIconAction(
                  icon: LottiIcons.sort,
                  tooltip: messages.projectTasksSortAndGroup,
                  onPressed: () => showProjectTaskListOptionsSheet(
                    context: context,
                    options: options,
                    onChanged: onChanged,
                  ),
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

/// The human label of a task group's [key], localized for [context].
///
/// The ungrouped set ([ProjectTaskAllKey]) never gets a header, so it has no
/// label.
String projectTaskGroupLabel(BuildContext context, ProjectTaskGroupKey key) {
  final messages = context.messages;
  return switch (key) {
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
              // Opaque: the header stays pinned while rows scroll beneath it.
              color: ShowcasePalette.surface(context),
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
                    projectTaskGroupLabel(context, group.key),
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
///
/// [highlighted] paints the hover wash without a pointer, for the row the
/// list was just asked to bring into view.
class TaskSummaryRow extends StatelessWidget {
  const TaskSummaryRow({
    required this.summary,
    this.topInset = 0,
    this.bottomInset = 0,
    this.highlighted = false,
    this.onTap,
    super.key,
  });

  final TaskSummary summary;
  final double topInset;
  final double bottomInset;
  final bool highlighted;
  final ValueChanged<TaskSummary>? onTap;

  @override
  Widget build(BuildContext context) {
    return _TaskSummaryRowSurface(
      summary: summary,
      topInset: topInset,
      bottomInset: bottomInset,
      highlighted: highlighted,
      onTap: onTap,
    );
  }
}

class _TaskSummaryRowSurface extends StatefulWidget {
  const _TaskSummaryRowSurface({
    required this.summary,
    required this.topInset,
    required this.bottomInset,
    required this.highlighted,
    this.onTap,
  });

  final TaskSummary summary;
  final double topInset;
  final double bottomInset;
  final bool highlighted;
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
    final backgroundColor = _hovered || widget.highlighted
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
