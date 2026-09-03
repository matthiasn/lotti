import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_pickers.dart';
import 'package:lotti/features/tasks/ui/widgets/task_ai_cost_indicator.dart';
import 'package:lotti/features/tasks/ui/widgets/task_estimate_progress_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// How a [TaskMetaSection] lays its rows out.
enum TaskMetaDensity {
  /// Label column and value column side by side, on one shared label width so
  /// the values align into a scannable second column. The fly-out's measure.
  wide,

  /// Label above value, with no fixed label width. The details column is
  /// `kTaskMetaColumnWidth` wide, and a fixed label column there would either
  /// starve the values or clip a long localized label — "Fälligkeitsdatum"
  /// does not fit beside its own date in 320 points.
  narrow,
}

/// The task metadata **section**: every attribute as a descriptive
/// **label + value** row, each still editable in place through the shared
/// pickers ([TaskMetaPickers]).
///
/// One section, two hosts. It is the body of the metadata fly-out
/// (`TaskMetaFlyout`) on narrow layouts, and the content of the persistent
/// details column (`TaskMetaColumn`) when a focused task has a wide enough
/// window beside it. [TaskMetaDensity] is the only difference between them.
///
/// Metadata is set once and rarely changed, so it does not earn permanent
/// button-styled chrome inside the page body — the header keeps a compact
/// read-only summary and this section holds the full detail plus the editing
/// affordances.
///
/// Watches the task so every row reflects an edit the moment the picker
/// persists it, while the host stays open.
class TaskMetaSection extends ConsumerWidget {
  const TaskMetaSection({
    required this.taskId,
    this.density = TaskMetaDensity.wide,
    this.onStatusPicked,
    super.key,
  });

  final String taskId;

  /// How the rows lay out. See [TaskMetaDensity].
  final TaskMetaDensity density;

  /// Dismisses the surface hosting this section, called the instant the status
  /// picker returns a choice.
  ///
  /// Only the status row reports back: it is the one attribute whose write
  /// plays a celebration on the header behind this section, and a panel left
  /// standing over it dims the moment it exists to mark. A dismissible host
  /// (the fly-out) passes its own pop; the persistent details column has
  /// nothing to dismiss and passes nothing.
  final VoidCallback? onStatusPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when label definitions change (names, colours, visibility).
    ref.watch(labelsStreamProvider);
    final entryState = ref.watch(entryControllerProvider(taskId)).value;
    final task = entryState?.entry;
    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final messages = context.messages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TaskMetaFieldRow(
          density: density,
          label: stripTrailingColon(messages.taskStatusLabel),
          value: _StatusValue(status: task.data.status),
          onTap: () => TaskMetaPickers.showStatusPicker(
            context,
            ref,
            task,
            onStatusPicked: onStatusPicked,
          ),
        ),
        TaskMetaFieldRow(
          density: density,
          label: messages.taskMetaPriorityLabel,
          value: _PriorityValue(priority: task.data.priority),
          onTap: () => TaskMetaPickers.showPriorityPicker(context, ref, task),
        ),
        TaskMetaFieldRow(
          density: density,
          label: messages.habitCategoryLabel,
          value: _CategoryValue(categoryId: task.meta.categoryId),
          onTap: () => TaskMetaPickers.showCategoryPicker(context, ref, task),
        ),
        if (task.meta.categoryId case final categoryId?)
          TaskMetaFieldRow(
            density: density,
            label: messages.projectPickerLabel,
            value: _ProjectValue(taskId: taskId),
            onTap: () => TaskMetaPickers.showProjectPicker(
              context,
              ref,
              taskId: taskId,
              categoryId: categoryId,
              // `.value` keeps the picker's current selection through a
              // background reload (same rationale as _ProjectValue).
              current: ref.read(projectForTaskProvider(taskId)).value,
            ),
          ),
        TaskMetaFieldRow(
          density: density,
          label: messages.taskMetaDueDateLabel,
          value: _DueDateValue(task: task),
          onTap: () => TaskMetaPickers.showDueDatePicker(context, ref, task),
        ),
        TaskMetaFieldRow(
          density: density,
          label: messages.taskMetaEstimateLabel,
          value: _TimeValue(task: task),
          onTap: () =>
              TaskMetaPickers.showEstimatePickerForTask(context, ref, task),
        ),
        TaskMetaFieldRow(
          density: density,
          label: messages.taskMetaLabelsLabel,
          value: _LabelsValue(task: task),
          onTap: () => TaskMetaPickers.openLabelSelector(context, task),
        ),
        ..._aiSpendRow(context, ref),
      ],
    );
  }

  /// The AI-spend read-out — a fact about the task, not a setting, so the row
  /// carries no edit affordance and disappears entirely for tasks without
  /// recorded AI calls.
  ///
  /// The read-only indicator: the same leaf-and-amount component the task
  /// list rows carry, but without their tap. Here it already *is* the details
  /// that tap would open.
  List<Widget> _aiSpendRow(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(taskConsumptionTotalsProvider(taskId)).value;
    if (totals == null || totals.callCount == 0) return const [];
    return [
      TaskMetaFieldRow(
        density: density,
        label: context.messages.taskMetaAiSpendLabel,
        value: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TaskAiCostIndicator.readOnly(
            taskId: taskId,
            // The section owns a full row for this, so it spells the whole
            // story out: cost, energy, carbon.
            density: AiCostDensity.detail,
            foregroundColor: TaskShowcasePalette.mediumText(context),
          ),
        ),
      ),
    ];
  }
}

/// One label + value row. [onTap] adds the trailing chevron and makes the
/// whole row the hit target; without it the row is a plain read-out.
///
/// [density] decides whether label and value sit side by side or stack — see
/// [TaskMetaDensity]. Everything else about the row is shared, so the two
/// hosts cannot drift apart in behaviour, only in measure.
class TaskMetaFieldRow extends StatelessWidget {
  const TaskMetaFieldRow({
    required this.label,
    required this.value,
    this.density = TaskMetaDensity.wide,
    this.onTap,
    super.key,
  });

  final String label;
  final Widget value;
  final TaskMetaDensity density;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final labelText = Text(
      label,
      style: tokens.typography.styles.others.caption.copyWith(
        color: TaskShowcasePalette.mediumText(context),
      ),
    );

    Widget chevron({required bool highlighted}) => Icon(
      LottiIcons.chevronRight,
      size: IconSizes.s,
      // The chevron already marks the row as tappable; a hover fill across
      // the whole band made it a phantom button, so the chevron brightening
      // carries hover/focus/press instead.
      color: highlighted
          ? TaskShowcasePalette.highText(context)
          : TaskShowcasePalette.lowText(context),
    );

    Widget row({required bool highlighted}) => Padding(
      padding: EdgeInsets.symmetric(
        vertical: density == TaskMetaDensity.wide
            ? tokens.spacing.step4
            : tokens.spacing.step3,
        horizontal: tokens.spacing.step2,
      ),
      child: Row(
        children: [
          if (density == TaskMetaDensity.wide) ...[
            SizedBox(
              // One shared width for every row's label column (step12 = 96),
              // so the values align into a scannable second column.
              width: tokens.spacing.step12,
              child: labelText,
            ),
            SizedBox(width: tokens.spacing.step4),
            Expanded(child: value),
          ] else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  SizedBox(height: tokens.spacing.step1),
                  value,
                ],
              ),
            ),
          if (onTap != null) chevron(highlighted: highlighted),
        ],
      ),
    );

    if (onTap == null) return row(highlighted: false);
    return DsQuietInk(
      borderRadius: BorderRadius.circular(tokens.radii.s),
      onTap: onTap,
      builder: (context, highlighted) => row(highlighted: highlighted),
    );
  }
}

/// Shared style for the value column: high-emphasis body-small text.
TextStyle _valueStyle(BuildContext context) {
  final tokens = context.designTokens;
  return tokens.typography.styles.body.bodySmall.copyWith(
    color: TaskShowcasePalette.highText(context),
  );
}

TextStyle _unsetStyle(BuildContext context) {
  final tokens = context.designTokens;
  return tokens.typography.styles.body.bodySmall.copyWith(
    color: TaskShowcasePalette.lowText(context),
  );
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TaskShowcaseStatusGlyph(status: status),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            status.localizedLabel(context),
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(context),
          ),
        ),
      ],
    );
  }
}

class _PriorityValue extends StatelessWidget {
  const _PriorityValue({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TaskShowcasePriorityGlyph(priority: priority),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            priority.localizedLabel(context),
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(context),
          ),
        ),
      ],
    );
  }
}

class _CategoryValue extends StatelessWidget {
  const _CategoryValue({required this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);
    if (category == null) {
      return Text(
        context.messages.taskMetaValueNotSet,
        style: _unsetStyle(context),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colorFromCssHex(
              category.color,
              substitute: Theme.of(context).colorScheme.primary,
            ),
            // Matches the breadcrumb's 10×10 category square.
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            category.name,
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(context),
          ),
        ),
      ],
    );
  }
}

class _ProjectValue extends ConsumerWidget {
  const _ProjectValue({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`, not `.asData`: a background invalidation (task or project
    // notification) re-enters loading while retaining the previous value,
    // and an established project must not flash "No project" during it.
    final project = ref.watch(projectForTaskProvider(taskId)).value;
    if (project == null) {
      return Text(
        context.messages.projectPickerUnassigned,
        style: _unsetStyle(context),
      );
    }
    return Text(
      project.data.title,
      overflow: TextOverflow.ellipsis,
      style: _valueStyle(context),
    );
  }
}

class _DueDateValue extends StatelessWidget {
  const _DueDateValue({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final due = task.data.due;
    if (due == null) {
      return Text(
        context.messages.taskMetaValueNotSet,
        style: _unsetStyle(context),
      );
    }
    final isClosed =
        task.data.status is TaskDone || task.data.status is TaskRejected;
    final urgency = isClosed
        ? DueDateUrgency.normal
        : getDueDateStatus(dueDate: due, referenceDate: clock.now()).urgency;
    final color = switch (urgency) {
      DueDateUrgency.overdue => TaskShowcasePalette.error(context),
      DueDateUrgency.dueToday => TaskShowcasePalette.warning(context),
      DueDateUrgency.normal => TaskShowcasePalette.highText(context),
    };
    final label = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(due);
    return Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: _valueStyle(context).copyWith(color: color),
    );
  }
}

/// Tracked-of-estimated read-out with the same small progress bar the header
/// estimate tag carries, or "Not set" when the task has no estimate.
class _TimeValue extends ConsumerWidget {
  const _TimeValue({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = task.data.estimate;
    final hasEstimate = estimate != null && estimate != Duration.zero;
    if (!hasEstimate) {
      return Text(
        context.messages.taskMetaValueNotSet,
        style: _unsetStyle(context),
      );
    }

    final tokens = context.designTokens;
    final progressState = ref
        .watch(taskProgressControllerProvider(task.meta.id))
        .value;
    final progress = progressState?.progress ?? Duration.zero;
    final isOvertime = TaskEstimateProgressBar.isOvertime(
      tracked: progress,
      estimate: estimate,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.messages.taskEstimateProgressLabel(
              formatRangeDuration(progress),
              formatRangeDuration(estimate),
            ),
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(context).copyWith(
              color: isOvertime
                  ? TaskShowcasePalette.error(context)
                  : TaskShowcasePalette.highText(context),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        TaskEstimateProgressBar(tracked: progress, estimate: estimate),
      ],
    );
  }
}

class _LabelsValue extends StatelessWidget {
  const _LabelsValue({required this.task});

  final Task task;

  /// How many label names spell out before the remainder compress to "+N".
  static const int _maxNamed = 3;

  @override
  Widget build(BuildContext context) {
    final cache = getIt<EntitiesCacheService>();
    final showPrivate = cache.showPrivateEntries;
    final labels = <LabelDefinition>[];
    for (final id in task.meta.labelIds ?? const <String>[]) {
      final def = cache.getLabelById(id);
      if (def == null) continue;
      if (!showPrivate && (def.private ?? false)) continue;
      labels.add(def);
    }
    if (labels.isEmpty) {
      return Text(
        context.messages.taskMetaValueNotSet,
        style: _unsetStyle(context),
      );
    }
    labels.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    final named = labels.take(_maxNamed).map((label) => label.name);
    final overflow = labels.length - _maxNamed;
    final text = overflow > 0
        ? '${named.join(', ')} '
              '${context.messages.taskLabelsMoreCount(overflow)}'
        : named.join(', ');
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: _valueStyle(context),
    );
  }
}
