import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_pickers.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The task metadata fly-out: every attribute as a descriptive
/// **label + value** row, each still editable in place through the shared
/// pickers ([TaskMetaPickers]).
///
/// This panel replaces the always-visible pill lanes the header used to
/// carry. Metadata is set once and rarely changed, so it does not earn
/// permanent button-styled chrome on the page — the header keeps a compact
/// read-only summary and this fly-out holds the full detail plus the editing
/// affordances.
class TaskMetaFlyout {
  const TaskMetaFlyout._();

  /// Opens the fly-out for [taskId] near the header ("Details" affordance).
  static Future<void> show(BuildContext context, {required String taskId}) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.taskMetaSheetTitle,
      builder: (_) => TaskMetaFlyoutContent(taskId: taskId),
    );
  }
}

/// The fly-out body. Watches the task so every row reflects an edit the
/// moment the picker persists it, while the fly-out stays open.
class TaskMetaFlyoutContent extends ConsumerWidget {
  const TaskMetaFlyoutContent({required this.taskId, super.key});

  final String taskId;

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
          label: stripTrailingColon(messages.taskStatusLabel),
          value: _StatusValue(status: task.data.status),
          onTap: () => TaskMetaPickers.showStatusPicker(context, ref, task),
        ),
        TaskMetaFieldRow(
          label: messages.taskMetaPriorityLabel,
          value: _PriorityValue(priority: task.data.priority),
          onTap: () => TaskMetaPickers.showPriorityPicker(context, ref, task),
        ),
        TaskMetaFieldRow(
          label: messages.habitCategoryLabel,
          value: _CategoryValue(categoryId: task.meta.categoryId),
          onTap: () => TaskMetaPickers.showCategoryPicker(context, ref, task),
        ),
        if (task.meta.categoryId case final categoryId?)
          TaskMetaFieldRow(
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
          label: messages.taskMetaDueDateLabel,
          value: _DueDateValue(task: task),
          onTap: () => TaskMetaPickers.showDueDatePicker(context, ref, task),
        ),
        TaskMetaFieldRow(
          label: messages.taskMetaTimeLabel,
          value: _TimeValue(task: task),
          onTap: () =>
              TaskMetaPickers.showEstimatePickerForTask(context, ref, task),
        ),
        TaskMetaFieldRow(
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
  /// recorded AI calls (matching the header chip it replaces).
  List<Widget> _aiSpendRow(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(taskConsumptionTotalsProvider(taskId)).value;
    if (totals == null || totals.callCount == 0) return const [];
    return [
      TaskMetaFieldRow(
        label: context.messages.taskMetaAiSpendLabel,
        value: ConsumptionSummaryPill(
          totals: totals,
          foregroundColor: TaskShowcasePalette.mediumText(context),
        ),
      ),
    ];
  }
}

/// One label + value row. [onTap] adds the trailing chevron and makes the
/// whole row the hit target; without it the row is a plain read-out.
class TaskMetaFieldRow extends StatelessWidget {
  const TaskMetaFieldRow({
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final row = Padding(
      padding: EdgeInsets.symmetric(
        vertical: tokens.spacing.step4,
        horizontal: tokens.spacing.step2,
      ),
      child: Row(
        children: [
          SizedBox(
            // One shared width for every row's label column (step12 = 96),
            // so the values align into a scannable second column.
            width: tokens.spacing.step12,
            child: Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: TaskShowcasePalette.mediumText(context),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(child: value),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: IconSizes.s,
              color: TaskShowcasePalette.lowText(context),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        onTap: onTap,
        child: row,
      ),
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
/// chip used to carry, or "Not set" when the task has no estimate.
class _TimeValue extends ConsumerWidget {
  const _TimeValue({required this.task});

  final Task task;

  /// Formats a duration as plain units ("1h 30m", "45m", "2h") rather than a
  /// zero-padded clock — see the estimate chip this replaces.
  static String format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

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
    final isOvertime = progress > estimate;
    final progressValue = estimate.inSeconds > 0
        ? math.min(progress.inSeconds / estimate.inSeconds, 1).toDouble()
        : 0.0;
    final barTrack = isOvertime
        ? TaskShowcasePalette.error(context).withValues(alpha: 0.2)
        : TaskShowcasePalette.lowText(context).withValues(alpha: 0.2);
    final barFill = isOvertime
        ? TaskShowcasePalette.error(context)
        : TaskShowcasePalette.success(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.messages.taskEstimateProgressLabel(
              format(progress),
              format(estimate),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          // The same 36×6 bar the old header estimate chip carried — kept
          // verbatim so the read-out is visually continuous with what it
          // replaced (no sizing token matches a 6px bar height).
          child: SizedBox(
            width: 36,
            height: 6,
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: barTrack,
              color: barFill,
            ),
          ),
        ),
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
